# 服务器端应用（Server-Side Apply）

**FEATURE STATE:** `Kubernetes v1.16 [beta]`

## 简介

服务器端应用协助用户、控制器通过声明式配置的方式管理他们的资源。 它发送完整描述的目标（A fully specified intent）， 声明式地创建和/或修改 [对象](https://kubernetes.io/zh/docs/concepts/overview/working-with-objects/kubernetes-objects/)。

一个完整描述的目标并不是一个完整的对象，仅包括能体现用户意图的字段和值。 该目标（intent）可以用来创建一个新对象， 也可以通过服务器来实现与现有对象的[合并](https://kubernetes.io/zh/docs/reference/using-api/server-side-apply/#merge-strategy)。

系统支持多个应用者（appliers）在同一个对象上开展协作。

“[字段管理（field management）](https://kubernetes.io/zh/docs/reference/using-api/server-side-apply/#field-management)”机制追踪对象字段的变化。 当一个字段值改变时，其所有权从当前管理器（manager）转移到施加变更的管理器。 当尝试将新配置应用到一个对象时，如果字段有不同的值，且由其他管理器管理， 将会引发[冲突](https://kubernetes.io/zh/docs/reference/using-api/server-side-apply/#conflicts)。 冲突引发警告信号：此操作可能抹掉其他协作者的修改。 冲突可以被刻意忽略，这种情况下，值将会被改写，所有权也会发生转移。

当你从配置文件中删除一个字段，然后应用这个配置文件， 这将触发服务端应用检查此字段是否还被其他字段管理器拥有。 如果没有，那就从活动对象中删除该字段；如果有，那就重置为默认值。 该规则同样适用于 list 或 map 项目。

**服务器端应用既是原有 `kubectl apply` 的替代品， 也是控制器发布自身变化的一个简化机制。**

如果你启用了服务器端应用，控制平面就会跟踪被所有新创建对象管理的字段。

## 字段管理

相对于通过 `kubectl` 管理的注解 `last-applied`， 服务器端应用使用了一种更具声明式特点的方法： 它持续的跟踪用户的字段管理，而不仅仅是最后一次的执行状态。 这就意味着，作为服务器端应用的一个副作用， 关于用哪一个字段管理器负责管理对象中的哪个字段的这类信息，都要对外界开放了。

用户管理字段这件事，在服务器端应用的场景中，意味着用户依赖并期望字段的值不要改变。 最后一次对字段值做出断言的用户将被记录到当前字段管理器。 这可以通过发送 `POST`、 `PUT`、 或非应用（non-apply）方式的 `PATCH` 等命令来修改字段值的方式实现， 或通过把字段放在配置文件中，然后发送到服务器端应用的服务端点的方式实现。 当使用服务器端应用，尝试着去改变一个被其他人管理的字段， 会导致请求被拒绝（在没有设置强制执行时，参见[冲突](https://kubernetes.io/zh/docs/reference/using-api/server-side-apply/#conflicts)）。

如果两个或以上的应用者均把同一个字段设置为相同值，他们将共享此字段的所有权。 后续任何改变共享字段值的尝试，不管由那个应用者发起，都会导致冲突。 共享字段的所有者可以放弃字段的所有权，这只需从配置文件中删除该字段即可。

字段管理的信息存储在 `managedFields` 字段中，该字段是对象的 [`metadata`](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#objectmeta-v1-meta)中的一部分。

服务器端应用创建对象的简单示例如下：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-cm
  namespace: default
  labels:
    test-label: test
  managedFields:
  - manager: kubectl
    operation: Apply
    apiVersion: v1
    time: "2010-10-10T0:00:00Z"
    fieldsType: FieldsV1
    fieldsV1:
      f:metadata:
        f:labels:
          f:test-label: {}
      f:data:
        f:key: {}
data:
  key: some value
```

上述对象在 `metadata.managedFields` 中包含了唯一的管理器。 管理器由管理实体自身的基本信息组成，比如操作类型、API 版本、以及它管理的字段。

> **说明：** 该字段由 API 服务器管理，用户不应该改动它。

不过，执行 `Update` 操作修改 `metadata.managedFields` 也是可实现的。 强烈不鼓励这么做，但当发生如下情况时， 比如 `managedFields` 进入不一致的状态（显然不应该发生这种情况）， 这么做也是一个合理的尝试。

`managedFields` 的格式在 [API](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#fieldsv1-v1-meta) 文档中描述。

## 冲突

冲突是一种特定的错误状态， 发生在执行 `Apply` 改变一个字段，而恰巧该字段被其他用户声明过主权时。 这可以防止一个应用者不小心覆盖掉其他用户设置的值。 冲突发生时，应用者有三种办法来解决它：

- **覆盖前值，成为唯一的管理器：** 如果打算覆盖该值（或应用者是一个自动化部件，比如控制器）， 应用者应该设置查询参数 `force` 为 true，然后再发送一次请求。 这将强制操作成功，改变字段的值，从所有其他管理器的 managedFields 条目中删除指定字段。
- **不覆盖前值，放弃管理权：** 如果应用者不再关注该字段的值， 可以从配置文件中删掉它，再重新发送请求。 这就保持了原值不变，并从 managedFields 的应用者条目中删除该字段。
- **不覆盖前值，成为共享的管理器：** 如果应用者仍然关注字段值，并不想覆盖它， 他们可以在配置文件中把字段的值改为和服务器对象一样，再重新发送请求。 这样在不改变字段值的前提下， 就实现了字段管理被应用者和所有声明了管理权的其他的字段管理器共享。

## 管理器

管理器识别出正在修改对象的工作流程（在冲突时尤其有用）, 管理器可以通过修改请求的参数 `fieldManager` 指定。 虽然 kubectl 默认发往 `kubectl` 服务端点，但它则请求到应用的服务端点（apply endpoint）。 对于其他的更新，它默认的是从用户代理计算得来。

## 应用和更新

此特性涉及两类操作，分别是 `Apply` （内容类型为 `application/apply-patch+yaml` 的 `PATCH` 请求） 和 `Update` （所有修改对象的其他操作）。 这两类操作都会更新字段 `managedFields`，但行为表现有一点不同。

> **说明：**
>
> 不管你提交的是 JSON 数据还是 YAML 数据， 都要使用 `application/apply-patch+yaml` 作为 `Content-Type` 的值。
>
> 所有的 JSON 文档 都是合法的 YAML。

例如，在冲突发生的时候，只有 `apply` 操作失败，而 `update` 则不会。 此外，`apply` 操作必须通过提供一个 `fieldManager` 查询参数来标识自身， 而此查询参数对于 `update` 操作则是可选的。 最后，当使用 `apply` 命令时，你不能在应用中的对象中持有 `managedFields`。

一个包含多个管理器的对象，示例如下：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-cm
  namespace: default
  labels:
    test-label: test
  managedFields:
  - manager: kubectl
    operation: Apply
    apiVersion: v1
    fields:
      f:metadata:
        f:labels:
          f:test-label: {}
  - manager: kube-controller-manager
    operation: Update
    apiVersion: v1
    time: '2019-03-30T16:00:00.000Z'
    fields:
      f:data:
        f:key: {}
data:
  key: new value
```

在这个例子中， 第二个操作被管理器 `kube-controller-manager` 以 `Update` 的方式运行。 此 `update` 更改 data 字段的值， 并使得字段管理器被改为 `kube-controller-manager`。

如果把 `update` 操作改为 `Apply`，那就会因为所有权冲突的原因，导致操作失败。

## 合并策略

由服务器端应用实现的合并策略，提供了一个总体更稳定的对象生命周期。 服务器端应用试图依据谁管理它们来合并字段，而不只是根据值来否决。 这么做是为了多个参与者可以更简单、更稳定的更新同一个对象，且避免引起意外干扰。

当用户发送一个“完整描述的目标”对象到服务器端应用的服务端点， 服务器会将它和活动对象做一次合并，如果两者中有重复定义的值，那就以配置文件的为准。 如果配置文件中的项目集合不是此用户上一次操作项目的超集， 所有缺少的、没有其他应用者管理的项目会被删除。 关于合并时用来做决策的对象规格的更多信息，参见 [sigs.k8s.io/structured-merge-diff](https://sigs.k8s.io/structured-merge-diff).

Kubernetes 1.16 和 1.17 中添加了一些标记， 允许 API 开发人员描述由 list、map、和 structs 支持的合并策略。 这些标记可应用到相应类型的对象，在 Go 文件或在 [CRD](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21#jsonschemaprops-v1-apiextensions-k8s-io) 的 OpenAPI 的模式中定义：

| Golang 标记     | OpenAPI extension            | 可接受的值                                                   | 描述                                                         | 引入版本 |
| --------------- | ---------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | -------- |
| `//+listType`   | `x-kubernetes-list-type`     | `atomic`/`set`/`map`                                         | 适用于 list。 `atomic` 和 `set` 适用于只包含标量元素的 list。 `map` 适用于只包含嵌套类型的 list。 如果配置为 `atomic`, 合并时整个列表会被替换掉; 任何时候，唯一的管理器都把列表作为一个整体来管理。如果是 `set` 或 `map` ，不同的管理器也可以分开管理条目。 | 1.16     |
| `//+listMapKey` | `x-kubernetes-list-map-keys` | 用来唯一标识条目的 map keys 切片，例如 `["port", "protocol"]` | 仅当 `+listType=map` 时适用。组合值的字符串切片必须唯一标识列表中的条目。尽管有多个 key，`listMapKey` 是单数的，这是因为 key 需要在 Go 类型中单独的指定。 | 1.16     |
| `//+mapType`    | `x-kubernetes-map-type`      | `atomic`/`granular`                                          | 适用于 map。 `atomic` 指 map 只能被单个的管理器整个的替换。 `granular` 指 map 支持多个管理器各自更新自己的字段。 | 1.17     |
| `//+structType` | `x-kubernetes-map-type`      | `atomic`/`granular`                                          | 适用于 structs；否则就像 `//+mapType` 有相同的用法和 openapi 注释. | 1.17     |

### 自定义资源

默认情况下，服务器端应用把自定义资源看做非结构化数据。 所有的键值（keys）就像 struct 的字段一样被处理， 所有的 list 被认为是原子性的。

如果自定义资源定义（Custom Resource Definition，CRD）定义了一个 [模式](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21#jsonschemaprops-v1-apiextensions-k8s-io)， 它包含类似以前“合并策略”章节中定义过的注解， 这些注解将在合并此类型的对象时使用。

### 在控制器中使用服务器端应用

控制器的开发人员可以把服务器端应用作为简化控制器的更新逻辑的方式。 读-改-写 和/或 patch 的主要区别如下所示：

- 应用的对象必须包含控制器关注的所有字段。
- 对于在控制器没有执行过应用操作之前就已经存在的字段，不能删除。 （控制器在这种用例环境下，依然可以发送一个 PATCH/UPDATE）
- 对象不必事先读取，`resourceVersion` 不必指定。

强烈推荐：设置控制器在冲突时强制执行，这是因为冲突发生时，它们没有其他解决方案或措施。

### 转移所有权

除了通过[冲突解决方案](https://kubernetes.io/zh/docs/reference/using-api/server-side-apply/#conflicts)提供的并发控制， 服务器端应用提供了一些协作方式来将字段所有权从用户转移到控制器。

最好通过例子来说明这一点。 让我们来看看，在使用 HorizontalPodAutoscaler 资源和与之配套的控制器， 且开启了 Deployment 的自动水平扩展功能之后， 怎么安全的将 `replicas` 字段的所有权从用户转移到控制器。

假设用户定义了 Deployment，且 `replicas` 字段已经设置为期望的值：

[`application/ssa/nginx-deployment.yaml`](https://raw.githubusercontent.com/kubernetes/website/master/content/zh/examples/application/ssa/nginx-deployment.yaml) ![Copy application/ssa/nginx-deployment.yaml to clipboard](https://d33wubrfki0l68.cloudfront.net/0901162ab78eb4ff2e9e5dc8b17c3824befc91a6/44ccd/images/copycode.svg)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
```

并且，用户使用服务器端应用，像这样创建 Deployment：

```bash
kubectl apply -f https://k8s.io/examples/application/ssa/nginx-deployment.yaml --server-side
```

然后，为 Deployment 启用 HPA，例如：

```bash
kubectl autoscale deployment nginx-deployment --cpu-percent=50 --min=1 --max=10
```

现在，用户希望从他们的配置中删除 `replicas`，所以他们总是和 HPA 控制器冲突。 然而，这里存在一个竟态： 在 HPA 需要调整 `replicas` 之前会有一个时间窗口， 如果在 HPA 写入字段成为所有者之前，用户删除了`replicas`， 那 API 服务器就会把 `replicas` 的值设为1， 也就是默认值。 这不是用户希望发生的事情，即使是暂时的。

这里有两个解决方案：

- （容易） 把 `replicas` 留在配置文件中；当 HPA 最终写入那个字段， 系统基于此事件告诉用户：冲突发生了。在这个时间点，可以安全的删除配置文件。
- （高级）然而，如果用户不想等待，比如他们想为合作伙伴保持集群清晰， 那他们就可以执行以下步骤，安全的从配置文件中删除 `replicas`。

首先，用户新定义一个只包含 `replicas` 字段的配置文件：

[`application/ssa/nginx-deployment-replicas-only.yaml`](https://raw.githubusercontent.com/kubernetes/website/master/content/zh/examples/application/ssa/nginx-deployment-replicas-only.yaml) ![Copy application/ssa/nginx-deployment-replicas-only.yaml to clipboard](https://d33wubrfki0l68.cloudfront.net/0901162ab78eb4ff2e9e5dc8b17c3824befc91a6/44ccd/images/copycode.svg)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
```

用户使用名为 `handover-to-hpa` 的字段管理器，应用此配置文件。

```bash
kubectl apply -f https://k8s.io/examples/application/ssa/nginx-deployment-replicas-only.yaml \
  --server-side --field-manager=handover-to-hpa \
  --validate=false
```

如果应用操作和 HPA 控制器产生冲突，那什么都不做。 冲突只是表明控制器在更早的流程中已经对字段声明过所有权。

在此时间点，用户可以从配置文件中删除 `replicas` 。

[`application/ssa/nginx-deployment-no-replicas.yaml`](https://raw.githubusercontent.com/kubernetes/website/master/content/zh/examples/application/ssa/nginx-deployment-no-replicas.yaml) ![Copy application/ssa/nginx-deployment-no-replicas.yaml to clipboard](https://d33wubrfki0l68.cloudfront.net/0901162ab78eb4ff2e9e5dc8b17c3824befc91a6/44ccd/images/copycode.svg)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
```

注意，只要 HPA 控制器为 `replicas` 设置了一个新值， 该临时字段管理器将不再拥有任何字段，会被自动删除。 这里不需要执行清理工作。

## 在用户之间转移所有权

通过在配置文件中把一个字段设置为相同的值，用户可以在他们之间转移字段的所有权， 从而共享了字段的所有权。 当用户共享了字段的所有权，任何一个用户可以从他的配置文件中删除该字段， 并应用该变更，从而放弃所有权，并实现了所有权向其他用户的转移。

## 与客户端应用的对比

由服务器端应用实现的冲突检测和解决方案的一个结果就是， 应用者总是可以在本地状态中得到最新的字段值。 如果得不到最新值，下次执行应用操作时就会发生冲突。 解决冲突三个选项的任意一个都会保证：此应用过的配置文件是服务器上对象字段的最新子集。

这和客户端应用（Client Side Apply） 不同，如果有其他用户覆盖了此值， 过期的值被留在了应用者本地的配置文件中。 除非用户更新了特定字段，此字段才会准确， 应用者没有途径去了解下一次应用操作是否会覆盖其他用户的修改。

另一个区别是使用客户端应用的应用者不能改变他们正在使用的 API 版本，但服务器端应用支持这个场景。

## 从客户端应用升级到服务器端应用

客户端应用方式时，用户使用 `kubectl apply` 管理资源， 可以通过使用下面标记切换为使用服务器端应用。

```bash
kubectl apply --server-side [--dry-run=server]
```

默认情况下，对象的字段管理从客户端应用方式迁移到 kubectl 触发的服务器端应用时，不会发生冲突。

> **注意：**
>
> 保持注解 `last-applied-configuration` 是最新的。 从注解能推断出字段是由客户端应用管理的。 任何没有被客户端应用管理的字段将引发冲突。
>
> 举例说明，比如你在客户端应用之后， 使用 `kubectl scale` 去更新 `replicas` 字段， 可是该字段并没有被客户端应用所拥有， 在执行 `kubectl apply --server-side` 时就会产生冲突。

此操作以 `kubectl` 作为字段管理器来应用到服务器端应用。 作为例外，可以指定一个不同的、非默认字段管理器停止的这种行为，如下面的例子所示。 对于 kubectl 触发的服务器端应用，默认的字段管理器是 `kubectl`。

```bash
kubectl apply --server-side --field-manager=my-manager [--dry-run=server]
```

## 从服务器端应用降级到客户端应用

如果你用 `kubectl apply --server-side` 管理一个资源， 可以直接用 `kubectl apply` 命令将其降级为客户端应用。

降级之所以可行，这是因为 `kubectl server-side apply` 会保存最新的 `last-applied-configuration` 注解。

此操作以 `kubectl` 作为字段管理器应用到服务器端应用。 作为例外，可以指定一个不同的、非默认字段管理器停止这种行为，如下面的例子所示。 对于 kubectl 触发的服务器端应用，默认的字段管理器是 `kubectl`。

```bash
kubectl apply --server-side --field-manager=my-manager [--dry-run=server]
```

## API 端点

启用了服务器端应用特性之后， `PATCH` 服务端点接受额外的内容类型 `application/apply-patch+yaml`。 服务器端应用的用户就可以把 YAMl 格式的 部分定义对象（partially specified objects）发送到此端点。 当一个配置文件被应用时，它应该包含所有体现你意图的字段。

## 清除 ManagedFields

可以从对象中剥离所有 managedField， 实现方法是通过使用 `MergePatch`、 `StrategicMergePatch`、 `JSONPatch`、 `Update`、以及所有的非应用方式的操作来覆盖它。 这可以通过用空条目覆盖 managedFields 字段的方式实现。

```
PATCH /api/v1/namespaces/default/configmaps/example-cm
Content-Type: application/merge-patch+json
Accept: application/json
Data: {"metadata":{"managedFields": [{}]}}
PATCH /api/v1/namespaces/default/configmaps/example-cm
Content-Type: application/json-patch+json
Accept: application/json
Data: [{"op": "replace", "path": "/metadata/managedFields", "value": [{}]}]
```

这一操作将用只包含一个空条目的 list 覆写 managedFields， 来实现从对象中整个的去除 managedFields。 注意，只把 managedFields 设置为空 list 并不会重置字段。 这么做是有目的的，所以 managedFields 将永远不会被与该字段无关的客户删除。

在重置操作结合 managedFields 以外其他字段更改的场景中， 将导致 managedFields 首先被重置，其他改变被押后处理。 其结果是，应用者取得了同一个请求中所有字段的所有权。

> **注意：** 对于不接受资源对象类型的子资源（sub-resources）， 服务器端应用不能正确地跟踪其所有权。 如果你对这样的子资源使用服务器端应用，变更的字段将不会被跟踪。

## 禁用此功能

服务器端应用是一个 beta 版特性，默认启用。 要关闭此[特性门控](https://kubernetes.io/zh/docs/reference/command-line-tools-reference/feature-gates)， 你需要在启动 `kube-apiserver` 时包含参数 `--feature-gates ServerSideApply=false`。 如果你有多个 `kube-apiserver` 副本，他们都应该有相同的标记设置。