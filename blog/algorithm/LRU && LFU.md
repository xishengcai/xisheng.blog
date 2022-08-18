### 简述

#### LRU : 缓存中淘汰最久未使用的是数据

通过维护一个列表，将使用过的数据放在最前，按照这种队列头部插入的方法，形成按使用时间排序的队列。当数据达到上限后，淘汰队尾元素。

```
type LRUCache struct{
	Capacility int
	keys map[string]*Element
	list *list.List
}
```





```
type Element struct{
	pre, next *Element
	head *List
	value interface{}
}
```







#### LFU：缓存中淘汰最近使用次数最少的

维护一个元素队列，元素每使用一次， 计数器+1，按计数器使用次数排序，淘汰队尾元素。













- [链接](https://halfrost.com/lru_lfu_interview/)