## 万字长文：K8s 创建 pod 时，背后到底发生了什么？

KubeSphere云原生 *1周前*

收录于话题

\#Kubernetes45

\#云原生44

\#CNI3

\#开源31

![图片](https://mmbiz.qpic.cn/mmbiz_png/u5Pibv7AcsEUdYMNOn9maYiaibOU7W6BBUNDq2Oib9pyjquaibTicwAyjuyHvBwthA2wyvBQ7yRiaSJq9yc9I8MvdzKVQ/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)

本文基于 2019 年的一篇文章 **What happens when ... Kubernetes edition!**[1] **梳理了 K8s 创建 pod**（及其 deployment/replicaset）**的整个过程**， 整理了每个**重要步骤的代码调用栈**，以在实现层面加深对整个过程的理解。

原文参考的 K8s 代码已经较老（`v1.8`/`v1.14` 以及当时的 `master`），且部分代码 链接已失效；**本文代码基于 v1.21[2]**。

由于内容已经不与原文一一对应（有增加和删减），因此标题未加 “[译]” 等字样。感谢原作者（们）的精彩文章。

全文大纲：

- K8s 组件启动过程
- kubectl（命令行客户端）
- kube-apiserver
- 写入 etcd
- Initializers
- Control loops（控制循环）
- Kubelet

------

本文试图回答以下问题：**敲下 `kubectl run nginx --image=nginx --replicas=3` 命令后**，**K8s 中发生了哪些事情？**

要弄清楚这个问题，我们需要：

1. 了解 K8s 几个核心组件的启动过程，它们分别做了哪些事情，以及
2. 从客户端发起请求到 pod ready 的整个过程。

## 0 K8s 组件启动过程

首先看几个核心组件的启动过程分别做了哪些事情。

### 0.1 kube-apiserver 启动

#### 调用栈

创建命令行（`kube-apiserver`）入口：

```
main                                         // cmd/kube-apiserver/apiserver.go
 |-cmd := app.NewAPIServerCommand()          // cmd/kube-apiserver/app/server.go
 |  |-RunE := func() {
 |      Complete()
 |        |-ApplyAuthorization(s.Authorization)
 |        |-if TLS:
 |            ServiceAccounts.KeyFiles = []string{CertKey.KeyFile}
 |      Validate()
 |      Run(completedOptions, handlers) // 核心逻辑
 |    }
 |-cmd.Execute()
```

`kube-apiserver` 启动后，会执行到其中的 `Run()` 方法：

```
Run()          // cmd/kube-apiserver/app/server.go
 |-server = CreateServerChain()
 |           |-CreateKubeAPIServerConfig()
 |           |   |-buildGenericConfig
 |           |   |   |-genericapiserver.NewConfig()     // staging/src/k8s.io/apiserver/pkg/server/config.go
 |           |   |   |  |-return &Config{
 |           |   |   |       Serializer:             codecs,
 |           |   |   |       BuildHandlerChainFunc:  DefaultBuildHandlerChain, // 注册 handler
 |           |   |   |    }
 |           |   |   |
 |           |   |   |-OpenAPIConfig = DefaultOpenAPIConfig()  // OpenAPI schema
 |           |   |   |-kubeapiserver.NewStorageFactoryConfig() // etcd 相关配置
 |           |   |   |-APIResourceConfig = genericConfig.MergedResourceConfig
 |           |   |   |-storageFactoryConfig.Complete(s.Etcd)
 |           |   |   |-storageFactory = completedStorageFactoryConfig.New()
 |           |   |   |-s.Etcd.ApplyWithStorageFactoryTo(storageFactory, genericConfig)
 |           |   |   |-BuildAuthorizer(s, genericConfig.EgressSelector, versionedInformers)
 |           |   |   |-pluginInitializers, admissionPostStartHook = admissionConfig.New()
 |           |   |
 |           |   |-capabilities.Initialize
 |           |   |-controlplane.ServiceIPRange()
 |           |   |-config := &controlplane.Config{}
 |           |   |-AddPostStartHook("start-kube-apiserver-admission-initializer", admissionPostStartHook)
 |           |   |-ServiceAccountIssuerURL = s.Authentication.ServiceAccounts.Issuer
 |           |   |-ServiceAccountJWKSURI = s.Authentication.ServiceAccounts.JWKSURI
 |           |   |-ServiceAccountPublicKeys = pubKeys
 |           |
 |           |-createAPIExtensionsServer
 |           |-CreateKubeAPIServer
 |           |-createAggregatorServer    // cmd/kube-apiserver/app/aggregator.go
 |           |   |-aggregatorConfig.Complete().NewWithDelegate(delegateAPIServer)   // staging/src/k8s.io/kube-aggregator/pkg/apiserver/apiserver.go
 |           |   |  |-apiGroupInfo := NewRESTStorage()
 |           |   |  |-GenericAPIServer.InstallAPIGroup(&apiGroupInfo)
 |           |   |  |-InstallAPIGroups
 |           |   |  |-openAPIModels := s.getOpenAPIModels(APIGroupPrefix, apiGroupInfos...)
 |           |   |  |-for apiGroupInfo := range apiGroupInfos {
 |           |   |  |   s.installAPIResources(APIGroupPrefix, apiGroupInfo, openAPIModels)
 |           |   |  |   s.DiscoveryGroupManager.AddGroup(apiGroup)
 |           |   |  |   s.Handler.GoRestfulContainer.Add(discovery.NewAPIGroupHandler(s.Serializer, apiGroup).WebService())
 |           |   |  |
 |           |   |  |-GenericAPIServer.Handler.NonGoRestfulMux.Handle("/apis", apisHandler)
 |           |   |  |-GenericAPIServer.Handler.NonGoRestfulMux.UnlistedHandle("/apis/", apisHandler)
 |           |   |  |-
 |           |   |-
 |-prepared = server.PrepareRun()     // staging/src/k8s.io/kube-aggregator/pkg/apiserver/apiserver.go
 |            |-GenericAPIServer.AddPostStartHookOrDie
 |            |-GenericAPIServer.PrepareRun
 |            |  |-routes.OpenAPI{}.Install()
 |            |     |-registerResourceHandlers // staging/src/k8s.io/apiserver/pkg/endpoints/installer.go
 |            |         |-POST: XX
 |            |         |-GET: XX
 |            |
 |            |-openapiaggregator.BuildAndRegisterAggregator()
 |            |-openapiaggregator.NewAggregationController()
 |            |-preparedAPIAggregator{}
 |-prepared.Run() // staging/src/k8s.io/kube-aggregator/pkg/apiserver/apiserver.go
    |-s.runnable.Run()
```

#### 一些重要步骤

1. **创建 server chain**。Server aggregation（聚合）是一种支持多 apiserver 的方式，其中 包括了一个 **generic apiserver**[3]，作为默认实现。
2. **生成 OpenAPI schema**，保存到 apiserver 的 **Config.OpenAPIConfig 字段**[4]。
3. 遍历 schema 中的所有 API group，为每个 API group 配置一个 **storage provider**[5]， 这是一个通用 backend 存储抽象层。
4. 遍历每个 group 版本，为每个 HTTP route **配置 REST mappings**[6]。稍后处理请求时，就能将 requests 匹配到合适的 handler。

### 0.2 controller-manager 启动

#### 调用栈

```
NewDeploymentController
NewReplicaSetController
```

### 0.3 kubelet 启动

#### 调用栈

```
main                                                                            // cmd/kubelet/kubelet.go
 |-NewKubeletCommand                                                            // cmd/kubelet/app/server.go
   |-Run                                                                        // cmd/kubelet/app/server.go
      |-initForOS                                                               // cmd/kubelet/app/server.go
      |-run                                                                     // cmd/kubelet/app/server.go
        |-initConfigz                                                           // cmd/kubelet/app/server.go
        |-InitCloudProvider
        |-NewContainerManager
        |-ApplyOOMScoreAdj
        |-PreInitRuntimeService
        |-RunKubelet                                                            // cmd/kubelet/app/server.go
        | |-k = createAndInitKubelet                                            // cmd/kubelet/app/server.go
        | |  |-NewMainKubelet
        | |  |  |-watch k8s Service
        | |  |  |-watch k8s Node
        | |  |  |-klet := &Kubelet{}
        | |  |  |-init klet fields
        | |  |
        | |  |-k.BirthCry()
        | |  |-k.StartGarbageCollection()
        | |
        | |-startKubelet(k)                                                     // cmd/kubelet/app/server.go
        |    |-go k.Run()                                                       // -> pkg/kubelet/kubelet.go
        |    |  |-go cloudResourceSyncManager.Run()
        |    |  |-initializeModules
        |    |  |-go volumeManager.Run()
        |    |  |-go nodeLeaseController.Run()
        |    |  |-initNetworkUtil() // setup iptables
        |    |  |-go Until(PerformPodKillingWork, 1*time.Second, neverStop)
        |    |  |-statusManager.Start()
        |    |  |-runtimeClassManager.Start
        |    |  |-pleg.Start()
        |    |  |-syncLoop(updates, kl)                                         // pkg/kubelet/kubelet.go
        |    |
        |    |-k.ListenAndServe
        |
        |-go http.ListenAndServe(healthz)
```

### 0.4 小结

以上核心组件启动完成后，就可以从命令行发起请求创建 pod 了。

## 1 kubectl（命令行客户端）

### 1.0 调用栈概览

```
NewKubectlCommand                                    // staging/src/k8s.io/kubectl/pkg/cmd/cmd.go
 |-matchVersionConfig = NewMatchVersionFlags()
 |-f = cmdutil.NewFactory(matchVersionConfig)
 |      |-clientGetter = matchVersionConfig
 |-NewCmdRun(f)                                      // staging/src/k8s.io/kubectl/pkg/cmd/run/run.go
 |  |-Complete                                       // staging/src/k8s.io/kubectl/pkg/cmd/run/run.go
 |  |-Run(f)                                         // staging/src/k8s.io/kubectl/pkg/cmd/run/run.go
 |    |-validate parameters
 |    |-generators = GeneratorFn("run")
 |    |-runObj = createGeneratedObject(generators)   // staging/src/k8s.io/kubectl/pkg/cmd/run/run.go
 |    |           |-obj = generator.Generate()       // -> staging/src/k8s.io/kubectl/pkg/generate/versioned/run.go
 |    |           |        |-get pod params
 |    |           |        |-pod = v1.Pod{params}
 |    |           |        |-return &pod
 |    |           |-mapper = f.ToRESTMapper()        // -> staging/src/k8s.io/cli-runtime/pkg/genericclioptions/config_flags.go
 |    |           |  |-f.clientGetter.ToRESTMapper() // -> staging/src/k8s.io/kubectl/pkg/cmd/util/factory_client_access.go
 |    |           |     |-f.Delegate.ToRESTMapper()  // -> staging/src/k8s.io/kubectl/pkg/cmd/util/kubectl_match_version.go
 |    |           |        |-ToRESTMapper            // -> staging/src/k8s.io/cli-runtime/pkg/resource/builder.go
 |    |           |        |-delegate()              //    staging/src/k8s.io/cli-runtime/pkg/resource/builder.go
 |    |           |--actualObj = resource.NewHelper(mapping).XX.Create(obj)
 |    |-PrintObj(runObj.Object)
 |
 |-NewCmdEdit(f)      // kubectl edit   命令
 |-NewCmdScale(f)     // kubectl scale  命令
 |-NewCmdCordon(f)    // kubectl cordon 命令
 |-NewCmdUncordon(f)
 |-NewCmdDrain(f)
 |-NewCmdTaint(f)
 |-NewCmdExecute(f)
 |-...
```

### 1.1 参数验证（validation）和资源对象生成器（generator）

#### 参数验证

敲下 `kubectl` 命令后，它首先会做一些客户端侧的验证。如果命令行参数有问题，例如，**镜像名为空或格式不对**[7]， 这里会直接报错，从而避免了将明显错误的请求发给 kube-apiserver，减轻了后者的压力。

此外，kubectl 还会检查其他一些配置，例如

- 是否需要记录（record）这条命令（用于 rollout 或审计）
- 是否只是测试执行（`--dry-run`）

#### 创建 HTTP 请求

所有**查询或修改 K8s 资源的操作**都需要与 kube-apiserver 交互，后者会进一步和 etcd 通信。

因此，验证通过之后，kubectl 接下来会创建发送给 kube-apiserver 的 HTTP 请求。

#### Generators

**创建 HTTP 请求用到了所谓的** **generator**[8]（**文档**[9]） ，它封装了资源的序列化（serialization）操作。例如，创建 pod 时用到的 generator 是 **BasicPod**[10]：

```
// staging/src/k8s.io/kubectl/pkg/generate/versioned/run.go

type BasicPod struct{}

func (BasicPod) ParamNames() []generate.GeneratorParam {
    return []generate.GeneratorParam{
        {Name: "labels", Required: false},
        {Name: "name", Required: true},
        {Name: "image", Required: true},
        ...
    }
}
```

每个 generator 都实现了一个 `Generate()` 方法，用于生成一个该资源的运行时对象（runtime object）。对于 `BasicPod`，其**实现**[11]为：

```
func (BasicPod) Generate(genericParams map[string]interface{}) (runtime.Object, error) {
    pod := v1.Pod{
        ObjectMeta: metav1.ObjectMeta{  // metadata 字段
            Name:        name,
            Labels:      labels,
            ...
        },
        Spec: v1.PodSpec{               // spec 字段
            ServiceAccountName: params["serviceaccount"],
            Containers: []v1.Container{
                {
                    Name:            name,
                    Image:           params["image"]
                },
            },
        },
    }

    return &pod, nil
}
```

### 1.2 API group 和版本协商（version negotiation）

有了 runtime object 之后，kubectl 需要用合适的 API 将请求发送给 kube-apiserver。

#### API Group

K8s 用 API group 来管理 resource API。这是一种不同于 monolithic API（所有 API 扁平化）的 API 管理方式。

具体来说，**同一资源的不同版本的 API，会放到一个 group 里面**。例如 Deployment 资源的 API group 名为 `apps`，最新的版本是 `v1`。这也是为什么 我们在创建 Deployment 时，需要在 yaml 中指定 `apiVersion: apps/v1` 的原因。

#### 版本协商

生成 runtime object 之后，kubectl 就开始**搜索合适的 API group 和版本**[12]：

```
// staging/src/k8s.io/kubectl/pkg/cmd/run/run.go

    obj := generator.Generate(params) // 创建运行时对象
    mapper := f.ToRESTMapper()        // 寻找适合这个资源（对象）的 API group
```

然后**创建一个正确版本的客户端（versioned client）**[13]，

```
// staging/src/k8s.io/kubectl/pkg/cmd/run/run.go

    gvks, _ := scheme.Scheme.ObjectKinds(obj)
    mapping := mapper.RESTMapping(gvks[0].GroupKind(), gvks[0].Version)
```

这个客户端能感知资源的 REST 语义。

以上过程称为版本协商。在实现上，kubectl 会**扫描 kube-apiserver 的 `/apis` 路径**（OpenAPI 格式的 schema 文档），获取所有的 API groups。

出于性能考虑，kubectl 会**缓存这份 OpenAPI schema**[14]， 路径是 `~/.kube/cache/discovery`。**想查看这个 API discovery 过程，可以删除这个文件**， 然后随便执行一条 kubectl 命令，并指定足够大的日志级别（例如 `kubectl get ds -v 10`）。

#### 发送 HTTP 请求

现在有了 runtime object，也找到了正确的 API，因此接下来就是 将请求真正**发送出去**[15]：

```
// staging/src/k8s.io/kubectl/pkg/cmd/cmd.go

        actualObj = resource.
            NewHelper(client, mapping).
            DryRun(o.DryRunStrategy == cmdutil.DryRunServer).
            WithFieldManager(o.fieldManager).
            Create(o.Namespace, false, obj)
```

发送成功后，会以恰当的格式打印返回的消息。

### 1.3 客户端认证（client auth）

前面其实有意漏掉了一步：客户端认证。它发生在发送 HTTP 请求之前。

**用户凭证（credentials）一般都放在 kubeconfig 文件中，但这个文件可以位于多个位置**， 优先级从高到低：

- 命令行 `--kubeconfig <file>`
- 环境变量 `$KUBECONFIG`
- 某些**预定义的路径**[16]，例如 `~/.kube`。

**这个文件中存储了集群、用户认证等信息**，如下面所示：

```
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/ca.crt
    server: https://192.168.2.100:443
  name: k8s-cluster-1
contexts:
- context:
    cluster: k8s-cluster-1
    user: default-user
  name: default-context
current-context: default-context
kind: Config
preferences: {}
users:
- name: default-user
  user:
    client-certificate: /etc/kubernetes/pki/admin.crt
    client-key: /etc/kubernetes/pki/admin.key
```

有了这些信息之后，客户端就可以组装 HTTP 请求的认证头了。支持的认证方式有几种：

- **X509 证书**：放到 **TLS**[17] 中发送；
- **Bearer token**：放到 HTTP `"Authorization"` 头中**发送**[18]；
- **用户名密码**：放到 HTTP basic auth **发送**[19]；
- **OpenID auth**：需要先由用户手动处理，将其转成一个 token，然后和 bearer token 类似发送。

## 2 kube-apiserver

请求从客户端发出后，便来到服务端，也就是 kube-apiserver。

### 2.0 调用栈概览

```
buildGenericConfig
  |-genericConfig = genericapiserver.NewConfig(legacyscheme.Codecs)  // cmd/kube-apiserver/app/server.go

NewConfig       // staging/src/k8s.io/apiserver/pkg/server/config.go
 |-return &Config{
      Serializer:             codecs,
      BuildHandlerChainFunc:  DefaultBuildHandlerChain,
   }                          /
                            /
                          /
                        /
DefaultBuildHandlerChain       // staging/src/k8s.io/apiserver/pkg/server/config.go
 |-handler := filterlatency.TrackCompleted(apiHandler)
 |-handler = genericapifilters.WithAuthorization(handler)
 |-handler = genericapifilters.WithAudit(handler)
 |-handler = genericapifilters.WithAuthentication(handler)
 |-return handler


WithAuthentication
 |-withAuthentication
    |-resp, ok := AuthenticateRequest(req)
    |  |-for h := range authHandler.Handlers {
    |      resp, ok := currAuthRequestHandler.AuthenticateRequest(req)
    |      if ok {
    |          return resp, ok, err
    |      }
    |    }
    |    return nil, false, utilerrors.NewAggregate(errlist)
    |
    |-audiencesAreAcceptable(apiAuds, resp.Audiences)
    |-req.Header.Del("Authorization")
    |-req = req.WithContext(WithUser(req.Context(), resp.User))
    |-return handler.ServeHTTP(w, req)
```

### 2.1 认证（Authentication）

kube-apiserver 首先会对请求进行认证（authentication），以确保用户身份是合法的（verify that the requester is who they say they are）。

具体过程：启动时，检查所有的**命令行参数**[20]，组织成一个 authenticator list，例如，

- 如果指定了 `--client-ca-file`，就会将 x509 证书加到这个列表；
- 如果指定了 `--token-auth-file`，就会将 token 加到这个列表；

不同 anthenticator 做的事情有所不同：

- **x509 handler**[21] 验证该 HTTP 请求是用 TLS key 加密的，并且有 CA root 证书的签名。
- **bearer token handler**[22] 验证请求中带的 token（HTTP Authorization 头中），在 apiserver 的 auth file 中是存在的（`--token-auth-file`）。
- **basicauth handler**[23] 对 basic auth 信息进行校验。

**如果认证成功，就会将 `Authorization` 头从请求中删除**，然后在上下文中**加上用户信息**[24]。这使得后面的步骤（例如鉴权和 admission control）能用到这里已经识别出的用户身份信息。

```
// staging/src/k8s.io/apiserver/pkg/endpoints/filters/authentication.go

// WithAuthentication creates an http handler that tries to authenticate the given request as a user, and then
// stores any such user found onto the provided context for the request.
// On success, "Authorization" header is removed from the request and handler
// is invoked to serve the request.
func WithAuthentication(handler http.Handler, auth authenticator.Request, failed http.Handler,
    apiAuds authenticator.Audiences) http.Handler {
    return withAuthentication(handler, auth, failed, apiAuds, recordAuthMetrics)
}

func withAuthentication(handler http.Handler, auth authenticator.Request, failed http.Handler,
    apiAuds authenticator.Audiences, metrics recordMetrics) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
        resp, ok := auth.AuthenticateRequest(req) // 遍历所有 authenticator，任何一个成功就返回 OK
        if !ok {
            return failed.ServeHTTP(w, req)       // 所有认证方式都失败了
        }

        if !audiencesAreAcceptable(apiAuds, resp.Audiences) {
            fmt.Errorf("unable to match the audience: %v , accepted: %v", resp.Audiences, apiAuds)
            failed.ServeHTTP(w, req)
            return
        }

        req.Header.Del("Authorization") // 认证成功后，这个 header 就没有用了，可以删掉

        // 将用户信息添加到请求上下文中，供后面的步骤使用
        req = req.WithContext(WithUser(req.Context(), resp.User))
        handler.ServeHTTP(w, req)
    })
}
```

`AuthenticateRequest()` 实现：遍历所有 authenticator，任何一个成功就返回 OK，

```
// staging/src/k8s.io/apiserver/pkg/authentication/request/union/union.go

func (authHandler *unionAuthRequestHandler) AuthenticateRequest(req) (*Response, bool) {
    for currAuthRequestHandler := range authHandler.Handlers {
        resp, ok := currAuthRequestHandler.AuthenticateRequest(req)
        if ok {
            return resp, ok, err
        }
    }

    return nil, false, utilerrors.NewAggregate(errlist)
}
```

### 2.2 鉴权（Authorization）

**发送者身份（认证）是一个问题，但他是否有权限执行这个操作（鉴权），是另一个问题**。因此确认发送者身份之后，还需要进行鉴权。

鉴权的过程与认证非常相似，也是逐个匹配 authorizer 列表中的 authorizer：如果都失败了， 返回 `Forbidden` 并停止 **进一步处理**[25]。如果成功，就继续。

内置的 **几种 authorizer 类型**：

- **webhook**[26]：与其他服务交互，验证是否有权限。
- **ABAC**[27]：根据静态文件中规定的策略（policies）来进行鉴权。
- **RBAC**[28]：根据 role 进行鉴权，其中 role 是 k8s 管理员提前配置的。
- **Node**[29]：确保 node clients，例如 kubelet，只能访问本机内的资源。

要看它们的具体做了哪些事情，可以查看它们各自的 `Authorize()` 方法。

### 2.3 Admission control

至此，认证和鉴权都通过了。但这还没结束，K8s 中的其它组件还需要对请求进行检查， 其中就包括 **admission controllers**[30]。

#### 与鉴权的区别

- 鉴权（authorization）在前面，关注的是**用户是否有操作权限**，
- Admission controllers 在更后面，**对请求进行拦截和过滤，确保它们符合一些更广泛的集群规则和限制**， 是**将请求对象持久化到 etcd 之前的最后堡垒**。

#### 工作方式

- 与认证和鉴权类似，也是遍历一个列表，
- 但有一点核心区别：**任何一个 controller 检查没通过，请求就会失败**。

#### 设计：可扩展

- 每个 controller 作为一个 plugin 存放在 **plugin/pkg/admission 目录**[31],
- 设计时已经考虑，只需要实现很少的几个接口
- 但注意，**admission controller 最终会编译到 k8s 的二进制文件**（而非独立的 plugin binary）

#### 类型

Admission controllers 通常按不同目的分类，包括：**资源管理、安全管理、默认值管 理、引用一致性**（referential consistency）等类型。

例如，下面是资源管理类的几个 controller：

- `InitialResources`：为容器设置默认的资源限制（基于过去的使用量）；
- `LimitRanger`：为容器的 requests and limits 设置默认值，或对特定资源设置上限（例如，内存默认 512MB，最高不超过 2GB）。
- `ResourceQuota`：资源配额。

## 3 写入 etcd

至此，K8s 已经完成对请求的验证，允许它进行接下来的处理。

kube-apiserver 将对请求进行反序列化，构造 runtime objects**（ kubectl generator 的反过程），并将它们**持久化到 etcd。下面详细 看这个过程。

### 3.0 调用栈概览

对于本文创建 pod 的请求，相应的入口是**POST handler**[32]，它又会进一步将请求委托给一个创建具体资源的 handler。

```
registerResourceHandlers // staging/src/k8s.io/apiserver/pkg/endpoints/installer.go
 |-case POST:
// staging/src/k8s.io/apiserver/pkg/endpoints/installer.go

        switch () {
        case "POST": // Create a resource.
            var handler restful.RouteFunction
            if isNamedCreater {
                handler = restfulCreateNamedResource(namedCreater, reqScope, admit)
            } else {
                handler = restfulCreateResource(creater, reqScope, admit)
            }

            handler = metrics.InstrumentRouteFunc(action.Verb, group, version, resource, subresource, .., handler)
            article := GetArticleForNoun(kind, " ")
            doc := "create" + article + kind
            if isSubresource {
                doc = "create " + subresource + " of" + article + kind
            }

            route := ws.POST(action.Path).To(handler).
                Doc(doc).
                Operation("create"+namespaced+kind+strings.Title(subresource)+operationSuffix).
                Produces(append(storageMeta.ProducesMIMETypes(action.Verb), mediaTypes...)...).
                Returns(http.StatusOK, "OK", producedObject).
                Returns(http.StatusCreated, "Created", producedObject).
                Returns(http.StatusAccepted, "Accepted", producedObject).
                Reads(defaultVersionedObject).
                Writes(producedObject)

            AddObjectParams(ws, route, versionedCreateOptions)
            addParams(route, action.Params)
            routes = append(routes, route)
        }

        for route := range routes {
            route.Metadata(ROUTE_META_GVK, metav1.GroupVersionKind{
                Group:   reqScope.Kind.Group,
                Version: reqScope.Kind.Version,
                Kind:    reqScope.Kind.Kind,
            })
            route.Metadata(ROUTE_META_ACTION, strings.ToLower(action.Verb))
            ws.Route(route)
        }
```

### 3.1 kube-apiserver 请求处理过程

从 apiserver 的请求处理函数开始：

```
// staging/src/k8s.io/apiserver/pkg/server/handler.go

func (d director) ServeHTTP(w http.ResponseWriter, req *http.Request) {
    path := req.URL.Path

    // check to see if our webservices want to claim this path
    for _, ws := range d.goRestfulContainer.RegisteredWebServices() {
        switch {
        case ws.RootPath() == "/apis":
            if path == "/apis" || path == "/apis/" {
                return d.goRestfulContainer.Dispatch(w, req)
            }

        case strings.HasPrefix(path, ws.RootPath()):
            if len(path) == len(ws.RootPath()) || path[len(ws.RootPath())] == '/' {
                return d.goRestfulContainer.Dispatch(w, req)
            }
        }
    }

    // if we didn't find a match, then we just skip gorestful altogether
    d.nonGoRestfulMux.ServeHTTP(w, req)
}
```

如果能匹配到请求（例如匹配到前面注册的路由），它将**分派给相应的 handler**[33]；否则，fall back 到**path-based handler**[34]（`GET /apis` 到达的就是这里）；

基于 path 的 handlers：

```
// staging/src/k8s.io/apiserver/pkg/server/mux/pathrecorder.go

func (h *pathHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    if exactHandler, ok := h.pathToHandler[r.URL.Path]; ok {
        return exactHandler.ServeHTTP(w, r)
    }

    for prefixHandler := range h.prefixHandlers {
        if strings.HasPrefix(r.URL.Path, prefixHandler.prefix) {
            return prefixHandler.handler.ServeHTTP(w, r)
        }
    }

    h.notFoundHandler.ServeHTTP(w, r)
}
```

如果还是没有找到路由，就会 fallback 到 non-gorestful handler，最终可能是一个 not found handler。

对于我们的场景，会匹配到一条已经注册的、名为**`createHandler`**[35]为的路由。

### 3.2 Create handler 处理过程

```
// staging/src/k8s.io/apiserver/pkg/endpoints/handlers/create.go

func createHandler(r rest.NamedCreater, scope *RequestScope, admit Interface, includeName bool) http.HandlerFunc {
    return func(w http.ResponseWriter, req *http.Request) {
        namespace, name := scope.Namer.Name(req) // 获取资源的 namespace 和 name（etcd item key）
        s := negotiation.NegotiateInputSerializer(req, false, scope.Serializer)

        body := limitedReadBody(req, scope.MaxRequestBodyBytes)
        obj, gvk := decoder.Decode(body, &defaultGVK, original)

        admit = admission.WithAudit(admit, ae)

        requestFunc := func() (runtime.Object, error) {
            return r.Create(
                name,
                obj,
                rest.AdmissionToValidateObjectFunc(admit, admissionAttributes, scope),
            )
        }

        result := finishRequest(ctx, func() (runtime.Object, error) {
            if scope.FieldManager != nil {
                liveObj := scope.Creater.New(scope.Kind)
                obj = scope.FieldManager.UpdateNoErrors(liveObj, obj, managerOrUserAgent(options.FieldManager, req.UserAgent()))
                admit = fieldmanager.NewManagedFieldsValidatingAdmissionController(admit)
            }

            admit.(admission.MutationInterface)
            mutatingAdmission.Handles(admission.Create)
            mutatingAdmission.Admit(ctx, admissionAttributes, scope)

            return requestFunc()
        })

        code := http.StatusCreated
        status, ok := result.(*metav1.Status)
        transformResponseObject(ctx, scope, trace, req, w, code, outputMediaType, result)
    }
}
```

1. 首先解析 HTTP request，然后执行基本的验证，例如保证 JSON 与 versioned API resource 期望的是一致的；

2. 执行审计和最终 admission；

3. 将资源最终**写到 etcd**[36]， 这会进一步调用到 **storage provider**[37]。

   **etcd key 的格式一般是** `<namespace>/<name>`（例如，`default/nginx-0`），但这个也是可配置的。

4. 最后，storage provider 执行一次 `get` 操作，确保对象真的创建成功了。如果有额外的收尾任务（additional finalization），会执行 post-create handlers 和 decorators。

5. 返回 **生成的**[38]HTTP response。

以上过程可以看出，apiserver 做了大量的事情。

总结：至此我们的 pod 资源已经在 etcd 中了。但是，此时 `kubectl get pods -n <ns>` 还看不见它。

## 4 Initializers

**对象持久化到 etcd 之后，apiserver 并未将其置位对外可见，它也不会立即就被调度**， 而是要先等一些 **initializers**[39] 运行完成。

### 4.1 Initializer

Initializer 是与特定资源类型（resource type）相关的 controller，

- 负责**在该资源对外可见之前对它们执行一些处理**，
- 如果一种资源类型没有注册任何 initializer，这个步骤就会跳过，**资源对外立即可见**。

这是一种非常强大的特性，使得我们能**执行一些通用的启动初始化（bootstrap）操作**。例如，

- 向 Pod 注入 sidecar、暴露 80 端口，或打上特定的 annotation。
- 向某个 namespace 内的所有 pod 注入一个存放了测试证书（test certificates）的 volume。
- 禁止创建长度小于 20 个字符的 Secret （例如密码）。

### 4.2 InitializerConfiguration

可以用 `InitializerConfiguration` **声明对哪些资源类型（resource type）执行哪些 initializer**。

例如，要实现所有 pod 创建时都运行一个自定义的 initializer `custom-pod-initializer`， 可以用下面的 yaml：

```
apiVersion: admissionregistration.k8s.io/v1alpha1
kind: InitializerConfiguration
metadata:
  name: custom-pod-initializer
initializers:
  - name: podimage.example.com
    rules:
      - apiGroups:
          - ""
        apiVersions:
          - v1
        resources:
          - pods
```

创建以上配置（`kubectl create -f xx.yaml`）之后，K8s 会将`custom-pod-initializer` **追加到每个 pod 的 `metadata.initializers.pending` 字段**。

在此之前需要启动 initializer controller，它会

- 定期扫描是否有新 pod 创建；
- 当**检测到它的名字出现在 pod 的 pending 字段**时，就会执行它的处理逻辑；
- 执行完成之后，它会将自己的名字从 pending list 中移除。

pending list 中的 initializers，每次只有第一个 initializer 能执行。当**所有 initializer 执行完成，`pending` 字段为空**之后，就认为**这个对象已经完成初始化了**（considered initialized）。

细心的同学可能会有疑问：**前面说这个对象还没有对外可见，那用 户空间的 initializer controller 又是如何能检测并操作这个对象的呢？**答案是：kube-apiserver 提供了一个 `?includeUninitialized` 查询参数，它会返回所有对象， 包括那些还未完成初始化的（uninitialized ones）。

## 5 Control loops（控制循环）

至此，对象已经在 etcd 中了，所有的初始化步骤也已经完成了。下一步是设置资源拓扑（resource topology）。例如，一个 Deployment 其实就是一组 ReplicaSet，而一个 ReplicaSet 就是一组 Pod。K8s 是如何根据一个 HTTP 请求创建出这个层级关系的呢？靠的是 **K8s 内置的控制器**（controllers）。

K8s 中大量使用 "controllers"，

- 一个 controller 就是一个异步脚本（an asynchronous script），
- 不断检查资源的**当前状态**（current state）和**期望状态**（desired state）是否一致，
- 如果不一致就尝试将其变成期望状态，这个过程称为 **reconcile**。

每个 controller 负责的东西都比较少，**所有 controller 并行运行， 由 kube-controller-manager 统一管理**。

### 5.1 Deployments controller

#### Deployments controller 启动

当一个 Deployment record 存储到 etcd 并（被 initializers）初始化之后， kube-apiserver 就会将其置为对外可见的。此后， Deployment controller 监听了 Deployment 资源的变动，因此此时就会检测到这个新创建的资源。

```
// pkg/controller/deployment/deployment_controller.go

// NewDeploymentController creates a new DeploymentController.
func NewDeploymentController(dInformer DeploymentInformer, rsInformer ReplicaSetInformer,
    podInformer PodInformer, client clientset.Interface) (*DeploymentController, error) {

    dc := &DeploymentController{
        client:        client,
        queue:         workqueue.NewNamedRateLimitingQueue(),
    }
    dc.rsControl = controller.RealRSControl{ // ReplicaSet controller
        KubeClient: client,
        Recorder:   dc.eventRecorder,
    }

    // 注册 Deployment 事件回调函数
    dInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc:    dc.addDeployment,    // 有 Deployment 创建时触发
        UpdateFunc: dc.updateDeployment,
        DeleteFunc: dc.deleteDeployment,
    })
    // 注册 ReplicaSet 事件回调函数
    rsInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc:    dc.addReplicaSet,
        UpdateFunc: dc.updateReplicaSet,
        DeleteFunc: dc.deleteReplicaSet,
    })
    // 注册 Pod 事件回调函数
    podInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        DeleteFunc: dc.deletePod,
    })

    dc.syncHandler = dc.syncDeployment
    dc.enqueueDeployment = dc.enqueue

    return dc, nil
}
```

#### 创建 Deployment：回调函数处理

在本文场景中，触发的是 controller **注册的 addDeployment() 回调函数**[40]其所做的工作就是将 deployment 对象放到一个内部队列：

```
// pkg/controller/deployment/deployment_controller.go

func (dc *DeploymentController) addDeployment(obj interface{}) {
    d := obj.(*apps.Deployment)
    dc.enqueueDeployment(d)
}
```

#### 主处理循环

worker 不断遍历这个 queue，从中 dequeue item 并进行处理：

```
// pkg/controller/deployment/deployment_controller.go

func (dc *DeploymentController) worker() {
    for dc.processNextWorkItem() {
    }
}

func (dc *DeploymentController) processNextWorkItem() bool {
    key, quit := dc.queue.Get()
    dc.syncHandler(key.(string)) // dc.syncHandler = dc.syncDeployment
}

// syncDeployment will sync the deployment with the given key.
func (dc *DeploymentController) syncDeployment(key string) error {
    namespace, name := cache.SplitMetaNamespaceKey(key)

    deployment := dc.dLister.Deployments(namespace).Get(name)
    d := deployment.DeepCopy()

    // 获取这个 Deployment 的所有 ReplicaSets, while reconciling ControllerRef through adoption/orphaning.
    rsList := dc.getReplicaSetsForDeployment(d)

    // 获取这个 Deployment 的所有 pods, grouped by their ReplicaSet
    podMap := dc.getPodMapForDeployment(d, rsList)

    if d.DeletionTimestamp != nil { // 这个 Deployment 已经被标记，等待被删除
        return dc.syncStatusOnly(d, rsList)
    }

    dc.checkPausedConditions(d)
    if d.Spec.Paused { // pause 状态
        return dc.sync(d, rsList)
    }

    if getRollbackTo(d) != nil {
        return dc.rollback(d, rsList)
    }

    scalingEvent := dc.isScalingEvent(d, rsList)
    if scalingEvent {
        return dc.sync(d, rsList)
    }

    switch d.Spec.Strategy.Type {
    case RecreateDeploymentStrategyType:             // re-create
        return dc.rolloutRecreate(d, rsList, podMap)
    case RollingUpdateDeploymentStrategyType:        // rolling-update
        return dc.rolloutRolling(d, rsList)
    }
    return fmt.Errorf("unexpected deployment strategy type: %s", d.Spec.Strategy.Type)
}
```

controller 会通过 label selector 从 kube-apiserver 查询 与这个 deployment 关联的 ReplicaSet 或 Pod records（然后发现没有）。

如果发现当前状态与预期状态不一致，就会触发同步过程（（synchronization process））。这个同步过程是无状态的，也就是说，它并不区分是新记录还是老记录，一视同仁。

#### 执行扩容（scale up）

如上，发现 pod 不存在之后，它会开始扩容过程（scaling process）：

```
// pkg/controller/deployment/sync.go

// scale up/down 或新创建（pause）时都会执行到这里
func (dc *DeploymentController) sync(d *apps.Deployment, rsList []*apps.ReplicaSet) error {

    newRS, oldRSs := dc.getAllReplicaSetsAndSyncRevision(d, rsList, false)
    dc.scale(d, newRS, oldRSs)

    // Clean up the deployment when it's paused and no rollback is in flight.
    if d.Spec.Paused && getRollbackTo(d) == nil {
        dc.cleanupDeployment(oldRSs, d)
    }

    allRSs := append(oldRSs, newRS)
    return dc.syncDeploymentStatus(allRSs, newRS, d)
}
```

大致步骤：

1. Rolling out (例如 creating）一个 ReplicaSet resource
2. 分配一个 label selector
3. 初始版本好（revision number）置为 1

ReplicaSet 的 PodSpec，以及其他一些 metadata 是从 Deployment 的 manifest 拷过来的。

最后会更新 deployment 状态，然后重新进入 reconciliation 循环，直到 deployment 进入预期的状态。

#### 小结

由于 **Deployment controller 只负责 ReplicaSet 的创建**，因此下一步 （ReplicaSet -> Pod）要由 reconciliation 过程中的另一个 controller —— ReplicaSet controller 来完成。

### 5.2 ReplicaSets controller

上一步周，Deployments controller 已经创建了 Deployment 的第一个 ReplicaSet，但此时还没有任何 Pod。下面就轮到 ReplicaSet controller 出场了。它的任务是监控 ReplicaSet 及其依赖资源（pods）的生命周期，实现方式也是注册事件回调函数。

#### ReplicaSets controller 启动

```
// pkg/controller/replicaset/replica_set.go

func NewReplicaSetController(rsInformer ReplicaSetInformer, podInformer PodInformer,
    kubeClient clientset.Interface, burstReplicas int) *ReplicaSetController {

    return NewBaseController(rsInformer, podInformer, kubeClient, burstReplicas,
        apps.SchemeGroupVersion.WithKind("ReplicaSet"),
        "replicaset_controller",
        "replicaset",
        controller.RealPodControl{
            KubeClient: kubeClient,
        },
    )
}

// 抽象出 NewBaseController() 是为了代码复用，例如 NewReplicationController() 也会调用这个函数。
func NewBaseController(rsInformer, podInformer, kubeClient clientset.Interface, burstReplicas int,
    gvk GroupVersionKind, metricOwnerName, queueName, podControl PodControlInterface) *ReplicaSetController {

    rsc := &ReplicaSetController{
        kubeClient:       kubeClient,
        podControl:       podControl,
        burstReplicas:    burstReplicas,
        expectations:     controller.NewUIDTrackingControllerExpectations(NewControllerExpectations()),
        queue:            workqueue.NewNamedRateLimitingQueue()
    }

    rsInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc:    rsc.addRS,
        UpdateFunc: rsc.updateRS,
        DeleteFunc: rsc.deleteRS,
    })
    rsc.rsLister = rsInformer.Lister()

    podInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc: rsc.addPod,
        UpdateFunc: rsc.updatePod,
        DeleteFunc: rsc.deletePod,
    })
    rsc.podLister = podInformer.Lister()

    rsc.syncHandler = rsc.syncReplicaSet
    return rsc
}
```

#### 创建 ReplicaSet：回调函数处理

#### 主处理循环

当一个 ReplicaSet 被（Deployment controller）创建之后，

```
// pkg/controller/replicaset/replica_set.go

// syncReplicaSet will sync the ReplicaSet with the given key if it has had its expectations fulfilled,
// meaning it did not expect to see any more of its pods created or deleted.
func (rsc *ReplicaSetController) syncReplicaSet(key string) error {

    namespace, name := cache.SplitMetaNamespaceKey(key)
    rs := rsc.rsLister.ReplicaSets(namespace).Get(name)

    selector := metav1.LabelSelectorAsSelector(rs.Spec.Selector)

    // 包括那些不匹配 rs selector，但有 stale controller ref 的 pod
    allPods := rsc.podLister.Pods(rs.Namespace).List(labels.Everything())
    filteredPods := controller.FilterActivePods(allPods) // Ignore inactive pods.
    filteredPods = rsc.claimPods(rs, selector, filteredPods)

    if rsNeedsSync && rs.DeletionTimestamp == nil { // 需要同步，并且没有被标记待删除
        rsc.manageReplicas(filteredPods, rs)        // *主处理逻辑*
    }

    newStatus := calculateStatus(rs, filteredPods, manageReplicasErr)
    updatedRS := updateReplicaSetStatus(AppsV1().ReplicaSets(rs.Namespace), rs, newStatus)
}
```

RS controller 检查 ReplicaSet 的状态， 发现当前状态和期望状态之间有偏差（skew），因此接下来调用 `manageReplicas()` 来 reconcile 这个状态，在这里做的事情就是增加这个 ReplicaSet 的 pod 数量。

```
// pkg/controller/replicaset/replica_set.go

func (rsc *ReplicaSetController) manageReplicas(filteredPods []*v1.Pod, rs *apps.ReplicaSet) error {
    diff := len(filteredPods) - int(*(rs.Spec.Replicas))
    rsKey := controller.KeyFunc(rs)

    if diff < 0 {
        diff *= -1
        if diff > rsc.burstReplicas {
            diff = rsc.burstReplicas
        }

        rsc.expectations.ExpectCreations(rsKey, diff)
        successfulCreations := slowStartBatch(diff, controller.SlowStartInitialBatchSize, func() {
            return rsc.podControl.CreatePodsWithControllerRef( // 扩容
                // 调用栈 CreatePodsWithControllerRef -> createPod() -> Client.CoreV1().Pods().Create()
                rs.Namespace, &rs.Spec.Template, rs, metav1.NewControllerRef(rs, rsc.GroupVersionKind))
        })

        // The skipped pods will be retried later. The next controller resync will retry the slow start process.
        if skippedPods := diff - successfulCreations; skippedPods > 0 {
            for i := 0; i < skippedPods; i++ {
                // Decrement the expected number of creates because the informer won't observe this pod
                rsc.expectations.CreationObserved(rsKey)
            }
        }
        return err
    } else if diff > 0 {
        if diff > rsc.burstReplicas {
            diff = rsc.burstReplicas
        }

        relatedPods := rsc.getIndirectlyRelatedPods(rs)
        podsToDelete := getPodsToDelete(filteredPods, relatedPods, diff)
        rsc.expectations.ExpectDeletions(rsKey, getPodKeys(podsToDelete))

        for _, pod := range podsToDelete {
            go func(targetPod *v1.Pod) {
                rsc.podControl.DeletePod(rs.Namespace, targetPod.Name, rs) // 缩容
            }(pod)
        }
    }

    return nil
}
```

增加 pod 数量的操作比较小心，每次最多不超过 burst count（这个配置是从 ReplicaSet 的父对象 Deployment 那里继承来的）。

另外，创建 Pods 的过程是 **批处理的**[41], “慢启动”操，开始时是 `SlowStartInitialBatchSize`，每执行成功一批，下次的 batch size 就翻倍。这样设计是为了避免给 kube-apiserver 造成不必要的压力，例如，如果由于 quota 不足，这批 pod 大部分都会失败，那 这种方式只会有一小批请求到达 kube-apiserver，而如果一把全上的话，请求全部会打过去。同样是失败，这种失败方式比较优雅。

#### Owner reference

K8s **通过 Owner Reference**（子资源中的一个字段，指向的是其父资源的 ID）**维护对象层级**（hierarchy）。这可以带来两方面好处：

1. 实现了 cascading deletion，即父对象被 GC 时会确保 GC 子对象；
2. 父对象之间不会出现竞争子对象的情况（例如，两个父对象认为某个子对象都是自己的）

另一个隐藏的好处是：Owner Reference 是有状态的：如果 controller 重启，重启期间不会影响 系统的其他部分，因为资源拓扑（resource topology）是独立于 controller 的。这种隔离设计也体现在 controller 自己的设计中：**controller 不应该操作 其他 controller 的资源**（resources they don't explicitly own）。

有时也可能会出现“孤儿”资源（"orphaned" resources）的情况，例如

1. 父资源删除了，子资源还在；
2. GC 策略导致子资源无法被删除。

这种情况发生时，**controller 会确保孤儿资源会被某个新的父资源收养**。多个父资源都可以竞争成为孤儿资源的父资源，但只有一个会成功（其余的会收到一个 validation 错误）。

### 5.3 Informers

很多 controller（例如 RBAC authorizer 或 Deployment controller）需要将集群信息拉到本地。

例如 RBAC authorizer 中，authenticator 会将用户信息保存到请求上下文中。随后， RBAC authorizer 会用这个信息获取 etcd 中所有与这个用户相关的 role 和 role bindings。

那么，controller 是如何访问和修改这些资源的？在 K8s 中，这是通过 informer 机制实现的。

**informer 是一种 controller 订阅存储（etcd）事件的机制**，能方便地获取它们感兴趣的资源。

- 这种方式除了提供一种很好的抽象之外，还负责处理缓存（caching，非常重要，因为可 以减少 kube-apiserver 连接数，降低 controller 测和 kube-apiserver 侧的序列化 成本）问题。
- 此外，这种设计还使得 controller 的行为是 threadsafe 的，避免影响其他组件或服务。

关于 informer 和 controller 的联合工作机制，可参考**这篇博客**[42]。

### 5.4 Scheduler（调度器）

以上 controllers 执行完各自的处理之后，etcd 中已经有了一个 Deployment、一个 ReplicaSet 和三个 Pods，可以通过 kube-apiserver 查询到。但此时，**这三个 pod 还卡在 Pending 状态，因为它们还没有被调度到任何节点**。**另外一个 controller —— 调度器**—— 负责做这件事情。

scheduler 作为控制平面的一个独立服务运行，但工作方式与其他 controller 是一样的：监听事件，然后尝试 reconcile 状态。

#### 调用栈概览

```
Run // pkg/scheduler/scheduler.go
  |-SchedulingQueue.Run()
  |
  |-scheduleOne()
     |-bind
     |  |-RunBindPlugins
     |     |-runBindPlugins
     |        |-Bind
     |-sched.Algorithm.Schedule(pod)
        |-findNodesThatFitPod
        |-prioritizeNodes
        |-selectHost
```

#### 调度过程

```
// pkg/scheduler/core/generic_scheduler.go

// 将 pod 调度到指定 node list 中的某台 node 上
func (g *genericScheduler) Schedule(ctx context.Context, fwk framework.Framework,
    state *framework.CycleState, pod *v1.Pod) (result ScheduleResult, err error) {

    feasibleNodes, diagnosis := g.findNodesThatFitPod(ctx, fwk, state, pod) // 过滤可用 nodes
    if len(feasibleNodes) == 0 {
        return result, &framework.FitError{}
    }

    if len(feasibleNodes) == 1 { // 可用 node 只有一个，就选它了
        return ScheduleResult{SuggestedHost:  feasibleNodes[0].Name}, nil
    }

    priorityList := g.prioritizeNodes(ctx, fwk, state, pod, feasibleNodes)
    host := g.selectHost(priorityList)

    return ScheduleResult{
        SuggestedHost:  host,
        EvaluatedNodes: len(feasibleNodes) + len(diagnosis.NodeToStatusMap),
        FeasibleNodes:  len(feasibleNodes),
    }, err
}

// Filters nodes that fit the pod based on the framework filter plugins and filter extenders.
func (g *genericScheduler) findNodesThatFitPod(ctx context.Context, fwk framework.Framework,
    state *framework.CycleState, pod *v1.Pod) ([]*v1.Node, framework.Diagnosis, error) {

    diagnosis := framework.Diagnosis{
        NodeToStatusMap:      make(framework.NodeToStatusMap),
        UnschedulablePlugins: sets.NewString(),
    }

    // Run "prefilter" plugins.
    s := fwk.RunPreFilterPlugins(ctx, state, pod)
    allNodes := g.nodeInfoSnapshot.NodeInfos().List()

    if len(pod.Status.NominatedNodeName) > 0 && featureGate.Enabled(features.PreferNominatedNode) {
        feasibleNodes := g.evaluateNominatedNode(ctx, pod, fwk, state, diagnosis)
        if len(feasibleNodes) != 0 {
            return feasibleNodes, diagnosis, nil
        }
    }

    feasibleNodes := g.findNodesThatPassFilters(ctx, fwk, state, pod, diagnosis, allNodes)
    feasibleNodes = g.findNodesThatPassExtenders(pod, feasibleNodes, diagnosis.NodeToStatusMap)
    return feasibleNodes, diagnosis, nil
}
```

它会过滤 **过滤 PodSpect 中 NodeName 字段为空的 pods**[43]，尝试为这样的 pods 挑选一个 node 调度上去。

#### 调度算法

下面简单看下内置的默认调度算法。

##### 注册默认 predicates

这些 predicates 其实都是函数，被调用到时，执行相应的**过滤**[44]。例如，**如果 PodSpec 里面显式要求了 CPU 或 RAM 资源，而一个 node 无法满足这些条件**， 那就会将这个 node 从备选列表中删除。

```
// pkg/scheduler/algorithmprovider/registry.go

// NewRegistry returns an algorithm provider registry instance.
func NewRegistry() Registry {
    defaultConfig := getDefaultConfig()
    applyFeatureGates(defaultConfig)

    caConfig := getClusterAutoscalerConfig()
    applyFeatureGates(caConfig)

    return Registry{
        schedulerapi.SchedulerDefaultProviderName: defaultConfig,
        ClusterAutoscalerProvider:                 caConfig,
    }
}

func getDefaultConfig() *schedulerapi.Plugins {
    plugins := &schedulerapi.Plugins{
        PreFilter: schedulerapi.PluginSet{...},
        Filter: schedulerapi.PluginSet{
            Enabled: []schedulerapi.Plugin{
                {Name: nodename.Name},        // 指定 node name 调度
                {Name: tainttoleration.Name}, // 指定 toleration 调度
                {Name: nodeaffinity.Name},    // 指定 node affinity 调度
                ...
            },
        },
        PostFilter: schedulerapi.PluginSet{...},
        PreScore: schedulerapi.PluginSet{...},
        Score: schedulerapi.PluginSet{
            Enabled: []schedulerapi.Plugin{
                {Name: interpodaffinity.Name, Weight: 1},
                {Name: nodeaffinity.Name, Weight: 1},
                {Name: tainttoleration.Name, Weight: 1},
                ...
            },
        },
        Reserve: schedulerapi.PluginSet{...},
        PreBind: schedulerapi.PluginSet{...},
        Bind: schedulerapi.PluginSet{...},
    }

    return plugins
}
```

plugin 的实现见 `pkg/scheduler/framework/plugins/`，以 `nodename` filter 为例：

```
// pkg/scheduler/framework/plugins/nodename/node_name.go

// Filter invoked at the filter extension point.
func (pl *NodeName) Filter(ctx context.Context, pod *v1.Pod, nodeInfo *framework.NodeInfo) *framework.Status {
    if !Fits(pod, nodeInfo) {
        return framework.NewStatus(UnschedulableAndUnresolvable, ErrReason)
    }
    return nil
}

// 如果 pod 没有指定 NodeName，或者指定的 NodeName 等于该 node 的 name，返回 true；其他返回 false
func Fits(pod *v1.Pod, nodeInfo *framework.NodeInfo) bool {
    return len(pod.Spec.NodeName) == 0 || pod.Spec.NodeName == nodeInfo.Node().Name
}
```

##### 对筛选出的 node 排序

选择了合适的 nodes 之后，接下来会执行一系列 priority function **对这些 nodes 进行排序**。例如，如果算法是希望将 pods 尽量分散到整个集群，那 priority 会选择资源尽量空闲的节点。

这些函数会给每个 node 打分，**得分最高的 node 会被选中**，调度到该节点。

```
// pkg/scheduler/core/generic_scheduler.go

// 运行打分插件（score plugins）对 nodes 进行排序。
func (g *genericScheduler) prioritizeNodes(ctx context.Context, fwk framework.Framework,
    state *framework.CycleState, pod *v1.Pod, nodes []*v1.Node,) (framework.NodeScoreList, error) {

    // 如果没有指定 priority 配置，所有 node 将都得 1 分。
    if len(g.extenders) == 0 && !fwk.HasScorePlugins() {
        result := make(framework.NodeScoreList, 0, len(nodes))
        for i := range nodes {
            result = append(result, framework.NodeScore{ Name:  nodes[i].Name, Score: 1 })
        }
        return result, nil
    }

    preScoreStatus := fwk.RunPreScorePlugins(ctx, state, pod, nodes)       // PreScoe 插件
    scoresMap, scoreStatus := fwk.RunScorePlugins(ctx, state, pod, nodes)  // Score 插件

    result := make(framework.NodeScoreList, 0, len(nodes))
    for i := range nodes {
        result = append(result, framework.NodeScore{Name: nodes[i].Name, Score: 0})
        for j := range scoresMap {
            result[i].Score += scoresMap[j][i].Score
        }
    }

    if len(g.extenders) != 0 && nodes != nil {
        combinedScores := make(map[string]int64, len(nodes))
        for i := range g.extenders {
            if !g.extenders[i].IsInterested(pod) {
                continue
            }
            go func(extIndex int) {
                prioritizedList, weight := g.extenders[extIndex].Prioritize(pod, nodes)
                for i := range *prioritizedList {
                    host, score := (*prioritizedList)[i].Host, (*prioritizedList)[i].Score
                    combinedScores[host] += score * weight
                }
            }(i)
        }

        for i := range result {
            result[i].Score += combinedScores[result[i].Name] * (MaxNodeScore / MaxExtenderPriority)
        }
    }

    return result, nil
}
```

#### 创建 `v1.Binding` 对象

算法选出一个 node 之后，调度器会**创建一个 Binding 对象**[45]， Pod 的 **ObjectReference 字段的值就是选中的 node 的名字**。

```
// pkg/scheduler/framework/runtime/framework.go

func (f *frameworkImpl) runBindPlugin(ctx context.Context, bp BindPlugin, state *CycleState,
    pod *v1.Pod, nodeName string) *framework.Status {

    if !state.ShouldRecordPluginMetrics() {
        return bp.Bind(ctx, state, pod, nodeName)
    }

    status := bp.Bind(ctx, state, pod, nodeName)
    return status
}
// pkg/scheduler/framework/plugins/defaultbinder/default_binder.go

// Bind binds pods to nodes using the k8s client.
func (b DefaultBinder) Bind(ctx, state *CycleState, p *v1.Pod, nodeName string) *framework.Status {
    binding := &v1.Binding{
        ObjectMeta: metav1.ObjectMeta{Namespace: p.Namespace, Name: p.Name, UID: p.UID},
        Target:     v1.ObjectReference{Kind: "Node", Name: nodeName}, // ObjectReference 字段为 nodeName
    }

    b.handle.ClientSet().CoreV1().Pods(binding.Namespace).Bind(ctx, binding, metav1.CreateOptions{})
}
```

如上，最后 `ClientSet().CoreV1().Pods(binding.Namespace).Bind()` 通过一个 **POST 请求发给 apiserver**。

#### kube-apiserver 更新 pod 对象

kube-apiserver 收到这个 Binding object 请求后，registry 反序列化对象，更新 Pod 对象的下列字段：

- 设置 NodeName
- 添加 annotations
- 设置 `PodScheduled` status 为 `True`

```
// pkg/registry/core/pod/storage/storage.go

func (r *BindingREST) setPodHostAndAnnotations(ctx context.Context, podID, oldMachine, machine string,
    annotations map[string]string, dryRun bool) (finalPod *api.Pod, err error) {

    podKey := r.store.KeyFunc(ctx, podID)
    r.store.Storage.GuaranteedUpdate(ctx, podKey, &api.Pod{}, false, nil,
        storage.SimpleUpdate(func(obj runtime.Object) (runtime.Object, error) {

        pod, ok := obj.(*api.Pod)
        pod.Spec.NodeName = machine
        if pod.Annotations == nil {
            pod.Annotations = make(map[string]string)
        }
        for k, v := range annotations {
            pod.Annotations[k] = v
        }
        podutil.UpdatePodCondition(&pod.Status, &api.PodCondition{
            Type:   api.PodScheduled,
            Status: api.ConditionTrue,
        })

        return pod, nil
    }), dryRun, nil)
}
```

#### 自定义调度器

> predicate 和 priority function 都是可扩展的，可以通过 `--policy-config-file`指定。
>
> K8s 还可以自定义调度器（自己实现调度逻辑）。**如果 PodSpec 中 schedulerName 字段不为空**，K8s 就会 将这个 pod 的调度权交给指定的调度器。

### 5.5 小结

总结一下前面已经完成的步骤：

1. HTTP 请求通过了认证、鉴权、admission control
2. Deployment, ReplicaSet 和 Pod resources 已经持久化到 etcd
3. 一系列 initializers 已经执行完毕，
4. 每个 Pod 也已经调度到了合适的 node 上。

但是，**到目前为止，我们看到的所有东西（状态），还只是存在于 etcd 中的元数据**。下一步就是将这些状态同步到计算节点上，然后计算节点上的 agent（kubelet）就开始干活了。

## 6 kubelet

每个 K8s node 上都会运行一个名为 kubelet 的 agent，它负责

- pod 生命周期管理。

  这意味着，它负责将 “Pod” 的逻辑抽象（etcd 中的元数据）转换成具体的容器（container）。

- 挂载目录

- 创建容器日志

- 垃圾回收等等

### 6.1 Pod sync（状态同步）

**kubelet 也可以认为是一个 controller**，它

1. 通过 ListWatch 接口，从 kube-apiserver **获取属于本节点的 Pod 列表**（根据`spec.nodeName`**过滤**[46]），
2. 然后与自己缓存的 pod 列表对比，如果有 pod 创建、删除、更新等操作，就开始同步状态。

下面具体看一下同步过程。

#### 同步过程

```
// pkg/kubelet/kubelet.go

// syncPod is the transaction script for the sync of a single pod.
func (kl *Kubelet) syncPod(o syncPodOptions) error {
    pod := o.pod

    if updateType == SyncPodKill { // kill pod 操作
        kl.killPod(pod, nil, podStatus, PodTerminationGracePeriodSecondsOverride)
        return nil
    }

    firstSeenTime := pod.Annotations["kubernetes.io/config.seen"] // 测量 latency，从 apiserver 第一次看到 pod 算起

    if updateType == SyncPodCreate { // create pod 操作
        if !firstSeenTime.IsZero() { // Record pod worker start latency if being created
            metrics.PodWorkerStartDuration.Observe(metrics.SinceInSeconds(firstSeenTime))
        }
    }

    // Generate final API pod status with pod and status manager status
    apiPodStatus := kl.generateAPIPodStatus(pod, podStatus)

    podStatus.IPs = []string{}
    if len(podStatus.IPs) == 0 && len(apiPodStatus.PodIP) > 0 {
        podStatus.IPs = []string{apiPodStatus.PodIP}
    }

    runnable := kl.canRunPod(pod)
    if !runnable.Admit { // Pod is not runnable; update the Pod and Container statuses to why.
        apiPodStatus.Reason = runnable.Reason
        ...
    }

    kl.statusManager.SetPodStatus(pod, apiPodStatus)

    // Kill pod if it should not be running
    if !runnable.Admit || pod.DeletionTimestamp != nil || apiPodStatus.Phase == v1.PodFailed {
        return kl.killPod(pod, nil, podStatus, nil)
    }

    // 如果 network plugin not ready，并且 pod 网络不是 host network 类型，返回相应错误
    if err := kl.runtimeState.networkErrors(); err != nil && !IsHostNetworkPod(pod) {
        return fmt.Errorf("%s: %v", NetworkNotReadyErrorMsg, err)
    }

    // Create Cgroups for the pod and apply resource parameters if cgroups-per-qos flag is enabled.
    pcm := kl.containerManager.NewPodContainerManager()

    if kubetypes.IsStaticPod(pod) { // Create Mirror Pod for Static Pod if it doesn't already exist
        ...
    }

    kl.makePodDataDirs(pod)                     // Make data directories for the pod
    kl.volumeManager.WaitForAttachAndMount(pod) // Wait for volumes to attach/mount
    pullSecrets := kl.getPullSecretsForPod(pod) // Fetch the pull secrets for the pod

    // Call the container runtime's SyncPod callback
    result := kl.containerRuntime.SyncPod(pod, podStatus, pullSecrets, kl.backOff)
    kl.reasonCache.Update(pod.UID, result)
}
```

1. 如果是 pod 创建事件，会记录一些 pod latency 相关的 metrics；

2. 然后调用 `generateAPIPodStatus()` **生成一个 v1.PodStatus 对象**，代表 pod 当前阶段（Phase）的状态。

   Pod 的 Phase 是对其生命周期中不同阶段的高层抽象，非常复杂，后面会介绍。

3. PodStatus 生成之后，将发送给 Pod status manager，后者的任务是异步地通过 apiserver 更新 etcd 记录。

4. 接下来会运行一系列 admission handlers，确保 pod 有正确的安全权限（security permissions）。

   其中包括 enforcing **AppArmor profiles and `NO_NEW_PRIVS`**[47]。在这个阶段被 deny 的 Pods 将无限期处于 Pending 状态。

5. 如果指定了 `cgroups-per-qos`，kubelet 将为这个 pod 创建 cgroups。可以实现更好的 QoS。

6. **为容器创建一些目录**。包括

7. - pod 目录 （一般是 `/var/run/kubelet/pods/<podID>`）
   - volume 目录 (`<podDir>/volumes`)
   - plugin 目录 (`<podDir>/plugins`).

8. volume manager 将 **等待**[48]`Spec.Volumes` 中定义的 volumes attach 完成。取决于 volume 类型，pod 可能会等待很长时间（例如 cloud 或 NFS volumes）。

9. 从 apiserver 获取 `Spec.ImagePullSecrets` 中指定的 **secrets，注入容器**。

10. **容器运行时（runtime）创建容器**（后面详细描述）。

#### Pod 状态

前面提到，`generateAPIPodStatus()` **生成一个 v1.PodStatus**[49]对象，代表 pod 当前阶段（Phase）的状态。

Pod 的 Phase 是对其生命周期中不同阶段的高层抽象，包括

- `Pending`
- `Running`
- `Succeeded`
- `Failed`
- `Unknown`

生成这个状态的过程非常复杂，一些细节如下：

1. 首先，顺序执行一系列 `PodSyncHandlers` 。每个 handler **判断这个 pod 是否还应该留在这个 node 上**。如果其中任何一个判断结果是否，那 pod 的 phase **将变为**[50]`PodFailed` 并最终会被从这个 node 驱逐。

   一个例子是 pod 的 `activeDeadlineSeconds` （Jobs 中会用到）超时之后，就会被驱逐。

2. 接下来决定 Pod Phase 的将是其 init 和 real containers。由于此时容器还未启动，因此 将处于 **waiting**[51] **状态**。**有 waiting 状态 container 的 pod，将处于 `Pending`[52] Phase**。

3. 由于此时容器运行时还未创建我们的容器 ，因此它将把 **`PodReady` 字段置为 False**[53].

### 6.2 CRI 及创建 pause 容器

至此，大部分准备工作都已完成，接下来即将创建容器了。**创建容器是通过 Container Runtime （例如 `docker` 或 `rkt`）完成的**。

为实现可扩展，kubelet 从 v1.5.0 开始，**使用 CRI（Container Runtime Interface）与具体的容器运行时交互**。简单来说，CRI 提供了 kubelet 和具体 runtime implementation 之间的抽象接口， 用 **protocol buffers**[54] 和 gRPC 通信。

#### CRI SyncPod

```
// pkg/kubelet/kuberuntime/kuberuntime_manager.go

// SyncPod syncs the running pod into the desired pod by executing following steps:
//  1. Compute sandbox and container changes.
//  2. Kill pod sandbox if necessary.
//  3. Kill any containers that should not be running.
//  4. Create sandbox if necessary.
//  5. Create ephemeral containers.
//  6. Create init containers.
//  7. Create normal containers.
//
func (m *kubeGenericRuntimeManager) SyncPod(pod *v1.Pod, podStatus *kubecontainer.PodStatus,
    pullSecrets []v1.Secret, backOff *flowcontrol.Backoff) (result kubecontainer.PodSyncResult) {

    // Step 1: Compute sandbox and container changes.
    podContainerChanges := m.computePodActions(pod, podStatus)
    if podContainerChanges.CreateSandbox {
        ref := ref.GetReference(legacyscheme.Scheme, pod)
        if podContainerChanges.SandboxID != "" {
            m.recorder.Eventf("Pod sandbox changed, it will be killed and re-created.")
        } else {
            InfoS("SyncPod received new pod, will create a sandbox for it")
        }
    }

    // Step 2: Kill the pod if the sandbox has changed.
    if podContainerChanges.KillPod {
        if podContainerChanges.CreateSandbox {
            InfoS("Stopping PodSandbox for pod, will start new one")
        } else {
            InfoS("Stopping PodSandbox for pod, because all other containers are dead")
        }

        killResult := m.killPodWithSyncResult(pod, ConvertPodStatusToRunningPod(m.runtimeName, podStatus), nil)
        result.AddPodSyncResult(killResult)

        if podContainerChanges.CreateSandbox {
            m.purgeInitContainers(pod, podStatus)
        }
    } else {
        // Step 3: kill any running containers in this pod which are not to keep.
        for containerID, containerInfo := range podContainerChanges.ContainersToKill {
            killContainerResult := NewSyncResult(kubecontainer.KillContainer, containerInfo.name)
            result.AddSyncResult(killContainerResult)
            m.killContainer(pod, containerID, containerInfo)
        }
    }

    // Keep terminated init containers fairly aggressively controlled
    // This is an optimization because container removals are typically handled by container GC.
    m.pruneInitContainersBeforeStart(pod, podStatus)

    // Step 4: Create a sandbox for the pod if necessary.
    podSandboxID := podContainerChanges.SandboxID
    if podContainerChanges.CreateSandbox {
        createSandboxResult := kubecontainer.NewSyncResult(kubecontainer.CreatePodSandbox, format.Pod(pod))
        result.AddSyncResult(createSandboxResult)
        podSandboxID, msg = m.createPodSandbox(pod, podContainerChanges.Attempt)
        podSandboxStatus := m.runtimeService.PodSandboxStatus(podSandboxID)
    }

    // the start containers routines depend on pod ip(as in primary pod ip)
    // instead of trying to figure out if we have 0 < len(podIPs) everytime, we short circuit it here
    podIP := ""
    if len(podIPs) != 0 {
        podIP = podIPs[0]
    }

    // Get podSandboxConfig for containers to start.
    configPodSandboxResult := kubecontainer.NewSyncResult(ConfigPodSandbox, podSandboxID)
    result.AddSyncResult(configPodSandboxResult)
    podSandboxConfig := m.generatePodSandboxConfig(pod, podContainerChanges.Attempt)

    // Helper containing boilerplate common to starting all types of containers.
    // typeName is a label used to describe this type of container in log messages,
    // currently: "container", "init container" or "ephemeral container"
    start := func(typeName string, spec *startSpec) error {
        startContainerResult := kubecontainer.NewSyncResult(kubecontainer.StartContainer, spec.container.Name)
        result.AddSyncResult(startContainerResult)

        isInBackOff, msg := m.doBackOff(pod, spec.container, podStatus, backOff)
        if isInBackOff {
            startContainerResult.Fail(err, msg)
            return err
        }

        m.startContainer(podSandboxID, podSandboxConfig, spec, pod, podStatus, pullSecrets, podIP, podIPs)
        return nil
    }

    // Step 5: start ephemeral containers
    // These are started "prior" to init containers to allow running ephemeral containers even when there
    // are errors starting an init container. In practice init containers will start first since ephemeral
    // containers cannot be specified on pod creation.
    for _, idx := range podContainerChanges.EphemeralContainersToStart {
        start("ephemeral container", ephemeralContainerStartSpec(&pod.Spec.EphemeralContainers[idx]))
    }

    // Step 6: start the init container.
    if container := podContainerChanges.NextInitContainerToStart; container != nil {
        start("init container", containerStartSpec(container))
    }

    // Step 7: start containers in podContainerChanges.ContainersToStart.
    for _, idx := range podContainerChanges.ContainersToStart {
        start("container", containerStartSpec(&pod.Spec.Containers[idx]))
    }
}
```

#### CRI create sandbox

kubelet **发起 RunPodSandbox**[55] RPC 调用。

**“sandbox” 是一个 CRI 术语，它表示一组容器，在 K8s 里就是一个 Pod**。这个词是有意用作比较宽泛的描述，这样对其他运行时的描述也是适用的（例如，在基于 hypervisor 的运行时中，sandbox 可能是一个虚拟机）。

```
// pkg/kubelet/kuberuntime/kuberuntime_sandbox.go

// createPodSandbox creates a pod sandbox and returns (podSandBoxID, message, error).
func (m *kubeGenericRuntimeManager) createPodSandbox(pod *v1.Pod, attempt uint32) (string, string, error) {
    podSandboxConfig := m.generatePodSandboxConfig(pod, attempt)

    // 创建 pod log 目录
    m.osInterface.MkdirAll(podSandboxConfig.LogDirectory, 0755)

    runtimeHandler := ""
    if m.runtimeClassManager != nil {
        runtimeHandler = m.runtimeClassManager.LookupRuntimeHandler(pod.Spec.RuntimeClassName)
        if runtimeHandler != "" {
            InfoS("Running pod with runtime handler", runtimeHandler)
        }
    }

    podSandBoxID := m.runtimeService.RunPodSandbox(podSandboxConfig, runtimeHandler)
    return podSandBoxID, "", nil
}
// pkg/kubelet/cri/remote/remote_runtime.go

// RunPodSandbox creates and starts a pod-level sandbox.
func (r *remoteRuntimeService) RunPodSandbox(config *PodSandboxConfig, runtimeHandler string) (string, error) {

    InfoS("[RemoteRuntimeService] RunPodSandbox", "config", config, "runtimeHandler", runtimeHandler)

    resp := r.runtimeClient.RunPodSandbox(ctx, &runtimeapi.RunPodSandboxRequest{
        Config:         config,
        RuntimeHandler: runtimeHandler,
    })

    InfoS("[RemoteRuntimeService] RunPodSandbox Response", "podSandboxID", resp.PodSandboxId)
    return resp.PodSandboxId, nil
}
```

#### Create sandbox：docker 相关代码

前面是 CRI 通用代码，如果我们的容器 runtime 是 docker，那接下来就会调用到 docker 相关代码。

在这种 runtime 中，**创建一个 sandbox 会转换成创建一个 “pause” 容器的操作**。Pause container 作为一个 pod 内其他所有容器的父角色，hold 了很多 pod-level 的资源， 具体说就是 Linux namespace，例如 IPC NS、Net NS、IPD NS。

"pause" container 提供了一种持有这些 ns、让所有子容器共享它们 的方式。例如，共享 netns 的好处之一是，pod 内不同容器之间可以通过 localhost 方式访问彼此。pause 容器的第二个用处是回收（reaping）dead processes。更多信息，可参考 **这篇博客**[56]。

Pause 容器创建之后，会被 checkpoint 到磁盘，然后启动。

```
// pkg/kubelet/dockershim/docker_sandbox.go

// 对于 docker runtime，PodSandbox 实现为一个 holding 网络命名空间（netns）的容器
func (ds *dockerService) RunPodSandbox(ctx context.Context, r *RunPodSandboxRequest) (*RunPodSandboxResponse) {

    // Step 1: Pull the image for the sandbox.
    ensureSandboxImageExists(ds.client, image)

    // Step 2: Create the sandbox container.
    createConfig := ds.makeSandboxDockerConfig(config, image)
    createResp := ds.client.CreateContainer(*createConfig)
    resp := &runtimeapi.RunPodSandboxResponse{PodSandboxId: createResp.ID}

    ds.setNetworkReady(createResp.ID, false) // 容器 network 状态初始化为 false

    // Step 3: Create Sandbox Checkpoint.
    CreateCheckpoint(createResp.ID, constructPodSandboxCheckpoint(config))

    // Step 4: Start the sandbox container。 如果失败，kubelet 会 GC 掉 sandbox
    ds.client.StartContainer(createResp.ID)

    rewriteResolvFile()

    // 如果是 hostNetwork 类型，到这里就可以返回了，无需下面的 CNI 流程
    if GetNetwork() == NamespaceMode_NODE {
        return resp, nil
    }

    // Step 5: Setup networking for the sandbox with CNI
    // 包括分配 IP、设置 sandbox 内的路由、创建虚拟网卡等。
    cID := kubecontainer.BuildContainerID(runtimeName, createResp.ID)
    ds.network.SetUpPod(Namespace, Name, cID, Annotations, networkOptions)

    return resp, nil
}
```

最后调用的 `SetUpPod()` 为容器创建网络，它有会调用到 plugin manager 的同名方法：

```
// pkg/kubelet/dockershim/network/plugins.go

func (pm *PluginManager) SetUpPod(podNamespace, podName, id ContainerID, annotations, options) error {
    const operation = "set_up_pod"
    fullPodName := kubecontainer.BuildPodFullName(podName, podNamespace)

    // 调用 CNI 插件为容器设置网络
    pm.plugin.SetUpPod(podNamespace, podName, id, annotations, options)
}
```

> Cgroup 也很重要，是 Linux 掌管资源分配的方式，docker 利用它实现资源隔离。更多信息，参考 **What even is a Container?**[57]

### 6.3 CNI 前半部分：CNI plugin manager 处理

现在我们的 pod 已经有了一个占坑用的 pause 容器，它占住了 pod 需要用到的所有 namespace。接下来需要做的就是：**调用底层的具体网络方案**（bridge/flannel/calico/cilium 等等） 提供的 CNI 插件，**创建并打通容器的网络**。

CNI 是 Container Network Interface 的缩写，工作机制与 Container Runtime Interface 类似。简单来说，CNI 是一个抽象接口，不同的网络提供商只要实现了 CNI 中的几个方法，就能接入 K8s，为容器创建网络。kubelet 与 CNI 插件之间通过 JSON 数据交互（配置文件放在 `/etc/cni/net.d`），通过 stdin 将配置数据传递给 CNI binary (located in `/opt/cni/bin`)。

CNI 插件有自己的配置，例如，内置的 bridge 插件可能配置如下：

```
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
```

还会通过 `CNI_ARGS` 环境变量传递 pod metadata，例如 name 和 ns。

#### 调用栈概览

下面的调用栈是 CNI 前半部分：**CNI plugin manager 调用到具体的 CNI 插件**（可执行文件）， 执行 shell 命令为容器创建网络：

```
SetUpPod                                                  // pkg/kubelet/dockershim/network/cni/cni.go
 |-ns = plugin.host.GetNetNS(id)
 |-plugin.addToNetwork(name, id, ns)                      // -> pkg/kubelet/dockershim/network/cni/cni.go
    |-plugin.buildCNIRuntimeConf
    |-cniNet.AddNetworkList(netConf)                      // -> github.com/containernetworking/cni/libcni/api.go
       |-for net := range list.Plugins
       |   result = c.addNetwork
       |              |-pluginPath = FindInPath(c.Path)
       |              |-ValidateContainerID(ContainerID)
       |              |-ValidateNetworkName(name)
       |              |-ValidateInterfaceName(IfName)
       |              |-invoke.ExecPluginWithResult(pluginPath, c.args("ADD", rt))
       |                        |-shell("/opt/cni/bin/xx <args>")
       |
       |-c.cacheAdd(result, list.Bytes, list.Name, rt)
```

最后一层调用 `ExecPlugin()`：

```
// vendor/github.com/containernetworking/cni/pkg/invoke/raw_exec.go

func (e *RawExec) ExecPlugin(ctx, pluginPath, stdinData []byte, environ []string) ([]byte, error) {
    c := exec.CommandContext(ctx, pluginPath)
    c.Env = environ
    c.Stdin = bytes.NewBuffer(stdinData)
    c.Stdout = stdout
    c.Stderr = stderr

    for i := 0; i <= 5; i++ { // Retry the command on "text file busy" errors
        err := c.Run()
        if err == nil { // Command succeeded
            break
        }

        if strings.Contains(err.Error(), "text file busy") {
            time.Sleep(time.Second)
            continue
        }

        // All other errors except than the busy text file
        return nil, e.pluginErr(err, stdout.Bytes(), stderr.Bytes())
    }

    return stdout.Bytes(), nil
}
```

可以看到，经过上面的几层调用，最终是通过 shell 命令执行了宿主机上的 CNI 插件， 例如 `/opt/cni/bin/cilium-cni`，并通过 stdin 传递了一些 JSON 参数。

### 6.4 CNI 后半部分：CNI plugin 实现

下面看 CNI 处理的后半部分：CNI 插件为容器创建网络，也就是可执行文件 `/opt/cni/bin/xxx` 的实现。

CNI 相关的代码维护在一个单独的项目 **github.com/containernetworking/cni**[58]。每个 CNI 插件只需要实现其中的几个方法，然后**编译成独立的可执行文件**，放在 `/etc/cni/bin`下面即可。下面是一些具体的插件，

```
$ ls /opt/cni/bin/
bridge  cilium-cni  cnitool  dhcp  host-local  ipvlan  loopback  macvlan  noop
```

#### 调用栈概览

CNI 插件（可执行文件）执行时会调用到 `PluginMain()`，从这往后的调用栈 （**注意源文件都是 `github.com/containernetworking/cni` 项目中的路径**）：

```
PluginMain                                                     // pkg/skel/skel.go
 |-PluginMainWithError                                         // pkg/skel/skel.go
   |-pluginMain                                                // pkg/skel/skel.go
      |-switch cmd {
          case "ADD":
            checkVersionAndCall(cmdArgs, cmdAdd)               // pkg/skel/skel.go
              |-configVersion = Decode(cmdArgs.StdinData)
              |-Check(configVersion, pluginVersionInfo)
              |-toCall(cmdArgs) // toCall == cmdAdd
                 |-cmdAdd(cmdArgs)
                   |-specific CNI plugin implementations

          case "DEL":
            checkVersionAndCall(cmdArgs, cmdDel)
          case "VERSION":
            versionInfo.Encode(t.Stdout)
          default:
            return createTypedError("unknown CNI_COMMAND: %v", cmd)
        }
```

可见对于 kubelet 传过来的 "ADD" 命令，最终会调用到 CNI 插件的 cmdAdd() 方法 —— 该方法默认是空的，需要由每种 CNI 插件自己实现。同理，删除 pod 时对应的是 `"DEL"`操作，调用到的 `cmdDel()` 方法也是要由具体 CNI 插件实现的。

#### CNI 插件实现举例：Bridge

**github.com/containernetworking/plugins**[59]项目中包含了很多种 CNI plugin 的实现，例如 IPVLAN、Bridge、MACVLAN、VLAN 等等。

`bridge` CNI plugin 的实现见**plugins/main/bridge/bridge.go**[60]

执行逻辑如下：

1. 在默认 netns 创建一个 Linux bridge，这台宿主机上的所有容器都将连接到这个 bridge。

2. 创建一个 veth pair，将容器和 bridge 连起来。

3. 分配一个 IP 地址，配置到 pause 容器，设置路由。

   IP 从配套的网络服务 IPAM（IP Address Management）中分配的。最场景的 IPAM plugin 是`host-local`，它从预先设置的一个网段里分配一个 IP，并将状态信息写到宿主机的本地文件系统，因此重启不会丢失。`host-local` IPAM 的实现见 **plugins/ipam/host-local**[61]。

4. 修改 `resolv.conf`，为容器配置 DNS。这里的 DNS 信息是从传给 CNI plugin 的参数中解析的。

以上过程完成之后，容器和宿主机（以及同宿主机的其他容器）之间的网络就通了， CNI 插件会将结果以 JSON 返回给 kubelet。

#### CNI 插件实现举例：Noop

再来看另一种比较有趣的 CNI 插件：`noop`。这个插件是 CNI 项目自带的， 代码见 **plugins/test/noop/main.go**[62]。

```
func cmdAdd(args *skel.CmdArgs) error {
    return debugBehavior(args, "ADD")
}

func cmdDel(args *skel.CmdArgs) error {
    return debugBehavior(args, "DEL")
}
```

从名字以及以上代码可以看出，这个 CNI 插件（几乎）什么事情都不做。用途：

1. **测试或调试**：它可以打印 debug 信息。

2. 给只支持 hostNetwork 的节点使用。

   每个 node 上必须有一个配置正确的 CNI 插件，kubelet 自检才能通过，否则 node 会处于 NotReady 状态。

   某些情况下，我们不想让一些 node（例如 master node）承担正常的、创建带 IP pod 的工作， 只要它能创建 hostNetwork 类型的 pod 就行了（这样就无需给这些 node 分配 PodCIDR， 也不需要在 node 上启动 IPAM 服务）。

   这种情况下，就可以用 noop 插件。参考配置：

   ```
   $ cat /etc/cni/net.d/98-noop.conf
   {
       "cniVersion": "0.3.1",
       "type": "noop"
   }
   ```

#### CNI 插件实现举例：Cilium

这个就很复杂了，做的事情非常多，可参考 Cilium Code Walk Through: CNI Create Network。

### 6.5 为容器配置跨节点通信网络（inter-host networking）

这项工作不在 K8s 及 CNI 插件的职责范围内，是由具体网络方案 在节点上的 agent 完成的，例如 flannel 网络的 flanneld，cilium 网络的 cilium-agent。

简单来说，跨节点通信有两种方式：

1. 隧道（tunnel or overlay）
2. 直接路由

这里赞不展开，可参考迈入 Cilium+BGP 的云原生网络时代。

### 6.6 创建 `init` 容器及业务容器

至此，网络部分都配置好了。接下来就开始启动真正的业务容器。

Sandbox 容器初始化完成后，kubelet 就开始创建其他容器。首先会启动 `PodSpec` 中指定的所有 init 容器，**代码**[63]然后才启动主容器（main containers）。

#### 调用栈概览

```
startContainer
 |-m.runtimeService.CreateContainer                      // pkg/kubelet/cri/remote/remote_runtime.go
 |  |-r.runtimeClient.CreateContainer                    // -> pkg/kubelet/dockershim/docker_container.go
 |       |-new(CreateContainerResponse)                  // staging/src/k8s.io/cri-api/pkg/apis/runtime/v1/api.pb.go
 |       |-Invoke("/runtime.v1.RuntimeService/CreateContainer")
 |
 |  CreateContainer // pkg/kubelet/dockershim/docker_container.go
 |      |-ds.client.CreateContainer                      // -> pkg/kubelet/dockershim/libdocker/instrumented_client.go
 |             |-d.client.ContainerCreate                // -> vendor/github.com/docker/docker/client/container_create.go
 |                |-cli.post("/containers/create")
 |                |-json.NewDecoder().Decode(&resp)
 |
 |-m.runtimeService.StartContainer(containerID)          // -> pkg/kubelet/cri/remote/remote_runtime.go
    |-r.runtimeClient.StartContainer
         |-new(CreateContainerResponse)                  // staging/src/k8s.io/cri-api/pkg/apis/runtime/v1/api.pb.go
         |-Invoke("/runtime.v1.RuntimeService/StartContainer")
```

#### 具体过程

```
// pkg/kubelet/kuberuntime/kuberuntime_container.go

func (m *kubeGenericRuntimeManager) startContainer(podSandboxID, podSandboxConfig, spec *startSpec, pod *v1.Pod,
     podStatus *PodStatus, pullSecrets []v1.Secret, podIP string, podIPs []string) (string, error) {

    container := spec.container

    // Step 1: 拉镜像
    m.imagePuller.EnsureImageExists(pod, container, pullSecrets, podSandboxConfig)

    // Step 2: 通过 CRI 创建容器
    containerConfig := m.generateContainerConfig(container, pod, restartCount, podIP, imageRef, podIPs, target)

    m.internalLifecycle.PreCreateContainer(pod, container, containerConfig)
    containerID := m.runtimeService.CreateContainer(podSandboxID, containerConfig, podSandboxConfig)
    m.internalLifecycle.PreStartContainer(pod, container, containerID)

    // Step 3: 启动容器
    m.runtimeService.StartContainer(containerID)

    legacySymlink := legacyLogSymlink(containerID, containerMeta.Name, sandboxMeta.Name, sandboxMeta.Namespace)
    m.osInterface.Symlink(containerLog, legacySymlink)

    // Step 4: 执行 post start hook
    m.runner.Run(kubeContainerID, pod, container, container.Lifecycle.PostStart)
}
```

过程：

1. **拉镜像**[64]。如果是私有镜像仓库，就会从 PodSpec 中寻找访问仓库用的 secrets。

2. 通过 CRI **创建 container**[65]。

   从 parent PodSpec 的 `ContainerConfig` struct 中解析参数（command, image, labels, mounts, devices, env variables 等等）， 然后通过 protobuf 发送给 CRI plugin。例如对于 docker，收到请求后会反序列化，从中提取自己需要的参数，然后发送给 Daemon API。过程中它会给容器添加几个 metadata labels （例如 container type, log path, sandbox ID）。

3. 然后通过 `runtimeService.startContainer()` 启动容器；

4. 如果注册了 post-start hooks，接下来就执行这些 hooks。**post Hook 类型**：

- `Exec`：在容器内执行具体的 shell 命令。
- `HTTP`：对容器内的服务（endpoint）发起 HTTP 请求。

如果 PostStart hook 运行时间过长，或者 hang 住或失败了，容器就无法进入 `running`状态。

## 7 结束

至此，应该已经有 3 个 pod 在运行了，取决于系统资源和调度策略，它们可能在一台 node 上，也可能分散在多台。

### 脚注

[1]What happens when ... Kubernetes edition!: *https://github.com/jamiehannaford/what-happens-when-k8s*[2]`v1.21`: *https://github.com/kubernetes/kubernetes/tree/v1.21.1*[3]generic apiserver: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/cmd/kube-apiserver/app/server.go#L219*[4]Config.OpenAPIConfig 字段: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/server/config.go#L167*[5]storage provider: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/kube-aggregator/pkg/apiserver/apiserver.go#L204*[6]配置 REST mappings: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/endpoints/groupversion.go#L92*[7]镜像名为空或格式不对: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/kubectl/pkg/cmd/run/run.go#L262*[8]generator: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/kubectl/pkg/cmd/run/run.go#L300*[9]文档: *https://kubernetes.io/docs/user-guide/kubectl-conventions/#generators*[10]`BasicPod`: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/kubectl/pkg/generate/versioned/run.go#L233*[11]实现: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/kubectl/pkg/generate/versioned/run.go#L259*[12]搜索合适的 API group 和版本: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/kubectl/pkg/cmd/run/run.go#L610-L619*[13]创建一个正确版本的客户端（versioned client）: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/kubectl/pkg/cmd/run/run.go#L641*[14]缓存这份 OpenAPI schema: *https://github.com/kubernetes/kubernetes/blob/v1.14.0/staging/src/k8s.io/cli-runtime/pkg/genericclioptions/config_flags.go#L234*[15]发送出去: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/kubectl/pkg/cmd/run/run.go#L654*[16]预定义的路径: *https://github.com/kubernetes/client-go/blob/v1.21.0/tools/clientcmd/loader.go#L52*[17]TLS: *https://github.com/kubernetes/client-go/blob/82aa063804cf055e16e8911250f888bc216e8b61/rest/transport.go#L80-L89*[18]发送: *https://github.com/kubernetes/client-go/blob/c6f8cf2c47d21d55fa0df928291b2580544886c8/transport/round_trippers.go#L314*[19]发送: *https://github.com/kubernetes/client-go/blob/c6f8cf2c47d21d55fa0df928291b2580544886c8/transport/round_trippers.go#L223*[20]命令行参数: *https://kubernetes.io/docs/admin/kube-apiserver/*[21]x509 handler: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/authentication/request/x509/x509.go#L60*[22]bearer token handler: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/authentication/request/bearertoken/bearertoken.go#L38*[23]basicauth handler: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/plugin/pkg/authenticator/request/basicauth/basicauth.go#L37*[24]加上用户信息: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/endpoints/filters/authentication.go#L71-L75*[25]进一步处理: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/endpoints/filters/authorization.go#L60*[26]webhook: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/plugin/pkg/authorizer/webhook/webhook.go#L143*[27]ABAC: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/auth/authorizer/abac/abac.go#L223*[28]RBAC: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/plugin/pkg/auth/authorizer/rbac/rbac.go#L43*[29]Node: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/plugin/pkg/auth/authorizer/node/node_authorizer.go#L67*[30]admission controllers: *https://kubernetes.io/docs/admin/admission-controllers/#what-are-they*[31]`plugin/pkg/admission` 目录: *https://github.com/kubernetes/kubernetes/tree/master/plugin/pkg/admission*[32]POST handler: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/endpoints/installer.go#L815*[33]分派给相应的 handler: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/server/handler.go#L136*[34]path-based handler: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/server/mux/pathrecorder.go#L146*[35]`createHandler`: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/endpoints/handlers/create.go#L37*[36]写到 etcd: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/endpoints/handlers/create.go#L401*[37]storage provider: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/registry/generic/registry/store.go#L362*[38]生成的: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/staging/src/k8s.io/apiserver/pkg/endpoints/handlers/create.go#L131-L142*[39]initializers: *https://kubernetes.io/docs/admin/extensible-admission-controllers/#initializers*[40]注册的 addDeployment() 回调函数: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/controller/deployment/deployment_controller.go#L122*[41]批处理的: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/controller/replicaset/replica_set.go#L487*[42]这篇博客: *http://borismattijssen.github.io/articles/kubernetes-informers-controllers-reflectors-stores*[43]过滤 PodSpect 中 NodeName 字段为空的 pods: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/plugin/pkg/scheduler/factory/factory.go#L190*[44]过滤: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/plugin/pkg/scheduler/core/generic_scheduler.go#L117*[45]创建一个 Binding 对象: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/plugin/pkg/scheduler/scheduler.go#L336-L342*[46]过滤: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/config/apiserver.go#L32*[47]AppArmor profiles and `NO_NEW_PRIVS`: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/kubelet.go#L883-L884*[48]等待: *https://github.com/kubernetes/kubernetes/blob/2723e06a251a4ec3ef241397217e73fa782b0b98/pkg/kubelet/volumemanager/volume_manager.go#L330*[49]生成一个 v1.PodStatus: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/kubelet_pods.go#L1287*[50]将变为: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/kubelet_pods.go#L1293-L1297*[51]waiting: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/kubelet_pods.go#L1244*[52]`Pending`: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/kubelet_pods.go#L1258-L1261*[53]`PodReady` 字段置为 False: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/status/generate.go#L70-L81*[54]protocol buffers: *https://github.com/google/protobuf*[55]发起 `RunPodSandbox`: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/kuberuntime/kuberuntime_sandbox.go#L51*[56]这篇博客: *https://www.ianlewis.org/en/almighty-pause-container*[57]What even is a Container?: *https://jvns.ca/blog/2016/10/10/what-even-is-a-container/*[58]github.com/containernetworking/cni: *https://github.com/containernetworking/cni*[59]github.com/containernetworking/plugins: *https://github.com/containernetworking/plugins*[60]plugins/main/bridge/bridge.go: *https://github.com/containernetworking/plugins/blob/v0.9.1/plugins/main/bridge/bridge.go*[61]plugins/ipam/host-local: *https://github.com/containernetworking/plugins/tree/v0.9.1/plugins/ipam/host-local*[62]plugins/test/noop/main.go: *https://github.com/containernetworking/cni/blob/v0.8.1/plugins/test/noop/main.go#L184*[63]代码: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/kuberuntime/kuberuntime_manager.go#L690*[64]拉镜像: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/kuberuntime/kuberuntime_container.go#L140*[65]创建 container: *https://github.com/kubernetes/kubernetes/blob/v1.21.0/pkg/kubelet/kuberuntime/kuberuntime_container.go#L179*



