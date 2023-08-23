# 使用 eBPF 零代码修改绘制全景应用拓扑



本文为 DeepFlow 在首届云原生社区可观测性峰会上的演讲实录。**回看链接**[1]，**PPT下载**[2]。

很高兴有机会在第一届可观测性峰会上向大家介绍我们的产品 DeepFlow，我相信它会是今天 eBPF 含量最高的一个分享。DeepFlow 的能力很多，而我今天的分享会聚焦于一个点上说透，希望大家由此感知到 eBPF 带给可观测性的变革。那么我今天要分享的内容就是，**DeepFlow 如何利用 eBPF 技术，在不改代码、不改配置、不重启进程的前提下，自动绘制云原生应用的全景拓扑**。全景应用拓扑能解决我们很多问题：观测任意服务的全景依赖关系、观测整个应用的瓶颈路径、定位整个应用中的故障位置。

在开始之前，我大概也介绍一下自己的背景：从清华毕业以来，我一直在云杉网络工作，我们从 2016 年开始开发 DeepFlow，我们基于 eBPF 等创新技术打通云基础设施和云原生应用的全栈环节，零侵扰的实现应用的可观测性。今天的分享分为四个部分：第一部分介绍传统的解决方案如何绘制应用拓扑；第二部分介绍如何用 eBPF 完全零侵扰的实现应用拓扑的计算；第三部分介绍如何利用 eBPF 实现进程、资源、服务等标签的注入，使得开发、运维、运营都能从自己熟悉的视角查看这个拓扑；最后第四部分介绍一个全链路压测的 Demo 和我们在客户处的几个实战案例。

# 01

# 传统解决方案的问题

首先我们知道，在应用拓扑中，节点可以展示为不同的粒度，例如按服务、按实例、按应用等不同粒度展现。例如对于服务粒度，一个节点代表一个服务，它由多个实例组成。节点之间的连线代表调用关系，通常也对应了一系列的指标，表示服务之间调用的吞吐、异常、时延等性能。在云原生时代，云基础设施、微服务拆分等因素会带来很多挑战，导致绘制一个全景的应用拓扑变得非常艰难。

传统的解决方案我们很熟悉，通过埋点、插码的方式，修改代码来输出类似于 Span 的调用信息，通过聚合 Span 得到应用拓扑。即使是采用自动化的 Java 字节码注入等技术，虽然看起来不用改代码，但还是要修改启动参数，意味着服务要重新发布，至少要重启服务进程。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/x1ES4Jic395KwXiaDO3J7vPJREotfZoxibprDsXQGnibcbY2Ir1ydCeaWxHGmLib5Nmp6HxteWwOm6P4Eoqy3MLAstA/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)插码方案的困难 - 难以升级

在云原生场景下，使用这样的方法来获取应用拓扑变得更加困难。随着服务拆得越来越微小，每个服务的开发人员的自由度变得越来越大，因此可能会出现各种新奇的语言、框架。相对于 Java agent 而言，其他语言基本都会涉及到代码修改、重编译重发布。当然一般我们都会将这部分逻辑实现在一个 SDK 中，然而 SDK 的升级也是一个痛苦甚至绝望的过程，业务方都不愿意升级，升级意味着发版，发版可能就意味着故障。

那有方法能避免修改代码吗？云原生时代我们还有一个选项 —— 使用服务网格（Service Mesh）。例如 Istio 在 K8s 及非容器环境下可构建一个服务网络。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/x1ES4Jic395KwXiaDO3J7vPJREotfZoxibpXOKCSYUkdwHnNkWtBERnzZqcaft0wnUkzOoatic3GXHcDpSKUpYKQgA/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)网格方案的困难 - 难以全覆盖

但服务网格的问题在于并不能覆盖所有协议，例如 Istio 主要覆盖 HTTP/gRPC，而其他大量各种各样的 Protobuf/Thrift RPC，以及 MySQL/Redis/Kafka/MQTT 等中间件访问都无法覆盖到。另外从因果关系来讲，我们可以因为选择了服务网格而顺带实现一部分可观测性，但肯定不会因为要去实现可观测性而引入服务网格这样一个带有侵入性的技术。

