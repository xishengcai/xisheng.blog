## 下一代镜像构建工具 Buildkit 简介


Buildkit 是 Docker 公司出品的一款更高效、docekrfile 无关、更契合`[云原生应用]`的新一代 Docker 构建工具。

## **开源工具已经不能满足 DID 的需求**

云原生的一个特点是一切基础设施都是动态的，除了提供服务的基础设施，CICD 的计算资源也趋向动态创建。很多企业已经有了自己的 k8s 集群作为服务，自然而然开始思考如何把 CICD 搬到 k8s 中，各种 CI 工具的插件应运而生，而容器集群中的构建成为了各种工具的焦点问题。

### **DID (Docker in docker 的演进)**

最原始的 Docker in docker 是使用 privilege 将[宿主机](https://cloud.tencent.com/product/cdh?from=20065&from_column=20065)的一切权限共享给用于构建的容器实例，这种方式容器可以获得宿主机的最高权限，有很大风险，很快就被淘汰了。

目前比较普遍的做法，是把 Docker daemon 的 socket 挂在到用于构建的容器中:

```javascript
docker run -v /var/run/docker.sock:/var/run/docker.sock -it docker
```

复制

这种方式已经经历了较长时间的验证，可以满足企业内部使用的大部分场景：

- **远程仓库权限**：对于 Docker credential 的隔离可以利用不同容器实例之间 Home directory 不同做到
- **缓存**：同一台宿主机上的缓存可以通过同一个 Docker daemon 共享
- **本地权限**：由于不同容器实例挂在同一个宿主机的 Docker daemon 进程，所有实例里 docker 命令的权限也是共享的，也就是说不同容器实例可以查看甚至更新、删除到同一个 Docker daemon 下别的容器实例构建产生的镜像。

本地权限的问题如果是在一个小企业内部以共享账号的方式或许还可以接受，稍微大一点的企业可以通过限制用户输入 Docker 命令，防止注入来规避权限盗用的风险。但目前看来这些方法都还是治标不治本，治本的方案要么是在 Docker daemon 建立一套权限机制，要么让 Docker 里的构建不依赖同一个 Docker daemon。

## **Build without docker daemon**

社区中目前有三款工具可以支持无 docker daemon 化的构建：kaniko，img 和 buildkit。

- Kaniko 是由 Google 开发的在 k8s 上做 docker 构建的[命令行工具](https://cloud.tencent.com/product/cli?from=20065&from_column=20065)，使用非常简洁，只需要 build 一个二进制工具即可，支持 dockerfile 构建、push、credentail 文件读取。
- Buildkit 是 docker 公司开发，目前由社区和 docker 公司合理维护的“含着金钥匙出生”的新一代构建工具，拥有良好的扩展性、极大地提高了构建速度，以及更好的安全性，功能上配合 docker 使用还是没问题的，独立使用功能其实有残缺，这个放到后面来讲。
- img 是社区贡献者开发，基于 buildkit 封装的类 docker 化命令行工具，无需 daemon 进程，无需 privilege，可以独立运行的二进制工具，非常小巧易用，而且有着和 buildkit 一样的性能优势。

### **社区活跃度**

**kaniko > img > buildkit**

![img](https://ask.qcloudimg.com/http-save/yehe-1487868/hlhm2e23th.png?imageView2/2/w/1200)

![img](https://ask.qcloudimg.com/http-save/yehe-1487868/b3ezvd2lvl.png?imageView2/2/w/1200)

![img](https://ask.qcloudimg.com/http-save/yehe-1487868/qhtg3dhjkk.png?imageView2/2/w/1200)

可以看出三个工具中 kaniko 是 star 最多的项目， img 目前是缺少维护的状态，buildkit start 最少但是社区活跃度还比较高。

### **kaniko 踩坑**

初步看来 kaniko 似乎是最佳选择，大厂背书，相对活跃的社区和相对多的市场验证。然而我们却发现了当前版本(v0.9.0)的两个不足：

- Dockerfile 支持不全：由于实现方式和 docker 不同，kaniko 并不是完全兼容 dockerfile 的所有语法：例如多阶段构建中 FROM … AS xxx 的语法 xxx 首字母不能大写；from 的镜像系统文件无法在 build 的时候被覆盖而是会报错
- 缓存不能共享，kaniko 的缓存只能够利用到基础镜像级别，即事先把镜像放到缓存目录下， kaniko 可以使用这个本地镜像，而构建过程中产生的镜像 layers 则不能复用。docker 多阶段构建会有相当多的 dependency 中间产物，每次构建都去下载这些依赖会极大地降低构建速度从而带来不好的体验

基于以上两点，kaniko 似乎仍是一个不够成熟的工具，暂时不能投入生产。

### **img 踩坑**

了解过 buildkit 的高性能之后，对 img 这样集简洁与性能于一身的工具可谓是满怀期待，而事实却不尽如人意，虽然 kaniko 遇到的 dockerfile img 都轻松支持了，但是在多阶段镜像构建的时候似乎在并行构建的处理上有些问题，对于复杂的多阶段构建会频繁曝出 IO 异常，怀疑是缺少了 daemon 进程文件锁的功能导致的，只好放弃。

## **Buildkit 介绍**

最后来说说本文的主角：buildkit

Buildkit 是由 Docker 公司开发的**下一代 docker build 工具**，2018 年 7 月正式内置于 Docker-ce 18.06.0 的 Docker daemon ，Mac 和 Linux 可以使用环境变量 `DOCKER_BUILDKIT=1` 开启，同年 10 月发布社区版本。

相比于 Docker daemon build，buildkit：

- 更**高效**：支持并行的多阶段构建、更好的缓存管理；
- 更**安全**：支持 secret mount，无需 root priviliege；
- 更**易于扩展**：使用自定义中间语言 LLB，完全兼容 Dockerfile，也可支持第三方语言（目前仅有Buildpacks），后台目前可支持 runC 和 containerd 两种 worker。

目前社区除了 moby/docker-ce 外还在使用 buildkit 的项目有 genuinetools/img, openFaaS Cloud, containerbuilding/cbi。

### **与其他构建工具对比**

![img](https://ask.qcloudimg.com/http-save/yehe-1487868/id36spess9.png?imageView2/2/w/1200)

需要补充的一点是 buildkit 是对 Dockerfile 语法完全支持：

![img](https://ask.qcloudimg.com/http-save/yehe-1487868/njse99jkbz.png?imageView2/2/w/1200)

图片来源：https://www.youtube.com/watch?v=kkpQ_UZn2uo

### **工作原理**

**buildkitd & buildctl**

后台启动一个 `buildkitd` 守护进程，通过 http 通信的方式执行构建。

- **gRPC API**: 使用 Google RPC 协议高效通信
- **Go client library**：基于 Go 的客户端方便调用
- **rootless execution**：buildctl 不需要 root 权限就可以执行
- **OpenTracing**：支持镜像 layer 的逐层溯源
- **multi-worker model**：支持多种 worker(runC 和 containerd)，可扩展

## **使用**

### **安装**

官方镜像：https://hub.docker.com/r/moby/buildkit

```javascript
docker run --name buildkit -d --privileged -p 1234:1234 moby/buildkit --addr tcp://0.0.0.0:1234
export BUILDKIT_HOST=tcp://0.0.0.0:1234
docker cp buildkit:/usr/bin/buildctl /usr/local/bin/
buildctl build --help
```

复制

Mac OS 在 https://github.com/moby/buildkit/releases 下载 buildctl

### **构建**

```javascript
# 本地构建
buildctl --addr tcp://localhost:1234 build --frontend=dockerfile.v0 --local context=. --local dockerfile=.
# 等同于 docker build
buildctl --addr tcp://localhost:1234 build --frontend=dockerfile.v0 --local context=. --local dockerfile=. --output type=docker,name=myimage | docker load
# push
buildctl build --frontend dockerfile.v0 --local context=. --local dockerfile=. --output type=image,name=docker.io/username/image,push=true
```

复制

### **权限**

使用 docker credentials权限

可以使用环境变量 DOCKER_CONFIG 指定 credential 读取路径从而达到权限隔离（这方面缺少文档，可以参考源码）：

https://github.com/moby/buildkit/blob/master/cmd/buildctl/build.go#L157

https://github.com/docker/cli/blob/master/cli/config/config.go#L127

![img](https://ask.qcloudimg.com/http-save/yehe-1487868/3o3f4kcgjn.jpeg?imageView2/2/w/1200)

### **缓存**

buildkit 支持 layer 级别缓存，可指定缓存 export/import 路径。

可以使用 registry 缓存：https://github.com/moby/buildkit#exportingimporting-build-cache-not-image-itself

## **不足**

### **运行权限**

Buildkitd 运行需要 privilege，这里有一个 issue 解释说是因为 runC 读写宿主机文件系统需要 root 权限

### **稳定性测试**

跑了一个晚上的定时脚本，构建的是同一个多阶段镜像，得到的结果不尽如人意：

- 速度不太稳定，同一个镜像在没有网络依赖的情况下构建速度在 30s-10min 之间摆动

![img](https://ask.qcloudimg.com/http-save/yehe-1487868/i4vbv18vkf.png?imageView2/2/w/1200)

- buildctl 和同一台宿主机上的 buildkitd 通信不时会出现网络问题，出现概率 10%

![img](https://ask.qcloudimg.com/http-save/yehe-1487868/knvmk3skx3.png?imageView2/2/w/1200)

## **结论**

Buildkit 似乎是一个很有前景的产品，只是目前还没有达到生产环境需要的水平。

我比较看好它的设计，比如内置文件[数据库](https://cloud.tencent.com/solution/database?from=20065&from_column=20065)，中心化调度思维，前后端可扩展，权限扩展单元，这些都是云原生时代需要的，只是产品的打磨还需要加以时日，以及市场的砺炼。

> 原文链接：https://www.duyidong.com/2019/05/19/build-image-in-container-via-buildkit/