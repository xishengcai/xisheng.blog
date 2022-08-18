# K8s: 准入控制



### 什么是准入控制插件

准入控制器是一段代码，它会在请求通过认证和授权之后、对象被持久化之前拦截到达 API 服务器的请求

有两个特殊的控制器：MutatingAdmissionWebhook 和 ValidatingAdmissionWebhook



### 如何启用一个准入控制器

Kubernetes API 服务器的 enable-admission-plugins 标志，它指定了一个用于在集群修改对象之前调用的（以逗号分隔的）准入控制插件顺序列表。

例如，下面的命令就启用了 NamespaceLifecycle 和 LimitRanger 准入控制插件：

```bash
kube-apiserver --enable-admission-plugins=NamespaceLifecycle,LimitRanger ...
```



### 怎么关闭准入控制器

Kubernetes API 服务器的 disable-admission-plugins 标志，会将传入的（以逗号分隔的）准入控制插件列表禁用，即使是默认启用的插件也会被禁用。

```bash
kube-apiserver --disable-admission-plugins=PodNodeSelector,AlwaysDeny ...
```



### 哪些插件是默认启用的

```bash
kube-apiserver -h | grep enable-admission-plugins
```



### 每个准入控制器的作用是什么

- AlwaysPullImages

该准入控制器会修改每一个新创建的 Pod 的镜像拉取策略为 Always 。 这在多租户集群中是有用的，这样用户就可以放心，他们的私有镜像只能被那些有凭证的人使用。 如果没有这个准入控制器，一旦镜像被拉取到节点上，任何用户的 pod 都可以通过已了解到的镜像的名称（假设 pod 被调度到正确的节点上）来使用它，而不需要对镜像进行任何授权检查。 当启用这个准入控制器时，总是在启动容器之前拉取镜像，这意味着需要有效的凭证。

- MutatingAdmissionWebhook

**FEATURE STATE**: Kubernetes v1.13

该准入控制器调用任何与请求匹配的变更 webhook。匹配的 webhook 将被串行调用。每一个 webhook 都可以根据需要修改对象。

MutatingAdmissionWebhook ，顾名思义，仅在变更阶段运行。

如果由此准入控制器调用的 Webhook 有副作用（如降低配额）， 则它 必须 具有协调系统，因为不能保证后续的 Webhook 和验证准入控制器都会允许完成请求。

如果你禁用了 MutatingAdmissionWebhook，那么还必须使用 --runtime-config 标志禁止 admissionregistration.k8s.io/v1beta1 组/版本中的 MutatingWebhookConfiguration 对象（版本 >=1.9 时，这两个对象都是默认启用的）

- ValidatingAdmissionWebhook

**FEATURE STATE**: Kubernetes v1.13

该准入控制器调用与请求匹配的所有验证 webhook。匹配的 webhook 将被并行调用。如果其中任何一个拒绝请求，则整个请求将失败。 该准入控制器仅在验证阶段运行；与 MutatingAdmissionWebhook 准入控制器所调用的 webhook 相反，它调用的 webhook 应该不会使对象出现变更。

如果以此方式调用的 webhook 有其它作用（如，配额递减），则它必须具有协调系统，因为不能保证后续的 webhook 或其他有效的准入控制器都允许请求完成。

<!- If you disable the ValidatingAdmissionWebhook, you must also disable the ValidatingWebhookConfiguration object in the admissionregistration.k8s.io/v1beta1 group/version via the --runtime-config flag (both are on by default in versions 1.9 and later). –> 如果您禁用了 ValidatingAdmissionWebhook，还必须在 admissionregistration.k8s.io/v1beta1 组/版本中使用 --runtime-config 标志来禁用 ValidatingWebhookConfiguration 对象（默认情况下在 1.9 版和更高版本中均处于启用状态）。

- ServiceAccount

**FEATURE STATE**: Kubernetes v1.16 alpha

该准入控制器实现了 serviceAccounts 的自动化。 如果您打算使用 Kubernetes 的 ServiceAccount 对象，我们强烈建议您使用这个准入控制器。

- 容器运行时类

