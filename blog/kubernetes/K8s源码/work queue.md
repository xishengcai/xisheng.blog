# work queue

[toc]

## what is it

Package work queue provides a simple queue that supports the following features:

* Fair: items processed in the order in which they are added

* Stingy: a single item will not be processed multiple times concurrently, and  if  an item

  is added multiple times before it can be processed, it will only be processed once.

* Multple consumers and producers. In particular, it is allowed for an item to be reenqueued

  while it is being processed.

* Shutdown notifications.

### 接口定义

```go
type Interface interface {
	Add(item interface{})
	Len() int
	Get() (item interface{}, shutdown bool)
	Done(item interface{})
	ShutDown()
	ShuttingDown() bool
}
```



### 数据结构

```go
// Type is a work queue (see the package comment).
type Type struct {
	// queue defines the order in which we will work on items. Every
	// element of queue should be in the dirty set and not in the
	// processing set.
	queue []t

	// dirty defines all of the items that need to be processed.
  // dirty 是对待消费的元素进行去重, 所谓待消费就是未被处理中.
	dirty set

	// Things that are currently being processed are in the processing set.
	// These things may be simultaneously in the dirty set. When we finish
	// processing something and remove it from this set, we'll check if
	// it's in the dirty set, and if so, add it to the queue.
  // processing 是对正在处理的元素进行去重和重排队.
	processing set

	cond *sync.Cond

	shuttingDown bool

	metrics queueMetrics

	unfinishedWorkUpdatePeriod time.Duration
	clock                      clock.Clock
}
```



### 无重复元素的set集合

```go
type empty struct{}
type t interface{}
type set map[t]empty

func (s set) has(item t) bool {
	_, exists := s[item]
	return exists
}

func (s set) insert(item t) {
	s[item] = empty{}
}

func (s set) delete(item t) {
	delete(s, item)
}
```





### Add(item interface{})

- 去重
- 防止同一个元素被并发处理

```go
// Add marks item as needing processing.
func (q *Type) Add(item interface{}) {
	q.cond.L.Lock()
	defer q.cond.L.Unlock()
	if q.shuttingDown {
		return
	}
  // 通过map 结构实现 set， 实现去重，在放入数组前，先放入 map
	if q.dirty.has(item) {
		return
	}

	q.metrics.add(item)

	q.dirty.insert(item)
	if q.processing.has(item) {
		return
	}

	q.queue = append(q.queue, item)
	q.cond.Signal()
}
```



case：

	shuttingDown
	
	dirty.has(item)
	
	processing.has(item)

可能的状态

| Queue | Dirty | Processing |
| ----- | ----- | ---------- |
| 1     | 1     | 0          |
| 0     | 0     | 1          |
| 0     | 1     | 1          |



### Len()

```go
// Len returns the current queue length, for informational purposes only. You
// shouldn't e.g. gate a call to Add() or Get() on Len() being a particular
// value, that can't be synchronized properly.
func (q *Type) Len() int {
	q.cond.L.Lock()
	defer q.cond.L.Unlock()
	return len(q.queue)
}

```

​	

### Get()

- 同时从 set 和 queue 中取出
- 放入处理中队列

```go
// Get blocks until it can return an item to be processed. If shutdown = true,
// the caller should end their goroutine. You must call Done with item when you
// have finished processing it.
func (q *Type) Get() (item interface{}, shutdown bool) {
	q.cond.L.Lock()
	defer q.cond.L.Unlock()
	for len(q.queue) == 0 && !q.shuttingDown {
		q.cond.Wait()
	}
	if len(q.queue) == 0 {
		// We must be shutting down.
		return nil, true
	}

  // pop head
	item, q.queue = q.queue[0], q.queue[1:]

	q.metrics.get(item)

  // 放入处理中队列
	q.processing.insert(item)
  
	q.dirty.delete(item)

	return item, false
}
```





### Done(item interface{})

- 删除processing中的元素
- 如果dirty 中有元素，append item to queue

`Done()` 用来标记某元素已经处理完, 可以从 processing 集合中去除, 然后判断 dirty 集合中是否有该对象, 如果存在则把该对象推到 queue 里再次入队. 这么让人迷糊的过程, 通过 processing 标记该元素正在被处理但还未完成, 其目的就是为了防止一个元素被并发同时处理.