除此之外，在云原生时代，即使我们去改业务代码、上服务网格，仍然无法获取到一个完整的应用拓扑。比如云基础设施中的 Open vSwitch，K8s 中的 IPVS，Ingress 位置的 Nginx 网关，这些都是看不到的。

下面出场的就是我们今天要讲的主角，eBPF，它是一个非常火热的新技术。我们来看看它是不是能解决我们今天聚焦的问题，能否将应用拓扑画全、画准，能为开发、运维等不同团队的人提供一个统一的视图，消除他们的 Gap。我们知道 eBPF 有很多很好的特性，它不需要业务改代码、不需要服务修改启动参数、不需要重启服务进程，它是编程语言无关的，而且能覆盖到云基础设施和云原生应用的整个技术栈。DeepFlow 基于 eBPF 技术也享受到了很多这方面的红利，我们的客户做 POC、社区的用户试用都非常丝滑，不用去考虑运维窗口、实施周期，**DeepFlow 的社区版只需一条命令，五分钟即可开启全景、全栈的可观测性**。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/x1ES4Jic395KwXiaDO3J7vPJREotfZoxibpfe3etf62N4cKgMbzp7Escib4N5jg24yicjAEN6V4QLrezS2I4zz2X7Vg/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)DeepFlow 软件架构

这里也用一页 PPT 来简单介绍一下 **DeepFlow 社区版的软件架构**。我们开源至今还不到一年，目前在社区受到了不少关注。上图中间蓝色的部分是 DeepFlow 的两个主要组件：Agent 负责采集数据，利用 eBPF 的零侵扰特性，覆盖各种各样的云原生技术栈；Server 负责富化数据，将标签与数据关联，并存储至实时数仓中。在北向，DeepFlow 提供 SQL、PromQL、OTLP 等接口，通过 DeepFlow 自己的 GUI 展现所有可观测性数据，也兼容 Grafana、Prometheus、OpenTelemetry Collector 等生态。在南向，DeepFlow 可集成 Prometheus 等指标数据、SkyWalking 等追踪数据、Pyrosope 等 Profile 数据。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/x1ES4Jic395KwXiaDO3J7vPJREotfZoxibp7fmOJtJlx1kawhEPGEQ7JJ1xs1rKibz89buKaehDsYEn4KHfK07Urew/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)AutoTracing + AutoTagging

今天我们要聚焦的一点，就是 DeepFlow 如何使用 eBPF 生成全景应用拓扑。DeepFlow 的两个核心能力 **AutoTracing** 和 **AutoTagging** 为应用拓扑的生成奠定了坚实的基础。在没有任何代码修改、不重启任何业务进程的情况下，我们实现了全景应用拓扑的绘制。首先，我们可通过 eBPF 从网络包、内核 Socket Data 中获取原始比特流；接下来我们分析 Raw Data 中的 IP、端口等信息，使用 eBPF 将原始数据与进程、资源、服务等信息关联，以便绘制不同团队不同视角的应用拓扑，这也是今天分享的第三部分；然后我们会从原始数据中提取应用调用协议，聚合调用中的请求和响应，计算调用的吞吐、时延和异常，以及其他系统和网络性能指标；最后，基于这类 Request Scope 的 Span 数据，我们可以聚合生成全景应用拓扑，也可以通过关联关系的计算生成分布式追踪火焰图。

今天我们主要讲的是应用拓扑的绘制，对于使用 eBPF 实现全自动的分布式追踪这个话题，DeepFlow 社区的博客 *https://deepflow.io/blog* 上有很多资料。

# 02

# eBPF 零侵扰计算全景应用拓扑

