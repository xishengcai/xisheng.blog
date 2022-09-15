# gocraft/work

gocraft/work lets you enqueue and processes background jobs in Go. Jobs are durable and backed by Redis. Very similar to Sidekiq for Go.

- Fast and efficient. Faster than [this](https://www.github.com/jrallison/go-workers), [this](https://www.github.com/benmanns/goworker), and [this](https://www.github.com/albrow/jobs). See below for benchmarks.
- Reliable - don't lose jobs even if your process crashes.
- Middleware on jobs -- good for metrics instrumentation, logging, etc.
- If a job fails, it will be retried a specified number of times.
- Schedule jobs to happen in the future.
- Enqueue unique jobs so that only one job with a given name/arguments exists in the queue at once.
- Web UI to manage failed jobs and observe the system.
- Periodically enqueue jobs on a cron-like schedule.
- Pause / unpause jobs and control concurrency within and across processes

#### Enqueue new jobs

To enqueue jobs, you need to make an Enqueuer with a redis namespace and a redigo pool. Each enqueued job has a name and can take optional arguments. Arguments are k/v pairs (serialized as JSON internally).

```go
package main

import (
	"github.com/gomodule/redigo/redis"
	"github.com/gocraft/work"
)

// Make a redis pool
var redisPool = &redis.Pool{
	MaxActive: 5,
	MaxIdle: 5,
	Wait: true,
	Dial: func() (redis.Conn, error) {
		return redis.Dial("tcp", ":6379")
	},
}

// Make an enqueuer with a particular namespace
var enqueuer = work.NewEnqueuer("my_app_namespace", redisPool)

func main() {
	// Enqueue a job named "send_email" with the specified parameters.
	_, err := enqueuer.Enqueue("send_email", work.Q{"address": "test@example.com", "subject": "hello world", "customer_id": 4})
	if err != nil {
		log.Fatal(err)
	}
}
```

#### Process jobs

In order to process jobs, you'll need to make a WorkerPool. Add middleware and jobs to the pool, and start the pool.

```go
package main

import (
	"github.com/gomodule/redigo/redis"
	"github.com/gocraft/work"
	"os"
	"os/signal"
)

// Make a redis pool
var redisPool = &redis.Pool{
	MaxActive: 5,
	MaxIdle: 5,
	Wait: true,
	Dial: func() (redis.Conn, error) {
		return redis.Dial("tcp", ":6379")
	},
}

type Context struct{
    customerID int64
}

func main() {
	// Make a new pool. Arguments:
	// Context{} is a struct that will be the context for the request.
	// 10 is the max concurrency
	// "my_app_namespace" is the Redis namespace
	// redisPool is a Redis pool
	pool := work.NewWorkerPool(Context{}, 10, "my_app_namespace", redisPool)

	// Add middleware that will be executed for each job
	pool.Middleware((*Context).Log)
	pool.Middleware((*Context).FindCustomer)

	// Map the name of jobs to handler functions
	pool.Job("send_email", (*Context).SendEmail)

	// Customize options:
	pool.JobWithOptions("export", work.JobOptions{Priority: 10, MaxFails: 1}, (*Context).Export)

	// Start processing jobs
	pool.Start()

	// Wait for a signal to quit:
	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, os.Interrupt, os.Kill)
	<-signalChan

	// Stop the pool
	pool.Stop()
}

func (c *Context) Log(job *work.Job, next work.NextMiddlewareFunc) error {
	fmt.Println("Starting job: ", job.Name)
	return next()
}

func (c *Context) FindCustomer(job *work.Job, next work.NextMiddlewareFunc) error {
	// If there's a customer_id param, set it in the context for future middleware and handlers to use.
	if _, ok := job.Args["customer_id"]; ok {
		c.customerID = job.ArgInt64("customer_id")
		if err := job.ArgError(); err != nil {
			return err
		}
	}

	return next()
}

func (c *Context) SendEmail(job *work.Job) error {
	// Extract arguments:
	addr := job.ArgString("address")
	subject := job.ArgString("subject")
	if err := job.ArgError(); err != nil {
		return err
	}

	// Go ahead and send the email...
	// sendEmailTo(addr, subject)

	return nil
}

func (c *Context) Export(job *work.Job) error {
	return nil
}
```

#### Special Features

##### Contexts

Just like in [gocraft/web](https://www.github.com/gocraft/web), gocraft/work lets you use your own contexts. Your context can be empty or it can have various fields in it. The fields can be whatever you want - it's your type! When a new job is processed by a worker, we'll allocate an instance of this struct and pass it to your middleware and handlers. This allows you to pass information from one middleware function to the next, and onto your handlers.

Custom contexts aren't really needed for trivial example applications, but are very important for production apps. For instance, one field in your context can be your tagged logger. Your tagged logger augments your log statements with a job-id. This lets you filter your logs by that job-id.

##### Check-ins

Since this is a background job processing library, it's fairly common to have jobs that that take a long time to execute. Imagine you have a job that takes an hour to run. It can often be frustrating to know if it's hung, or about to finish, or if it has 30 more minutes to go.

To solve this, you can instrument your jobs to "checkin" every so often with a string message. This checkin status will show up in the web UI. For instance, your job could look like this:

```go
func (c *Context) Export(job *work.Job) error {
	rowsToExport := getRows()
	for i, row := range rowsToExport {
		exportRow(row)
		if i % 1000 == 0 {
			job.Checkin("i=" + fmt.Sprint(i))   // Here's the magic! This tells gocraft/work our status
		}
	}
}
```

Then in the web UI, you'll see the status of the worker:

| Name   | Arguments           | Started At          | Check-in At         | Check-in |
| ------ | ------------------- | ------------------- | ------------------- | -------- |
| export | {"account_id": 123} | 2016/07/09 04:16:51 | 2016/07/09 05:03:13 | i=335000 |

##### Scheduled Jobs

You can schedule jobs to be executed in the future. To do so, make a new `Enqueuer` and call its `EnqueueIn` method:

```
enqueuer := work.NewEnqueuer("my_app_namespace", redisPool)
secondsInTheFuture := 300
_, err := enqueuer.EnqueueIn("send_welcome_email", secondsInTheFuture, work.Q{"address": "test@example.com"})
```

##### Unique Jobs

You can enqueue unique jobs so that only one job with a given name/arguments exists in the queue at once. For instance, you might have a worker that expires the cache of an object. It doesn't make sense for multiple such jobs to exist at once. Also note that unique jobs are supported for normal enqueues as well as scheduled enqueues.

```go
enqueuer := work.NewEnqueuer("my_app_namespace", redisPool)
job, err := enqueuer.EnqueueUnique("clear_cache", work.Q{"object_id_": "123"}) // job returned
job, err = enqueuer.EnqueueUnique("clear_cache", work.Q{"object_id_": "123"}) // job == nil -- this duplicate job isn't enqueued.
job, err = enqueuer.EnqueueUniqueIn("clear_cache", 300, work.Q{"object_id_": "789"}) // job != nil (diff id)
```

##### Periodic Enqueueing (Cron)

You can periodically enqueue jobs on your gocraft/work cluster using your worker pool. The [scheduling specification](https://godoc.org/github.com/robfig/cron#hdr-CRON_Expression_Format) uses a Cron syntax where the fields represent seconds, minutes, hours, day of the month, month, and week of the day, respectively. Even if you have multiple worker pools on different machines, they'll all coordinate and only enqueue your job once.

```
pool := work.NewWorkerPool(Context{}, 10, "my_app_namespace", redisPool)
pool.PeriodicallyEnqueue("0 0 * * * *", "calculate_caches") // This will enqueue a "calculate_caches" job every hour
pool.Job("calculate_caches", (*Context).CalculateCaches) // Still need to register a handler for this job separately
```

#### Run the Web UI

The web UI provides a view to view the state of your gocraft/work cluster, inspect queued jobs, and retry or delete dead jobs.

Building an installing the binary:

```
go get github.com/gocraft/work/cmd/workwebui
go install github.com/gocraft/work/cmd/workwebui
```

Then, you can run it:

```
workwebui -redis="redis:6379" -ns="work" -listen=":5040"
```

Navigate to `http://localhost:5040/`.

You'll see a view that looks like this:

![Web UI Screenshot](https://gocraft.github.io/work/images/webui.png)

#### Design and concepts

##### Enqueueing jobs

- When jobs are enqueued, they're serialized with JSON and added to a simple Redis list with LPUSH.
- Jobs are added to a list with the same name as the job. Each job name gets its own queue. Whereas with other job systems you have to design which jobs go on which queues, there's no need for that here.

##### Scheduling algorithm

- Each job lives in a list-based queue with the same name as the job.
- Each of these queues can have an associated priority. The priority is a number from 1 to 100000.
- Each time a worker pulls a job, it needs to choose a queue. It chooses a queue probabilistically based on its relative priority.
- If the sum of priorities among all queues is 1000, and one queue has priority 100, jobs will be pulled from that queue 10% of the time.
- Obviously if a queue is empty, it won't be considered.
- The semantics of "always process X jobs before Y jobs" can be accurately approximated by giving X a large number (like 10000) and Y a small number (like 1).

##### Processing a job

- To process a job, a worker will execute a Lua script to atomically move a job its queue to an in-progress queue.
  - A job is dequeued and moved to in-progress if the job queue is not paused and the number of active jobs does not exceed concurrency limit for the job type
- The worker will then run the job and increment the job lock. The job will either finish successfully or result in an error or panic.
  - If the process completely crashes, the reaper will eventually find it in its in-progress queue and requeue it.
- If the job is successful, we'll simply remove the job from the in-progress queue.
- If the job returns an error or panic, we'll see how many retries a job has left. If it doesn't have any, we'll move it to the dead queue. If it has retries left, we'll consume a retry and add the job to the retry queue.

##### Workers and WorkerPools

- WorkerPools provide the public API of gocraft/work.
  - You can attach jobs and middleware to them.
  - You can start and stop them.
  - Based on their concurrency setting, they'll spin up N worker goroutines.
- Each worker is run in a goroutine. It will get a job from redis, run it, get the next job, etc.
  - Each worker is independent. They are not dispatched work -- they get their own work.

##### Retry job, scheduled jobs, and the requeuer

- In addition to the normal list-based queues that normal jobs live in, there are two other types of queues: the retry queue and the scheduled job queue.
- Both of these are implemented as Redis z-sets. The score is the unix timestamp when the job should be run. The value is the bytes of the job.
- The requeuer will occasionally look for jobs in these queues that should be run now. If they should be, they'll be atomically moved to the normal list-based queue and eventually processed.

##### Dead jobs

- After a job has failed a specified number of times, it will be added to the dead job queue.
- The dead job queue is just a Redis z-set. The score is the timestamp it failed and the value is the job.
- To retry failed jobs, use the UI or the Client API.

##### The reaper

- If a process crashes hard (eg, the power on the server turns off or the kernal freezes), some jobs may be in progress and we won't want to lose them. They're safe in their in-progress queue.
- The reaper will look for worker pools without a heartbeat. It will scan their in-progress queues and requeue anything it finds.

##### Unique jobs

- You can enqueue unique jobs such that a given name/arguments are on the queue at once.
- Both normal queues and the scheduled queue are considered.
- When a unique job is enqueued, we'll atomically set a redis key that includes the job name and arguments and enqueue the job.
- When the job is processed, we'll delete that key to permit another job to be enqueued.

##### Periodic jobs

- You can tell a worker pool to enqueue jobs periodically using a cron schedule.
- Each worker pool will wake up every 2 minutes, and if jobs haven't been scheduled yet, it will schedule all the jobs that would be executed in the next five minutes.
- Each periodic job that runs at a given time has a predictable byte pattern. Since jobs are scheduled on the scheduled job queue (a Redis z-set), if the same job is scheduled twice for a given time, it can only exist in the z-set once.

#### Paused jobs

- You can pause jobs from being processed from a specific queue by setting a "paused" redis key (see `redisKeyJobsPaused`)
- Conversely, jobs in the queue will resume being processed once the paused redis key is removed

#### Job concurrency

- You can control job concurrency using `JobOptions{MaxConcurrency: <num>}`.
- Unlike the WorkerPool concurrency, this controls the limit on the number jobs of that type that can be active at one time by within a single redis instance
- This works by putting a precondition on enqueuing function, meaning a new job will not be scheduled if we are at or over a job's `MaxConcurrency` limit
- A redis key (see `redisKeyJobsLock`) is used as a counting semaphore in order to track job concurrency per job type
- The default value is `0`, which means "no limit on job concurrency"
- **Note:** if you want to run jobs "single threaded" then you can set the `MaxConcurrency` accordingly:

```
      worker_pool.JobWithOptions(jobName, JobOptions{MaxConcurrency: 1}, (*Context).WorkFxn)
```

##### Terminology reference

- "worker pool" - a pool of workers
- "worker" - an individual worker in a single goroutine. Gets a job from redis, does job, gets next job...
- "heartbeater" or "worker pool heartbeater" - goroutine owned by worker pool that runs concurrently with workers. Writes the worker pool's config/status (aka "heartbeat") every 5 seconds.
- "heartbeat" - the status written by the heartbeater.
- "observer" or "worker observer" - observes a worker. Writes stats. makes "observations".
- "worker observation" - A snapshot made by an observer of what a worker is working on.
- "periodic enqueuer" - A process that runs with a worker pool that periodically enqueues new jobs based on cron schedules.
- "job" - the actual bundle of data that constitutes one job
- "job name" - each job has a name, like "create_watch"
- "job type" - backend/private nomenclature for the handler+options for processing a job
- "queue" - each job creates a queue with the same name as the job. only jobs named X go into the X queue.
- "retry jobs" - if a job fails and needs to be retried, it will be put on this queue.
- "scheduled jobs" - jobs enqueued to be run in th future will be put on a scheduled job queue.
- "dead jobs" - if a job exceeds its MaxFails count, it will be put on the dead job queue.
- "paused jobs" - if paused key is present for a queue, then no jobs from that queue will be processed by any workers until that queue's paused key is removed
- "job concurrency" - the number of jobs being actively processed of a particular type across worker pool processes but within a single redis instance

#### Benchmarks

The benches folder contains various benchmark code. In each case, we enqueue 100k jobs across 5 queues. The jobs are almost no-op jobs: they simply increment an atomic counter. We then measure the rate of change of the counter to obtain our measurement.

| Library                                                      | Speed            |
| ------------------------------------------------------------ | ---------------- |
| [gocraft/work](https://www.github.com/gocraft/work)          | **20944 jobs/s** |
| [jrallison/go-workers](https://www.github.com/jrallison/go-workers) | 19945 jobs/s     |
| [benmanns/goworker](https://www.github.com/benmanns/goworker) | 10328.5 jobs/s   |
| [albrow/jobs](https://www.github.com/albrow/jobs)            | 40 jobs/s        |

#### gocraft

gocraft offers a toolkit for building web apps. Currently these packages are available:

- [gocraft/web](https://github.com/gocraft/web) - Go Router + Middleware. Your Contexts.
- [gocraft/dbr](https://github.com/gocraft/dbr) - Additions to Go's database/sql for super fast performance and convenience.
- [gocraft/health](https://github.com/gocraft/health) - Instrument your web apps with logging and metrics.
- [gocraft/work](https://github.com/gocraft/work) - Process background jobs in Go.

These packages were developed by the [engineering team](https://eng.uservoice.com/) at [UserVoice](https://www.uservoice.com/) and currently power much of its infrastructure and tech stack.

#### Authors

- Jonathan Novak -- https://github.com/cypriss
- Tai-Lin Chu -- https://github.com/taylorchu
- Sponsored by [UserVoice](https://eng.uservoice.com/)

Collapse ▴

## ![img](https://pkg.go.dev/static/img/pkg-icon-doc_20x12.svg)Documentation [¶](https://pkg.go.dev/github.com/gocraft/work#section-documentation)

### Index [¶](https://pkg.go.dev/github.com/gocraft/work#pkg-index)

- [Variables](https://pkg.go.dev/github.com/gocraft/work#pkg-variables)
- [type BackoffCalculator](https://pkg.go.dev/github.com/gocraft/work#BackoffCalculator)
- [type Client](https://pkg.go.dev/github.com/gocraft/work#Client)
- - [func NewClient(namespace string, pool *redis.Pool) *Client](https://pkg.go.dev/github.com/gocraft/work#NewClient)
- - [func (c *Client) DeadJobs(page uint) ([\]*DeadJob, int64, error)](https://pkg.go.dev/github.com/gocraft/work#Client.DeadJobs)
  - [func (c *Client) DeleteAllDeadJobs() error](https://pkg.go.dev/github.com/gocraft/work#Client.DeleteAllDeadJobs)
  - [func (c *Client) DeleteDeadJob(diedAt int64, jobID string) error](https://pkg.go.dev/github.com/gocraft/work#Client.DeleteDeadJob)
  - [func (c *Client) DeleteRetryJob(retryAt int64, jobID string) error](https://pkg.go.dev/github.com/gocraft/work#Client.DeleteRetryJob)
  - [func (c *Client) DeleteScheduledJob(scheduledFor int64, jobID string) error](https://pkg.go.dev/github.com/gocraft/work#Client.DeleteScheduledJob)
  - [func (c *Client) Queues() ([\]*Queue, error)](https://pkg.go.dev/github.com/gocraft/work#Client.Queues)
  - [func (c *Client) RetryAllDeadJobs() error](https://pkg.go.dev/github.com/gocraft/work#Client.RetryAllDeadJobs)
  - [func (c *Client) RetryDeadJob(diedAt int64, jobID string) error](https://pkg.go.dev/github.com/gocraft/work#Client.RetryDeadJob)
  - [func (c *Client) RetryJobs(page uint) ([\]*RetryJob, int64, error)](https://pkg.go.dev/github.com/gocraft/work#Client.RetryJobs)
  - [func (c *Client) ScheduledJobs(page uint) ([\]*ScheduledJob, int64, error)](https://pkg.go.dev/github.com/gocraft/work#Client.ScheduledJobs)
  - [func (c *Client) WorkerObservations() ([\]*WorkerObservation, error)](https://pkg.go.dev/github.com/gocraft/work#Client.WorkerObservations)
  - [func (c *Client) WorkerPoolHeartbeats() ([\]*WorkerPoolHeartbeat, error)](https://pkg.go.dev/github.com/gocraft/work#Client.WorkerPoolHeartbeats)
- [type DeadJob](https://pkg.go.dev/github.com/gocraft/work#DeadJob)
- [type Enqueuer](https://pkg.go.dev/github.com/gocraft/work#Enqueuer)
- - [func NewEnqueuer(namespace string, pool *redis.Pool) *Enqueuer](https://pkg.go.dev/github.com/gocraft/work#NewEnqueuer)
- - [func (e *Enqueuer) Enqueue(jobName string, args map[string\]interface{}) (*Job, error)](https://pkg.go.dev/github.com/gocraft/work#Enqueuer.Enqueue)
  - [func (e *Enqueuer) EnqueueIn(jobName string, secondsFromNow int64, args map[string\]interface{}) (*ScheduledJob, error)](https://pkg.go.dev/github.com/gocraft/work#Enqueuer.EnqueueIn)
  - [func (e *Enqueuer) EnqueueUnique(jobName string, args map[string\]interface{}) (*Job, error)](https://pkg.go.dev/github.com/gocraft/work#Enqueuer.EnqueueUnique)
  - [func (e *Enqueuer) EnqueueUniqueIn(jobName string, secondsFromNow int64, args map[string\]interface{}) (*ScheduledJob, error)](https://pkg.go.dev/github.com/gocraft/work#Enqueuer.EnqueueUniqueIn)
- [type GenericHandler](https://pkg.go.dev/github.com/gocraft/work#GenericHandler)
- [type GenericMiddlewareHandler](https://pkg.go.dev/github.com/gocraft/work#GenericMiddlewareHandler)
- [type Job](https://pkg.go.dev/github.com/gocraft/work#Job)
- - [func (j *Job) ArgBool(key string) bool](https://pkg.go.dev/github.com/gocraft/work#Job.ArgBool)
  - [func (j *Job) ArgError() error](https://pkg.go.dev/github.com/gocraft/work#Job.ArgError)
  - [func (j *Job) ArgFloat64(key string) float64](https://pkg.go.dev/github.com/gocraft/work#Job.ArgFloat64)
  - [func (j *Job) ArgInt64(key string) int64](https://pkg.go.dev/github.com/gocraft/work#Job.ArgInt64)
  - [func (j *Job) ArgString(key string) string](https://pkg.go.dev/github.com/gocraft/work#Job.ArgString)
  - [func (j *Job) Checkin(msg string)](https://pkg.go.dev/github.com/gocraft/work#Job.Checkin)
- [type JobOptions](https://pkg.go.dev/github.com/gocraft/work#JobOptions)
- [type NextMiddlewareFunc](https://pkg.go.dev/github.com/gocraft/work#NextMiddlewareFunc)
- [type Q](https://pkg.go.dev/github.com/gocraft/work#Q)
- [type Queue](https://pkg.go.dev/github.com/gocraft/work#Queue)
- [type RetryJob](https://pkg.go.dev/github.com/gocraft/work#RetryJob)
- [type ScheduledJob](https://pkg.go.dev/github.com/gocraft/work#ScheduledJob)
- [type WorkerObservation](https://pkg.go.dev/github.com/gocraft/work#WorkerObservation)
- [type WorkerPool](https://pkg.go.dev/github.com/gocraft/work#WorkerPool)
- - [func NewWorkerPool(ctx interface{}, concurrency uint, namespace string, pool *redis.Pool) *WorkerPool](https://pkg.go.dev/github.com/gocraft/work#NewWorkerPool)
- - [func (wp *WorkerPool) Drain()](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.Drain)
  - [func (wp *WorkerPool) Job(name string, fn interface{}) *WorkerPool](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.Job)
  - [func (wp *WorkerPool) JobWithOptions(name string, jobOpts JobOptions, fn interface{}) *WorkerPool](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.JobWithOptions)
  - [func (wp *WorkerPool) Middleware(fn interface{}) *WorkerPool](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.Middleware)
  - [func (wp *WorkerPool) PeriodicallyEnqueue(spec string, jobName string) *WorkerPool](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.PeriodicallyEnqueue)
  - [func (wp *WorkerPool) Start()](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.Start)
  - [func (wp *WorkerPool) Stop()](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.Stop)
- [type WorkerPoolHeartbeat](https://pkg.go.dev/github.com/gocraft/work#WorkerPoolHeartbeat)

### Constants [¶](https://pkg.go.dev/github.com/gocraft/work#pkg-constants)

This section is empty.

### Variables [¶](https://pkg.go.dev/github.com/gocraft/work#pkg-variables)

[View Source](https://github.com/gocraft/work/blob/v0.5.1/client.go#L14)

```
var ErrNotDeleted = fmt.Errorf("nothing deleted")
```

ErrNotDeleted is returned by functions that delete jobs to indicate that although the redis commands were successful, no object was actually deleted by those commmands.

[View Source](https://github.com/gocraft/work/blob/v0.5.1/client.go#L18)

```
var ErrNotRetried = fmt.Errorf("nothing retried")
```

ErrNotRetried is returned by functions that retry jobs to indicate that although the redis commands were successful, no object was actually retried by those commmands.

### Functions [¶](https://pkg.go.dev/github.com/gocraft/work#pkg-functions)

This section is empty.

### Types [¶](https://pkg.go.dev/github.com/gocraft/work#pkg-types)

#### type [BackoffCalculator](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L54) [¶](https://pkg.go.dev/github.com/gocraft/work#BackoffCalculator)

```
type BackoffCalculator func(job *Job) int64
```

You may provide your own backoff function for retrying failed jobs or use the builtin one. Returns the number of seconds to wait until the next attempt.

The builtin backoff calculator provides an exponentially increasing wait function.

#### type [Client](https://github.com/gocraft/work/blob/v0.5.1/client.go#L21) [¶](https://pkg.go.dev/github.com/gocraft/work#Client)

```
type Client struct {
	// contains filtered or unexported fields
}
```

Client implements all of the functionality of the web UI. It can be used to inspect the status of a running cluster and retry dead jobs.

#### func [NewClient](https://github.com/gocraft/work/blob/v0.5.1/client.go#L27) [¶](https://pkg.go.dev/github.com/gocraft/work#NewClient)

```
func NewClient(namespace string, pool *redis.Pool) *Client
```

NewClient creates a new Client with the specified redis namespace and connection pool.

#### func (*Client) [DeadJobs](https://github.com/gocraft/work/blob/v0.5.1/client.go#L337) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.DeadJobs)

```
func (c *Client) DeadJobs(page uint) ([]*DeadJob, int64, error)
```

DeadJobs returns a list of DeadJob's. The page param is 1-based; each page is 20 items. The total number of items (not pages) in the list of dead jobs is also returned.

#### func (*Client) [DeleteAllDeadJobs](https://github.com/gocraft/work/blob/v0.5.1/client.go#L456) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.DeleteAllDeadJobs)

```
func (c *Client) DeleteAllDeadJobs() error
```

DeleteAllDeadJobs deletes all dead jobs.

#### func (*Client) [DeleteDeadJob](https://github.com/gocraft/work/blob/v0.5.1/client.go#L355) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.DeleteDeadJob)

```
func (c *Client) DeleteDeadJob(diedAt int64, jobID string) error
```

DeleteDeadJob deletes a dead job from Redis.

#### func (*Client) [DeleteRetryJob](https://github.com/gocraft/work/blob/v0.5.1/client.go#L507) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.DeleteRetryJob)

```
func (c *Client) DeleteRetryJob(retryAt int64, jobID string) error
```

DeleteRetryJob deletes a job in the retry queue.

#### func (*Client) [DeleteScheduledJob](https://github.com/gocraft/work/blob/v0.5.1/client.go#L469) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.DeleteScheduledJob)

```
func (c *Client) DeleteScheduledJob(scheduledFor int64, jobID string) error
```

DeleteScheduledJob deletes a job in the scheduled queue.

#### func (*Client) [Queues](https://github.com/gocraft/work/blob/v0.5.1/client.go#L213) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.Queues)

```
func (c *Client) Queues() ([]*Queue, error)
```

Queues returns the Queue's it finds.

#### func (*Client) [RetryAllDeadJobs](https://github.com/gocraft/work/blob/v0.5.1/client.go#L410) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.RetryAllDeadJobs)

```
func (c *Client) RetryAllDeadJobs() error
```

RetryAllDeadJobs requeues all dead jobs. In other words, it puts them all back on the normal work queue for workers to pull from and process.

#### func (*Client) [RetryDeadJob](https://github.com/gocraft/work/blob/v0.5.1/client.go#L367) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.RetryDeadJob)

```
func (c *Client) RetryDeadJob(diedAt int64, jobID string) error
```

RetryDeadJob retries a dead job. The job will be re-queued on the normal work queue for eventual processing by a worker.

#### func (*Client) [RetryJobs](https://github.com/gocraft/work/blob/v0.5.1/client.go#L319) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.RetryJobs)

```
func (c *Client) RetryJobs(page uint) ([]*RetryJob, int64, error)
```

RetryJobs returns a list of RetryJob's. The page param is 1-based; each page is 20 items. The total number of items (not pages) in the list of retry jobs is also returned.

#### func (*Client) [ScheduledJobs](https://github.com/gocraft/work/blob/v0.5.1/client.go#L301) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.ScheduledJobs)

```
func (c *Client) ScheduledJobs(page uint) ([]*ScheduledJob, int64, error)
```

ScheduledJobs returns a list of ScheduledJob's. The page param is 1-based; each page is 20 items. The total number of items (not pages) in the list of scheduled jobs is also returned.

#### func (*Client) [WorkerObservations](https://github.com/gocraft/work/blob/v0.5.1/client.go#L135) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.WorkerObservations)

```
func (c *Client) WorkerObservations() ([]*WorkerObservation, error)
```

WorkerObservations returns all of the WorkerObservation's it finds for all worker pools' workers.

#### func (*Client) [WorkerPoolHeartbeats](https://github.com/gocraft/work/blob/v0.5.1/client.go#L47) [¶](https://pkg.go.dev/github.com/gocraft/work#Client.WorkerPoolHeartbeats)

```
func (c *Client) WorkerPoolHeartbeats() ([]*WorkerPoolHeartbeat, error)
```

WorkerPoolHeartbeats queries Redis and returns all WorkerPoolHeartbeat's it finds (even for those worker pools which don't have a current heartbeat).

#### type [DeadJob](https://github.com/gocraft/work/blob/v0.5.1/client.go#L295) [¶](https://pkg.go.dev/github.com/gocraft/work#DeadJob)

```
type DeadJob struct {
	DiedAt int64 `json:"died_at"`
	*Job
}
```

DeadJob represents a job in the dead queue.

#### type [Enqueuer](https://github.com/gocraft/work/blob/v0.5.1/enqueue.go#L11) [¶](https://pkg.go.dev/github.com/gocraft/work#Enqueuer)

```
type Enqueuer struct {
	Namespace string // eg, "myapp-work"
	Pool      *redis.Pool
	// contains filtered or unexported fields
}
```

Enqueuer can enqueue jobs.

#### func [NewEnqueuer](https://github.com/gocraft/work/blob/v0.5.1/enqueue.go#L23) [¶](https://pkg.go.dev/github.com/gocraft/work#NewEnqueuer)

```
func NewEnqueuer(namespace string, pool *redis.Pool) *Enqueuer
```

NewEnqueuer creates a new enqueuer with the specified Redis namespace and Redis pool.

#### func (*Enqueuer) [Enqueue](https://github.com/gocraft/work/blob/v0.5.1/enqueue.go#L40) [¶](https://pkg.go.dev/github.com/gocraft/work#Enqueuer.Enqueue)

```
func (e *Enqueuer) Enqueue(jobName string, args map[string]interface{}) (*Job, error)
```

Enqueue will enqueue the specified job name and arguments. The args param can be nil if no args ar needed. Example: e.Enqueue("send_email", work.Q{"addr": "test@example.com"})

#### func (*Enqueuer) [EnqueueIn](https://github.com/gocraft/work/blob/v0.5.1/enqueue.go#L68) [¶](https://pkg.go.dev/github.com/gocraft/work#Enqueuer.EnqueueIn)

```
func (e *Enqueuer) EnqueueIn(jobName string, secondsFromNow int64, args map[string]interface{}) (*ScheduledJob, error)
```

EnqueueIn enqueues a job in the scheduled job queue for execution in secondsFromNow seconds.

#### func (*Enqueuer) [EnqueueUnique](https://github.com/gocraft/work/blob/v0.5.1/enqueue.go#L107) [¶](https://pkg.go.dev/github.com/gocraft/work#Enqueuer.EnqueueUnique)

```
func (e *Enqueuer) EnqueueUnique(jobName string, args map[string]interface{}) (*Job, error)
```

EnqueueUnique enqueues a job unless a job is already enqueued with the same name and arguments. The already-enqueued job can be in the normal work queue or in the scheduled job queue. Once a worker begins processing a job, another job with the same name and arguments can be enqueued again. Any failed jobs in the retry queue or dead queue don't count against the uniqueness -- so if a job fails and is retried, two unique jobs with the same name and arguments can be enqueued at once. In order to add robustness to the system, jobs are only unique for 24 hours after they're enqueued. This is mostly relevant for scheduled jobs. EnqueueUnique returns the job if it was enqueued and nil if it wasn't

#### func (*Enqueuer) [EnqueueUniqueIn](https://github.com/gocraft/work/blob/v0.5.1/enqueue.go#L146) [¶](https://pkg.go.dev/github.com/gocraft/work#Enqueuer.EnqueueUniqueIn)

```
func (e *Enqueuer) EnqueueUniqueIn(jobName string, secondsFromNow int64, args map[string]interface{}) (*ScheduledJob, error)
```

EnqueueUniqueIn enqueues a unique job in the scheduled job queue for execution in secondsFromNow seconds. See EnqueueUnique for the semantics of unique jobs.

#### type [GenericHandler](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L66) [¶](https://pkg.go.dev/github.com/gocraft/work#GenericHandler)

```
type GenericHandler func(*Job) error
```

GenericHandler is a job handler without any custom context.

#### type [GenericMiddlewareHandler](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L69) [¶](https://pkg.go.dev/github.com/gocraft/work#GenericMiddlewareHandler)

```
type GenericMiddlewareHandler func(*Job, NextMiddlewareFunc) error
```

GenericMiddlewareHandler is a middleware without any custom context.

#### type [Job](https://github.com/gocraft/work/blob/v0.5.1/job.go#L11) [¶](https://pkg.go.dev/github.com/gocraft/work#Job)

```
type Job struct {
	// Inputs when making a new job
	Name       string                 `json:"name,omitempty"`
	ID         string                 `json:"id"`
	EnqueuedAt int64                  `json:"t"`
	Args       map[string]interface{} `json:"args"`
	Unique     bool                   `json:"unique,omitempty"`

	// Inputs when retrying
	Fails    int64  `json:"fails,omitempty"` // number of times this job has failed
	LastErr  string `json:"err,omitempty"`
	FailedAt int64  `json:"failed_at,omitempty"`
	// contains filtered or unexported fields
}
```

Job represents a job.

#### func (*Job) [ArgBool](https://github.com/gocraft/work/blob/v0.5.1/job.go#L141) [¶](https://pkg.go.dev/github.com/gocraft/work#Job.ArgBool)

```
func (j *Job) ArgBool(key string) bool
```

ArgBool returns j.Args[key] typed to a bool. If the key is missing or of the wrong type, it sets an argument error on the job. This function is meant to be used in the body of a job handling function while extracting arguments, followed by a single call to j.ArgError().

#### func (*Job) [ArgError](https://github.com/gocraft/work/blob/v0.5.1/job.go#L156) [¶](https://pkg.go.dev/github.com/gocraft/work#Job.ArgError)

```
func (j *Job) ArgError() error
```

ArgError returns the last error generated when extracting typed params. Returns nil if extracting the args went fine.

#### func (*Job) [ArgFloat64](https://github.com/gocraft/work/blob/v0.5.1/job.go#L120) [¶](https://pkg.go.dev/github.com/gocraft/work#Job.ArgFloat64)

```
func (j *Job) ArgFloat64(key string) float64
```

ArgFloat64 returns j.Args[key] typed to a float64. If the key is missing or of the wrong type, it sets an argument error on the job. This function is meant to be used in the body of a job handling function while extracting arguments, followed by a single call to j.ArgError().

#### func (*Job) [ArgInt64](https://github.com/gocraft/work/blob/v0.5.1/job.go#L92) [¶](https://pkg.go.dev/github.com/gocraft/work#Job.ArgInt64)

```
func (j *Job) ArgInt64(key string) int64
```

ArgInt64 returns j.Args[key] typed to an int64. If the key is missing or of the wrong type, it sets an argument error on the job. This function is meant to be used in the body of a job handling function while extracting arguments, followed by a single call to j.ArgError().

#### func (*Job) [ArgString](https://github.com/gocraft/work/blob/v0.5.1/job.go#L75) [¶](https://pkg.go.dev/github.com/gocraft/work#Job.ArgString)

```
func (j *Job) ArgString(key string) string
```

ArgString returns j.Args[key] typed to a string. If the key is missing or of the wrong type, it sets an argument error on the job. This function is meant to be used in the body of a job handling function while extracting arguments, followed by a single call to j.ArgError().

#### func (*Job) [Checkin](https://github.com/gocraft/work/blob/v0.5.1/job.go#L66) [¶](https://pkg.go.dev/github.com/gocraft/work#Job.Checkin)

```
func (j *Job) Checkin(msg string)
```

Checkin will update the status of the executing job to the specified messages. This message is visible within the web UI. This is useful for indicating some sort of progress on very long running jobs. For instance, on a job that has to process a million records over the course of an hour, the job could call Checkin with the current job number every 10k jobs.

#### type [JobOptions](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L57) [¶](https://pkg.go.dev/github.com/gocraft/work#JobOptions)

```
type JobOptions struct {
	Priority       uint              // Priority from 1 to 10000
	MaxFails       uint              // 1: send straight to dead (unless SkipDead)
	SkipDead       bool              // If true, don't send failed jobs to the dead queue when retries are exhausted.
	MaxConcurrency uint              // Max number of jobs to keep in flight (default is 0, meaning no max)
	Backoff        BackoffCalculator // If not set, uses the default backoff algorithm
}
```

JobOptions can be passed to JobWithOptions.

#### type [NextMiddlewareFunc](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L72) [¶](https://pkg.go.dev/github.com/gocraft/work#NextMiddlewareFunc)

```
type NextMiddlewareFunc func() error
```

NextMiddlewareFunc is a function type (whose instances are named 'next') that you call to advance to the next middleware.

#### type [Q](https://github.com/gocraft/work/blob/v0.5.1/job.go#L33) [¶](https://pkg.go.dev/github.com/gocraft/work#Q)

```
type Q map[string]interface{}
```

Q is a shortcut to easily specify arguments for jobs when enqueueing them. Example: e.Enqueue("send_email", work.Q{"addr": "test@example.com", "track": true})

#### type [Queue](https://github.com/gocraft/work/blob/v0.5.1/client.go#L206) [¶](https://pkg.go.dev/github.com/gocraft/work#Queue)

```
type Queue struct {
	JobName string `json:"job_name"`
	Count   int64  `json:"count"`
	Latency int64  `json:"latency"`
}
```

Queue represents a queue that holds jobs with the same name. It indicates their name, count, and latency (in seconds). Latency is a measurement of how long ago the next job to be processed was enqueued.

#### type [RetryJob](https://github.com/gocraft/work/blob/v0.5.1/client.go#L283) [¶](https://pkg.go.dev/github.com/gocraft/work#RetryJob)

```
type RetryJob struct {
	RetryAt int64 `json:"retry_at"`
	*Job
}
```

RetryJob represents a job in the retry queue.

#### type [ScheduledJob](https://github.com/gocraft/work/blob/v0.5.1/client.go#L289) [¶](https://pkg.go.dev/github.com/gocraft/work#ScheduledJob)

```
type ScheduledJob struct {
	RunAt int64 `json:"run_at"`
	*Job
}
```

ScheduledJob represents a job in the scheduled queue.

#### type [WorkerObservation](https://github.com/gocraft/work/blob/v0.5.1/client.go#L121) [¶](https://pkg.go.dev/github.com/gocraft/work#WorkerObservation)

```
type WorkerObservation struct {
	WorkerID string `json:"worker_id"`
	IsBusy   bool   `json:"is_busy"`

	// If IsBusy:
	JobName   string `json:"job_name"`
	JobID     string `json:"job_id"`
	StartedAt int64  `json:"started_at"`
	ArgsJSON  string `json:"args_json"`
	Checkin   string `json:"checkin"`
	CheckinAt int64  `json:"checkin_at"`
}
```

WorkerObservation represents the latest observation taken from a worker. The observation indicates whether the worker is busy processing a job, and if so, information about that job.

#### type [WorkerPool](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L14) [¶](https://pkg.go.dev/github.com/gocraft/work#WorkerPool)

```
type WorkerPool struct {
	// contains filtered or unexported fields
}
```

WorkerPool represents a pool of workers. It forms the primary API of gocraft/work. WorkerPools provide the public API of gocraft/work. You can attach jobs and middlware to them. You can start and stop them. Based on their concurrency setting, they'll spin up N worker goroutines.

#### func [NewWorkerPool](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L82) [¶](https://pkg.go.dev/github.com/gocraft/work#NewWorkerPool)

```
func NewWorkerPool(ctx interface{}, concurrency uint, namespace string, pool *redis.Pool) *WorkerPool
```

NewWorkerPool creates a new worker pool. ctx should be a struct literal whose type will be used for middleware and handlers. concurrency specifies how many workers to spin up - each worker can process jobs concurrently.

#### func (*WorkerPool) [Drain](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L226) [¶](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.Drain)

```
func (wp *WorkerPool) Drain()
```

Drain drains all jobs in the queue before returning. Note that if jobs are added faster than we can process them, this function wouldn't return.

#### func (*WorkerPool) [Job](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L135) [¶](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.Job)

```
func (wp *WorkerPool) Job(name string, fn interface{}) *WorkerPool
```

Job registers the job name to the specified handler fn. For instance, when workers pull jobs from the name queue they'll be processed by the specified handler function. fn can take one of these forms: (*ContextType).func(*Job) error, (ContextType matches the type of ctx specified when creating a pool) func(*Job) error, for the generic handler format.

#### func (*WorkerPool) [JobWithOptions](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L141) [¶](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.JobWithOptions)

```
func (wp *WorkerPool) JobWithOptions(name string, jobOpts JobOptions, fn interface{}) *WorkerPool
```

JobWithOptions adds a handler for 'name' jobs as per the Job function, but permits you specify additional options such as a job's priority, retry count, and whether to send dead jobs to the dead job queue or trash them.

#### func (*WorkerPool) [Middleware](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L109) [¶](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.Middleware)

```
func (wp *WorkerPool) Middleware(fn interface{}) *WorkerPool
```

Middleware appends the specified function to the middleware chain. The fn can take one of these forms: (*ContextType).func(*Job, NextMiddlewareFunc) error, (ContextType matches the type of ctx specified when creating a pool) func(*Job, NextMiddlewareFunc) error, for the generic middleware format.

#### func (*WorkerPool) [PeriodicallyEnqueue](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L169) [¶](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.PeriodicallyEnqueue)

```
func (wp *WorkerPool) PeriodicallyEnqueue(spec string, jobName string) *WorkerPool
```

PeriodicallyEnqueue will periodically enqueue jobName according to the cron-based spec. The spec format is based on https://godoc.org/github.com/robfig/cron, which is a relatively standard cron format. Note that the first value is the seconds! If you have multiple worker pools on different machines, they'll all coordinate and only enqueue your job once.

#### func (*WorkerPool) [Start](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L181) [¶](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.Start)

```
func (wp *WorkerPool) Start()
```

Start starts the workers and associated processes.

#### func (*WorkerPool) [Stop](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go#L203) [¶](https://pkg.go.dev/github.com/gocraft/work#WorkerPool.Stop)

```
func (wp *WorkerPool) Stop()
```

Stop stops the workers and associated processes.

#### type [WorkerPoolHeartbeat](https://github.com/gocraft/work/blob/v0.5.1/client.go#L35) [¶](https://pkg.go.dev/github.com/gocraft/work#WorkerPoolHeartbeat)

```
type WorkerPoolHeartbeat struct {
	WorkerPoolID string   `json:"worker_pool_id"`
	StartedAt    int64    `json:"started_at"`
	HeartbeatAt  int64    `json:"heartbeat_at"`
	JobNames     []string `json:"job_names"`
	Concurrency  uint     `json:"concurrency"`
	Host         string   `json:"host"`
	Pid          int      `json:"pid"`
	WorkerIDs    []string `json:"worker_ids"`
}
```

WorkerPoolHeartbeat represents the heartbeat from a worker pool. WorkerPool's write a heartbeat every 5 seconds so we know they're alive and includes config information.

## ![img](https://pkg.go.dev/static/img/pkg-icon-file_16x12.svg)Source Files 

[View all](https://github.com/gocraft/work/tree/v0.5.1)

- [client.go](https://github.com/gocraft/work/blob/v0.5.1/client.go)
- [dead_pool_reaper.go](https://github.com/gocraft/work/blob/v0.5.1/dead_pool_reaper.go)
- [enqueue.go](https://github.com/gocraft/work/blob/v0.5.1/enqueue.go)
- [heartbeater.go](https://github.com/gocraft/work/blob/v0.5.1/heartbeater.go)
- [identifier.go](https://github.com/gocraft/work/blob/v0.5.1/identifier.go)
- [job.go](https://github.com/gocraft/work/blob/v0.5.1/job.go)
- [log.go](https://github.com/gocraft/work/blob/v0.5.1/log.go)
- [observer.go](https://github.com/gocraft/work/blob/v0.5.1/observer.go)
- [periodic_enqueuer.go](https://github.com/gocraft/work/blob/v0.5.1/periodic_enqueuer.go)
- [priority_sampler.go](https://github.com/gocraft/work/blob/v0.5.1/priority_sampler.go)
- [redis.go](https://github.com/gocraft/work/blob/v0.5.1/redis.go)
- [requeuer.go](https://github.com/gocraft/work/blob/v0.5.1/requeuer.go)
- [run.go](https://github.com/gocraft/work/blob/v0.5.1/run.go)
- [time.go](https://github.com/gocraft/work/blob/v0.5.1/time.go)
- [worker.go](https://github.com/gocraft/work/blob/v0.5.1/worker.go)
- [worker_pool.go](https://github.com/gocraft/work/blob/v0.5.1/worker_pool.go)



王镇： 221学校，烽火科技 3年研发，华为4年工作经验，2年kubernetes 相关组件开发经验，了解并修改过kubernetes部分源代码，算法掌握还可以，期望薪资不低于25.  --- 可以压价谈谈。