# Golang sync.map

[toc]

## 1. sampexample

```go
package main

import (
    "fmt"
    "sync"
)

func main()  {
    var m sync.Map
    // 1. 写入
    m.Store("qcrao", 18)
    m.Store("stefno", 20)

    // 2. 读取
    age, _ := m.Load("qcrao")
    fmt.Println(age.(int))

    // 3. 遍历
    m.Range(func(key, value interface{}) bool {
        name := key.(string)
        age := value.(int)
        fmt.Println(name, age)
        return true
    })

    // 4. 删除
    m.Delete("qcrao")
    age, ok := m.Load("qcrao")
    fmt.Println(age, ok)

    // 5. 读取或写入
    m.LoadOrStore("stefno", 100)
    age, _ = m.Load("stefno")
    fmt.Println(age)
}
```



## 2. map 数据结构分析

```go
type Map struct {
	mu Mutex

	// read contains the portion of the map's contents that are safe for
	// concurrent access (with or without mu held).
	//
	// The read field itself is always safe to load, but must only be stored with
	// mu held.
	//
	// Entries stored in read may be updated concurrently without mu, but updating
	// a previously-expunged entry requires that the entry be copied to the dirty
	// map and unexpunged with mu held.
	read atomic.Pointer[readOnly]

	// dirty contains the portion of the map's contents that require mu to be
	// held. To ensure that the dirty map can be promoted to the read map quickly,
	// it also includes all of the non-expunged entries in the read map.
	//
	// Expunged entries are not stored in the dirty map. An expunged entry in the
	// clean map must be unexpunged and added to the dirty map before a new value
	// can be stored to it.
	//
	// If the dirty map is nil, the next write to the map will initialize it by
	// making a shallow copy of the clean map, omitting stale entries.
	dirty map[any]*entry

	// misses counts the number of loads since the read map was last updated that
	// needed to lock mu to determine whether the key was present.
	//
	// Once enough misses have occurred to cover the cost of copying the dirty
	// map, the dirty map will be promoted to the read map (in the unamended
	// state) and the next store to the map will make a new dirty copy.
	misses int
}
```



互斥量 `mu` 保护 read 和 dirty。

`read` 是 atomic.Value 类型，可以并发地读。但如果需要更新 `read`，则需要加锁保护。对于 read 中存储的 entry 字段，可能会被并发地 CAS 更新。但是如果要更新一个之前已被删除的 entry，则需要先将其状态从 expunged 改为 nil，再拷贝到 dirty 中，然后再更新。

`dirty` 是一个非线程安全的原始 map。包含新写入的 key，并且包含 `read` 中的所有未被删除的 key。这样，可以快速地将 `dirty` 提升为 `read` 对外提供服务。如果 `dirty` 为 nil，那么下一次写入时，会新建一个新的 `dirty`，这个初始的 `dirty` 是 `read` 的一个拷贝，但除掉了其中已被删除的 key。

每当从 read 中读取失败，都会将 `misses` 的计数值加 1，当加到一定阈值以后，需要将 dirty 提升为 read，以期减少 miss 的情形。

> `read map` 和 `dirty map` 的存储方式是不一致的。
> 前者使用 atomic.Value，后者只是单纯的使用 map。
> 原因是 read map 使用 lock free 操作，必须保证 load/store 的原子性；而 dirty map 的 load+store 操作是由 lock（就是 mu）来保护的。

真正存储 `key/value` 的是 read 和 dirty 字段。`read` 使用 atomic.Value，这是 lock-free 的基础，保证 load/store 的原子性。`dirty` 则直接用了一个原始的 map，对于它的 load/store 操作需要加锁



`read` 字段里实际上是存储的是：

```go
// readOnly is an immutable struct stored atomically in the Map.read field.
type readOnly struct {
	m       map[any]*entry
	amended bool // true if the dirty map contains some key not in m.
}
```

注意到 read 和 dirty 里存储的东西都包含 `entry`，来看一下：