![图片](data:image/svg+xml,%3C%3Fxml version='1.0' encoding='UTF-8'%3F%3E%3Csvg width='1px' height='1px' viewBox='0 0 1 1' version='1.1' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'%3E%3Ctitle%3E%3C/title%3E%3Cg stroke='none' stroke-width='1' fill='none' fill-rule='evenodd' fill-opacity='0'%3E%3Cg transform='translate(-249.000000, -126.000000)' fill='%23FFFFFF'%3E%3Crect x='249' y='126' width='1' height='1'%3E%3C/rect%3E%3C/g%3E%3C/g%3E%3C/svg%3E)Universal Application Topology

首先让我们看一个效果图，这是 DeepFlow 展示的一个全景应用拓扑。这个拓扑可能大家比较熟悉，它是 OpenTelemetry 的一个 Demo，它 Fork 自 Google Cloud Platform 的一个项目，它是一个小型的电商应用。从图中可以看到，DeepFlow 可以获取所有服务之间的调用关系以及相应的性能指标，这都是通过 eBPF 实现的，没有做任何的代码修改和进程重启，展现这些结果之前我们关闭了所有 OTel Instrumentation。

在这一节，我们将聚焦四个问题：**第一个问题是如何采集原始数据；第二个问题是如何解析应用协议，eBPF做了什么；第三个问题是如何计算全栈性能指标；第四个问题是如何适配低版本内核**，许多用户的内核版本可能是3.10。

**数据采集**：DeepFlow 同时用到了 eBPF 和它的前身，有 30 年历史的 Classic BPF（cBPF）。在云原生环境中，应用进程运行在容器 Pod 内，容器可能存在于多个节点上，并通过网关连接到数据库等其他服务。我们可以使用 eBPF 技术来覆盖所有的端节点，并使用 cBPF 覆盖所有的中间转发节点。从应用进程（端节点）层面，我们使用 kprobe 和 tracepoint 覆盖所有的 TCP/UDP socket 读写操作；并使用 uprobe 来挂载到应用程序内的核心函数上，比如 OpenSSL/Golang 的 TLS/SSL 函数，来获取加密或压缩之前的数据。除此之外，在两个服务之间还有许多中间转发路径，例如 IPVS、iptables、OvS 等，此时需要使用 cBPF 来获取网络包数据，因为这部分流量不会有用户态应用程序去读写，会直接在内核里查表转发。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/x1ES4Jic395KwXiaDO3J7vPJREotfZoxibpMkWczeQdvD9jP9aJ6vtTl1kfaZ1MGFGvia12H3wI8MmLhibcMyIXSKXw/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)eBPF Probes

这里列举了 DeepFlow 中主要使用到的 eBPF Probe，包括最左边的 kprobe，以及中间最高性能的 tracepoint，以及最右边解决加密和压缩数据的 uprobe。其中 tracepoint 满足了 DeepFlow 中的绝大多数需求。

**协议解析**：在获取原始数据方面，我们使用 eBPF 和 cBPF 来捕获字节流，但此时我们无法看到任何可理解的信息。接下来，我们要做的就是从这些字节流中提取出我们关心的应用协议。大多数协议都是明文的，例如 HTTP、RPC、SQL 等，我们可以直接遵照协议规范来解析它们的内容。对于一些特殊的协议，例如 HTTP2 之类的压缩协议，我们需要进行更复杂的处理。我们可以使用 tracepoint 或 kprobe 来提取未压缩的字段，但此时对于已经压缩的头部字段，还原它们是一项困难的工作，因此我们会选择使用 uprobe 作为补充来采集压缩协议的数据。另外对于加密流量也无法从内核函数中获取明文，我们通过 uprobe 直接获取加密之前的数据。最后，对于私有协议，它们没有可遵循的通用规范，或者虽然遵循了 Protobuf/Thrift 等标准但无法提供协议定义文件，此时我们提供了基于 WASM 的插件化的可编程接口，在未来也有计划提供基于 LUA 的插件机制。

在协议解析层面还需要考虑的一个事情是流重组。例如一个 HTTP2/gRPC 请求的头部字段可能会分为多次系统调用读写，或者分拆为多个网络包收发，此时我们需要还原完整请求或响应头，一遍重组一遍尝试解析。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/x1ES4Jic395KwXiaDO3J7vPJREotfZoxibpTG49so1uZ43eguvZM61GuY0h7QAInibyNibOyJnJBs8uAes3HYYFkYqQ/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)eBPF + WASM

