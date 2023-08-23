gocraft/work 工作队列源码简介简介功能特性注册Job注册Job 流程发送JobWoker Fetch JobWorker handle Job创建消费任务的2种方法执行消费任务的真正

# gocraft/work 工作队列源码简介

ubeadm init phase kubeconfig kubelet --node-name=cn-hangzhou.i-bp1bq96d1zohe28czs47 --kubeconfig-dir=/tmp/ --a piserver-advertise-address=172.16.112.134  --apiserver-bind-port=6443

## 简介

gocraft/work 是一款使用go开发的任务处理软件，通过redis 存储任务队列，可以使用工作池同时处理多个任务。本文主要介绍任务注册和任务消费的源代码。



## 功能特性

- Fast and efficient. Faster than [this](https://www.github.com/jrallison/go-workers), [this](https://www.github.com/benmanns/goworker), and [this](https://www.github.com/albrow/jobs). See below for benchmarks.
- Reliable - don't lose jobs even if your process crashes.
- Middleware on jobs -- good for metrics instrumentation, logging, etc.
- If a job fails, it will be retried a specified number of times.
- Schedule jobs to happen in the future.
- Enqueue unique jobs so that only one job with a given name/arguments exists in the queue at once.
- Web UI to manage failed jobs and observe the system.
- Periodically enqueue jobs on a cron-like schedule.
- Pause / unpause jobs and control concurrency within and across processes



## 注册Job

### 注册Job 流程

1. 创建redis client pool

2. 创建对象，定义 任务处理函数

3. 创建 任务工作池，需要传入 被处理对象结构体， 最大并发数， 命名空间， redis client pool

4. 创建Job， 需要传入 job 名称和 job 处理函数， job 在redis 中使用列表存储，key的组成：nameSapce:job:jobName， 同一namespace支持多种类型任务处理

   **这里使用任务名称作为key存入redis， 任务处理参数存放到列表中**

```

func main() {
  // Make a new pool. Arguments:
  // Context{} is a struct that will be the context for the request.
  // 10 is the max concurrency
  // "my_app_namespace" is the Redis namespace
  // redisPool is a Redis pool
  pool := work.NewWorkerPool(Context{}, 10, "my_app_namespace", redisPool)

  // Add middleware that will be executed for each job
  pool.Middleware((*Context).Log)

  // Map the name of jobs to handler functions
  // pool 中的 jobTypes是一个字典，key 是任务名称， value 是 任务处理函数
  // 当有任务的时候，会将任务需要的参数 放入到redis key 为jobName的列表中
  // 第二个参数必须是 工作池对象的方法
  pool.Job("send_email", (*Context).SendEmail)

  // Customize options:
  pool.JobWithOptions("export", work.JobOptions{Priority: 10, MaxFails: 1}, (*Context).Export)

  // Start processing jobs
  pool.Start()
  ...
}
```



## 发送Job

发送job 其实调用NewEnqueuer方法向redis 的列表中压入元素（具体的内容是任务参数）

```
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



## Woker Fetch Job

在New WrokPool的时候会根据并法参数concurrency，创建同等个数的woker。

Worker 是一个job处理者，通过永久for循环，不间断的从redis 的任务队列中获取任务，在处理任务的时候，协程阻塞，等待一个任务处理完，再继续下一个。

下面的代码是worker 在for循环中的重要操作（1） fetch job （2） process job

```
func (w *worker) loop() {
  for {
    select {
     。。。
    case <-timer.C:
      job, err := w.fetchJob()
      w.process(job)
    }
  }
}
```



fetchJob 本质是redis 的 pop，push 操作。首先将redis 列表中的任务 移除，然后再放入到处理队列中，这个操作必须是**原子操作**（原子性是指事务是一个**不可再分割的工作单元**，事务中的操作要么都发生，要么都不发生），作者使用了lua脚本完成。最后返回一个job 对象，里面有后面任务处理函数需要的args，即这里的rawJson

```
func (w *worker) fetchJob() (*Job, error) {

   scriptArgs = append(scriptArgs, w.poolID) // ARGV[1]
  ...
   values, err := redis.Values(w.redisFetchScript.Do(conn, scriptArgs...))
    ...
   job, err := newJob(rawJSON, dequeuedFrom, inProgQueue)
    ..
   return job, nil
}
```



## Worker handle Job

```
Pool.JobWithOptions(InstallMasterJob, work.JobOptions{Priority: 1, MaxFails: 1}, ConsumeJob)
```

workpool 注册任务ConsumeJob后， 该任务ConsumeJob会被赋值给 worker.jobTypes[job.Name].GenericHandler, 他的反射类型被赋值给了jobType.DynamicHandler。如果该消费任务使用了上下文参数。



### 创建消费任务的2种方法

-  If you don't need context:

   func YourFunctionName(job *work.Job) error

- If you want your handler to accept a context:

  func (c *Context) YourFunctionName(job *work.Job) error  // or,

  func YourFunctionName(c *Context, job *work.Job) error

```
func (wp *WorkerPool) JobWithOptions(name string, jobOpts JobOptions, fn interface{}) *WorkerPool {
  jobOpts = applyDefaultsAndValidate(jobOpts)

  vfn := reflect.ValueOf(fn)
  validateHandlerType(wp.contextType, vfn)
  jt := &jobType{
    Name:           name,
    //vfn 任务消费方法的反射类型， 如果消费方法中有ctx 参数，那么会调用反射执行    
    DynamicHandler: vfn, 
    JobOptions:     jobOpts,
  }
  if gh, ok := fn.(func(*Job) error); ok {
    // 用户的任务消费函数，被赋值给了jobType的GenericHandler， 如果消费方法只有一个job参数，则执行GenericHandler
    jt.IsGeneric = true
    jt.GenericHandler = gh
  }

  wp.jobTypes[name] = jt

  for _, w := range wp.workers {
    w.updateMiddlewareAndJobTypes(wp.middleware, wp.jobTypes)
  }

  return wp
}
```



### 执行消费任务的gocraft/work 工作队列源码简介简介功能特性注册Job注册Job 流程发送JobWoker Fetch JobWorker handle Job创建消费任务的2种方法执行消费任务的真正

# gocraft/work 工作队列源码简介

ubeadm init phase kubeconfig kubelet --node-name=cn-hangzhou.i-bp1bq96d1zohe28czs47 --kubeconfig-dir=/tmp/ --a piserver-advertise-address=172.16.112.134  --apiserver-bind-port=6443

## 简介

gocraft/work 是一款使用go开发的任务处理软件，通过redis 存储任务队列，可以使用工作池同时处理多个任务。本文主要介绍任务注册和任务消费的源代码。



## 功能特性

- Fast and efficient. Faster than [this](https://www.github.com/jrallison/go-workers), [this](https://www.github.com/benmanns/goworker), and [this](https://www.github.com/albrow/jobs). See below for benchmarks.
- Reliable - don't lose jobs even if your process crashes.
- Middleware on jobs -- good for metrics instrumentation, logging, etc.
- If a job fails, it will be retried a specified number of times.
- Schedule jobs to happen in the future.
- Enqueue unique jobs so that only one job with a given name/arguments exists in the queue at once.
- Web UI to manage failed jobs and observe the system.
- Periodically enqueue jobs on a cron-like schedule.
- Pause / unpause jobs and control concurrency within and across processes



## 注册Job

### 注册Job 流程

1. 创建redis client pool

2. 创建对象，定义 任务处理函数

3. 创建 任务工作池，需要传入 被处理对象结构体， 最大并发数， 命名空间， redis client pool

4. 创建Job， 需要传入 job 名称和 job 处理函数， job 在redis 中使用列表存储，key的组成：nameSapce:job:jobName， 同一namespace支持多种类型任务处理

   **这里使用任务名称作为key存入redis， 任务处理参数存放到列表中**

```

func main() {
  // Make a new pool. Arguments:
  // Context{} is a struct that will be the context for the request.
  // 10 is the max concurrency
  // "my_app_namespace" is the Redis namespace
  // redisPool is a Redis pool
  pool := work.NewWorkerPool(Context{}, 10, "my_app_namespace", redisPool)

  // Add middleware that will be executed for each job
  pool.Middleware((*Context).Log)

  // Map the name of jobs to handler functions
  // pool 中的 jobTypes是一个字典，key 是任务名称， value 是 任务处理函数
  // 当有任务的时候，会将任务需要的参数 放入到redis key 为jobName的列表中
  // 第二个参数必须是 工作池对象的方法
  pool.Job("send_email", (*Context).SendEmail)

  // Customize options:
  pool.JobWithOptions("export", work.JobOptions{Priority: 10, MaxFails: 1}, (*Context).Export)

  // Start processing jobs
  pool.Start()
  ...
}
```



## 发送Job

发送job 其实调用NewEnqueuer方法向redis 的列表中压入元素（具体的内容是任务参数）

```
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



## Woker Fetch Job

在New WrokPool的时候会根据并法参数concurrency，创建同等个数的woker。

Worker 是一个job处理者，通过永久for循环，不间断的从redis 的任务队列中获取任务，在处理任务的时候，协程阻塞，等待一个任务处理完，再继续下一个。

下面的代码是worker 在for循环中的重要操作（1） fetch job （2） process job

```
func (w *worker) loop() {
  for {
    select {
     。。。
    case <-timer.C:
      job, err := w.fetchJob()
      w.process(job)
    }
  }
}
```



fetchJob 本质是redis 的 pop，push 操作。首先将redis 列表中的任务 移除，然后再放入到处理队列中，这个操作必须是**原子操作**（原子性是指事务是一个**不可再分割的工作单元**，事务中的操作要么都发生，要么都不发生），作者使用了lua脚本完成。最后返回一个job 对象，里面有后面任务处理函数需要的args，即这里的rawJson

```
func (w *worker) fetchJob() (*Job, error) {

   scriptArgs = append(scriptArgs, w.poolID) // ARGV[1]
  ...
   values, err := redis.Values(w.redisFetchScript.Do(conn, scriptArgs...))
    ...
   job, err := newJob(rawJSON, dequeuedFrom, inProgQueue)
    ..
   return job, nil
}
```



## Worker handle Job

```
Pool.JobWithOptions(InstallMasterJob, work.JobOptions{Priority: 1, MaxFails: 1}, ConsumeJob)
```

workpool 注册任务ConsumeJob后， 该任务ConsumeJob会被赋值给 worker.jobTypes[job.Name].GenericHandler, 他的反射类型被赋值给了jobType.DynamicHandler。如果该消费任务使用了上下文参数。



### 创建消费任务的2种方法

-  If you don't need context:

   func YourFunctionName(job *work.Job) error

- If you want your handler to accept a context:

  func (c *Context) YourFunctionName(job *work.Job) error  // or,

  func YourFunctionName(c *Context, job *work.Job) error

```
func (wp *WorkerPool) JobWithOptions(name string, jobOpts JobOptions, fn interface{}) *WorkerPool {
  jobOpts = applyDefaultsAndValidate(jobOpts)

  vfn := reflect.ValueOf(fn)
  validateHandlerType(wp.contextType, vfn)
  jt := &jobType{
    Name:           name,
    //vfn 任务消费方法的反射类型， 如果消费方法中有ctx 参数，那么会调用反射执行    
    DynamicHandler: vfn, 
    JobOptions:     jobOpts,
  }
  if gh, ok := fn.(func(*Job) error); ok {
    // 用户的任务消费函数，被赋值给了jobType的GenericHandler， 如果消费方法只有一个job参数，则执行GenericHandler
    jt.IsGeneric = true
    jt.GenericHandler = gh
  }

  wp.jobTypes[name] = jt

  for _, w := range wp.workers {
    w.updateMiddlewareAndJobTypes(wp.middleware, wp.jobTypes)
  }

  return wp
}
```



### 执行消费任务的真正代码

worker对象的processJob（job * Job） 方法 调用了runJob方法执行GenericHandler or DynamicHandler.Call

```
func runJob(job *Job, ctxType reflect.Type, middleware []*middlewareHandler, jt *jobType) (returnCtx reflect.Value, returnError error) {
  。。。。
  next = func() error {
    。。。。
    if jt.IsGeneric {
      // 任务消费方法没有ctx时候执行
      return jt.GenericHandler(job)
    }
    
    // 任务消费方法有ctx时执行
    res := jt.DynamicHandler.Call([]reflect.Value{returnCtx, reflect.ValueOf(job)})
    x := res[0].Interface()
    if x == nil {
      return nil
    }
    return x.(error)
  }
  ...
  returnError = next()

  return
}
```

### 真正代码

worker对象的processJob（job * Job） 方法 调用了runJob方法执行GenericHandler or DynamicHandler.Call

```
func runJob(job *Job, ctxType reflect.Type, middleware []*middlewareHandler, jt *jobType) (returnCtx reflect.Value, returnError error) {
  。。。。
  next = func() error {
    。。。。
    if jt.IsGeneric {
      // 任务消费方法没有ctx时候执行
      return jt.GenericHandler(job)
    }
    
    // 任务消费方法有ctx时执行
    res := jt.DynamicHandler.Call([]reflect.Value{returnCtx, reflect.ValueOf(job)})
    x := res[0].Interface()
    if x == nil {
      return nil
    }
    return x.(error)
  }
  ...
  returnError = next()

  return
}
```