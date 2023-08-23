# 在 K8s 上构建端到端的无侵入开源可观测解决方案





Odigos(`https://github.com/keyval-dev/odigos`) 是一个开源的可观测性控制平面，允许企业创建和维护他们的可观测性管道，Odigos 允许应用程序在几分钟内提供追踪、指标和日志，重要的是**无需修改任何代码**，完全无任何侵入性。

![图片](https://mmbiz.qpic.cn/mmbiz_png/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZecf8ia9kwfCw2cHR9rCJBaI4Ym30EiaZy2GUos1KFjDhzuDrjickGDGYCg/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)

当你的应用程序在世界各地的数十个节点上的数百个 pod 上运行时，很难全面了解整个应用程序，对于需要跟踪、管理和优化这些环境的性能和可用性的团队来说，可观测性就成为了关键的工作任务。

如果整合得当，可观测性工具可以通过集中你的数据并提供对性能、使用情况和用户行为等关键指标提供更智能的洞察力来监控和排查问题，可观测性工具应支持你使用的语言和框架，与你的容器平台和你使用的其他工具轻松集成，包括任何通信或报警。问题是实施、维护和扩展是持续的任务，如果没有适当的执行和持续的配置，可观测性工具是有限的，很多时候还是无效的。

对于研发团队来说，在云上应用可观测性能力需要特定的技能组合，特别是考虑到向 OpenTelemetry & eBPF 的转变。企业必须确保他们能够在有限的、竞争激烈的人才库中获得特定的技能组合。学习 SDK、添加自动仪表（针对每种语言）、编写代码、部署和维护采集器--这些都需要大量的时间和知识，而大多数组织并不具备这些条件。

为了解决这些集成问题，一些大型的可观测性工具供应商提供自己的代理，提供他们自己的定制解决方案。这样做的问题是，通过使用专有格式摄取和存储数据的专有代理，但是会和这些供应商绑定在一起了。随着企业越来越多地寻求与开源标准的兼容性，以及跨部门共享和访问数据的能力，将数据锁定在一个独立的供应商中会阻碍这些努力并增加成本。

Odigos 可观测性控制平面提供了一个全面的、完全自动化的解决方案，使各组织能够在几分钟内建立他们的可观测性管道。Odigos 专注与第三方集成、开源、开放标准，以及整体上更加综合的方法，减少了结合多个可观测性软件平台和开源软件解决方案的复杂性。

Odigos 自动检测你集群中每个应用程序的编程语言，并相应地进行自动检测。对于已编译的语言（如 Go），使用 eBPF 来检测应用程序，对于虚拟机语言（如 Java）则使用 OpenTelemetry。此外，Odigos 创建的管道遵循最佳实践，例如：将 API 密钥持久化为 Kubernetes 的 Secret，使用最小的采集器镜像，等等。安装、配置和维护一个开源的、不可知的 Observabiity 控制平面的能力将使各种规模的组织有能力在任何时候采用适合他们的工具，并根据需要添加更多工具。

Odigos 使可观测性变得简单，人人都能使用。

## 使用

### 准备

接下来我们将安装一个 bank-of-athnos(`https://github.com/keyval-dev/bank-of-athnos`) 应用，这是一个由 Google 创建的银行应用程序示例，我们使用没有任何检测代码的修改版本来演示 Odigos 如何自动从应用程序收集可观察性数据。

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZeZKPmscQw294xrjVxXba2uYkSiaVia5hLeR91FMvg9aa9FHoS9s0x0kiaA/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&wx_co=1)

当然前提是需要一个 Kubernetes 集群，如果是在本地开发环境强烈推荐使用 kind 来创建一个测试集群，只需要使用名 `kind create cluster` 即可创建一个集群。有了集群后使用下面的命令部署测试应用即可：

```
kubectl apply -f https://raw.githubusercontent.com/keyval-dev/bank-of-athnos/main/release/kubernetes-manifests.yaml
```

在进入下一步之前，确保所有的 pod 都处于运行状态（可能需要一些时间）。

## 安装 Odigos

接下来我们需要先安装 Odigos，最简单的方式是使用 Helm Chart 进行安装：

```
helm repo add odigos https://keyval-dev.github.io/odigos-charts/
helm install my-odigos odigos/odigos --namespace odigos-system --create-namespace
```

在 `odigos-system` 命名空间中的所有 pod 运行后，通过运行以下命令可以打开 Odigos UI：

```
kubectl port-forward svc/odigos-ui 3000:3000 -n odigos-system
```

然后我们就可以在浏览器中通过 `http://localhost:3000` 访问 Odigos UI 了，正常可以看到如下所示的页面：

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZeV1Jam3AoDFLgK3icDw2M2LoYvZPHrBCPZ1FYwXyKLOo6MMWrBo7GNEQ/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&wx_co=1)

有两种方法可以选择 Odigos 应该使用哪些应用程序进行观测：

- `Opt out`（推荐）：检测所有程序，包括每一个将要部署的新应用，用户仍然可以手动标记不被检测的应用程序。
- `Opt in`：只对用户手动选择的应用程序进行检测。