特别提一下我们对私有协议的识别，通过结合 eBPF 和 WebAssembly 的能力，提供一个灵活的插件机制。**插件在 DeepFlow 中解决两个问题：提供对私有协议的解析能力、提供对任意协议的业务字段解析能力**。商用软件供应商或业务开发人员可以轻松添加自定义插件来解析协议，将可观测性从 IT 层面提升到业务层面。这样的方式使得我们可以自定义提取出一些业务指标或业务标签，例如订单量、用户 ID、交易 ID、车机 ID 等信息。这些业务信息对于不同的业务场景都是独特的，我们将这个灵活性给到了业务方，使得业务方可以快速实现零侵扰的可观测性。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/x1ES4Jic395KwXiaDO3J7vPJREotfZoxibpGN7vVqFPuuWuDtpJyOMR7Fg2eeB9mVQk66BInwRM4qfctYSf9DxT4g/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)RED Metrics

**性能指标**：我们可以通过数请求和响应的个数来获取吞吐量，同时还可以根据响应状态码、耗时等信息计算 Error 和 Delay 指标。吞吐和异常的计算相对简单，只需要基于单个请求或单个响应进行处理即可。最困难的是对时延的计算，我们需要使用 eBPF 技术来关联请求和响应这两个动作。这个过程又分为两步：从 Socket/Packet Data 中基于 `<sip, dip, sport, dport, protocol>` 五元组聚合出 TCP/UDP Flow；然后在 Flow 上下文中匹配应用协议的每一个 Request 和 Response。而对于第二步，一个 Flow 中一般会有多个请求和响应，匹配逻辑我们以 HTTP 协议为例解释：

- 对于串行协议如 HTTP 1.0，直接匹配临近的请求和响应即可
- 对于并发协议如 HTTP 2.0，需要提取协议头中的 StreamID 进行请求和响应的配对
- 还有一种特殊情况即 HTTP 1.1 中的管道机制，他是一种伪并发协议，我们可以利用它的 FIFO 特点完成请求和响应的配对

![图片](data:image/svg+xml,%3C%3Fxml version='1.0' encoding='UTF-8'%3F%3E%3Csvg width='1px' height='1px' viewBox='0 0 1 1' version='1.1' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'%3E%3Ctitle%3E%3C/title%3E%3Cg stroke='none' stroke-width='1' fill='none' fill-rule='evenodd' fill-opacity='0'%3E%3Cg transform='translate(-249.000000, -126.000000)' fill='%23FFFFFF'%3E%3Crect x='249' y='126' width='1' height='1'%3E%3C/rect%3E%3C/g%3E%3C/g%3E%3C/svg%3E)Network Metrics

但是，在云原生环境下，仅仅只统计应用层 RED 往往不够。例如我们会发现**客户端侧看到的时延是 3 秒，而服务端侧看到的时延是 3 毫秒；或者客户端和服务端侧都看不到有请求，但下游服务却报错了**。针对这些场景，我们基于 Flow 数据计算得到了网络层面的吞吐、异常、时延。业务开发发现时延高时，可以快速查看网络层时延来判断到底是业务自身的问题还是基础设施问题；另外在发现请求报错时可以快速查看是否建连或者传输异常了。

针对时延我们分的更细致，通过从 Packet Data 中重建 TCP 状态机来更加精细的展现各个层面引入的时延。在生产环境中我们会发现高时延的原因一般分为几个方面：

- **建连慢**：由于防火墙、负载均衡、网关的影响，导致 TCP 建连过程慢，这一过程又进一步拆分为了到底是客户侧建连慢还是服务侧建连慢
- **框架慢**：由于业务代码在建连后的慢处理，客户端在建连后等待了一段时间才发送请求，这段等待时间我们会刻画为客户端等待时延，它能够方面定位到底是框架/库层面的问题，还是业务代码的问题
- **系统慢**：由于操作系统处理不及时，例如系统负载高等，对请求的 TCP ACK 回复慢，从而导致 TCP 无法高效增大窗口大小
- **传输慢**：网络重传、零窗等也是导致高时延的一些可能原因

在云原生环境下，还有一个特点是网络路径非常长，例如两个服务之间的通信可能依次经过容器 Pod 网卡、容器 Node 网卡、KVM 主机网卡等。路径的复杂性也是引发**传输慢**的主要原因。由于 DeepFlow 同时使用 cBPF，因此可以从所有中间转发路径中观测到应用层和网络层的时延，然后通过对比逐跳时延来定位到底是哪一跳开始出现了问题。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/x1ES4Jic395KwXiaDO3J7vPJREotfZoxibpFCnsehT1fVhyjcS5sxicWMaBgPDTUY8BU3Pfltau5eicNkBJDuUcmoZQ/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)System Metrics

