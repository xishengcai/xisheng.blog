## Containerd Stargz Snapshotter



**问题**： 拉取镜像占用了容器启动时间的 `76%`，只有 `6.4%` 的时间用来读取数据。



这个问题一直困扰着各类工作负载，包括 serverless 函数的冷启动时间，镜像构建过程中基础镜像的拉取等。虽然有各种折中的解决方案，但这些方案都有缺陷：

- **缓存镜像** : 冷启动时仍然有性能损失。
- **减小镜像体积** : 无法避免某些场景需要用到大体积的镜像，比如机器学习。



Containerd 为了解决这个问题启动了一个非核心子项目 **Stargz Snapshotter**[2]，旨在提高镜像拉取的性能。该项目作为 Containerd 的一个插件，利用 Google 的 stargz 镜像格式[3]来延迟拉取镜像。这里的延迟拉取指的是 Containerd 在拉取时不会拉取整个镜像文件，而是按需获取必要的文件。
<img src="https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/021254.png" alt="image-20210507101238278" style="zoom:50%;" />







<img src="https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/021456.png" alt="image-20210507101452065" style="zoom:50%;" />

- `legacy` shows the startup performance when we use containerd's default snapshotter (`overlayfs`) with images copied from `docker.io/library` without optimization. For this configuration, containerd pulls entire image contents and `pull` operation takes accordingly. When we use stargz snapshotter with eStargz-converted images but without any optimization (`estargz-noopt`) we are seeing performance improvement on the `pull` operation because containerd can start the container without waiting for the `pull` completion and fetch necessary chunks of the image on-demand. But at the same time, we see the performance drawback for `run` operation because each access to files takes extra time for fetching them from the registry. When we use [eStargz with optimization](https://github.com/containerd/stargz-snapshotter/blob/master/docs/ctr-remote.md) (`estargz`), we can mitigate the performance drawback observed in `estargz-noopt` images. This is because [stargz snapshotter prefetches and caches *likely accessed files* during running the container](https://github.com/containerd/stargz-snapshotter/blob/master/docs/stargz-estargz.md). On the first container creation, stargz snapshotter waits for the prefetch completion so `create` sometimes takes longer than other types of image. But it's still shorter than waiting for downloading all files of all layers.

The above histogram is [the benchmarking result on the commit `ecdb227`](https://github.com/containerd/stargz-snapshotter/actions/runs/398606060). We are constantly measuring the performance of this snapshotter so you can get the latest one through the badge shown top of this doc. Please note that we sometimes see dispersion among the results because of the NW condition on the internet and the location of the instance in the Github Actions, etc. Our benchmarking method is based on [HelloBench](https://github.com/Tintri/hello-bench).

Stargz Snapshotter is a **non-core** sub-project of containerd.

## Quick Start with Kubernetes

- For more details about stargz snapshotter plugin and its configuration, refer to [Containerd Stargz Snapshotter Plugin Overview](https://github.com/containerd/stargz-snapshotter/blob/master/docs/overview.md).

For using stargz snapshotter on kubernetes nodes, you need the following configuration to containerd as well as run stargz snapshotter daemon on the node. We assume that you are using containerd (> v1.4.2) as a CRI runtime.

```
version = 2

# Plug stargz snapshotter into containerd
# Containerd recognizes stargz snapshotter through specified socket address.
# The specified address below is the default which stargz snapshotter listen to.
[proxy_plugins]
  [proxy_plugins.stargz]
    type = "snapshot"
    address = "/run/containerd-stargz-grpc/containerd-stargz-grpc.sock"

# Use stargz snapshotter through CRI
[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "stargz"
  disable_snapshot_annotations = false
```

**Note that `disable_snapshot_annotations = false` is required since containerd > v1.4.2**

This repo contains [a Dockerfile as a KinD node image](https://github.com/containerd/stargz-snapshotter/blob/master/Dockerfile) which includes the above configuration. You can use it with [KinD](https://github.com/kubernetes-sigs/kind) like the following,

```
$ docker build -t stargz-kind-node https://github.com/containerd/stargz-snapshotter.git
$ kind create cluster --name stargz-demo --image stargz-kind-node
```

Then you can create eStargz pods on the cluster. In this example, we create a stargz-converted Node.js pod (`ghcr.io/stargz-containers/node:13.13.0-esgz`) as a demo.

```
apiVersion: v1
kind: Pod
metadata:
  name: nodejs
spec:
  containers:
  - name: nodejs-stargz
    image: ghcr.io/stargz-containers/node:13.13.0-esgz
    command: ["node"]
    args:
    - -e
    - var http = require('http');
      http.createServer(function(req, res) {
        res.writeHead(200);
        res.end('Hello World!\n');
      }).listen(80);
    ports:
    - containerPort: 80
```

The following command lazily pulls `ghcr.io/stargz-containers/node:13.13.0-esgz` from Github Container Registry and creates the pod so the time to take for it is shorter than the original image `library/node:13.13`.

```
$ kubectl --context kind-stargz-demo apply -f stargz-pod.yaml && kubectl get po nodejs -w
$ kubectl --context kind-stargz-demo port-forward nodejs 8080:80 &
$ curl 127.0.0.1:8080
Hello World!
```

Stargz snapshotter also supports [further configuration](https://github.com/containerd/stargz-snapshotter/blob/master/docs/overview.md) including private registry authentication, mirror registries, etc.





DADI Block-Level Image Service ，  Stargz Snapshotter， Nydus