这里我们就选择使用 `Opt out` 模式。

### 配置

接下来是告诉 Odigos 如何访问我们自己的可观测后端，Odigos 支持很多的后端服务：

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZeibnTQ06tQvVEXh7SYdWujHwiauZXGUIJOnwYkAdu5V1jR6rF7eAficHmw/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&wx_co=1)

比如我们这里选择自己托管的 Prometheus、Tempo、Loki 三个服务，当然也需要提前部署该 3 个服务：

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZeYpMukSXPiaVSkVbWrAicmbo5lOb1zjKxogPaR6dmdH8GpugIXiaKNrQ9A/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&wx_co=1)

添加以下三个目的地：

**Tempo**

- **Name**: tempo
- **URL**: http://observability-tempo.observability

**Prometheus**：要添加其他目的地，请从侧栏中选择目的地，然后单击添加新目的地

- **Name**: prometheus
- **URL**: http://observability-prometheus-server.observability

**Loki**

- **Name**: loki
- **URL**: http://observability-loki.observability

选择后等待几秒钟，让 Odigos 完成部署所需的采集器并对目标应用程序进行检测。你可以通过运行以下程序来监控进度

```
kubectl get pods -w
```

等待所有的 pods 都处于运行状态（特别是注意 `transactionservice` 应用程序，它的启动时间很慢）。最后我们就可以在 Grafana 中探索我们的可观测数据，我们现在可以看到并将指标与追踪和日志数据关联了起来。

同样可以通过运行端口转发到你的 Grafana 实例。

```
kubectl port-forward svc/observability-grafana -n observability 3100:80
```

并导航到 `http://localhost:3100`，输入 admin 作为用户名，对于密码，输入以下命令的输出：

```
kubectl get secret -n observability observability-grafana -o jsonpath=”{.data.admin-password}” | base64 --decode
```

### Service Graph

现在我们就可以查看微服务的 Service Graph 了。

1. 点击侧边栏的 `Explorer`
2. 选择 `Tempo` 作为数据源
3. 选择 `Service Graph` 标签
4. 点击 `Run query` 按钮开始查询

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZecxLwEaa5OZdjupnmCCqLpHTOCbyibxH7ynibcdl6xTsORxg98CicVQHKw/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&wx_co=1)

**指标**

接着我们可以查看一些指标，从 `service graph` 中点击 `contacts` 节点并选择 `Request rate`：

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZejzoYDzpskJ3SnyImBUCwX39IzibPyYMrIElpab8UOCgz8Jg66JZWz0Q/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&wx_co=1)

就会出现如下所示的一个非常熟悉的图表：

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZe8OvLnG6ochDaEv4JiaFSTIsvkFlPpwJ7P8F7EBg9jqXpmVuias8Oov0Q/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&wx_co=1)

还有很多 Odigos 收集的指标可以从 Prometheus 数据源轻松查询，请查看此文档(`https://odigos.io/docs/telemetry-types/`)以了解完整的清单 。

**追踪**

再次点击 Service Graph 中的 contacts 应用，但这次选择请求直方图，为了将指标和追踪联系起来，我们将使用一个叫做 `exemplars` 的功能，要显示 `exemplars`，按照如下步骤：

1. 打开 options 菜单
2. 打开 `exemplars`
3. 注意现在直方图上增加了绿色的菱形

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZeib24NCuLzXokMCiacEBVEKic2ibP6bXUXHia4TDuwllwpUs4KicuU3YuSjVQ/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&wx_co=1)

将鼠标悬停在其中一个添加的点上，点击 **Query With Tempo**，应该会出现类似于下面的追踪数据。

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZePiaIEpzCkKWGatYW6YO3qoblCcTS4AzFF7uhvyXt0iclIWekM2ganh1A/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&wx_co=1)

在此 trace 中，可以准确地看到整个请求的每个部分花费了多少时间，深入其中一个部分将显示其他信息，例如数据库查询。

**日志**

要进一步调查具体操作，可以简单地按下小文件图标查询相关日志。按平衡器旁边的文件图标，显示相关日志。

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/z9BgVMEm7YtVz67ibqVib9memUBpHMzpZekPRhzia6H5CeEkev76AXcWbIn1flIsX5jibibbMxIdlSXrloNdndRwILA/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&wx_co=1)

## 总结

我们已经展示了仅使用开源解决方案提取和传输日志、追踪和指标是多么容易。此外，我们还能够在几分钟内从一个应用程序中生成追踪、指标和日志数据，现在也有能力在不同的信号之间进行关联。可以将指标与追踪和追踪与日志相关联，现在拥有所有需要的数据来快速检测和修复目标应用中的生产问题。

![img](http://mmbiz.qpic.cn/mmbiz_png/z9BgVMEm7YtTw2oONBkwaiaM9hBxUj6yRLDEw8rSSxR8wWZFLjjXWpmGq5LNDlEAn4v9lSALDiaGfC4MyPZwL95g/0?wx_fmt=png)