除了网络层面以外，造成慢调用的还有一个重要原因是 IO 慢。例如 Client 访问 DB 时可能出现时延抖动，而这些抖动通常是由 DB 的文件读写慢导致。再例如大数据场景下一批 Worker 中可能总有那么一两个 Worker 完成的慢，排查后会发现通常是由于文件读写慢导致。这里 DeepFlow 的做法是观测所有与应用调用相关的 IO 时延，并记录所有的慢 IO 事件。实现层面，文件 IO 与 Socket IO 事件可通过 tracepoint/kprobe hook 同样一组函数获取到，通过 FD 的类型可以进行区分。依靠这样的能力，我们能快速的定位到 deepflow-server 写入 clickhouse-server 偶发性慢是由于文件 IO 时延抖动造成，且能定位到具体的文件路径。

**低版内核**：最后我们总结一下本节。我们希望在低版本内核中 DeepFlow 也能展现更多的能力。以 Kernel 4.14 为界，DeepFlow 在 4.14+ 的环境下可以基于 eBPF 实现全功能，包括加密数据的观测、应用进程的性能指标、系统层面文件 IO 性能指标，以及全自动的分布式追踪能力。而在 4.14 以下的内核环境中，我们基于 cBPF 也实现了大部分的能力，包括对于明文协议、私有协议的观测，对于压缩协议部分头部字段的观测，以及对于应用性能、网络性能指标的采集，对于性能指标的全栈路径追踪。

# 03

# eBPF 自动关联服务和资源标签

讲到这里实际上我们整个目标只完成了一半。我们从原始数据中提取出来了指标、调用关系、调用链，但还需要以开发者熟悉的方式展现出来。Packet 和 Socket Data 中只有 IP 和端口号信息，这是开发和运维都无法理解的。我们希望所有的数据都能从实例、服务、业务等维度按需展示。

在这个问题上我们也遇到了一些挑战：我会先介绍从哪里采集标签，以及采集什么样的标签；然后讨论轮询采集的方式会带来哪些问题；接下来我会介绍一下基于 eBPF 的事件触发的方案，来避免轮询的缺陷；最后同样的也会介绍一下我们在低版本内核环境下的一些能力。

**标签数据**：首先仅通过 IP 地址是不能完整关联客户端和服务端的服务信息的，这是因为实际环境中普遍存在 NAT，包括 SNAT、DNAT、FULLNAT 等。实际上通过单侧的 IP+Port 也难以准确关联，这是因为 Client Port Reuse 也是一个普遍存在的现象。因此，在 DeepFlow 中使用五元组来将通信端点关联至服务。具体来讲，我们会通过 K8s apiserver 获取 IP 对应的容器资源标签；通过 CMDB 及脚本化的插件获取 PID 对应的业务标签信息；然后再依靠下面要讲的一些机制将 IP+Port 的五元组与 PID 关联起来，最终实现资源、服务、业务标签的自动注入。

