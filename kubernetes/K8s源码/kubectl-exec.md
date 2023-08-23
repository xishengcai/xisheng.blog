# kubectl exec

对于经常和 `Kubernetes` 打交道的 YAML 工程师来说，最常用的命令就是 `kubectl exec` 了，通过它可以直接在容器内执行命令来调试应用程序。如果你不满足于只是用用而已，想了解 `kubectl exec` 的工作原理，那么本文值得你仔细读一读。本文将通过参考 `kubectl`、`API Server`、`Kubelet` 和容器运行时接口（CRI）Docker API 中的相关代码来了解该命令是如何工作的。

kubectl exec 的工作原理用一张图就可以表示：

![image-20210521101250026](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/021257.png)



这里有两个重要的 HTTP 请求：

- `GET` 请求用来获取 Pod 信息。
- POST 请求调用 Pod 的子资源 `exec` 在容器内执行命令。

> 子资源（subresource）隶属于某个 K8S 资源，表示为父资源下方的子路径，例如 `/logs`、`/status`、`/scale`、`/exec` 等。其中每个子资源支持的操作根据对象的不同而改变。

最后 API Server 返回了 `101 Ugrade` 响应，向客户端表示已切换到 `SPDY` 协议。

> SPDY 允许在单个 TCP 连接上复用独立的 stdin/stdout/stderr/spdy-error 流。









Question：

1. http 如何复用SPDY协议

2. kubectl exec 是tcp 协议还是http





Link:

1. https://my.oschina.net/u/4131034/blog/3224587