```go

// An entry is a slot in the map corresponding to a particular key.
type entry struct {
	// p points to the interface{} value stored for the entry.
	//
	// If p == nil, the entry has been deleted, and either m.dirty == nil or
	// m.dirty[key] is e.
	//
	// If p == expunged, the entry has been deleted, m.dirty != nil, and the entry
	// is missing from m.dirty.
	//
	// Otherwise, the entry is valid and recorded in m.read.m[key] and, if m.dirty
	// != nil, in m.dirty[key].
	//
	// An entry can be deleted by atomic replacement with nil: when m.dirty is
	// next created, it will atomically replace nil with expunged and leave
	// m.dirty[key] unset.
	//
	// An entry's associated value can be updated by atomic replacement, provided
	// p != expunged. If p == expunged, an entry's associated value can be updated
	// only after first setting m.dirty[key] = e so that lookups using the dirty
	// map find the entry.
	p atomic.Pointer[any]
}
```



```go
// A Pointer is an atomic pointer of type *T. The zero value is a nil *T.
type Pointer[T any] struct {
	// Mention *T in a field to disallow conversion between Pointer types.
	// See go.dev/issue/56603 for more details.
	// Use *T, not T, to avoid spurious recursive type definition errors.
	_ [0]*T

	_ noCopy
	v unsafe.Pointer
}
```



很简单，它是一个指针，指向 value。看来，read 和 dirty 各自维护一套 key，key 指向的都是同一个 value。也就是说，只要修改了这个 entry，对 read 和 dirty 都是可见的。这个指针的状态有三种：

![image-20230309081632730](/Users/xishengcai/soft/xisheng.blog/blog/golang/map/image-20230309081632730.png)

当 `p == nil` 时，说明这个键值对已被删除，并且 m.dirty == nil，或 m.dirty[k] 指向该 entry。

当 `p == expunged` 时，说明这条键值对已被删除，并且 m.dirty != nil，且 m.dirty 中没有这个 key。

其他情况，p 指向一个正常的值，表示实际 `interface{}` 的地址，并且被记录在 m.read.m[key] 中。如果这时 m.dirty 不为 nil，那么它也被记录在 m.dirty[key] 中。两者实际上指向的是同一个值。

当删除 key 时，并不实际删除。一个 entry 可以通过原子地（CAS 操作）设置 p 为 nil 被删除。如果之后创建 m.dirty，nil 又会被原子地设置为 expunged，且不会拷贝到 dirty 中。

如果 p 不为 expunged，和 entry 相关联的这个 value 可以被原子地更新；如果 `p == expunged`，那么仅当它初次被设置到 m.dirty 之后，才可以被更新。

![image-20230309081822688](/Users/xishengcai/soft/xisheng.blog/blog/golang/map/image-20230309081822688.png) 	



## 3. store

先来看 expunged：

```go
var expunged = unsafe.Pointer(new(interface{}))
```

它是一个指向任意类型的指针，用来标记从 dirty map 中删除的 entry。

```go
// Store sets the value for a key.
func (m *Map) Store(key, value interface{}) {
    // 如果 read map 中存在该 key  则尝试直接更改(由于修改的是 entry 内部的 pointer，因此 dirty map 也可见)
    read, _ := m.read.Load().(readOnly)
    if e, ok := read.m[key]; ok && e.tryStore(&value) {
        return
    }

    m.mu.Lock()
    read, _ = m.read.Load().(readOnly)
    if e, ok := read.m[key]; ok {
        if e.unexpungeLocked() {
            // 如果 read map 中存在该 key，但 p == expunged，则说明 m.dirty != nil 并且 m.dirty 中不存在该 key 值 此时:
            //    a. 将 p 的状态由 expunged  更改为 nil
            //    b. dirty map 插入 key
            m.dirty[key] = e
        }
        // 更新 entry.p = value (read map 和 dirty map 指向同一个 entry)
        e.storeLocked(&value)
    } else if e, ok := m.dirty[key]; ok {
        // 如果 read map 中不存在该 key，但 dirty map 中存在该 key，直接写入更新 entry(read map 中仍然没有这个 key)
        e.storeLocked(&value)
    } else {
        // 如果 read map 和 dirty map 中都不存在该 key，则：
        //    a. 如果 dirty map 为空，则需要创建 dirty map，并从 read map 中拷贝未删除的元素到新创建的 dirty map
        //    b. 更新 amended 字段，标识 dirty map 中存在 read map 中没有的 key
        //    c. 将 kv 写入 dirty map 中，read 不变
        if !read.amended {
            // 到这里就意味着，当前的 key 是第一次被加到 dirty map 中。
            // store 之前先判断一下 dirty map 是否为空，如果为空，就把 read map 浅拷贝一次。
            m.dirtyLocked()
            m.read.Store(readOnly{m: read.m, amended: true})
        }
        // 写入新 key，在 dirty 中存储 value
        m.dirty[key] = newEntry(value)
    }
    m.mu.Unlock()
}
```