**轮询方案**：我们首先能想到的是通过轮询 `/proc/pid/net/` 文件夹来获取 PID 与 Socket 五元组的关联。每个 agent 获取本机的关联信息，并通过 server 交换得到全局的关联信息，从而使得每个 agent 能独立的为客户端和服务端标注双端的 PID 信息。

轮询方案也会碰到一些挑战，例如 LVS 场景下，`/proc` 下的 Socket 信息指向的是 LVS，但从业务上来讲我们希望获取 LVS 背后的 RS 的进程信息。DeepFlow 通过同步 LVS 转发规则解决这个问题。具体来讲，基于 LVS 规则和包头中嵌入的 TOA（TCP Option Address）字段，可以快速的在 RS 上定位客户端的 PID，并通过 LVS 转发规则快速的在客户端侧定位服务端的 PID。

**触发方案**：当时轮询总会存在时间间隔，因此永远无法解决短连接的监控问题。在这方面 DeepFlow 也做了一些工作，这就是下面我们要介绍的触发式方案。

受 TOA 的启发，我们基于 eBPF 实现了一个 TOT（TCP Option Tracing）的机制，即在 TCP 包头 Option 字段中嵌入额外的信息，表示发送方的 IP 和 PID。这样的话我们就能将源发的进程信息告知对端了。为了实现这样的机制，我们使用 eBPF sockops 和 tracepoint，一共 Hook 了五个函数。我们会在每个 TCP SYN、SYN-ACK 包中注入 TOT 信息，使得连接新建时即能标记进程信息。同时也会概率性的抽取 TCP PSH 包注入 TOT，使得对于长连接，即使 agent 的启动时间滞后于业务进程，也能及时获取到进程信息。

**低版内核**：同样这里也分享一下我们在低版本内核上做的一些工作。首先轮询的方案依靠扫描 `/proc` 文件夹实现，因此是能适配所有 2.6+ 的内核环境的。在 3.10 及以上的内核中，我们也提供了一个精巧的 ko 模块来实现 TOT 的注入，这个内核模块仅有 227 行代码，我们也进行了开源，欢迎大家使用。

# 04

# Demo - 持续观测全链路压测性能瓶颈

![图片](data:image/svg+xml,%3C%3Fxml version='1.0' encoding='UTF-8'%3F%3E%3Csvg width='1px' height='1px' viewBox='0 0 1 1' version='1.1' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'%3E%3Ctitle%3E%3C/title%3E%3Cg stroke='none' stroke-width='1' fill='none' fill-rule='evenodd' fill-opacity='0'%3E%3Cg transform='translate(-249.000000, -126.000000)' fill='%23FFFFFF'%3E%3Crect x='249' y='126' width='1' height='1'%3E%3C/rect%3E%3C/g%3E%3C/g%3E%3C/svg%3E)OTel Demo

最后通过一个 Demo 介绍一下这些工作的效果。我们仍然是以 OTel 的电商 Demo 为例，仍然是关闭了其中的所有 OTel Instrumentation。选择这个 Demo 的理由在于，他是一个典型的微服务架构的应用，且尽力模拟了比较真实的电商场景，微服务的实现语言涵盖了十二种之多，也包含了 PostgreSQL、Redis、Kafka、Envoy 等中间件。

首先我们可以看到，不修改代码、不修改启动参数、不重启进程，我们已经能自动绘制微服务粒度的全景应用。当我们注入一个 1.5K QPS 的压力时，能清晰的在拓扑中看到瓶颈链路。沿着 frontend 服务一路往下，也能快速的定位瓶颈服务 ProductCatalog。接下来我们分为三次，分别将 ProductCatalog 扩容至 2x、4x、8x 副本数，扩容的过程中也可清晰的看到瓶颈链路在逐渐消失，知道最终所有服务的时延恢复正常。

除了这个 Demo 以外，这里也**分享几个我们在客户处的实战案例**：

- 某造车新势力客户，使用 DeepFlow 从数万 Pod 中在 5 分钟内定位 RDS 访问量最大的 Pod、所属服务、负责该服务的团队。
- 某股份制银行客户，信用卡核心业务上线受阻，压测性能上不去，使用 DeepFlow 在 5 分钟内发现两个服务之间 API 网关是性能瓶颈，进而发现缓存设置不合理。
- 某互联网客户，使用 DeepFlow 在 5 分钟内定位服务间 K8s CNI 性能瓶颈，识别由于环路造成的某个服务上下云访问时延周期性飙升的问题，云厂商两周无解。
- 某证券客户，使用 DeepFlow 在 5 分钟内定位 ARP 故障导致 Pod 无法上线的问题，「瞬间」结束业务、系统、网络多部门「会商」。
- 某基础设施软件客户，使用 DeepFlow 在 5 分钟内定位 Rust 客户端使用 Tokio 不合理导致的 gRPC 偶发性超大时延，终结了 QA 及多个开发团队之间踢来踢去的 Bug。
- 某四大行客户，使用 DeepFlow 在 5 分钟内定位某个 NFVGW 实例对特定服务流量不转发导致的客户端频繁重试。

从这些案例中我们能发现，依靠 eBPF 技术的零侵扰特性，我们能完整的覆盖应用的全景调用拓扑，且能展现任意调用路径中的全栈性能指标。得益于这些可观测性能力，我们能快速的定位 RDS、API 网关、K8s CNI、ARP 故障、Rust Tokio 库、NFVGW 造成的故障。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/x1ES4Jic395KwXiaDO3J7vPJREotfZoxibpGtBVK51oxPe6fpuDlZ0gVkEEbnV8ibhtdMDPfdItLyu7XBatfMMTXjw/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)Distributed Profile

