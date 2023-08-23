# clusternet

[toc]

## 架构介绍

Clusternet ( Cluster Internet )  是腾讯开源的多集群和应用管理软件，无论集群是运行在公有云、私有云、混合云还是边缘云上，Clusternet 都可以让您像在本地运行一样管理/访问它们，用 Kubernetes API 集中部署和协调多集群的应用程序和服务。通过 Addon 插件方式，用户可以一键安装、运维及集成，轻松地管理数以百万计的 Kubernetes 集群，就像访问 Internet 一样自由便捷。

![image-20211022011736527](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20211022011736527.png)



Clusternet 面向未来混合云、分布式云和边缘计算场景设计，支持海量集群的接入和管理，灵活的集群注册能力可以适应各种复杂网络条件下的集群管理需求，通过兼容云原生的 Kubernetes API 简化用户的管理和运维成本，加快用户业务的云原生转型。

`clusternet-agent` is responsible for

- auto-registering current cluster to a parent cluster as a child cluster, which is also been called `ManagedCluster`;

  自动将当前集群注册到父集群（也叫管理集群）

- reporting heartbeats of current cluster, including Kubernetes version, running platform, `healthz`/`readyz`/`livez` status, etc;

  自动上报当前集群心跳，包括集群版本，运行平台，健康/就绪/存活状态等

- setting up a websocket connection that provides full-duplex communication channels over a single TCP connection to parent cluster;

  启动一个websocket连接，通过连接到当前集群的一个TCP连接提供全双工通信

`clusternet-hub` is responsible for

- approving cluster registration requests and creating dedicated resources, such as namespaces, serviceaccounts and RBAC rules, for each child cluster;

  允许集群注册请求和创建专用资源，比如 为子集群创建 namespaces, serviceaccounts and RBAC rules等;

- serving as an **aggregated apiserver (AA)**, which is used to serve as a websocket server that maintain multiple active websocket connections from child clusters;

  提供聚合api服务，作为webshocket服务用于维持和多个子集群websocket连接的活动

- providing Kubernstes-styled API to redirect/proxy/upgrade requests to each child cluster;

  提供k8s风格的API 直连/代理/升级 请求到子集群

- coordinating and deploying applications to multiple clusters from a single set of APIs;

  从一组API协调和发布应用到多个集群



### 相关概念

For every Kubernetes cluster that wants to be managed, we call it **child cluster**. The cluster where child clusters are registerring to, we call it **parent cluster**.

`clusternet-agent` runs in child cluster, while `clusternet-hub` runs in parent cluster.

- `ClusterRegistrationRequest` is an object that `clusternet-agent` creates in parent cluster for child cluster registration.

  集群注册申请，用于子集群申请注册

  

- `ManagedCluster` is an object that `clusternet-hub` creates in parent cluster after approving `ClusterRegistrationRequest`.

  管理集群

  