如果一个元素正在被处理, 这时候如果再次添加同一个元素, 由于该元素还在处理未完成, 只能把对象放到 dirty 里, 为什么不放到 queue slice 里, 因为放 queue slice 里, 并发消费场景下, 同一个元素会被多个协程并发处理. 当执行完毕调用 `Done()` 时, 会把 dirty 的任务重新入队, 起到了排队的效果.

```go
// Done marks item as done processing, and if it has been marked as dirty again
// while it was being processed, it will be re-added to the queue for
// re-processing.
func (q *Type) Done(item interface{}) {
	q.cond.L.Lock()
	defer q.cond.L.Unlock()

	q.metrics.done(item)

	q.processing.delete(item)
	if q.dirty.has(item) {
		q.queue = append(q.queue, item)
		q.cond.Signal()
	}
}
```





## 延时队列接口定义

```go
// DelayingInterface is an Interface that can Add an item at a later time. This makes it easier to
// requeue items after failures without ending up in a hot-loop.
type DelayingInterface interface {
	Interface
	// AddAfter adds an item to the workqueue after the indicated duration has passed
  // 塞入 channel 缓冲区
	AddAfter(item interface{}, duration time.Duration)
}
```



### 数据结构

```go
// delayingType wraps an Interface and provides delayed re-enquing
type delayingType struct {
	Interface

	// clock tracks time for delayed firing
	clock clock.Clock

	// stopCh lets us signal a shutdown to the waiting loop
	stopCh chan struct{}
	// stopOnce guarantees we only signal shutdown a single time
	stopOnce sync.Once

	// heartbeat ensures we wait no more than maxWait before firing
	heartbeat clock.Ticker

	// waitingForAddCh is a buffered channel that feeds waitingForAdd
	waitingForAddCh chan *waitFor

	// metrics counts the number of retries
	metrics retryMetrics
}
```

### delayingQueue 关键方法的实现原理



![image-20230706111326778](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20230706111326778.png)

delayingQueue.	 首先使用数据结构小顶堆 minheap 来排列定时任务. 当添加定时任务时, 把该任务扔到一个 chan 里, 然后由一个独立的协程监听该 chan, 把任务扔到 heap 中, 该独立协程会从堆里找到最近到期的任务, 并对该任务的进行到期监听, 当定时后期后, 会把到期的定时任务添加到 queue 队列中.



### AddAfter(item interface{})

1. 判断延时时间
2. 放入 queue or waitingForAddCh

```go
// AddAfter adds the given item to the work queue after the given delay
func (q *delayingType) AddAfter(item interface{}, duration time.Duration) {
   // don't add if we're already shutting down
   if q.ShuttingDown() {
      return
   }

   q.metrics.retry()

   // immediately add things with no delay
   if duration <= 0 {
      q.Add(item)
      return
   }

   select {
   case <-q.stopCh:
      // unblock if ShutDown() is called
   case q.waitingForAddCh <- &waitFor{data: item, readyAt: q.clock.Now().Add(duration)}:
   }
}
```





### waitingLoop

1. Get item from waitingForCh to waitingForQueue
2. Pop item from waitingForQueue to queue

