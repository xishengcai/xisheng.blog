# gocraft-wroker

<!--toc-->

## what

gocraft/work lets you enqueue and processes background jobs in Go. Jobs are durable and backed by Redis. Very similar to Sidekiq for Go.

## feature

- Fast and efficient. Faster than [this](https://www.github.com/jrallison/go-workers), [this](https://www.github.com/benmanns/goworker), and [this](https://www.github.com/albrow/jobs). See below for benchmarks.
- Reliable - don't lose jobs even if your process crashes.
- Middleware on jobs -- good for metrics instrumentation, logging, etc.
- If a job fails, it will be retried a specified number of times.
- Schedule jobs to happen in the future.
- Enqueue unique jobs so that only one job with a given name/arguments exists in the queue at once.
- Web UI to manage failed jobs and observe the system.
- Periodically enqueue jobs on a cron-like schedule.
- Pause / unpause jobs and control concurrency within and across processes

## use example

1. Pass namespace and json argument to workPool
2. Define Consumer function
3. Start workPool



注册job

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



消费job

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



## coding

### job

retry job， dead job， schedule job

### client

get scheduledJob

get retryJob

get deadJob

get workpool heartbeats

get delete zsetJob



### heartbeat

### workpool

### enque

### run







## watch available





## other job productor