整体流程：

1. 如果在 read 里能够找到待存储的 key，并且对应的 entry 的 p 值不为 expunged，也就是没被删除时，直接更新对应的 entry 即可。
2. 第一步没有成功：要么 read 中没有这个 key，要么 key 被标记为删除。则先加锁，再进行后续的操作。
3. 再次在 read 中查找是否存在这个 key，也就是 double check 一下，这也是 lock-free 编程里的常见套路。如果 read 中存在该 key，但 `p == expunged`，说明 m.dirty != nil 并且 m.dirty 中不存在该 key 值 此时: a. 将 p 的状态由 expunged 更改为 nil；b. dirty map 插入 key。然后，直接更新对应的 value。
4. 如果 read 中没有此 key，那就查看 dirty 中是否有此 key，如果有，则直接更新对应的 value，这时 read 中还是没有此 key。
5. 最后一步，如果 read 和 dirty 中都不存在该 key，则：a. 如果 dirty 为空，则需要创建 dirty，并从 read 中拷贝未被删除的元素；b. 更新 amended 字段，标识 dirty map 中存在 read map 中没有的 key；c. 将 k-v 写入 dirty map 中，read.m 不变。最后，更新此 key 对应的 value。

先来看 expunged：

```text
var expunged = unsafe.Pointer(new(interface{}))
```

它是一个指向任意类型的指针，用来标记从 dirty map 中删除的 entry。

```text
// Store sets the value for a key.
func (m *Map) Store(key, value interface{}) {
    // 如果 read map 中存在该 key  则尝试直接更改(由于修改的是 entry 内部的 pointer，因此 dirty map 也可见)
    read, _ := m.read.Load().(readOnly)
    if e, ok := read.m[key]; ok && e.tryStore(&value) {
        return
    }

    m.mu.Lock()
    read, _ = m.read.Load().(readOnly)
    if e, ok := read.m[key]; ok {
        if e.unexpungeLocked() {
            // 如果 read map 中存在该 key，但 p == expunged，则说明 m.dirty != nil 并且 m.dirty 中不存在该 key 值 此时:
            //    a. 将 p 的状态由 expunged  更改为 nil
            //    b. dirty map 插入 key
            m.dirty[key] = e
        }
        // 更新 entry.p = value (read map 和 dirty map 指向同一个 entry)
        e.storeLocked(&value)
    } else if e, ok := m.dirty[key]; ok {
        // 如果 read map 中不存在该 key，但 dirty map 中存在该 key，直接写入更新 entry(read map 中仍然没有这个 key)
        e.storeLocked(&value)
    } else {
        // 如果 read map 和 dirty map 中都不存在该 key，则：
        //    a. 如果 dirty map 为空，则需要创建 dirty map，并从 read map 中拷贝未删除的元素到新创建的 dirty map
        //    b. 更新 amended 字段，标识 dirty map 中存在 read map 中没有的 key
        //    c. 将 kv 写入 dirty map 中，read 不变
        if !read.amended {
            // 到这里就意味着，当前的 key 是第一次被加到 dirty map 中。
            // store 之前先判断一下 dirty map 是否为空，如果为空，就把 read map 浅拷贝一次。
            m.dirtyLocked()
            m.read.Store(readOnly{m: read.m, amended: true})
        }
        // 写入新 key，在 dirty 中存储 value
        m.dirty[key] = newEntry(value)
    }
    m.mu.Unlock()
}
```

