# bloomfilter

布隆过滤器，是一种节省空间的概率数据结构（就是位图+哈希）。主要的功能是查找一个元素是否在给定的集合中。说它是一种概率数据结构是因为每次对它的查询会返回 2 种结果；一种是“可能在集合中”，也就是说它可能会误报，这个误报是有一定概率的。



在正式介绍布隆过滤器之前，我们先介绍一下位图，因为前面我们也说了布隆过滤器=位图+哈希。那么什么是位图呢？位图（bitmap）我们可以理解为是一个 bit 数组，每个元素存储数据的状态（由于每个元素只有 1 bit，所以只能存储 0 或 1 这 2 种状态）适用于数据量超大，但是数据的状态很少的情况。比如判断一个整数是否在给定的超大的整数集中。举个例子我们初始化一个包含1,7,5,20,10,99,96 数据的文件：

![](https://pic2.zhimg.com/80/v2-3a76ceee908956df45ffeb0589055ced_1440w.jpg)

我们只需要将给定数字的对应位置改为 1 即可，当需要判断一个数字是不是在该集合中的时候就只需要判断该数字对应的位置是不是 1 即可，是 1 则表示该数字在集合中，为 0 则表示该数字不在集合中。由于位图不需要存储元数据，还需要用一个 bit 存储元数据的状态，所以能极大的减少存储空间。当然位图的缺陷也很明显；只能处理整数。

好现在我们回到布隆过滤器看看它的原理。它先定义一个长度为 m 的位图数组，初始值都为 0 ，然后定义 k 个不同的符合随机分布的哈希函数，添加一个元素的时候通过 k 个哈希函数得到 k 个 hash 值，将它们映射到位图数组中（当然计算出来的 hash 值可能超过了 m，那么就需要扩容，java 中 BitSet 的扩容方案是 Math.max(2 * 当前长度, 计算出来的 hash 值); ）



![](https://pic3.zhimg.com/80/v2-5927fe52f47220c4369459fc18fe183e_1440w.jpg)

查询的时候把这个元素作为 K 个哈希函数的输入，得到 K 个数组的位置。如果这些位置中有任意一个是 0，说明元素肯定不在集合中。如果这些位置全部为 1，那么该元素很可能是在集合中，因为也有可能这些位置是被其他元素设置的。

![image-20220515110227112](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20220515110227112.png)

通过计算 4 G 空间就基本能满足需求了。我们总结一下布隆过滤器的优缺点：

**优点：**

1.查询时间复杂度 O(k) 一个较小的常数

2.极度节约空间

3.不存储数据本身，对源数据有一定保密性

**缺点：**

1.有一定误差

2.不能删除