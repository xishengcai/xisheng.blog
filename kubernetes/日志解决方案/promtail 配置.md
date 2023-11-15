# Promtail 配置

[toc]



## 1. 概述

Promtail是一个Agent，用于将本地日志内容发送到Loki。通常，它部署在需要监控的每台机器上。

其主要功能包括：

1. 发现目标：Promtail能够主动探测并发现需要监控的目标。
2. 为日志流添加标签：Promtail可以给日志流附加标签，以便更好地进行过滤和查询。
3. 将日志推送至Loki：Promtail将处理后的日志推送到Loki中进行存储和分析。

目前，Promtail可以从两个来源获取日志：本地日志文件和systemd journal日志（仅适用于AMD64架构的机器）。



### 2.1 日志文件发现

在Promtail能够将日志文件的数据发送到Loki之前，它需要获取有关其环境的信息。具体来说，这意味着发现将日志行发送到需要监控的文件的应用程序。

Promtail使用了与Prometheus相同的服务发现机制，尽管目前它仅支持静态和Kubernetes服务发现。这个限制是因为Promtail作为一个守护程序部署在每台本地机器上，并且无法从其他机器上发现标签。Kubernetes服务发现从Kubernetes API服务器获取所需的标签，而静态服务发现通常涵盖其他所有用例。

