

# golang map



map 是一种经典的数据结构，描述的 key 与 value 的对应关系。

最常见的实现方式有两种： hash 散列 和 平衡树



## 设计哈希算法有两大核心： hash 函数和 解决hash 冲突





```go
// A header for a Go map.
type hmap struct {
	// Note: the format of the hmap is also encoded in cmd/compile/internal/reflectdata/reflect.go.
	// Make sure this stays in sync with the compiler's definition.
   // 元素个数，调用 len(map) 时，直接返回此值
	count     int // # live cells == size of map.  Must be first (used by len() builtin)
	flags     uint8
	B         uint8  // log_2 of # of buckets (can hold up to loadFactor * 2^B items)
	noverflow uint16 // approximate number of overflow buckets; see incrnoverflow for details
	hash0     uint32 // hash seed

   // buckets 的对数 log_2
	buckets    unsafe.Pointer // array of 2^B Buckets. may be nil if count==0.
	oldbuckets unsafe.Pointer // previous bucket array of half the size, non-nil only when growing
	nevacuate  uintptr        // progress counter for evacuation (buckets less than this have been evacuated)

	extra *mapextra // optional fields
}
```



需要实现的功能

1. 长度 （count）
2. 扩容 （oldbuckets， nevacuate）
3. 解决hash 冲突 （hash0， buckets)
4. 并发（flags）







bmap

hiter

mapextra

hmap





## 深入 桶列表 (buckets)

buckets 字段中是存储桶数据的地方。正常会一次申请至少2^N长度的数组，数组中每个元素就是一个桶。N 就是结构体中的B。这里面要注意以下几点：

1. **为啥是2的幂次方** 为了做完hash后，通过掩码的方式取到数组的偏移量, 省掉了不必要的计算。
2. **B 这个数是怎么确定的** 这个和我们map中要存放的数据量是有很大关系的。我们在创建map的时候来详述。
3. **bucket 的偏移是怎么计算的** hash 方法有多个，在 runtime/alg.go 里面定义了。不同的类型用不同的hash算法。算出来是一个uint32的一个hash 码，通过和B取掩码，就找到了bucket的偏移了。下面是取对应bucket的例子：



```
// 根据key的类型取相应的hash算法
alg := t.key.alg
hash := alg.hash(key, uintptr(h.hash0))
// 根据B拿到一个掩码
m := bucketMask(h.B)
// 通过掩码以及hash指，计算偏移得到一个bucket
b := (*bmap)(add(h.buckets, (hash&m)*uintptr(t.bucketsize)))
```



## 技术总结

golang 实现的map比朴素的hashmap 在很多方面都有优化。

1. 使用掩码方式获取偏移，减少判断。
2. bucket 存储方式的优化。
3. 通过tophash 先进行一次比较，减少key 比较的成本。
4. 当然，有一点是不太明白的，为啥 overflow 指针要放在 kv 后面？ 放在tophash 之后的位置岂不是更完美？

今天的作业就交完了。下一篇将学习golang map的数据初始化实现。





new



扩容



删除



相关文章：

1. https://www.kevinwu0904.top/blogs/golang-map/