这是最后一张PPT，我想和大家分享一下 DeepFlow 对可观测性的更多思考。在传统 APM 中，我们通常使用 Span 之间的关联关系以火焰图的方式展现一次分布式调用（Trace），也会讲所有的 Span 聚合为指标来展现所有服务之间的应用拓扑。我们发现拓扑展现了所有调用的数据，而追踪展现了一个调用的数据，它们二者恰恰是取了两个极端。DeepFlow 目前正在探索，中间是否有一个折中的点，他们展示一组聚合的火焰图或拓扑图，有点类似于单个进程的 Profile，但是用于分布式应用的场景，我们称它为 `Distributed Profile`。我们相信这样的折中会带来效率的提升，它不香所有调用聚合而成的拓扑，会有太多噪声；也不像单一请求展示出来的 Trace，问题排查需要一个一个 Trace 的看。

而 eBPF，正是绝佳的实现 `Distributed Profile` 的技术手段，请期待后续我们进一步的分享。

# 05

# 什么是 DeepFlow

**DeepFlow**[3] 是一款开源的高度自动化的可观测性平台，是为云原生应用开发者建设可观测性能力而量身打造的全栈、全链路、高性能数据引擎。DeepFlow 使用 eBPF、WASM、OpenTelemetry 等新技术，创新的实现了 AutoTracing、AutoMetrics、AutoTagging、SmartEncoding 等核心机制，帮助开发者提升埋点插码的自动化水平，降低可观测性平台的运维复杂度。利用 DeepFlow 的可编程能力和开放接口，开发者可以快速将其融入到自己的可观测性技术栈中。

**GitHub 地址：**https://github.com/deepflowio/deepflow

访问 **DeepFlow Demo**[4]，体验高度自动化的可观测性新时代。

### 参考资料

[1]

回看链接: *https://www.bilibili.com/video/BV1B14y1f7UB/*

[2]

PPT下载: *http://yunshan-guangzhou.oss-cn-beijing.aliyuncs.com/yunshan-ticket/pdf/1a1847b242ae7c16d53f0af31d9c6aa4_20230509140119.pdf*

[3]

DeepFlow: *https://github.com/deepflowio/deepflow*

[4]

DeepFlow Demo: *https://deepflow.yunshan.net/docs/zh/install/overview/*





Grafana URL: http://8.218.199.129:31892/?orgId=1

Grafana auth: admin:deepflow