整体流程：

1. 如果在 read 里能够找到待存储的 key，并且对应的 entry 的 p 值不为 expunged，也就是没被删除时，直接更新对应的 entry 即可。
2. 第一步没有成功：要么 read 中没有这个 key，要么 key 被标记为删除。则先加锁，再进行后续的操作。
3. 再次在 read 中查找是否存在这个 key，也就是 double check 一下，这也是 lock-free 编程里的常见套路。如果 read 中存在该 key，但 `p == expunged`，说明 m.dirty != nil 并且 m.dirty 中不存在该 key 值 此时: a. 将 p 的状态由 expunged 更改为 nil；b. dirty map 插入 key。然后，直接更新对应的 value。
4. 如果 read 中没有此 key，那就查看 dirty 中是否有此 key，如果有，则直接更新对应的 value，这时 read 中还是没有此 key。
5. 最后一步，如果 read 和 dirty 中都不存在该 key，则：a. 如果 dirty 为空，则需要创建 dirty，并从 read 中拷贝未被删除的元素；b. 更新 amended 字段，标识 dirty map 中存在 read map 中没有的 key；c. 将 k-v 写入 dirty map 中，read.m 不变。最后，更新此 key 对应的 value。



// unexpungeLocked 函数确保了 entry 没有被标记成已被清除。

```text
// 如果 entry 先前被清除过了，那么在 mutex 解锁之前，它一定要被加入到 dirty map 中
func (e *entry) unexpungeLocked() (wasExpunged bool) {
    return atomic.CompareAndSwapPointer(&e.p, expunged, nil)
}
```



## 4. Load

```text
func (m *Map) Load(key interface{}) (value interface{}, ok bool) {
    read, _ := m.read.Load().(readOnly)
    e, ok := read.m[key]
    // 如果没在 read 中找到，并且 amended 为 true，即 dirty 中存在 read 中没有的 key
    if !ok && read.amended {
        m.mu.Lock() // dirty map 不是线程安全的，所以需要加上互斥锁
        // double check。避免在上锁的过程中 dirty map 提升为 read map。
        read, _ = m.read.Load().(readOnly)
        e, ok = read.m[key]
        // 仍然没有在 read 中找到这个 key，并且 amended 为 true
        if !ok && read.amended {
            e, ok = m.dirty[key] // 从 dirty 中找
            // 不管 dirty 中有没有找到，都要"记一笔"，因为在 dirty 提升为 read 之前，都会进入这条路径
            m.missLocked()
        }
        m.mu.Unlock()
    }
    if !ok { // 如果没找到，返回空，false
        return nil, false
    }
    return e.load()
}
```

处理路径分为 fast path 和 slow path，整体流程如下：

1. 首先是 fast path，直接在 read 中找，如果找到了直接调用 entry 的 load 方法，取出其中的值。
2. 如果 read 中没有这个 key，且 amended 为 fase，说明 dirty 为空，那直接返回 空和 false。
3. 如果 read 中没有这个 key，且 amended 为 true，说明 dirty 中可能存在我们要找的 key。当然要先上锁，再尝试去 dirty 中查找。在这之前，仍然有一个 double check 的操作。若还是没有在 read 中找到，那么就从 dirty 中找。不管 dirty 中有没有找到，都要"记一笔"，因为在 dirty 被提升为 read 之前，都会进入这条路径

这里主要看下 `missLocked` 的函数的实现：

```text
func (m *Map) missLocked() {
    m.misses++
    if m.misses < len(m.dirty) {
        return
    }
    // dirty map 晋升
    m.read.Store(readOnly{m: m.dirty})
    m.dirty = nil
    m.misses = 0
}
```