- `HelmChart` is an object contains a [helm chart](https://helm.sh/docs/topics/charts/) configuration.

  

- `Subscription` defines the resources that subscribers want to install into clusters. For every matched cluster, a corresponding `Base` object will be created in its dedicated namespace.

  “Subscription”定义了订阅者想要安装到集群的资源。对于每一个匹配的集群，一个对应的`Base`对象将会被创建在专用的命名空间。

  

- `Clusternet` provides a ***two-stage priority based*** override strategy. `Localization` and `Globalization` will define the overrides with priority, where lower numbers are considered lower priority. `Localization` is namespace-scoped resource, while `Globalization` is cluster-scoped. Refer to [Deploying Applications to Multiple Clusters](https://github.com/clusternet/clusternet#deploying-applications-to-multiple-clusters) on how to use these.

  “Clusternet”提供了一种基于优先级的两阶段覆盖策略。 “本地化”和“全局化”将定义优先级覆盖，数字越低优先级越低。“本地化”是命名空间作用域的资源，而“全球化”是集群作用域的资源。关于如何使用它们，请参阅[将应用程序部署到多个集群](https://github.com/clusternet/clusternet#deploying-applications-to-multiple-clusters)。

  

- `Base` objects will be rendered to `Description` objects with `Globalization` and `Localization` settings applied. `Description` is the final resources to be deployed into target child clusters.

  “基础”对象将被渲染为“描述”对象，并应用“全球化”和“本地化”设置。“Description”是部署到目标子集群的最终资源。

![image-20211022014620720](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20211022014620720.png)



## 部署 Clusternet

You need to deploy `clusternet-agent` and `clusternet-hub` in child cluster and parent cluster respectively.



### Deploying `clusternet-hub` in parent cluster

```
$ kubectl apply -f deploy/hub
```

Next, you need to create a token for cluster registration, which will be used later by `clusternet-agent`. Either a bootstrap token or a service account token is okay.

- If bootstrapping authentication is supported, i.e. `--enable-bootstrap-token-auth=true` is explicitly set in the kube-apiserver running in parent cluster,

  ```
  $ # this will create a bootstrap token 07401b.f395accd246ae52d
  $ kubectl apply -f manifests/samples/cluster_bootstrap_token.yaml
  ```

- If bootstrapping authentication is not supported by the kube-apiserver in parent cluster (like [k3s](https://k3s.io/)) , i.e. `--enable-bootstrap-token-auth=false` (which defaults to be `false`), please use serviceaccount token instead.

  ```
  $ # this will create a serviceaccount token
  $ kubectl apply -f manifests/samples/cluster_serviceaccount_token.yaml
  $ kubectl get secret -n clusternet-system -o=jsonpath='{.items[?(@.metadata.annotations.kubernetes\.io/service-account\.name=="cluster-bootstrap-use")].data.token}' | base64 --decode; echo
  HERE WILL OUTPUTS A LONG STRING. PLEASE REMEMBER THIS.
  ```



### Deploying `clusternet-agent` in child cluster

`clusternet-agent` runs in child cluster and helps register self-cluster to parent cluster.

`clusternet-agent` could be configured with below three kinds of `SyncMode` (configured by flag `--cluster-sync-mode`),

- `Push` means that all the resource changes in the parent cluster will be synchronized, pushed and applied to child clusters by `clusternet-hub` automatically.

  `Push（推）` 模式是指父集群的所有资源变化将由 `clusternet-hub` 自动同步、推送并应用到子集群

- `Pull` means `clusternet-agent` will watch, synchronize and apply all the resource changes from the parent cluster to child cluster.

  `Pull（拉）` 模式表示 `clusternet-agent` 将自动 watch、同步和应用所有从父集群到子集群的资源变化

- `Dual` combines both `Push` and `Pull` mode. This mode is strongly recommended, which is usually used together with feature gate `AppPusher`.

  `Dual` 推拉结合模式，这种模式强烈推荐，通常与特性 `AppPusher` 一起使用

Feature gate `AppPusher` works on agent side, which is introduced mainly for below two reasons,

- `SyncMode` is not suggested getting changed after registration, which may bring in inconsistent settings and behaviors. That's why `Dual` mode is strong recommended. When `Dual` mode is set, feature gate `AppPusher` provides a way to help switch `Push` mode to `Pull` mode without really changing flag `--cluster-sync-mode`, and vice versa.

  不建议在注册后改变同步模式，这可能会带来不一致的配置和行为，这就是为什么强烈推荐双模式。当双模式被设置后，`AppPusher` 提供了一种方法来帮助将 Push 模式切换到 Pull 模式，而无需真正更改标志 `--cluster-sync-mode`，反之亦然。

  

- For security concerns, such as child cluster security risks, etc.

  When a child cluster has disabled feature gate `AppPusher`, the parent cluster won't deploy any applications to it, even if SyncMode `Push` or `Dual` is set. At this time, this child cluster is working like `Pull` mode.

  Resources to be deployed are represented as `Description`, you can run your own controllers as well to watch changes of `Description` objects, then distribute and deploy resources.

  当一个子集群禁用 `AppPusher` 时，父集群不会向其部署任何应用程序，即使设置为 `Push` 或 `Dual` 模式，这个时候，这个子集群的工作方式就像 `Pull` 模式。

  要部署的资源被表示为 `Description` 对象，你也可以运行你自己的控制器来 watch 该对象的变化，然后来分发和部署资源。

Upon deploying `clusternet-agent`, a secret that contains token for cluster registration should be created firstly.

```bash
$ # create namespace clusternet-system if not created
$ kubectl create ns clusternet-system
$ # here we use the token created above
$ PARENTURL=https://192.168.10.10 REGTOKEN=07401b.f395accd246ae52d envsubst < ./deploy/templates/clusternet_agent_secret.yaml | kubectl apply -f -
```

> 📌 📌 Note:
>
> If you're creating service account token above, please replace `07401b.f395accd246ae52d` with above long string token that outputs.

The `PARENTURL` above is the apiserver address of the parent cluster that you want to register to, the `https` scheme must be specified and it is the only one supported at the moment. If the apiserver is not listening on the standard https port (:443), please specify the port number in the URL to ensure the agent connects to the right endpoint, for instance, `https://192.168.10.10:6443`.

```
$ # before deploying, you could update the SyncMode if needed
$ kubectl apply -f deploy/agent
```



## Visit ManagedCluster With RBAC

***Clusternet supports visiting all your managed clusters with RBAC.***

There is one prerequisite here, that is `kube-apiserver` should **allow anonymous requests**. The flag `--anonymous-auth` is set to be `true` by default. So you can just ignore this unless this flag is set to `false` explicitly

```bash
# Here the token is base64 decoded and from your child cluster.
export CHILDCLUSTERTOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6IkhSaVJtdERIOEdhTkYzVndXMnEyNk02SWsxMnM3UTM3bFFBZHJ5Q2FLM3MifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi10b2tlbi1zcWMyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJhZG1pbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjAwZTI2NjIwLTZkYzgtNDkwOC1hMjcxLTQ0YTBkMTQ1NDIzYSIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTphZG1pbiJ9.Zwnpr86dghryoVXIU11IegOuiw-CULvCd7A03TXmE1nOopJweR9SAzPAnrVC-O6gMVGSNXmYPFYtCW_4zCjoTlhxnAgv4WiNOndQQdOmNPMLHdcTjrtG_LT29IuHvgdDWSOQ-p2bk5wl0K5dlRNIpqex5LpzU-JzyJY8ek5Ug2gnA80HF-HMyBM_qBpDxiJvf_kOzpOc1m4P1q1oDqc86y8S5tS9EYV68T9I-NAmmh3XqjKVpUfcCMvN3YSzxFWX9XYGEPwIiqRKFPug946cKKtqaLHJ7GTkkpCKV9Ls_59WFJPkdsYuO5Czm63joLhfdSfaGkPWWe3BhKPiJ8EcXA"

# The Parent Cluster APIServer Address    username: system:anonymous
    as: clusternet
    as-user-extra:
        clusternet-token:
            - BASE64-DECODED-PLEASE-CHANGE-ME
export APISERVER="https://47.243.203.89:6443"

# specify the child cluster id
export CHILDCLUSTERID="703c80cf-34cd-481d-b477-d692032103da"
curl -k -XGET  -H "Accept: application/json" -H "Impersonate-User: clusternet" -H "Impersonate-Extra-Clusternet-Token: ${CHILDCLUSTERTOKEN}" -H "Authorization: Basic system:anonymous" "${APISERVER}/apis/proxies.clusternet.io/v1alpha1/sockets/${CHILDCLUSTERID}/proxy/direct/api/v1/namespaces"


```



## 发布应用

Clusternet supports deploying applications to multiple clusters from a single set of APIs in a hosting cluster.

> 📌 📌 Note:
>
> Feature gate `Deployer` should be enabled by `clusternet-hub`.

First, let's see an exmaple application. Below `Subscription` "app-demo" defines the target child clusters to be distributed to, and the resources to be deployed with.

```yaml
# examples/applications/subscription.yaml
apiVersion: apps.clusternet.io/v1alpha1
kind: Subscription
metadata:
  name: app-demo
  namespace: default
spec:
  subscribers: # defines the clusters to be distributed to
    - clusterAffinity:
        matchLabels:
          clusters.clusternet.io/cluster-id: dc91021d-2361-4f6d-a404-7c33b9e01118 # PLEASE UPDATE THIS CLUSTER-ID TO YOURS!!!
  feeds: # defines all the resources to be deployed with
    - apiVersion: apps.clusternet.io/v1alpha1
      kind: HelmChart
      name: mysql
      namespace: default
    - apiVersion: v1
      kind: Namespace
      name: foo
    - apiVersion: apps/v1
      kind: Service
      name: my-nginx-svc
      namespace: foo
    - apiVersion: apps/v1
      kind: Deployment
      name: my-nginx
      namespace: foo
```

Before applying this `Subscription`, please modify [examples/applications/subscription.yaml](https://github.com/clusternet/clusternet/blob/main/examples/applications/subscription.yaml) with your clusterID.

`Clusternet` also provides a ***two-stage priority based*** override strategy. You can define namespace-scoped `Localization` and cluster-scoped `Globalization` with priorities (ranging from 0 to 1000, default to be 500), where lower numbers are considered lower priority. These Globalization(s) and Localization(s) will be applied by order from lower priority to higher. That means override values in lower `Globalization` will be overridden by those in higher `Globalization`. Globalization(s) come first and then Localization(s).

 “Clusternet”还提供了一个基于优先级的两阶段覆盖策略。您可以定义具有优先级的名称空间作用域的“本地化”和集群作用域的“全球化”(范围从0到1000，默认为500)，其中较低的数字被认为是较低的优先级。这些全球化和本地化将按优先级从低到高的顺序应用。这意味着较低“全球化”中的覆盖值将被较高“全球化”中的覆盖值所覆盖。首先是全球化，然后是本地化。



> 💫 💫 For example,
>
> Globalization (priority: 100) -> Globalization (priority: 600) -> Localization (priority: 100) -> Localization (priority 500)



Meanwhile, below override policies are supported,

- `ApplyNow` will apply overrides for matched objects immediately, including those are already populated.
- Default override policy `ApplyLater` will only apply override for matched objects on next updates (including updates on `Subscription`, `HelmChart`, etc) or new created objects.

Before applying these Localization(s), please modify [examples/applications/localization.yaml](https://github.com/clusternet/clusternet/blob/main/examples/applications/localization.yaml) with your `ManagedCluster` namespace, such as `clusternet-5l82l`.

After installing kubectl plugin [kubectl-clusternet](https://github.com/clusternet/kubectl-clusternet), you could run below commands to distribute this application to child clusters.

```
$ kubectl clusternet apply -f examples/applications/
helmchart.apps.clusternet.io/mysql created
namespace/foo created
deployment.apps/my-nginx created
service/my-nginx-svc created
subscription.apps.clusternet.io/app-demo created
$ # or
$ # kubectl-clusternet apply -f examples/applications/
```

Then you can view the resources just created,

```
$ # list Subscription
$ kubectl clusternet get subs -A
NAMESPACE   NAME       AGE
default     app-demo   6m4s
$ kubectl clusternet get chart
NAME             CHART   VERSION   REPO                                 STATUS   AGE
mysql            mysql   8.6.2     https://charts.bitnami.com/bitnami   Found    71s
$ kubectl clusternet get ns
NAME   CREATED AT
foo    2021-08-07T08:50:55Z
$ kubectl clusternet get svc -n foo
NAME           CREATED AT
my-nginx-svc   2021-08-07T08:50:57Z
$ kubectl clusternet get deploy -n foo
NAME       CREATED AT
my-nginx   2021-08-07T08:50:56Z
```

`Clusternet` will help deploy and coordinate applications to multiple clusters. You can check the status by following commands,

```
$ kubectl clusternet get mcls -A
NAMESPACE          NAME                       CLUSTER ID                             SYNC MODE   KUBERNETES   READYZ   AGE
clusternet-5l82l   clusternet-cluster-hx455   dc91021d-2361-4f6d-a404-7c33b9e01118   Dual        v1.21.0      true     5d22h
$ # list Descriptions
$ kubectl clusternet get desc -A
NAMESPACE          NAME               DEPLOYER   STATUS    AGE
clusternet-5l82l   app-demo-generic   Generic    Success   2m55s
clusternet-5l82l   app-demo-helm      Helm       Success   2m55s
$ kubectl describe desc -n clusternet-5l82l   app-demo-generic
...
Status:
  Phase:  Success
Events:
  Type    Reason                Age    From            Message
  ----    ------                ----   ----            -------
  Normal  SuccessfullyDeployed  2m55s  clusternet-hub  Description clusternet-5l82l/app-demo-generic is deployed successfully
$ # list Helm Release
$ # hr is an alias for HelmRelease
$ kubectl clusternet get hr -n clusternet-5l82l
NAME                  CHART       VERSION   REPO                                 STATUS     AGE
helm-demo-mysql       mysql       8.6.2     https://charts.bitnami.com/bitnami   deployed   2m55s
```

You can also verify the installation with Helm command line in your child cluster,

```
$ helm ls -n abc
NAME               	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART            	APP VERSION
helm-demo-mysql    	abc      	1       	2021-07-06 14:34:44.188938 +0800 CST	deployed	mysql-8.6.2      	8.0.25
```

> 📌 📌 Note:
>
> Admission webhooks could be configured in parent cluster, but please make sure that [dry-run](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#side-effects) mode is supported in these webhooks. At the same time, a webhook must explicitly indicate that it will not have side-effects when running with `dryRun`. That is [`sideEffects`](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#side-effects) must be set to `None` or `NoneOnDryRun`.
>
> While, these webhooks could be configured per child cluster without above limitations as well.



## 优点

#### 一站式管理各类 Kubernetes 集群

Clusternet 支持 Pull 模式和 Push 模式管理集群。即使集群运行在 VPC 内网中、边缘或防火墙后时，Clusternet 仍可建立网络隧道连接管理集群。



#### 支持跨集群的服务发现及服务互访

在无专网通道的情况下，仍可提供跨集群的访问路由。



#### 完全兼容原生 Kubernetes API

完全兼容 Kubernetes 的标准 API，比如：Deployment，StatefulSet，DaemonSet，同时也包括用户自定义的 CRD 等，用户从单集群应用升级到多集群只需做简单的配置，无需学习复杂的多集群 API。



#### 支持部署 Helm Chart、Kubernetes 原生的应用以及自定义的 CRD

支持 Helm chart 类型应用，包括 Chart 的分发、差异化配置、状态的汇聚等，和原生 Kubernetes API 的能力一致。



#### 丰富、灵活的配置管理

提供了多种类型的配置策略，用户可灵活的搭配这些配置来实现复杂的业务场景，比如多集群灰度发布。



#### Addon 能力，架构简单

采用了 Aggregated ApiServer 的方式，且不依赖额外的存储，架构简单，便于部署，大大降低了运维复杂度。



#### 便捷接入

Clusternet 提供了完善的对接能力，支持 **kubectl plugin**[1] 以及 **client-go**[2]，方便业务一键接入，具备管理多集群的能力。



## 实现原理

略



link

- https://mp.weixin.qq.com/s/y8z8VYk-K28M99uC_bqwRQ

