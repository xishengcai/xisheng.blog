# informer

- 基础功能

infromer是client-go中的一个核心基础包。在kubernetes源码中，如果kubernetes中的某个组件，需要List/Get Kubernetes中的Object，在绝大多数情况下，会直接使用informer实例中的Lister()方法（该方法包含了Get和List方法），而很少直接请求 Kubernetes API。Informer 最基本 的功能就是 List/Get Kubernetes 中的 Object。

如下图所示，仅需要十行左右的代码就能实现对 Pod 的 List 和 Get。

![img](https://www.kubernetes.org.cn/img/2017/09/20170914090111.jpg)



- 高级功能

Client-go 的首要目标是满足 Kubernetes 的自身需求。Informer 作为其中的核心工具包，面对 Kubernetes 极为复杂业务逻辑，如果仅实现 List/Get 功能，根本无法满足 Kubernetes 自身需求。因此，Informer 被设计为一个灵活而复杂的工具包，除 List/Get Object 外，Informer 还可以监听事件并触发回调函数等，以实现更加复杂的业务逻辑。



- 设计思路

为了让 Client-go 更快地返回 List/Get 请求的结果、减少对 Kubenetes API 的直接调用，Informer 被设计实现为一个依赖 Kubernetes List/Watch API 、可监听事件并触发回调函数的二级缓存工具包。



使用 Informer 实例的 Lister() 方法， List/Get Kubernetes 中的 Object 时，Informer 不会去请求 Kubernetes API，而是直接查找缓存在本地内存中的数据(这份数据由 Informer 自己维护)。通过这种方式，Informer 既可以更快地返回结果，又能减少对 Kubernetes API 的直接调用。



### 依赖 Kubernetes List/Watch API

Informer 只会调用 Kubernetes List 和 Watch 两种类型的 API。Informer 在初始化的时，先调用 Kubernetes List API 获得某种 resource 的全部 Object，缓存在内存中; 然后，调用 Watch API 去 watch 这种 resource，去维护这份缓存; 最后，Informer 就不再调用 Kubernetes 的任何 API。



用 List/Watch 去维护缓存、保持一致性是非常典型的做法，但令人费解的是，Informer 只在初始化时调用一次 List API，之后完全依赖 Watch API 去维护缓存，没有任何 resync 机制。

笔者在阅读 Informer 代码时候，对这种做法十分不解。按照多数人思路，通过 resync 机制，重新 List 一遍 resource 下的所有 Object，可以更好的保证 Informer 缓存和 Kubernetes 中数据的一致性。

> 咨询过 Google 内部 Kubernetes 开发人员之后，得到的回复是:
> 在 Informer 设计之初，确实存在一个 relist 无法去执 resync 操作， 但后来被取消了。原因是现有的这种 List/Watch 机制，完全能够保证永远不会漏掉任何事件，因此完全没有必要再添加 relist 方法去 resync informer 的缓存。这种做法也说明了 Kubernetes 完全信任 etcd。



### 可监听事件并触发回调函数

Informer 通过 Kubernetes Watch API 监听某种 resource 下的所有事件。而且，Informer 可以添加自定义的回调函数，这个回调函数实例(即 ResourceEventHandler 实例)只需实现 OnAdd(obj interface{}) OnUpdate(oldObj, newObj interface{}) 和 OnDelete(obj interface{}) 三个方法，这三个方法分别对应 informer 监听到创建、更新和删除这三种事件类型。



在 Controller 的设计实现中，会经常用到 informer 的这个功能。 Controller 相关文章请见此文《[如何用 client-go 拓展 Kubernetes 的 API](https://mp.weixin.qq.com/s?__biz=MzU1OTAzNzc5MQ==&mid=2247484052&idx=1&sn=cec9f4a1ee0d21c5b2c51bd147b8af59&chksm=fc1c2ea4cb6ba7b283eef5ac4a45985437c648361831bc3e6dd5f38053be1968b3389386e415&scene=21#wechat_redirect)》。



### 二级缓存

二级缓存属于 Informer 的底层缓存机制，这两级缓存分别是 DeltaFIFO 和 LocalStore。

这两级缓存的用途各不相同。DeltaFIFO 用来存储 Watch API 返回的各种事件 ，LocalStore 只会被 Lister 的 List/Get 方法访问 。

虽然 Informer 和 Kubernetes 之间没有 resync 机制，但 Informer 内部的这两级缓存之间存在 resync 机制。

以上是 Informer 设计中的一些关键点，没有介绍一些太细节的东西，尤其对于 Informer 两级缓存还未做深入介绍。下一章节将对 Informer 详细的工作流程做一个详细介绍。



## Informer 详细解析

### Informer 内部主要组件

Informer 中主要包含 Controller、Reflector、DeltaFIFO、LocalStore、Lister 和 Processor 六个组件，其中 Controller 并不是 Kubernetes Controller，这两个 Controller 并没有任何联系；Reflector 的主要作用是通过 Kubernetes Watch API 监听某种 resource 下的所有事件；DeltaFIFO 和 LocalStore 是 Informer 的两级缓存；Lister 主要是被调用 List/Get 方法；Processor 中记录了所有的回调函数实例(即 ResourceEventHandler 实例)，并负责触发这些函数。



### Informer 关键逻辑解析

我们以 Pod 为例，详细说明一下 Informer 的关键逻辑：

1. Informer 在初始化时，Reflector 会先 List API 获得所有的 Pod
2. Reflect 拿到全部 [Pod](https://www.kubernetes.org.cn/tags/pod) 后，会将全部 Pod 放到 Store 中
3. 如果有人调用 Lister 的 List/Get 方法获取 Pod， 那么 Lister 会直接从 Store 中拿数据
4. ![img](https://www.kubernetes.org.cn/img/2017/09/20170914090122.jpg)
5. Informer 初始化完成之后，Reflector 开始 Watch Pod，监听 Pod 相关 的所有事件;如果此时 pod_1 被删除，那么 Reflector 会监听到这个事件
6. Reflector 将 pod_1 被删除 的这个事件发送到 DeltaFIFO
7. DeltaFIFO 首先会将这个事件存储在自己的数据结构中(实际上是一个 queue)，然后会直接操作 Store 中的数据，删除 Store 中的 pod_1
8. DeltaFIFO 再 Pop 这个事件到 Controller 中
9. ![img](https://www.kubernetes.org.cn/img/2017/09/20170914090128.jpg)
10. Controller 收到这个事件，会触发 Processor 的回调函数

![img](https://www.kubernetes.org.cn/img/2017/09/20170914090134.jpg)

LocalStore 会周期性地把所有的 Pod 信息重新放到 DeltaFIFO 中

## Informer 总结

Informer 的内部原理比较复杂、不太容易上手，但 Informer 却是一个非常稳定可靠的 package，已被 Kubernetes 广泛使用。但是，目前关于 Informer 的文章不是很多，如果文章中有表述不正确的地方，希望各位读者悉心指正。





## Link

https://cloudnative.to/blog/client-go-informer/