直接将 misses 的值加 1，表示一次未命中，如果 misses 值小于 m.dirty 的长度，就直接返回。否则，将 m.dirty 晋升为 read，并清空 dirty，清空 misses 计数值。这样，之前一段时间新加入的 key 都会进入到 read 中，从而能够提升 read 的命中率。

再来看下 entry 的 load 方法：

```text
func (e *entry) load() (value interface{}, ok bool) {
    p := atomic.LoadPointer(&e.p)
    if p == nil || p == expunged {
        return nil, false
    }
    return *(*interface{})(p), true
}
```

对于 nil 和 expunged 状态的 entry，直接返回 `ok=false`；否则，将 p 转成 `interface{}` 返回。

## 5. Delete

```text
// Delete deletes the value for a key.
func (m *Map) Delete(key interface{}) {
    read, _ := m.read.Load().(readOnly)
    e, ok := read.m[key]
    // 如果 read 中没有这个 key，且 dirty map 不为空
    if !ok && read.amended {
        m.mu.Lock()
        read, _ = m.read.Load().(readOnly)
        e, ok = read.m[key]
        if !ok && read.amended {
            delete(m.dirty, key) // 直接从 dirty 中删除这个 key
        }
        m.mu.Unlock()
    }
    if ok {
        e.delete() // 如果在 read 中找到了这个 key，将 p 置为 nil
    }
}
```

可以看到，基本套路还是和 Load，Store 类似，都是先从 read 里查是否有这个 key，如果有则执行 `entry.delete` 方法，将 p 置为 nil，这样 read 和 dirty 都能看到这个变化。

如果没在 read 中找到这个 key，并且 dirty 不为空，那么就要操作 dirty 了，操作之前，还是要先上锁。然后进行 double check，如果仍然没有在 read 里找到此 key，则从 dirty 中删掉这个 key。但不是真正地从 dirty 中删除，而是更新 entry 的状态。

来看下 `entry.delete` 方法：

```text
func (e *entry) delete() (hadValue bool) {
    for {
        p := atomic.LoadPointer(&e.p)
        if p == nil || p == expunged {
            return false
        }
        if atomic.CompareAndSwapPointer(&e.p, p, nil) {
            return true
        }
    }
}
```

它真正做的事情是将正常状态（指向一个 interface{}）的 p 设置成 nil。没有设置成 expunged 的原因是，当 p 为 expunged 时，表示它已经不在 dirty 中了。这是 p 的状态机决定的，在 `tryExpungeLocked` 函数中，会将 nil 原子地设置成 expunged。

`tryExpungeLocked` 是在新创建 dirty 时调用的，会将已被删除的 entry.p 从 nil 改成 expunged，这个 entry 就不会写入 dirty 了。

```text
func (e *entry) tryExpungeLocked() (isExpunged bool) {
    p := atomic.LoadPointer(&e.p)
    for p == nil {
        // 如果原来是 nil，说明原 key 已被删除，则将其转为 expunged。
        if atomic.CompareAndSwapPointer(&e.p, nil, expunged) {
            return true
        }
        p = atomic.LoadPointer(&e.p)
    }
    return p == expunged
}
```

注意到如果 key 同时存在于 read 和 dirty 中时，删除只是做了一个标记，将 p 置为 nil；而如果仅在 dirty 中含有这个 key 时，会直接删除这个 key。原因在于，若两者都存在这个 key，仅做标记删除，可以在下次查找这个 key 时，命中 read，提升效率。若只有在 dirty 中存在时，read 起不到“缓存”的作用，直接删除。



## 6. LoadOrStore

这个函数结合了 Load 和 Store 的功能，如果 map 中存在这个 key，那么返回这个 key 对应的 value；否则，将 key-value 存入 map。这在需要先执行 Load 查看某个 key 是否存在，之后再更新此 key 对应的 value 时很有效，因为 LoadOrStore 可以并发执行。

具体的过程不再一一分析了，可参考 Load 和 Store 的源码分析。



## 7. Range

Range 的参数是一个函数：

```text
f func(key, value interface{}) bool
```

由使用者提供实现，Range 将遍历调用时刻 map 中的所有 k-v 对，将它们传给 f 函数，如果 f 返回 false，将停止遍历。