```go
// waitingLoop runs until the workqueue is shutdown and keeps a check on the list of items to be added.
func (q *delayingType) waitingLoop() {
	defer utilruntime.HandleCrash()

	// Make a placeholder channel to use when there are no items in our list
	never := make(<-chan time.Time)

	// Make a timer that expires when the item at the head of the waiting queue is ready
	var nextReadyAtTimer clock.Timer

	waitingForQueue := &waitForPriorityQueue{}
	heap.Init(waitingForQueue)

	waitingEntryByData := map[t]*waitFor{}

	for {
		if q.Interface.ShuttingDown() {
			return
		}

		now := q.clock.Now()

		// Add ready entries
		for waitingForQueue.Len() > 0 {
			entry := waitingForQueue.Peek().(*waitFor)
			if entry.readyAt.After(now) {
				break
			}

			entry = heap.Pop(waitingForQueue).(*waitFor)
			q.Add(entry.data)
			delete(waitingEntryByData, entry.data)
		}

		// Set up a wait for the first item's readyAt (if one exists)
		nextReadyAt := never
		if waitingForQueue.Len() > 0 {
			if nextReadyAtTimer != nil {
				nextReadyAtTimer.Stop()
			}
			entry := waitingForQueue.Peek().(*waitFor)
			nextReadyAtTimer = q.clock.NewTimer(entry.readyAt.Sub(now))
			nextReadyAt = nextReadyAtTimer.C()
		}

		select {
		case <-q.stopCh:
			return

		case <-q.heartbeat.C():
			// continue the loop, which will add ready items

		case <-nextReadyAt:
			// continue the loop, which will add ready items

		case waitEntry := <-q.waitingForAddCh:
			if waitEntry.readyAt.After(q.clock.Now()) {
				insert(waitingForQueue, waitingEntryByData, waitEntry)
			} else {
				q.Add(waitEntry.data)
			}

			drained := false
			for !drained {
				select {
				case waitEntry := <-q.waitingForAddCh:
					if waitEntry.readyAt.After(q.clock.Now()) {
						insert(waitingForQueue, waitingEntryByData, waitEntry)
					} else {
						q.Add(waitEntry.data)
					}
				default:
					drained = true
				}
			}
		}
	}
}

```



### 小顶堆

```go
type waitFor struct {
	// 存放元素
	data    t

	// 时间点
	readyAt time.Time

	// 同一个时间点下对比递增的索引
	index int
}

type waitForPriorityQueue []*waitFor

func (pq waitForPriorityQueue) Len() int {
	return len(pq)
}
func (pq waitForPriorityQueue) Less(i, j int) bool {
	return pq[i].readyAt.Before(pq[j].readyAt)
}
func (pq waitForPriorityQueue) Swap(i, j int) {
	pq[i], pq[j] = pq[j], pq[i]
	pq[i].index = i
	pq[j].index = j
}

func (pq *waitForPriorityQueue) Push(x interface{}) {
	n := len(*pq)
	item := x.(*waitFor)
	item.index = n
	*pq = append(*pq, item)
}

func (pq *waitForPriorityQueue) Pop() interface{} {
	n := len(*pq)
	item := (*pq)[n-1]
	item.index = -1
	*pq = (*pq)[0:(n - 1)]
	return item
}

func (pq waitForPriorityQueue) Peek() interface{} {
	return pq[0]
}
```



## RateLimitingInterface 限频队列