[容器运行时类](https://kubernetes.io/docs/concepts/containers/runtime-class/)定义描述了与运行 Pod 相关的开销。此准入控制器将相应地设置 pod.Spec.Overhead 字段。
详情请参见 [Pod 开销](https://kubernetes.io/docs/concepts/configuration/pod-overhead/)。

- 有推荐的准入控制器吗

有，对于 Kubernetes 1.10 以上的版本，推荐使用的准入控制器默认情况下都处于启用状态（查看这里）。 因此您无需显式指定它们。您可以使用 --enable-admission-plugins 标志（ 顺序不重要 ）来启用默认设置以外的其他准入控制器。

> **注意** : --admission-control 在 1.10 中已废弃，已由 --enable-admission-plugins 取代。

对于 Kubernetes 1.9 及更早版本，我们建议使用 --admission-control 标志（顺序很重要）运行下面的一组准入控制器

```bash
--admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota
```



### 什么是 admission webhook

Admission webhook 是一种用于接收准入请求并对其进行处理的 HTTP 回调机制。 可以定义两种类型的 admission webhook，即 validating admission webhook 和 mutating admission webhook。 Mutating admission webhook 会先被调用。它们可以更改发送到 API 服务器的对象以执行自定义的设置默认值操作。

在完成了所有对象修改并且 API 服务器也验证了所传入的对象之后，validating admission webhook 会被调用，并通过拒绝请求的方式来强制实施自定义的策略。

> 注意： 如果 admission webhook 需要保证它们所看到的是对象的最终状态以实施某种策略。则应使用 validating admission webhook，因为对象被 mutating webhook 看到之后仍然可能被修改。

required

- 确保 Kubernetes 集群版本至少为 v1.16（以便使用 admissionregistration.k8s.io/v1 API） 或者 v1.9 （以便使用 admissionregistration.k8s.io/v1beta1 API）。

- 确保启用 MutatingAdmissionWebhook 和 ValidatingAdmissionWebhook 控制器。 这里 是一组推荐的 admission 控制器，通常可以启用。

- 确保启用了 admissionregistration.k8s.io/v1beta1 API。

```yaml
    - --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
    - --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
    - --requestheader-allowed-names=front-proxy-client
    - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
    - --requestheader-extra-headers-prefix=X-Remote-Extra-
    - --requestheader-group-headers=X-Remote-Group
    - --requestheader-username-headers=X-Remote-User
    - --secure-port=6443
    - --service-account-key-file=/etc/kubernetes/pki/sa.pub
    - --service-cluster-ip-range=10.96.0.0/12
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
    - --enable-admission-plugins=NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
```

上面的enable-admission-plugins参数中带上了MutatingAdmissionWebhook和ValidatingAdmissionWebhook两个准入控制插件，如果没有的，需要添加上这两个参数，然后重启 apiserver。

然后通过运行下面的命令检查集群中是否启用了准入注册 API：

```bash
[root@wyh ~]# kubectl api-versions |grep admission
admissionregistration.k8s.io/v1beta1
```

![kubernetes API request lifecycle](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/162325.png)



#### write admission webhook server

请参阅 Kubernetes e2e 测试中的 admission webhook 服务器 的实现。webhook 处理由 apiserver 发送的 AdmissionReview 请求，并且将其决定作为 AdmissionReview 对象以相同版本发送回去。

有关发送到 webhook 的数据的详细信息，请参阅 webhook 请求。

要获取来自 webhook 的预期数据，请参阅 webhook 响应。

示例 admission webhook 服务器置 ClientAuth 字段为空，默认为 NoClientCert 。这意味着 webhook 服务器不会验证客户端的身份，认为其是 apiservers。 如果您需要双向 TLS 或其他方式来验证客户端，请参阅如何对 apiservers 进行身份认证。



#### deploy admission webhook server

#### webhook 配置

要注册 admssion webhook，请创建 MutatingWebhookConfiguration 或 ValidatingWebhookConfiguration API 对象。

每种配置可以包含一个或多个 webhook。如果在单个配置中指定了多个 webhook，则应为每个 webhook 赋予一个唯一的名称。 这在 admissionregistration.k8s.io/v1 中是必需的，但是在使用 admissionregistration.k8s.io/v1beta1 时强烈建议使用，以使生成的审核日志和指标更易于与活动配置相匹配。

每个 webhook 定义以下内容。

匹配请求-规则

每个 webhook 必须指定用于确定是否应将对 apiserver 的请求发送到 webhook 的规则列表。 每个规则都指定一个或多个 operations、apiGroups、apiVersions 和 resources 以及资源的 scope：

- operations 列出一个或多个要匹配的操作。可以是 CREATE、UPDATE、DELETE、CONNECT 或 * 以匹配所有内容。
- apiGroups 列出了一个或多个要匹配的 API 组。"" 是核心 API 组。"*" 匹配所有 API 组。
- apiVersions 列出了一个或多个要匹配的 API 版本。"*" 匹配所有 API 版本。
- resources 列出了一个或多个要匹配的资源。
  - "*" 匹配所有资源，但不包括子资源。
  - "*/*" 匹配所有资源，包括子资源。
  - "pods/*" 匹配 pod 的所有子资源。
  - "*/status" 匹配所有 status 子资源。

- scope 指定要匹配的范围。有效值为 "Cluster"、"Namespaced" 和 "*"。子资源匹配其父资源的范围。在 Kubernetes v1.14+ 版本中才被支持。默认值为 "*"，对应 1.14 版本之前的行为。
  - "Cluster" 表示只有集群作用域的资源才能匹配此规则（API 对象 Namespace 是集群作用域的）。
  - "Namespaced" 意味着仅具有命名空间的资源才符合此规则。
  - "*" 表示没有范围限制。

如果传入请求与任何 Webhook 规则的指定操作、组、版本、资源和范围匹配，则该请求将发送到 Webhook。

以下是可用于指定应拦截哪些资源的规则的其他示例。

匹配针对 apps/v1 和 apps/v1beta1 组中 deployments 和 replicasets 资源的 CREATE 或 UPDATE 请求：

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
...
webhooks:
- name: my-webhook.example.com
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["apps"]
    apiVersions: ["v1", "v1beta1"]
    resources: ["deployments", "replicasets"]
    scope: "Namespaced"
  ...
```

```yaml
# v1.16 中被废弃，推荐使用 admissionregistration.k8s.io/v1
apiVersion: admissionregistration.k8s.io/v1beta1
kind: ValidatingWebhookConfiguration
...
webhooks:
- name: my-webhook.example.com
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["apps"]
    apiVersions: ["v1", "v1beta1"]
    resources: ["deployments", "replicasets"]
    scope: "Namespaced"
  ...
```

参考文献:

1. https://kubernetes.io/zh/docs/reference/access-authn-authz/webhook/
2. https://www.qikqiak.com/post/k8s-admission-webhook/
3. https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#how-do-i-turn-on-an-admission-controller
4. https://kubernetes.io/zh/docs/reference/access-authn-authz/extensible-admission-controllers/#webhook-configuration