```text
func (m *Map) Range(f func(key, value interface{}) bool) {
    read, _ := m.read.Load().(readOnly)
    if read.amended {
        m.mu.Lock()
        read, _ = m.read.Load().(readOnly)
        if read.amended {
            read = readOnly{m: m.dirty}
            m.read.Store(read)
            m.dirty = nil
            m.misses = 0
        }
        m.mu.Unlock()
    }

    for k, e := range read.m {
        v, ok := e.load()
        if !ok {
            continue
        }
        if !f(k, v) {
            break
        }
    }
}
```

当 amended 为 true 时，说明 dirty 中含有 read 中没有的 key，因为 Range 会遍历所有的 key，是一个 O(n) 操作。将 dirty 提升为 read，会将开销分摊开来，所以这里直接就提升了。

之后，遍历 read，取出 entry 中的值，调用 f(k, v)。



## 8. 其他

关于为何 `sync.map` 没有 Len 方法，参考资料里给出了 [issue](https://link.zhihu.com/?target=https%3A//github.com/golang/go/issues/20680)，`bcmills` 认为对于并发的数据结构和非并发的数据结构并不一定要有相同的方法。例如，map 有 Len 方法，sync.map 却不一定要有。就像 sync.map 有 LoadOrStore 方法，map 就没有一样。

有些实现增加了一个计数器，并原子地增加或减少它，以此来表示 sync.map 中元素的个数。但 `bcmills` 提出这会引入竞争：`atomic` 并不是 `contention-free` 的，它只是把竞争下沉到了 CPU 层级。这会给其他不需要 Len 方法的场景带来负担。



## 总结

1. `sync.map` 是线程安全的，读取，插入，删除也都保持着常数级的时间复杂度。
2. 通过读写分离，降低锁时间来提高效率，适用于读多写少的场景。
3. Range 操作需要提供一个函数，参数是 `k,v`，返回值是一个布尔值：`f func(key, value interface{}) bool`。
4. 调用 Load 或 LoadOrStore 函数时，如果在 read 中没有找到 key，则会将 misses 值原子地增加 1，当 misses 增加到和 dirty 的长度相等时，会将 dirty 提升为 read。以期减少“读 miss”。
5. 新写入的 key 会保存到 dirty 中，如果这时 dirty 为 nil，就会先新创建一个 dirty，并将 read 中未被删除的元素拷贝到 dirty。
6. 当 dirty 为 nil 的时候，read 就代表 map 所有的数据；当 dirty 不为 nil 的时候，dirty 才代表 map 所有的数据。

## 参考资料

【德志大佬-设计并发安全的 map】[https://halfrost.com/go_map_chapter_one/](https://link.zhihu.com/?target=https%3A//halfrost.com/go_map_chapter_one/)

【德志大佬-设计并发安全的 map】[https://halfrost.com/go_map_chapter_two/](https://link.zhihu.com/?target=https%3A//halfrost.com/go_map_chapter_two/)

【关于 sync.map 为什么没有 len 方法的 issue】[https://github.com/golang/go/issues/20680](https://link.zhihu.com/?target=https%3A//github.com/golang/go/issues/20680)

【芮神增加了 len 方法】[http://xiaorui.cc/archives/4972](https://link.zhihu.com/?target=http%3A//xiaorui.cc/archives/4972)

【图解 map 操作】[https://wudaijun.com/2018/02/go-sync-map-implement/](https://link.zhihu.com/?target=https%3A//wudaijun.com/2018/02/go-sync-map-implement/)

【从一道面试题开始】[https://segmentfault.com/a/1190000018657984](https://link.zhihu.com/?target=https%3A//segmentfault.com/a/1190000018657984)

【源码分析】https://zhuanlan.zhihu.com/p/44585993

【行文通畅，流程图清晰】[https://juejin.im/post/5d36a7cbf265da1bb47da444](https://link.zhihu.com/?target=https%3A//juejin.im/post/5d36a7cbf265da1bb47da444)