![img](https://camo.githubusercontent.com/c2a8d1e99ccca0405c1e7f244c05b4801b04dcc118660dc61fb365a20bcbaa9a/68747470733a2f2f7869616f7275692d63632e6f73732d636e2d68616e677a686f752e616c6979756e63732e636f6d2f696d616765732f3230323330312f3230323330313134313635373334312e706e67)

`RateLimitingInterface` 是在 DelayingInterface 基础上实现的队列. k8s 的 controller/scheduler/ ... 组件都有使用 `RateLimitingInterface`.

通过 `AddRateLimited` 入队时, 需要先经过 ratelimiter 计算是否触发限频. 如需限频则计算该元素所需的 delay 时长, 把该对象推到 DelayingInterface 延迟队列中处理.

`DelayingInterface` 内部的 `waitingLoop` 协程会监听由 `AddRateLimited` 推入的定时任务, 如果是延迟任务则放到 heap 里, 否则立马推到 Queue 队列里.



### 接口定义

```go
// RateLimitingInterface is an interface that rate limits items being added to the queue.
type RateLimitingInterface interface {
	DelayingInterface

	// AddRateLimited adds an item to the workqueue after the rate limiter says it's ok
	AddRateLimited(item interface{})

	// Forget indicates that an item is finished being retried.  Doesn't matter whether it's for perm failing
	// or for success, we'll stop the rate limiter from tracking it.  This only clears the `rateLimiter`, you
	// still have to call `Done` on the queue.
	Forget(item interface{})

	// NumRequeues returns back how many times the item was requeued
	NumRequeues(item interface{}) int
}
```



### 数据结构

```go
// rateLimitingType wraps an Interface and provides rateLimited re-enquing
type rateLimitingType struct {
   DelayingInterface

   rateLimiter RateLimiter
}
```



### RateLimitingInterface 的代码实现

在实例化 `rateLimitingType` 时, 需要创建 DelayingInterface 和配置 Ratelimiter.

`AddRateLimited` 方法是通过限频器计算出需要等待的时长, 然后调用 `delayingQueue.AddAfter()` 方法来决定把对象扔到延迟队里还是队列里.

k8s 控制器在使用限频类的 workqueue 时, 当入队超过一定阈值后会采用异步的方法来添加任务, 这样对于 k8s controller 来说避免了同步等待, 及时去处理后面任务.

拿 deploment controller 来说, informer 关联的 eventHanlder 方法直接用 `Add` 入队. 只有错误的时候才会使用 `AddRateLimited` 进行入队.

另外 `Forget` 方法是在 rateLimiter 里清理掉某对象的相关记录. 值得注意的是, 不是所有的 rateLimiter 真正的实现了该接口. 具体情况还是要分析 ratelimiter 代码.

```go
// NewRateLimitingQueue constructs a new workqueue with rateLimited queuing ability
// Remember to call Forget!  If you don't, you may end up tracking failures forever.
func NewRateLimitingQueue(rateLimiter RateLimiter) RateLimitingInterface {
	return &rateLimitingType{
		DelayingInterface: NewDelayingQueue(),
		rateLimiter:       rateLimiter,
	}
}

// 实现了 RateLimitingInterface 接口
type rateLimitingType struct {
	DelayingInterface

	rateLimiter RateLimiter
}

// 通过限频器计算出需要当代的时间, 如需要等待, 然后把对象扔到延迟队里.
// AddRateLimited AddAfter's the item based on the time when the rate limiter says it's ok
func (q *rateLimitingType) AddRateLimited(item interface{}) {
	q.DelayingInterface.AddAfter(item, q.rateLimiter.When(item))
}


// 从限频器里获取该对象的计数信息.
func (q *rateLimitingType) NumRequeues(item interface{}) int {
	return q.rateLimiter.NumRequeues(item)
}

// 从限频器里删除该对象的记录的信息.
func (q *rateLimitingType) Forget(item interface{}) {
	q.rateLimiter.Forget(item)
}


```

### RateLimiter 的具体的实现

下面为 RateLimiter 的接口定义.

```go
type RateLimiter interface {
	// 获取该元素需要等待多久才能入队.
	When(item interface{}) time.Duration

	// 删除该元素的追踪记录, 有些 rateLimiter 记录了该对象的次数.
	Forget(item interface{})

	// 该对象记录的次数
	NumRequeues(item interface{}) int
}
```

下面是 workqueue 内置的几个 RateLimiter 限频器. 当然也可以自定义限频器, 只需实现 `RateLimiter` 接口即可.

- BucketRateLimiter, 通过 rate.Limiter 进行限速.
- ItemExponentialFailureRateLimiter, 通过 backoff 进行限速.
- ItemFastSlowRateLimiter, 超过阈值则使用 fastDelay, 否则使用 slowDelay 等待间隔.
- MaxOfRateLimiter, 抽象了 RateLimiter 方法, 可以同时对多个 rateLimiter 实例进行计算, 最后求出合理值.

源码位置: `util/workqueue/default_rate_limiters.go`

#### 令牌桶限速器的实现原理

```go
type BucketRateLimiter struct {
	*rate.Limiter
}

// 该类实现了 RateLimiter 接口
var _ RateLimiter = &BucketRateLimiter{}

func (r *BucketRateLimiter) When(item interface{}) time.Duration {
	// 通过 rate 获取新元素需要等待的时间.
	return r.Limiter.Reserve().Delay()
}

func (r *BucketRateLimiter) NumRequeues(item interface{}) int {
	// 直接返回 0.
	return 0
}

func (r *BucketRateLimiter) Forget(item interface{}) {
	// 暂未实现该方法.
}
```



#### 基于 backoff ratelimiter 的实现原理

使用一个 map 记录了各个元素的计数, 后通过经典 backoff 算法可以求出当前需要等待的时长. 默认为 1, 只要不 Forget 抹掉计数, 那么下次再入队时, 其等待的时长为上次的二次方.

```go
type ItemExponentialFailureRateLimiter struct {
	failuresLock sync.Mutex
	failures     map[interface{}]int

	baseDelay time.Duration
	maxDelay  time.Duration
}

func NewItemExponentialFailureRateLimiter(baseDelay time.Duration, maxDelay time.Duration) RateLimiter {
	return &ItemExponentialFailureRateLimiter{
		failures:  map[interface{}]int{},
		baseDelay: baseDelay,
		maxDelay:  maxDelay,
	}
}

func (r *ItemExponentialFailureRateLimiter) When(item interface{}) time.Duration {
	r.failuresLock.Lock()
	defer r.failuresLock.Unlock()

	// 获取上次计数, 且递增增加一.
	exp := r.failures[item]
	r.failures[item] = r.failures[item] + 1

	// 通过公式计算 backoff 时长, 当前时长为上次的二次方.
	backoff := float64(r.baseDelay.Nanoseconds()) * math.Pow(2, float64(exp))
	if backoff > math.MaxInt64 {
		// 不能超过 maxDelay
		return r.maxDelay
	}

	// 把纳秒的时间戳转成 time duration
	calculated := time.Duration(backoff)
	if calculated > r.maxDelay {
		// 不能超过 maxDelay
		return r.maxDelay
	}

	return calculated
}

// 获取该对象的入队的次数.
func (r *ItemExponentialFailureRateLimiter) NumRequeues(item interface{}) int {
	r.failuresLock.Lock()
	defer r.failuresLock.Unlock()

	return r.failures[item]
}

// 不在追踪该对象, 在这里是不记录该对象的次数.
func (r *ItemExponentialFailureRateLimiter) Forget(item interface{}) {
	r.failuresLock.Lock()
	defer r.failuresLock.Unlock()

	delete(r.failures, item)
}
```



#### MaxOfRateLimiter 的实现原理

`MaxOfRateLimiter` 实例化时可以传入多个 RateLimiter 限速器实例, 使用 `When()` 求等待间隔时, 遍历计算所有的 RateLimiter 实例, 求最大的时长. `Forget()` 同理, 也是对所有的 RateLimiter 集合遍历调用.

```go
type MaxOfRateLimiter struct {
	// 多个 ratelimiter 实例
	limiters []RateLimiter
}

func (r *MaxOfRateLimiter) When(item interface{}) time.Duration {
	ret := time.Duration(0)
	// 依次调用, 求最大的时长
	for _, limiter := range r.limiters {
		curr := limiter.When(item)
		if curr > ret {
			ret = curr
		}
	}

	return ret
}

// 创建入口
func NewMaxOfRateLimiter(limiters ...RateLimiter) RateLimiter {
	return &MaxOfRateLimiter{limiters: limiters}
}

func (r *MaxOfRateLimiter) NumRequeues(item interface{}) int {
	ret := 0
	// 依次调用, 求最大
	for _, limiter := range r.limiters {
		curr := limiter.NumRequeues(item)
		if curr > ret {
			ret = curr
		}
	}

	return ret
}

func (r *MaxOfRateLimiter) Forget(item interface{}) {
	// 依次调用
	for _, limiter := range r.limiters {
		limiter.Forget(item)
	}
}
```



## 总结

client-go workqueue 共实现了三个队列类型. 

Interface 为基本的队列类型. DelayingInterface 在 Interface 基础上实现的延迟队列. `RateLimitingInterface` 又在 DelayingInterface 基础上实现的限频队列.

![](https://xiaorui-cc.oss-cn-hangzhou.aliyuncs.com/images/202301/202301141656245.png)

从 k8s controller/scheduler/kube-proxy/kubelet ... 等组件源码中, 可以找到不少经典的 workqueue 的用法. 

其简化的流程原理是这样. 先通过 k8s informer 监听资源的变更, 实例化 informer 时需注册 addFunc/updateFunc/deleteFunc 事件方法. 这事件方法对应的操作是把 delta 对象扔到 workqueue 里. 控制器通常会开启多个协程去 workqueue 消费, 拿到的对象后使用控制器的 sync 进行状态同步.

![](https://xiaorui-cc.oss-cn-hangzhou.aliyuncs.com/images/202301/202301142109871.png)