与Prometheus一样，Promtail使用`scrape_configs`配置段进行配置。通过`relabel_configs`，可以对要获取的内容、要丢弃的内容以及要附加到日志行的最终元数据进行精细控制。有关配置Promtail的详细信息，请参考[文档](https://grafana.com/docs/loki/latest/clients/promtail/configuration/)。

#### 2.1.1 支持获取压缩文件

Promtail支持获取压缩文件。如果发现的目标已配置了解压缩，Promtail将延迟(lazy)地解压缩压缩文件并将解析后的数据推送到Loki。下面是一个示例的Promtail配置，展示如何设置解压缩：

```yaml
 1server:
 2  http_listen_port: 9080
 3  grpc_listen_port: 0
 4positions:
 5  filename: /var/lib/promtail/positions.yaml
 6clients:
 7  - url: http://localhost:3100/loki/api/v1/push
 8scrape_configs:
 9- job_name: system
10  decompression:
11    enabled: true
12    initial_sleep: 10s
13    format: gz
14  static_configs:
15  - targets:
16      - localhost
17    labels:
18      job: varlogs
19      __path__: /var/log/**.gz
```

在上面的配置中，我们使用了`decompress` pipeline stage来配置解压缩。`__path__`标签指定了压缩文件的路径，而`regex`用于匹配压缩文件的正则表达式。在解压缩阶段后，可以进一步添加其他的pipeline stages进行数据处理和标签添加。

请注意，上述示例仅供参考，请根据实际情况进行相应的配置。更多关于配置Promtail的详细信息，请参考相关文档。

重要细节如下：

- Promtail依赖于"`\n`“字符将数据分隔为不同的日志行。
- 压缩文件中的最大日志行大小为`2MB`字节。
- 数据以4096字节的块进行解压缩。例如：首先从压缩文件中获取一个4096字节的块并进行处理。处理完这个块并将数据推送到Loki后，再获取下一个4096字节的块，依此类推。
- Promtail支持以下扩展名：
  - `.gz`：使用原生的Golang Gunzip包（`pkg/compress/gzip`）进行解压缩。
  - `.z`：使用原生的Golang Zlib包（`pkg/compress/zlib`）进行解压缩。
  - `.bz2`：使用原生的Golang Bzip2包（`pkg/compress/bzip2`）进行解压缩。
  - `.tar.gz`：与`.gz`扩展名完全相同进行解压缩。然而，由于tar会在压缩文件开头添加元数据，因此第一行解析的数据将包含元数据和日志行。具体示例可参考`./clients/pkg/promtail/targets/file/decompresser_test.go`文件。
  - 目前不支持.zip扩展名，因为它不支持Promtail所需的某些接口。Promtail计划在不久的将来添加对它的支持。
- 解压缩过程对CPU的要求较高，并且可能会产生大量的内存分配，特别是根据文件的大小而定。您可以预期垃圾回收运行次数和CPU使用率会大幅上升，但不会出现内存泄漏。
- 支持记录位置。这意味着，如果在解析和推送（例如）压缩文件数据的45%之后中断Promtail，您可以预期Promtail将从上次解析的行重新开始工作，并处理剩余的55%。
- 由于解压缩和推送速度可能非常快，根据压缩文件的大小，Loki可能会对提取(ingestion)进行限制。在这种情况下，您可以配置Promtail的[limits stage](https://grafana.com/docs/loki/latest/clients/promtail/stages/limit/)以减缓速度或增加Loki的[ingestion limits](https://grafana.com/docs/loki/latest/configuration/#limits_config)。
- 目前不支持日志轮转(Log rotations)，主要是因为它要求改Promtail以依赖文件的inode而不是文件名。如果你希望看到对其的支持，请在Github上创建一个新的issue，请求支持并解释你的用例。
- 如果你在正在被抓取的文件夹下压缩文件，Promtail可能会在您完成压缩之前尝试提取文件。为了避免这种情况，选择足够长的`initial_delay`来避免冲突。
- 如果你希望看到不在此列表中的压缩协议的支持，请在Github上创建一个新的issue，请求支持并解释您的用例。

### 2.2 Loki Push API

Promtail还可以通过暴露[Loki的推送API](https://grafana.com/docs/loki/latest/api/#push-log-entries-to-loki)（[`loki_push_api`](https://grafana.com/docs/loki/latest/clients/promtail/configuration/#loki_push_api)）来配置接收来自另一个Promtail或任何Loki客户端的日志。

以下几种情况下可能会有所帮助：

1. 复杂的网络基础设施，不希望许多机器都有出口(egress)。
2. 使用Docker Logging Driver并希望提供复杂的管道或从日志中提取指标。
3. 无服务器(serverless)中，许多临时日志源希望发送到Loki。将其发送到具有`use_incoming_timestamp == false`的Promtail实例可以避免乱序错误，并避免使用高基数标签。

### 2.3 接收来自Syslog的日志

当使用[Syslog Target](https://grafana.com/docs/loki/latest/clients/promtail/configuration/#syslog)时，日志可以用syslog协议写入配置的端口。

### 2.4 标签和解析

在服务发现过程中，会确定元数据（如 Pod 名称、文件名等），可以将其作为标签附加到日志行上，以便在查询Loki日志时更容易进行识别。通过`relabel_configs`，可以将发现的标签改变成所需的形式。

为了在之后进行更复杂的过滤，Promtail允许根据每个日志行的内容设置标签，而不仅仅是从服务发现中获取。可以使用`pipeline_stages`来添加或更新标签、修正时间戳或完全重写日志行。有关pipeline的更多详细信息，请参阅[文档](https://grafana.com/docs/loki/latest/clients/promtail/pipelines/)。

### 2.5 日志传送(Shipping)

一旦Promtail设置好了目标（例如要读取的文件）并且所有标签都正确设置，它将开始从目标中持续读取（tail）日志。一旦读取到足够的数据或在可配置的超时时间后，将作为一个批次（batch）将数据刷新到Loki。

当Promtail从源（如文件和systemd日志，如果配置了）读取数据时，它会在一个位置文件中跟踪它读取的最后偏移量。默认情况下，位置文件存储在 `/var/log/positions.yaml`。位置文件有助于在Promtail实例重新启动时从离开的位置继续读取。

### 2.6 API

Promtail具有嵌入式Web服务器，在根路径（/）下暴露一个Web控制台以及以下API端点：

```fallback
1GET /ready
```

此端点在Promtail正常运行且至少有一个可用的目标时返回200。

```fallback
1GET /metrics
```

此端点返回Promtail的Prometheus指标。请参考[Observing Grafana Loki](https://grafana.com/docs/loki/latest/operations/observability/)获取exproter的metrics。

Promtail的Web服务器可以在Promtail的yaml配置文件中进行配置：

```yaml
1server:
2  http_listen_address: 127.0.0.1
3  http_listen_port: 9080
```

## 3.Promtail的配置

Promtail的配置文件是一个YAML文件（通常称为config.yaml），其中包含有关Promtail服务器、位置文件的存储方式以及如何从文件中抓取日志的信息。

### 3.1 在运行时打印Promtail的配置

如果递给Promtail命令行参数`-print-config-stderr`或`-log-config-reverse-order`（或`-print-config-stderr=true`），Promtail将会打印出它从内置默认值中创建的整个配置对象，首先与配置文件中的覆盖值组合，然后再与命令行参数中的覆盖值组合。

结果是Promtail配置结构体(struct)中每个配置对象的值。

某些值可能与您的安装不相关，这是正常的，因为每个选项都有一个默认值，无论是否使用它。

此配置是Promtail用于运行的配置，对于调试与配置相关的问题非常有价值，并且在确保配置文件和命令行参数被正确读取和加载时特别有用。

当直接运行Promtail时（例如./promtail），`-print-config-stderr`很方便，因为可以快速输出整个Promtail配置。

`-log-config-reverse-order`是我们在所有环境中运行Promtail时使用的标志，配置条目被反转，以便在Grafana的Explore中查看时，配置顺序从上到下正确显示。

### 3.2 配置文件参考

为了指定要加载的配置文件，请在命令行中传递`-config.file`标志。该文件以YAML格式编写，其架构定义如下。方括号表示参数是可选的。对于非列表参数，值将设置为指定的默认值。

有关配置如何发现和抓取目标日志的更详细信息，请参阅”[Scraping](https://grafana.com/docs/loki/latest/clients/promtail/scraping/)"。有关从抓取的目标中转换日志的更多信息，请参阅"[Pipelines](https://grafana.com/docs/loki/latest/clients/promtail/pipelines/)"。

#### 3.2.1 在配置文件中使用环境变量

在配置文件中可以使用环境变量引用来设置在部署过程中需要配置的值。要实现这一点，传递`-config.expand-env=true`并使用以下方式：

```fallback
1${VAR}
```

上面VAR是环境变量的名称。

每个变量引用在启动时都会被环境变量的值替换。替换是区分大小写的，并在解析YAML文件之前进行。对未定义的变量的引用将被替换为空字符串，除非您指定了默认值或自定义错误文本。

使用下面的方式指定默认值:

```fallback
1${VAR:-default_value}
```

其中，`default_value`是在环境变量未定义时使用的值。

> 注意：使用`expand-env=true`时，配置文件首先会通过`envsubst`进行处理，它会将双斜杠替换为单斜杠。因此，每次使用斜杠`\`时都需要将其替换为双斜杠`\\`。

#### 3.2.2 通用占位符

通用占位符:

- `<boolean>`: 一个布尔值，可以取值true或false
- `<int>`: 任何符合正则表达式[1-9]+[0-9]*的整数
- `<duration>`: 一个符合正则表达式[0-9]+(ms|[smhdwy])的持续时间
- `<labelname>`: 一个符合正则表达式[a-zA-Z_][a-zA-Z0-9_]*的字符串
- `<labelvalue>`: 一个由Unicode字符组成的字符串
- `<filename>`: 一个相对于当前工作目录的有效路径或绝对路径
- `<host>`: 一个有效的字符串，由主机名或IP地址后跟可选的端口号组成
- `<string>`: 一个字符串
- `<secret>`: 代表密钥（如密码）的字符串

#### 3.2.3 config.yaml支持的配置项及其默认值

```yaml
 1# 配置Promtail服务器。
 2[server: <server_config>]
 3
 4# 描述Promtail如何连接到多个Loki实例，并将日志发送到每个实例。
 5# 警告：如果其中一个远程Loki服务器无法响应或响应任何可重试的错误，这将影响发送日志到任何其他配置的远程Loki服务器。发送操作在单个线程上执行！
 6# 通常建议同时运行多个Promtail客户端，以并行发送到多个远程Loki实例。
 7clients:
 8  - [<client_config>]
 9
10# 描述如何将读取的文件偏移保存到磁盘上。
11[positions: <position_config>]
12
13scrape_configs:
14  - [<scrape_config>]
15
16# 为此Promtail实例配置全局限制。
17[limits_config: <limits_config>]
18
19# 配置如何监视监控目标。
20[target_config: <target_config>]
21
22# Promtail的其他配置。
23[options: <options_config>]
24
25# 配置追踪支持
26[tracing: <tracing_config>]
```

### 3.3 server配置

以下是关于 `server`块配置的说明，用于配置Promtail作为HTTP服务器的行为：

```yaml
 1# 禁用 HTTP 和 GRPC 服务器。
 2[disable: <boolean> | 默认值 = false]
 3
 4# 启用用于性能分析的 /debug/fgprof 和 /debug/pprof 端点。
 5[profiling_enabled: <boolean> | 默认值 = false]
 6
 7# HTTP 服务器监听主机
 8[http_listen_address: <string>]
 9
10# HTTP 服务器监听端口（0 表示随机端口）
11[http_listen_port: <int> | 默认值 = 80]
12
13# gRPC 服务器监听主机
14[grpc_listen_address: <string>]
15
16# gRPC 服务器监听端口（0 表示随机端口）
17[grpc_listen_port: <int> | 默认值 = 9095]
18
19# 注册instrumentation处理程序（/metrics 等）
20[register_instrumentation: <boolean> | 默认值 = true]
21
22# 优雅关闭的超时时间
23[graceful_shutdown_timeout: <duration> | 默认值 = 30s]
24
25# HTTP 服务器读取超时时间
26[http_server_read_timeout: <duration> | 默认值 = 30s]
27
28# HTTP 服务器写入超时时间
29[http_server_write_timeout: <duration> | 默认值 = 30s]
30
31# HTTP 服务器空闲超时时间
32[http_server_idle_timeout: <duration> | 默认值 = 120s]
33
34# 可接收的最大 gRPC 消息大小
35[grpc_server_max_recv_msg_size: <int> | 默认值 = 4194304]
36
37# 可发送的最大 gRPC 消息大小
38[grpc_server_max_send_msg_size: <int> | 默认值 = 4194304]
39
40# gRPC 调用的并发流的限制数量（0 表示无限制）
41[grpc_server_max_concurrent_streams: <int> | 默认值 = 100]
42
43# 仅记录给定严重性或更高严重性的消息。支持的值 [debug, info, warn, error]
44[log_level: <string> | 默认值 = "info"]
45
46# 所有API路由的基本路径（例如，/v1/）。
47[http_path_prefix: <string>]
48
49# Promtail就绪状态的目标管理器检查标志，如果设置为 false，则忽略检查
50[health_check_target: <bool> | 默认值 = true]
51
52# 通过HTTP请求启用运行时重新加载。
53[enable_runtime_reload: <bool> | 默认值 = false]
```

### 3.4 clients配置

`clients`块配置了Promtail如何连接到Loki的实例：

```yaml
  1# Loki监听的URL，在Loki中表示为http_listen_address和http_listen_port。
  2# 如果Loki运行在微服务模式下，这是Distributor的HTTP URL。
  3# 需要包含推送API的路径。
  4# 示例：http://example.com:3100/loki/api/v1/push
  5url: <string>
  6
  7# 每个推送请求发送时要附带的自定义HTTP标头。
  8# 请注意，Promtail本身设置的标头（如 X-Scope-OrgID）无法被覆盖。
  9headers:
 10  # 示例：CF-Access-Client-Id: xxx
 11  [ <labelname>: <labelvalue> ... ]
 12
 13# 用于默认推送日志到Loki的租户ID。
 14# 如果省略或为空，则假定Loki运行在单租户模式下，不会发送X-Scope-OrgID标头。
 15[tenant_id: <string>]
 16
 17# 发送批次之前等待的最大时间，即使批次不满也会发送。
 18[batchwait: <duration> | 默认值 = 1s]
 19
 20# 积累日志的最大批次大小（以字节为单位），在发送给Loki之前。
 21[batchsize: <int> | 默认值 = 1048576]
 22
 23# 如果使用基本身份验证，配置要发送的用户名和密码。
 24basic_auth:
 25  # 用于基本身份验证的用户名
 26  [username: <string>]
 27
 28  # 用于基本身份验证的密码
 29  [password: <string>]
 30
 31  # 包含基本身份验证密码的文件
 32  [password_file: <filename>]
 33
 34# 可选的 OAuth 2.0 配置
 35# 不能与 basic_auth 或 authorization 同时使用
 36oauth2:
 37  # OAuth2的客户端ID和密钥
 38  [client_id: <string>]
 39  [client_secret: <secret>]
 40
 41  # 从文件中读取客户端密钥
 42  # 与`client_secret`互斥
 43  [client_secret_file: <filename>]
 44
 45  # 用于令牌请求的可选范围
 46  scopes:
 47    [ - <string> ... ]
 48
 49  # 用于获取令牌的URL
 50  token_url: <string>
 51
 52  # 追加到令牌URL的可选参数
 53  endpoint_params:
 54    [ <string>: <string> ... ]
 55
 56# 发送到服务器的Bearer令牌。
 57[bearer_token: <secret>]
 58
 59# 包含要发送到服务器的Bearer令牌的文件。
 60[bearer_token_file: <filename>]
 61
 62# 用于连接服务器的HTTP代理服务器。
 63[proxy_url: <string>]
 64
 65# 如果连接到TLS服务器，配置TLS验证握手的操作方式。
 66tls_config:
 67  # 用于验证服务器的CA文件
 68  [ca_file: <string>]
 69
 70  # 发送到服务器用于客户端身份验证的证书文件
 71  [cert_file: <filename>]
 72
 73  # 发送到服务器用于客户端身份验证的密钥文件
 74 
 75  [key_file: <filename>]
 76
 77  # 验证服务器证书中的服务器名称是否与此值匹配。
 78  [server_name: <string>]
 79
 80  # 如果为true，则忽略服务器证书由未知CA签名的情况。
 81  [insecure_skip_verify: <boolean> | 默认值 = false]
 82
 83# 配置请求失败时如何重试向Loki发送请求。
 84# 默认的退避(backoff)时间表：
 85# 0.5s、1s、2s、4s、8s、16s、32s、64s、128s、256s（4.267m）
 86# 共计 511.5s（8.5m）的时间，超过该时间将丢失日志。
 87backoff_config:
 88  # 重试之间的初始退避时间
 89  [min_period: <duration> | 默认值 = 500ms]
 90
 91  # 重试之间的最大退避时间
 92  [max_period: <duration> | 默认值 = 5m]
 93
 94  # 最大重试次数
 95  [max_retries: <int> | 默认值 = 10]
 96
 97# 禁用对Loki响应状态码为429（TooManyRequests）的批次的重试。
 98# 这减少了来自其他租户的批次的影响，因为由于指数退避可能会导致这些批次被延迟或丢失。
 99[drop_rate_limited_batches: <boolean> | 默认值 = false]
100
101# 添加到发送到Loki的所有日志的静态标签。
102# 使用类似 {"foo": "bar"} 的映射添加标签foo和值bar。
103# 这些也可以从命令行指定：
104# -client.external-labels=k1=v1,k2=v2
105# （或 --client.external-labels，取决于您的操作系统）
106# 命令行提供的标签将应用于 `clients` 部分中配置的所有客户端。
107# 注意：配置文件中定义的值将替换命令行中针对给定客户端相同标签键的值。
108external_labels:
109  [ <labelname>: <labelvalue> ... ]
110
111# 等待服务器响应请求的最大时间。
112[timeout: <duration> | 默认值 = 10s]
```

### 3.5 positions配置

`positions` 块配置了Promtail将保存一个文件，用于指示它已经读取到文件的哪个位置。这在Promtail重新启动时是必需的，以便它可以从上次离开的位置继续读取。

```yaml
1# 位置文件的路径
2[filename: <string> | default = "/var/log/positions.yaml"]
3
4# 更新位置文件的频率
5[sync_period: <duration> | default = 10s]
6
7# 是否忽略并在后续覆盖损坏的位置文件
8[ignore_invalid_yaml: <boolean> | default = false]
```

### 3.6 scrape_configs配置

`scrape_configs`块配置了Promtail如何使用指定的发现方法从一系列目标(targets)中抓取日志：

```yaml
 1# 在Promtail UI中用于标识此抓取配置的名称。
 2job_name: <string>
 3
 4# 描述如何转换来自目标的日志。
 5[pipeline_stages: <pipeline_stages>]
 6
 7# 定义给定抓取目标的解压行为。
 8decompression:
 9  # 是否尝试解压缩。
10  [enabled: <boolean> | default = false]
11
12  # 开始解压缩前等待的初始延迟时间。
13  # 在发现压缩文件在压缩完成之前就存在的情况下非常有用。
14  [initial_delay: <duration> | default = 0s]
15
16  # 压缩格式。支持的格式有：'gz'、'bz2' 和 'z'。
17  [format: <string> | default = ""]
18
19# 描述如何从journal日志记录中抓取日志。
20[journal: <journal_config>]
21
22# 描述要将抓取的文件从哪种编码转换为。
23[encoding: <iana_encoding_name>]
24
25# 描述如何从syslog接收日志。
26[syslog: <syslog_config>]
27
28# 描述如何通过Loki推送API接收日志，（例如从其他Promtails或Docker Logging Driver）。
29[loki_push_api: <loki_push_api_config>]
30
31# 描述如何从Windows事件日志抓取日志。
32[windows_events: <windows_events_config>]
33
34# 描述如何拉取/接收Google Cloud Platform (GCP)日志。
35[gcplog: <gcplog_config>]
36
37# 描述如何通过Consumer组从Kafka抓取日志。
38[kafka: <kafka_config>]
39
40# 描述如何从gelf客户端接收日志。
41[gelf: <gelf_config>]
42
43# 描述如何拉取Cloudflare的日志。
44[cloudflare: <cloudflare>]
45
46# 描述如何拉取来自Heroku LogPlex drain的日志。
47[heroku_drain: <heroku_drain>]
48
49# 描述如何重新标记目标以确定是否应处理它们。
50relabel_configs:
51  - [<relabel_config>]
52
53# 静态目标进行抓取。
54static_configs:
55  - [<static_config>]
56
57# 包含要抓取的目标的文件。
58file_sd_configs:
59  - [<file_sd_configs>]
60
61# 描述如何发现运行在相同主机上的Kubernetes服务。
62kubernetes_sd_configs:
63  - [<kubernetes_sd_config>]
64
65# 描述如何使用Consul Catalog API 发现在consul集群中注册的服务。
66consul_sd_configs:
67  [ - <consul_sd_config> ... ]
68
69# 描述如何使用Consul Agent API 发现与Promtail在同一主机上运行的consul agent注册的服务。
70consulagent_sd_configs:
71  [ - <consulagent_sd_config> ... ]
72
73# 描述如何使用Docker 守护程序API发现在与Promtail相同的主机上运行的容器。
74docker_sd_configs:
75  [ - <docker_sd_config> ... ]
```

#### 3.6.1 pipeline_stages的配置

`pipeline_stages`用于转换日志条目及其标签。流水线在发现(discovery)过程完成后执行。`pipeline_stages`对象包含一系列与下面列出的项目相对应的阶段。

在大多数情况下，你可以使用`regex`或`json` stage从日志中提取数据。提取的数据被转换为临时的map对象。然后，Promtail可以使用这些数据作为标签的值或作为输出的内容。除了`docker`和`cri` stage外，任何其他阶段都可以访问提取的数据。

```yaml
 1- [
 2    <docker> |
 3    <cri> |
 4    <regex> |
 5    <json> |
 6    <template> |
 7    <match> |
 8    <timestamp> |
 9    <output> |
10    <labels> |
11    <metrics> |
12    <tenant> |
13    <replace>
14  ]
```

**docker**

Docker阶段解析Docker容器中的日志内容，并通过一个空对象以名称定义：

```yaml
1docker: {}
```

docker阶段将匹配并解析以下格式的日志行：

```fallback
1{"log":"level=info ts=2019-04-30T02:12:41.844179Z caller=filetargetmanager.go:180 msg=\"Adding target\"\n","stream":"stderr","time":"2019-04-30T02:12:41.8443515Z"}
```

自动从日志中提取时间戳，并将流转化为标签，将日志字段转化为输出，这对于Docker包装应用程序日志的方式非常有帮助，这样可以进一步处理仅包含日志内容的管道。

Docker阶段只是对这个定义的包装:

```yaml
 1- json:
 2    expressions:
 3      output: log
 4      stream: stream
 5      timestamp: time
 6- labels:
 7    stream:
 8- timestamp:
 9    source: timestamp
10    format: RFC3339Nano
11- output:
12    source: output
```

**cri**

CRI阶段解析CRI容器中的日志内容，并通过一个空对象以名称定义：

```yaml
1cri: {}
```

CRI阶段将匹配并解析以下格式的日志行：

```fallback
12019-01-01T01:00:00.000000001Z stderr P some log message
```

自动从日志中提取时间戳，并将流转化为标签，将剩余的消息转化为输出，这对于CRI以这种方式包装应用程序日志非常有帮助，这将使其解包，以便进一步处理仅包含日志内容的管道。

CRI阶段只是对这个定义的包装:

```yaml
1- regex:
2    expression: "^(?s)(?P<time>\\S+?) (?P<stream>stdout|stderr) (?P<flags>\\S+?) (?P<content>.*)$"
3- labels:
4    stream:
5- timestamp:
6    source: time
7    format: RFC3339Nano
8- output:
9    source: content
```

**regex**

正则表达式阶段（Regex stage）接受一个正则表达式，并提取捕获的命名分组，以便在后续阶段中使用。

```yaml
1regex:
2  # RE2正则表达式。每个捕获组必须具有名称。
3  expression: <字符串>
4
5  # 从提取的数据中解析的名称。如果为空，则使用日志消息。
6  [source: <字符串>]
```

**json**

JSON阶段解析日志行为JSON，并使用JMESPath表达式从JSON中提取数据，以便在后续阶段中使用。

```yaml
1json:
2  # 一组JMESPath表达式的键值对。键将成为提取数据中的键，而表达式将作为值从源数据中进行JMESPath评估。
3  expressions:
4    [ <字符串>: <字符串> ... ]
5
6  # 从提取的数据中解析的名称。如果为空，则使用日志消息。
7  [source: <字符串>]
```

**template**

模板阶段使用Go的文本/模板语言来操作值。

```yaml
1template:
2  # 从提取的数据中解析的名称。如果提取数据中的键不存在，将创建一个条目。
3  source: <字符串>
4
5  # 要使用的Go模板字符串。除了常规模板函数外，还可以使用ToLower、ToUpper、Replace、Trim、TrimLeft、TrimRight、TrimPrefix、TrimSuffix和TrimSpace作为函数。
6  template: <字符串>
```

示例:

```yaml
1template:
2  source: level
3  template: '{{ if eq .Value "WARN" }}{{ Replace .Value "WARN" "OK" -1 }}{{ else }}{{ .Value }}{{ end }}'
```

**match**

匹配阶段（match stage）在日志条目与可配置的LogQL流选择器匹配时，有条件地执行一组阶段。

```yaml
 1match:
 2  # LogQL流选择器。
 3  selector: <字符串>
 4
 5  # 为管道命名。当定义时，会在pipeline_duration_seconds直方图中创建一个额外的标签，其中的值与job_name使用下划线连接。
 6  [pipeline_name: <字符串>]
 7
 8  # 如果选择器匹配日志条目的标签，则嵌套一组管道阶段：
 9  stages:
10    - [
11        <docker> |
12        <cri> |
13        <regex> |
14        <json> |
15        <template> |
16        <match> |
17        <timestamp> |
18        <output> |
19        <labels> |
20        <metrics>
21      ]
```

**timestamp**

时间戳阶段（timestamp stage）从提取的map中解析数据，并覆盖Loki存储的日志的最终时间值。如果没有这个阶段，Promtail将将日志条目的时间戳与读取该条目的时间关联起来。

```yaml
1timestamp:
2  # 从提取的数据中用于时间戳的名称。
3  source: <字符串>
4
5  # 确定如何解析时间字符串。可以使用预定义的格式名称：[ANSIC UnixDate RubyDate RFC822 RFC822Z RFC850 RFC1123 RFC1123Z RFC3339 RFC3339Nano Unix UnixMs UnixUs UnixNs]。
6  format: <字符串>
7
8  # IANA时区数据库字符串。
9  [location: <字符串>]
```

**output**

输出阶段（output stage）从提取的map中获取数据，并设置将由Loki存储的日志条目的内容。

```yaml
1output:
2  # 从提取的数据中用于日志条目的名称。
3  source: <字符串>
```

**labels**

标签阶段（labels stage）从提取的map中获取数据，并在将发送给Loki的日志条目上设置附加标签。

```yaml
1labels:
2  # 键是必需的，是将创建的标签的名称。
3  # 值是可选的，将是提取数据中的名称，其值将用作标签的值。
4  # 如果为空，则值将被推断为与键相同。
5  [ <字符串>: [<字符串>] ... ]
```

**metrics**

度量指标阶段（metrics stage）允许根据提取的数据定义度量指标。

创建的度量指标不会推送到Loki，而是通过Promtail的`/metrics`端点公开。需要配置Prometheus以抓取Promtail，以便能够检索由此阶段配置的度量指标。

```yaml
1# 一个map，其中键是度量指标的名称，值是特定的度量指标类型。
2metrics:
3  [ <字符串>: [ <counter> | <gauge> | <histogram> ] ...]
```

**counter**

定义一个计数器度量指标，其值只会递增。

```yaml
 1# 度量指标类型。必须为Counter。
 2type: Counter
 3
 4# 描述度量指标。
 5[description: <字符串>]
 6
 7# 从提取的数据映射中用于度量指标的键，如果不存在，默认为度量指标的名称。
 8[source: <字符串>]
 9
10config:
11  # 过滤源数据，并仅在目标值与提供的字符串完全匹配时更改度量指标。
12  # 如果不存在，所有数据都将匹配。
13  [value: <字符串>]
14
15  # 必须是"inc"或"add"（不区分大小写）。如果选择inc，每个通过过滤器的日志行接收到时，度量指标值将递增1。如果选择add，提取的值必须可转换为正浮点数，并将其值添加到度量指标中。
16  action: <字符串>
```

**gauge**

定义一个计数器度量指标，其值可以增加或减少。

```yaml
 1# 度量指标类型。必须为Gauge。
 2type: Gauge
 3
 4# 描述度量指标。
 5[description: <字符串>]
 6
 7# 从提取的数据映射中用于度量指标的键，如果不存在，默认为度量指标的名称。
 8[source: <字符串>]
 9
10config:
11  # 过滤源数据，并仅在目标值与提供的字符串完全匹配时更改度量指标。
12  # 如果不存在，所有数据都将匹配。
13  [value: <字符串>]
14
15  # 必须是"set"、"inc"、"dec"、"add"或"sub"之一。如果选择add、set或sub，提取的值必须可转换为正浮点数。inc和dec分别将度量指标的值递增或递减1。
16  action: <字符串>
```

**histogram**

定义一个直方图度量指标，其值被分桶(bucket)。

```yaml
 1# 度量指标类型。必须为Histogram。
 2type: Histogram
 3
 4# 描述度量指标。
 5[description: <字符串>]
 6
 7# 从提取的数据映射中用于度量指标的键，如果不存在，默认为度量指标的名称。
 8[source: <字符串>]
 9
10config:
11  # 过滤源数据，并仅在目标值与提供的字符串完全匹配时更改度量指标。
12  # 如果不存在，所有数据都将匹配。
13  [value: <字符串>]
14
15  # 必须是"inc"或"add"（不区分大小写）。如果选择inc，每个通过过滤器的日志行接收到时，度量指标值将递增1。如果选择add，提取的值必须可转换为正浮点数，并将其值添加到度量指标中。
16  action: <字符串>
17
18  # 用于分桶度量指标的所有数字。
19  buckets:
20    - <整数>
```

**tenant**

tenant stage是一个操作阶段，它从提取的数据map中的字段中选择并设置日志条目的租户ID。

```yaml
1tenant:
2  # 从提取的数据中选择其值作为租户ID的字段的名称。
3  # source或value配置选项是必需的，但不能同时存在（它们是互斥的）。
4  [source: <字符串>]
5
6  # 当执行此阶段时，用于设置租户ID的值。在包含条件管道（"match"）中使用此阶段时很有用。
7  [value: <字符串>]
```

**replace**

replace stage是一个解析阶段，使用正则表达式解析日志行并替换该日志行。

```yaml
 1replace:
 2  # RE2正则表达式。每个命名捕获组将添加到提取的数据中。
 3  # 每个捕获组和命名捕获组将被替换为`replace`中给定的值。
 4  expression: <字符串>
 5
 6  # 从提取的数据中用于解析的名称。如果为空，则使用日志消息。
 7  # 替换后的值将被重新分配给源键。
 8  [source: <字符串>]
 9
10  # 捕获组将被替换为的值。捕获组或命名捕获组将被替换为此值，
11  # 并且日志行将被替换为新的替换值。空值将从日志行中删除捕获组。
12  [replace: <字符串>]
```

#### 3.6.2 journal配置

journal块配置了从Promtail读取systemd日志。在构建Promtail时需要启用journal支持。如果使用AMD64 Docker镜像，则默认启用此功能。

```yaml
 1# 当为true时，来自journal的日志消息将以JSON消息的形式通过管道传递，包含所有journal条目的原始字段。
 2# 当为false时，日志消息是journal条目的MESSAGE字段的文本内容。
 3[json: <布尔值> | 默认值 = false]
 4
 5# 从进程启动开始读取并发送到Loki的最早相对时间。
 6[max_age: <持续时间> | 默认值 = 7h]
 7
 8# 要添加到从journal中出来的每个日志的标签映射。
 9labels:
10  [ <标签名称>: <标签值> ... ]
11
12# 读取条目的目录路径。为空时，默认为系统路径（/var/log/journal和/run/log/journal）。
13[path: <字符串>]
```

> 注意：`priority`标签既可作为值也可作为关键字使用。例如，如果`priority`为`3`，则标签将为`__journal_priority`，值为`3`，以及`__journal_priority_keyword`，关键字为`err`。

#### 3.6.3 syslog配置

syslog模块配置了一个syslog监听器，允许用户使用syslog协议将日志推送到Promtail。目前支持的是[IETF Syslog（RFC5424）](https://tools.ietf.org/html/rfc5424)协议，支持带有和不带有八位计数的方式。

建议部署时，在Promtail之前使用专门的syslog转发器，如syslog-ng或rsyslog。转发器可以处理存在的各种规范和传输方式（UDP，BSD syslog等）。

推荐使用[八位计数](https://tools.ietf.org/html/rfc6587#section-3.4.1)作为消息分帧方法。在[非透明分帧](https://tools.ietf.org/html/rfc6587#section-3.4.2)的流中，Promtail需要等待下一条消息以捕获多行消息，因此可能会出现消息之间的延迟。

请参阅[syslog-ng](https://grafana.com/docs/loki/latest/clients/promtail/scraping/#syslog-ng-output-configuration)和[rsyslog](https://grafana.com/docs/loki/latest/clients/promtail/scraping/#rsyslog-output-configuration)的推荐输出配置。这两个配置都启用了带有八位计数的IETF Syslog协议。

如果有很多客户端连接，您可能需要增加Promtail进程的打开文件限制。（`ulimit -Sn`）

```yaml
 1# 要监听的TCP地址，格式为“主机:端口”。
 2listen_address: <string>
 3
 4# 配置接收器使用TLS。
 5tls_config:
 6  # 由服务器发送的证书和密钥文件（必需）
 7  cert_file: <string>
 8  key_file: <string>
 9
10  # 用于验证客户端证书的CA证书。当指定时启用客户端证书验证。
11  [ ca_file: <string> ]
12
13# TCP syslog连接的空闲超时时间，默认为120秒。
14idle_timeout: <duration>
15
16# 是否将syslog结构化数据转换为标签。
17# 结构化数据条目 [example@99999 test="yes"] 将变为标签 "__syslog_message_sd_example_99999_test"，其值为 "yes"。
18label_structured_data: <bool>
19
20# 每个日志消息要添加的标签映射。
21labels:
22  [ <labelname>: <labelvalue> ... ]
23
24# Promtail是否应该传递来自传入syslog消息的时间戳。
25# 当为false时，或者如果syslog消息上没有时间戳，Promtail将在处理日志时分配当前时间戳。
26# 默认为false。
27use_incoming_timestamp: <bool>
28
29# 设置syslog消息的最大长度限制
30max_message_length: <int>
```

可用的labels:

- `__syslog_connection_ip_address`：远程IP地址。
- `__syslog_connection_hostname`：远程主机名。
- `__syslog_message_severity`：从消息中解析的syslog严重性。按照syslog_message.go中的符号名称。
- `__syslog_message_facility`：从消息中解析的syslog设施。按照syslog_message.go和syslog(3)中的符号名称。
- `__syslog_message_hostname`：从消息中解析的主机名。
- `__syslog_message_app_name`：从消息中解析的app-name字段。
- `__syslog_message_proc_id`：从消息中解析的procid字段。
- `__syslog_message_msg_id`：从消息中解析的msgid字段。
- `__syslog_message_sd_<sd_id>[_<iana_enterprise_id>]_<sd_name>`：从消息中解析的结构化数据字段。数据字段 [custom@99770 example=“1”] 变为 __syslog_message_sd_custom_99770_example。

#### 3.6.4 loki_push_api

`loki_push_api`配置Promtail暴露一个Loki push API server.

每个使用`loki_push_api`配置的job将公开此API，并需要一个单独的端口。

请注意，server配置与3.3中的server配置相同。

Promtail还在`/promtail/api/v1/raw`上公开了第二个端点，该端点期望以换行分隔的日志行。这可用于发送`NDJSON`或纯文本日志。

> NDJSON(Newline Delimited JSON)，即使用换行符分割的JSON，同时能够保证每一行的内容都是一个完整的JSON。

可以使用`/ready`端点检查`loki_push_api`服务器的可用性。

```yaml
 1# 推送服务器的配置选项
 2[server: <server_config>]
 3
 4# 添加到发送到推送API的每个日志行的标签映射
 5labels:
 6  [ <labelname>: <labelvalue> ... ]
 7
 8# 指定Promtail是否应将传入日志的时间戳传递给下游处理程序
 9# 当为false时，Promtail会在处理日志时将当前时间戳分配给日志。
10# 不适用于`/promtail/api/v1/raw`上的明文端点。
11[use_incoming_timestamp: <bool> | default = false]
```

#### 3.6.5 windows_events配置

`windows_events`块配置Promtail以抓取Windows事件日志并将其发送到Loki。

要订阅特定的事件流，您需要提供`eventlog_name`或`xpath_query`之一。

默认情况下，事件会每3秒进行定期抓取，但可以使用`poll_interval`进行更改。

必须提供一个书签路径`bookmark_path`，它将用作位置文件，Promtail将在其中记录上次处理的最后一个事件。该文件会在Promtail重新启动时保留。

如果您希望保留传入事件的时间戳，可以设置`use_incoming_timestamp`。默认情况下，Promtail将使用从事件日志读取事件时的时间戳。

Promtail将序列化JSON格式的Windows事件，并从收到的事件中添加通道（channel）和计算机（computer）标签。您可以使用`labels`属性添加其他标签。

```yaml
 1# 用于事件渲染的LCID（区域设置ID）
 2# - 1033 强制使用英语语言
 3# -  0 使用默认的Windows区域设置
 4[locale: <int> | default = 0]
 5
 6# 事件日志的名称，仅在xpath_query为空时使用
 7# 示例："Application"
 8[eventlog_name: <string> | default = ""]
 9
10# xpath_query可以使用定义的简短形式，例如"Event/System[EventID=999]"
11# 或者您可以构建一个XML查询。请参阅“消耗事件”文章：
12# https://docs.microsoft.com/en-us/windows/win32/wes/consuming-events
13# XML查询是推荐的形式，因为它最灵活
14# 您可以通过在Windows事件查看器中创建自定义视图，然后将结果XML复制到这里来创建或调试XML查询
15[xpath_query: <string> | default = "*"]
16
17# 设置文件系统上的书签位置。
18# 书签包含目标在XML中的当前位置。
19# 当重新启动或升级Promtail时，基于书签位置，目标将继续从上次离开的位置抓取事件。
20# 每处理一个条目后，位置都会更新。
21[bookmark_path: <string> | default = ""]
22
23# PollInterval是我们检查是否有新事件可用的间隔。默认情况下，目标每3秒钟检查一次。
24[poll_interval: <duration> | default = 3s]
25
26# 允许排除XML事件数据。
27[exclude_event_data: <bool> | default = false]
28
29# 允许排除人类可读的事件消息。
30[exclude_event_message: <bool> | default = false]
31
32# 允许排除每个Windows事件的用户数据。
33[exclude_user_data: <bool> | default = false]
34
35# 添加到从Windows事件日志读取的每个日志行的标签映射
36labels:
37  [ <labelname>: <labelvalue> ... ]
38
39# 如果Promtail应传递传入日志的时间戳，则为true；否则为false。
40# 当为false时，Promtail会在处理日志时将当前时间戳分配给日志
41[use_incoming_timestamp: <bool> | default = false]
```

#### 3.6.6 gcplog配置

略

#### 3.6.7 kafka配置

略

#### 3.6.8 gelf配置

略

#### 3.6.9 cloudflare配置

略

#### 3.6.10 heroku_drain配置

略

#### 3.6.11 relabel_configs配置

重新标记（Relabeling）是一种在目标被抓取之前动态重写目标的标签集的强大工具。每个抓取配置可以配置多个重新标记步骤。它们按照配置文件中的顺序应用于每个目标的标签集。

重新标记完成后，默认情况下，如果在重新标记过程中未设置`instance`标签，则将`instance`标签设置为`__address__`的值。标签`__scheme__`和`__metrics_path__`分别设置为目标的协议schema和metrics路径。标签`__param_<name>`设置为名为`<name>`的第一个传递的URL参数的值。

在重新标记阶段，可能还会存在以`__meta_`为前缀的其他标签。它们由提供目标的服务发现机制设置，并且在不同的机制之间可能会有所变化。

在目标重新标记完成后，以`__`开头的标签将从标签集中移除。

如果重新标记步骤需要临时存储标签值（作为后续重新标记步骤的输入），请使用`__tmp`标签名称前缀。此前缀保证不会被Prometheus本身使用。

```yaml
 1# 源标签从现有标签中选择值。它们的内容使用配置的分隔符连接起来，
 2# 并与配置的正则表达式进行替换、保留和删除操作进行匹配。
 3[ source_labels: '[' <labelname> [, ...] ']' ]
 4
 5# 用于连接源标签值的分隔符。
 6[ separator: <string> | default = ";" ]
 7
 8# 在替换操作中将结果值写入的标签。
 9# 对于替换操作，此项为必填项。可以使用正则表达式捕获组。
10[ target_label: <labelname> ]
11
12# 用于匹配提取的值的正则表达式。
13[ regex: <regex> | default = "(.*)" ]
14
15# 哈希源标签值后取模的值。
16[ modulus: <uint64> ]
17
18# 如果正则表达式匹配，执行基于替换的替换值。
19# 可以使用正则表达式捕获组。
20[ replacement: <string> | default = "$1" ]
21
22# 基于正则表达式匹配执行的操作。
23[ action: <relabel_action> | default = "replace" ]
```

以下是翻译的结果：

`<regex>` 是任何有效的 RE2 正则表达式。它在替换、保留、删除、labelmap、labeldrop 和 labelkeep 操作中都是必需的。正则表达式在两端都锚定。要取消锚定，可以使用 .*.*。

`<relabel_action>` 确定重新标记操作的执行方式：

- replace: 将正则表达式与连接后的 `source_labels` 进行匹配。然后，将 `target_label` 设置为 `replacement`，其中替换中的匹配组引用（`${1}`、`${2}` 等）将被其值替换。如果正则表达式不匹配，则不进行替换。
- keep: 对于正则表达式不匹配的连接后的 `source_labels`，丢弃相应的目标。
- drop: 对于正则表达式匹配的连接后的 `source_labels`，丢弃相应的目标。
- hashmod: 将 `target_label` 设置为连接后的 `source_labels` 的哈希值的模。
- labelmap: 将正则表达式与所有标签名称进行匹配。然后将匹配标签的值复制到由 `replacement` 给出的标签名称中，其中替换中的匹配组引用（`${1}`、`${2}` 等）将被其值替换。
- labeldrop: 将正则表达式与所有标签名称进行匹配。匹配的任何标签都将从标签集中移除。
- labelkeep: 将正则表达式与所有标签名称进行匹配。不匹配的任何标签都将从标签集中移除。

在使用 `labeldrop` 和 `labelkeep` 时必须小心，确保在删除标签后日志仍然具有唯一的标签。

#### 3.6.12 static_configs配置

`static_configs`允许指定一个目标列表和一个共同的标签集合。这是在抓取配置中指定静态目标的标准方式。

```yaml
 1# 配置在当前机器上查找发现目标。
 2# 这是Prometheus服务发现代码所需的，但对于只能查看本地机器上的文件的Promtail来说并不适用。
 3# 因此，它只应该具有localhost的值，或者可以完全排除它，Promtail将应用localhost的默认值。
 4
 5targets:
 6  - localhost
 7
 8# 定义要抓取的文件和要应用于__path__文件定义的所有流的可选附加标签集合。
 9
10labels:
11  # 从中加载日志的路径。可以使用通配符模式（例如，/var/log/*.log）。
12  __path__: <string>
13
14  # 用于排除要加载的文件。也可以使用通配符模式。
15  __path_exclude__: <string>
16
17  # 分配给日志的附加标签
18  [ <labelname>: <labelvalue> ... ]
```

#### 3.6.13 file_sd_config配置

基于文件的服务发现提供了一种更通用的配置静态目标的方式，并作为插入自定义服务发现机制的接口。

它通过读取包含零个或多个`<static_config>`的文件集来实现。通过磁盘监视立即检测并应用所有已定义文件的更改。文件可以以YAML或JSON格式提供。只有生成良好格式的目标组(target group)的更改才会被应用。

JSON文件必须包含一个静态配置列表，使用以下格式：

```json
 1[
 2  {
 3    "targets": [ "localhost" ],
 4    "labels": {
 5      "__path__": "<string>", ...
 6      "<labelname>": "<labelvalue>", ...
 7    }
 8  },
 9  ...
10]
```

作为备选方案，文件内容也会定期按照指定的刷新间隔重新读取。

在重新标记阶段(relabeling phase.)，每个目标都具有一个元标签`__meta_filepath`。其值被设置为提取目标的文件路径。

```yaml
1# 用于提取目标组的文件模式。
2files:
3  [ - <filename_pattern> ... ]
4
5# 重新读取文件的刷新间隔。
6[ refresh_interval: <duration> | default = 5m ]
```

其中，`<filename_pattern>`可以是以`.json`、`.yml`或`.yaml`结尾的路径。最后一个路径段可以包含一个单独的`*`，用于匹配任何字符序列，例如`my/path/tg_*.json`。

#### 3.6.14 kubernetes_sd_config配置

Kubernetes SD（服务发现）配置允许从Kubernetes的REST API中检索抓取目标，并始终与集群状态保持同步。

可以配置以下角色类型之一来发现目标：

**node**

node role为每个集群节点发现一个目标，地址默认为Kubelet的HTTP端口。

目标地址默认为Kubernetes节点对象的地址类型顺序中的第一个现有地址，顺序为`NodeInternalIP`、`NodeExternalIP`、`NodeLegacyHostIP`和`NodeHostName`。

可用的元标签：

- `__meta_kubernetes_node_name`：节点对象的名称。
- `__meta_kubernetes_node_label_<labelname>`：节点对象的每个标签。
- `__meta_kubernetes_node_labelpresent_<labelname>`：节点对象的每个标签的值为true。
- `__meta_kubernetes_node_annotation_<annotationname>`：节点对象的每个注释。
- `__meta_kubernetes_node_annotationpresent_<annotationname>`：节点对象的每个注释的值为true。
- `__meta_kubernetes_node_address_<address_type>`：每个节点地址类型的第一个地址（如果存在）。

此外，节点的`instance`标签将设置为从API服务器检索的节点名称。

**service**

service role为每个服务的每个服务端口发现一个目标。这通常用于对服务进行黑盒监控。地址将设置为服务的Kubernetes DNS名称和相应的服务端口。

可用的元标签：

- `__meta_kubernetes_namespace`：服务对象的命名空间。
- `__meta_kubernetes_service_annotation_<annotationname>`：服务对象的每个注释。
- `__meta_kubernetes_service_annotationpresent_<annotationname>`：“true”，用于服务对象的每个注释。
- `__meta_kubernetes_service_cluster_ip`：服务的集群IP地址。（不适用于类型为ExternalName的服务）
- `__meta_kubernetes_service_external_name`：服务的DNS名称。（适用于类型为ExternalName的服务）
- `__meta_kubernetes_service_label_<labelname>`：服务对象的每个标签。
- `__meta_kubernetes_service_labelpresent_<labelname>`：服务对象的每个标签的值为true。
- `__meta_kubernetes_service_name`：服务对象的名称。
- `__meta_kubernetes_service_port_name`：目标的服务端口名称。
- `__meta_kubernetes_service_port_protocol`：目标的服务端口协议。

**pod**

pod role发现所有的Pod并将它们的容器暴露为目标。对于每个容器声明的端口，将生成一个单独的目标。如果一个容器没有指定端口，则会为每个容器创建一个无端口的目标，以便通过重新标记手动添加端口。

可用的元标签：

- `__meta_kubernetes_namespace`：Pod对象的命名空间。
- `__meta_kubernetes_pod_name`：Pod对象的名称。
- `__meta_kubernetes_pod_ip`：Pod对象的Pod IP。
- `__meta_kubernetes_pod_label_<labelname>`：Pod对象的每个标签。
- `__meta_kubernetes_pod_labelpresent_<labelname>`：Pod对象的每个标签的值为true。
- `__meta_kubernetes_pod_annotation_<annotationname>`：Pod对象的每个注释。
- `__meta_kubernetes_pod_annotationpresent_<annotationname>`：Pod对象的每个注释的值为true。
- `__meta_kubernetes_pod_container_init`：如果容器是InitContainer，则为true。
- `__meta_kubernetes_pod_container_name`：目标地址指向的容器的名称。
- `__meta_kubernetes_pod_container_port_name`：容器端口的名称。
- `__meta_kubernetes_pod_container_port_number`：容器端口的编号。
- `__meta_kubernetes_pod_container_port_protocol`：容器端口的协议。
- `__meta_kubernetes_pod_ready`：用于指示Pod是否就绪的状态，值为true或false。
- `__meta_kubernetes_pod_phase`：Pod的生命周期阶段，可能的取值为Pending、Running、Succeeded、Failed或Unknown。
- `__meta_kubernetes_pod_node_name`：Pod所调度到的节点的名称。
- `__meta_kubernetes_pod_host_ip`：Pod对象的当前主机IP。
- `__meta_kubernetes_pod_uid`：Pod对象的UID。
- `__meta_kubernetes_pod_controller_kind`：Pod控制器的对象类型。
- `__meta_kubernetes_pod_controller_name`：Pod控制器的名称。

**endpoints**

endpoints role从服务的端点列表中发现目标。对于每个端点地址，每个端口会发现一个目标。如果端点由一个Pod支持，那么该Pod的所有额外容器端口（未绑定到端点端口）也会作为目标被发现。

可用的元标签：

- `__meta_kubernetes_namespace`：端点对象的命名空间。
- `__meta_kubernetes_endpoints_name`：端点对象的名称。

对于直接从端点列表中发现的所有目标（不是从底层Pod中额外推断出来的），附加以下标签：

- `__meta_kubernetes_endpoint_hostname`：端点的主机名。
- `__meta_kubernetes_endpoint_node_name`：托管端点的节点名称。
- `__meta_kubernetes_endpoint_ready`：用于指示端点是否就绪的状态，值为true或false。
- `__meta_kubernetes_endpoint_port_name`：端点端口的名称。
- `__meta_kubernetes_endpoint_port_protocol`：端点端口的协议。
- `__meta_kubernetes_endpoint_address_target_kind`：端点地址目标的类型。
- `__meta_kubernetes_endpoint_address_target_name`：端点地址目标的名称。

如果端点属于一个服务，则附加服务发现角色的所有标签。 对于由Pod支持的所有目标，附加Pod发现角色的所有标签。

**ingress***

ingress role为每个ingress的每个路径发现一个目标。这通常用于对ingress进行黑盒监控。地址将设置为ingress规范中指定的主机。

可用的元标签：

- `__meta_kubernetes_namespace`：ingress对象的命名空间。
- `__meta_kubernetes_ingress_name`：ingress对象的名称。
- `__meta_kubernetes_ingress_label_<labelname>`：ingress对象的每个标签。
- `__meta_kubernetes_ingress_labelpresent_<labelname>`：ingress对象的每个标签的值为true。
- `__meta_kubernetes_ingress_annotation_<annotationname>`：ingress对象的每个注释。
- `__meta_kubernetes_ingress_annotationpresent_<annotationname>`：ingress对象的每个注释的值为true。
- `__meta_kubernetes_ingress_scheme`：ingress的协议方案，如果设置了TLS配置，则为https。默认为http。
- `__meta_kubernetes_ingress_path`：来自ingress规范的路径。默认为/。

有关Kubernetes发现的配置选项，请参阅下面的内容：

```yaml
 1# 访问Kubernetes API的信息。
 2
 3# API服务器地址。如果留空，假定Prometheus在集群内部运行，
 4# 将自动发现API服务器，并使用位于/var/run/secrets/kubernetes.io/serviceaccount/的Pod的CA证书和Bearer令牌文件。
 5[ api_server: <host> ]
 6
 7# 需要发现的实体的Kubernetes角色。
 8role: <role>
 9
10# 用于身份验证到API服务器的可选身份验证信息。
11# 请注意，`basic_auth`，`bearer_token`和`bearer_token_file`选项是
12# 互斥的。
13# password和password_file是互斥的。
14
15# 可选的HTTP基本身份验证信息。
16basic_auth:
17  [ username: <string> ]
18  [ password: <secret> ]
19  [ password_file: <string> ]
20
21# 可选的Bearer令牌身份验证信息。
22[ bearer_token: <secret> ]
23
24# 可选的Bearer令牌文件身份验证信息。
25[ bearer_token_file: <filename> ]
26
27# 可选的代理URL。
28[ proxy_url: <string> ]
29
30# TLS配置。
31tls_config:
32  [ <tls_config> ]
33
34# 可选的命名空间发现。如果省略，将使用所有命名空间。
35namespaces:
36  names:
37    [ - <string> ]
38
39# 可选的标签和字段选择器，用于将发现过程限制为可用资源的子集。
40# 请参阅
41# https://kubernetes.io/docs/concepts/overview/working-with-objects/field-selectors/
42# 和 https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
43# 了解可用的过滤器。endpoints角色支持pod、service和endpoint选择器。
44# 仅支持与角色本身匹配的选择器；
45# 例如，节点角色只能包含节点选择器。
46# 注意：在决定使用字段/标签选择器时，请确保这是最佳方法。
47# 它将阻止Promtail为所有抓取配置重用单个列表/监视。
48# 这可能会导致对Kubernetes API的更大负载，因为对于每个选择器组合，将有额外的LIST/WATCH。
49# 另一方面，如果您想监视大型集群的一小部分Pod，
50# 我们建议使用选择器。选择是否使用选择器取决于具体情况。
51[ selectors:
52          [ - role: <string>
53                  [ label: <string> ]
54                  [ field: <string> ] ]]
```

其中`<role>`必须为`endpoints`、`service、pod`、`node`或`ingress`。

请参考[此示例Prometheus配置文件](https://github.com/prometheus/prometheus/blob/master/documentation/examples/prometheus-kubernetes.yml)，详细了解如何配置Kubernetes的Prometheus。

您可能还希望了解第三方的[Prometheus Operator](https://github.com/coreos/prometheus-operator)，它可以在Kubernetes上自动化配置Prometheus。

#### 3.6.15 consul_sd_config配置

略

#### 3.6.17 consulagent_sd_config配置

略

#### 3.6.18 docker_sd_config配置

略

### 3.7 limits_config配置

可选的 limits_config 块用于配置 Promtail 的全局限制。

```yaml
 1# 当为true时，在此Promtail实例上强制执行速率限制。
 2[readline_rate_enabled: <bool> | 默认值 = false]
 3
 4# 每秒允许此Promtail实例推送到Loki的日志行数限制。
 5[readline_rate: <int> | 默认值 = 10000]
 6
 7# 允许此Promtail实例推送到Loki的突发行数限制。
 8[readline_burst: <int> | 默认值 = 10000]
 9
10# 当为true时，超过速率限制会导致此Promtail实例丢弃日志行，而不是发送到Loki。当为false时，超过速率限制会导致此Promtail实例暂时推迟发送日志行，并稍后重试。
11[readline_rate_drop: <bool> | 默认值 = true]
12
13# 限制最大活动流的数量。
14# 通过限制流的数量，可以有效控制Promtail的内存使用，避免OOM情况。
15# 0表示禁用。
16[max_streams: <int> | 默认值 = 0]
17
18# 允许的最大日志行字节大小，超过此大小将会被丢弃。示例：256kb，2M。设置为0禁用此限制。
19[max_line_size: <int> | 默认值 = 0]
20# 是否截断超过最大行大小的行。如果max_line_size未启用，则无效。
21[max_line_size_truncate: <bool> | 默认值 = false]
```

### 3.8 target_config配置

`target_config`块控制从发现的目标中读取文件的行为。

```yaml
1# 同步周期，重新同步正在监视的目录和正在尾随的文件以发现新文件或停止监视已删除的文件。
2sync_period: "10s"
```

### 3.9 options_config配置

```yaml
1# 已弃用。
2# 逗号分隔的标签列表，包含在流滞后度量中的标签“promtail_stream_lag_seconds”中。
3# 默认值为“filename”。始终包含一个“host”标签。
4# 流滞后度量指示哪些流在向Loki写入时滞后。请注意不要使用过多的标签，
5# 因为这可能会增加基数。
6[stream_lag_labels: <string> | default = "filename"]
```

### 3.10 tracing_config配置

tracing块配置Jaeger的追踪。目前，仅支持通过环境变量进行配置。

```yaml
1[enabled: <boolean> | default = false]
```

## 参考

- https://grafana.com/docs/loki/latest/clients/
- https://grafana.com/docs/loki/latest/clients/promtail/
- https://grafana.com/docs/loki/latest/clients/promtail/configuration/

