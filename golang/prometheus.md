# Prometheus



[toc]



## metrics

https://segmentfault.com/a/1190000024467720

为了能够帮助用户理解和区分这些不同监控指标之间的差异，Prometheus定义了4种不同的指标类型(metric type)：Counter（计数器）、Gauge（仪表盘）、Histogram（直方图）、Summary（摘要）。



在Exporter返回的样本数据中，其注释中也包含了该样本的类型。例如：

```
# HELP node_cpu Seconds the cpus spent in each mode.
# TYPE node_cpu counter
node_cpu{cpu="cpu0",mode="idle"} 362812.7890625
```



### Counter：只增不减的计数器

Counter类型的指标其工作方式和计数器一样，只增不减（除非系统发生重置）。常见的监控指标，如http_requests_total，node_cpu都是Counter类型的监控指标。 一般在定义Counter类型指标的名称时推荐使用_total作为后缀。

Counter是一个简单但有强大的工具，例如我们可以在应用程序中记录某些事件发生的次数，通过以时序的形式存储这些数据，我们可以轻松的了解该事件产生速率的变化。 PromQL内置的聚合操作和函数可以让用户对这些数据进行进一步的分析：

例如，通过rate()函数获取HTTP请求量的增长率：

```
rate(http_requests_total[5m])
```



查询当前系统中，访问量前10的HTTP地址：

```
topk(10, http_requests_total)
```



### Gauge：可增可减的仪表盘

与Counter不同，Gauge类型的指标侧重于反应系统的当前状态。因此这类指标的样本数据可增可减。常见指标如：node_memory_MemFree（主机当前空闲的内容大小）、node_memory_MemAvailable（可用内存大小）都是Gauge类型的监控指标。

通过Gauge指标，用户可以直接查看系统的当前状态：

```
node_memory_MemFree
```

对于Gauge类型的监控指标，通过PromQL内置函数delta()可以获取样本在一段时间返回内的变化情况。例如，计算CPU温度在两个小时内的差异：

```
delta(cpu_temp_celsius{host="zeus"}[2h])
```

还可以使用deriv()计算样本的线性回归模型，甚至是直接使用predict_linear()对数据的变化趋势进行预测。例如，预测系统磁盘空间在4个小时之后的剩余情况：

```
predict_linear(node_filesystem_free{job="node"}[1h], 4 * 3600)
```





### 使用Histogram和Summary分析数据分布情况

除了Counter和Gauge类型的监控指标以外，Prometheus还定义了Histogram和Summary的指标类型。Histogram和Summary主用用于统计和分析样本的分布情况。

在大多数情况下人们都倾向于使用某些量化指标的平均值，例如CPU的平均使用率、页面的平均响应时间。这种方式的问题很明显，以系统API调用的平均响应时间为例：如果大多数API请求都维持在100ms的响应时间范围内，而个别请求的响应时间需要5s，那么就会导致某些WEB页面的响应时间落到中位数的情况，而这种现象被称为长尾问题。

为了区分是平均的慢还是长尾的慢，最简单的方式就是按照请求延迟的范围进行分组。例如，统计延迟在0~10ms之间的请求数有多少而10~20ms之间的请求数又有多少。通过这种方式可以快速分析系统慢的原因。Histogram和Summary都是为了能够解决这样问题的存在，通过Histogram和Summary类型的监控指标，我们可以快速了解监控样本的分布情况。

例如，指标prometheus_tsdb_wal_fsync_duration_seconds的指标类型为Summary。 它记录了Prometheus Server中wal_fsync处理的处理时间，通过访问Prometheus Server的/metrics地址，可以获取到以下监控样本数据：

```
# HELP prometheus_tsdb_wal_fsync_duration_seconds Duration of WAL fsync.
# TYPE prometheus_tsdb_wal_fsync_duration_seconds summary
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.5"} 0.012352463
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.9"} 0.014458005
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.99"} 0.017316173
prometheus_tsdb_wal_fsync_duration_seconds_sum 2.888716127000002
prometheus_tsdb_wal_fsync_duration_seconds_count 216
```



从上面的样本中可以得知当前Prometheus Server进行wal_fsync操作的总次数为216次，耗时2.888716127000002s。其中中位数（quantile=0.5）的耗时为0.012352463，9分位数（quantile=0.9）的耗时为0.014458005s。

在Prometheus Server自身返回的样本数据中，我们还能找到类型为Histogram的监控指标prometheus_tsdb_compaction_chunk_range_bucket。



```
# HELP prometheus_tsdb_compaction_chunk_range Final time range of chunks on their first compaction
# TYPE prometheus_tsdb_compaction_chunk_range histogram
prometheus_tsdb_compaction_chunk_range_bucket{le="100"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="400"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="1600"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="6400"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="25600"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="102400"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="409600"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="1.6384e+06"} 260
prometheus_tsdb_compaction_chunk_range_bucket{le="6.5536e+06"} 780
prometheus_tsdb_compaction_chunk_range_bucket{le="2.62144e+07"} 780
prometheus_tsdb_compaction_chunk_range_bucket{le="+Inf"} 780
prometheus_tsdb_compaction_chunk_range_sum 1.1540798e+09
prometheus_tsdb_compaction_chunk_range_count 780
```

与Summary类型的指标相似之处在于Histogram类型的样本同样会反应当前指标的记录的总数(以_count作为后缀)以及其值的总量（以_sum作为后缀）。不同在于Histogram指标直接反应了在不同区间内样本的个数，区间通过标签len进行定义。

同时对于Histogram的指标，我们还可以通过histogram_quantile()函数计算出其值的分位数。不同在于Histogram通过histogram_quantile函数是在服务器端计算的分位数。 而Sumamry的分位数则是直接在客户端计算完成。因此对于分位数的计算而言，Summary在通过PromQL进行查询时有更好的性能表现，而Histogram则会消耗更多的资源。反之对于客户端而言Histogram消耗的资源更少。在选择这两种方式时用户应该按照自己的实际场景进行选择。



## install prometheus

helm https://artifacthub.io/packages/helm/prometheus-community/prometheus

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kube-state-metrics https://kubernetes.github.io/kube-state-metrics
helm repo update

helm install prometheus prometheus-community/prometheus --set alertmanager.enabled=false --set persistentVolume.enabled=false

helm show values prometheus-community/prometheus > value.yaml

```





## golang project 集成 prometheus

- [Installation](https://prometheus.io/docs/guides/go-application/#installation)
- [How Go exposition works](https://prometheus.io/docs/guides/go-application/#how-go-exposition-works)
- [Adding your own metrics](https://prometheus.io/docs/guides/go-application/#adding-your-own-metrics)
- [Other Go client features](https://prometheus.io/docs/guides/go-application/#other-go-client-features)
- [Summary](https://prometheus.io/docs/guides/go-application/#summary)

Prometheus has an official [Go client library](https://github.com/prometheus/client_golang) that you can use to instrument Go applications. In this guide, we'll create a simple Go application that exposes Prometheus metrics via HTTP.

**NOTE:** For comprehensive API documentation, see the [GoDoc](https://godoc.org/github.com/prometheus/client_golang) for Prometheus' various Go libraries.



### Installation

You can install the `prometheus`, `promauto`, and `promhttp` libraries necessary for the guide using [`go get`](https://golang.org/doc/articles/go_command.html):

```
go get github.com/prometheus/client_golang/prometheus
go get github.com/prometheus/client_golang/prometheus/promauto
go get github.com/prometheus/client_golang/prometheus/promhttp
```

### How Go exposition works

To expose Prometheus metrics in a Go application, you need to provide a `/metrics` HTTP endpoint. You can use the [`prometheus/promhttp`](https://godoc.org/github.com/prometheus/client_golang/prometheus/promhttp) library's HTTP [`Handler`](https://godoc.org/github.com/prometheus/client_golang/prometheus/promhttp#Handler) as the handler function.

This minimal application, for example, would expose the default metrics for Go applications via `http://localhost:2112/metrics`:

```
package main

import (
        "net/http"

        "github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
        http.Handle("/metrics", promhttp.Handler())
        http.ListenAndServe(":2112", nil)
}
```

To start the application:

```
go run main.go
```

To access the metrics:

```
curl http://localhost:2112/metrics
```

### Adding your own metrics

The application [above](https://prometheus.io/docs/guides/go-application/#how-go-exposition-works) exposes only the default Go metrics. You can also register your own custom application-specific metrics. This example application exposes a `myapp_processed_ops_total` [counter](https://prometheus.io/docs/concepts/metric_types/#counter) that counts the number of operations that have been processed thus far. Every 2 seconds, the counter is incremented by one.

```
package main

import (
        "net/http"
        "time"

        "github.com/prometheus/client_golang/prometheus"
        "github.com/prometheus/client_golang/prometheus/promauto"
        "github.com/prometheus/client_golang/prometheus/promhttp"
)

func recordMetrics() {
        go func() {
                for {
                        opsProcessed.Inc()
                        time.Sleep(2 * time.Second)
                }
        }()
}

var (
        opsProcessed = promauto.NewCounter(prometheus.CounterOpts{
                Name: "myapp_processed_ops_total",
                Help: "The total number of processed events",
        })
)

func main() {
        recordMetrics()

        http.Handle("/metrics", promhttp.Handler())
        http.ListenAndServe(":2112", nil)
}
```

To run the application:

```
go run main.go
```

To access the metrics:

```
curl http://localhost:2112/metrics
```

In the metrics output, you'll see the help text, type information, and current value of the `myapp_processed_ops_total` counter:

我们利用`promauto`包提供的`NewCounter`方法定义了一个Counter类型的监控指标，只需要填充名字以及帮助信息，该指标就创建完成了。需要注意的是，Counter类型数据的名字要尽量以`_total`作为后缀。否则当Prometheus与其他系统集成时，可能会出现指标无法识别的问题。每当有请求访问根目录时，该指标就会调用`Inc()`方法加一，当然，我们也可以调用`Add()`方法累加任意的非负数。

再次运行修改后的程序，先对根路径进行多次访问，再对`/metrics`路径进行访问，可以看到新定义的指标已经成功暴露了：

```
# HELP myapp_processed_ops_total The total number of processed events
# TYPE myapp_processed_ops_total counter
myapp_processed_ops_total 5
```

You can [configure](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config) a locally running Prometheus instance to scrape metrics from the application. Here's an example `prometheus.yml` configuration:

```
scrape_configs:
- job_name: myapp
  scrape_interval: 10s
  static_configs:
  - targets:
    - localhost:2112
```



### Gauge example

监控累积的请求处理显然还是不够的，通常我们还想知道当前正在处理的请求的数量。Prometheus中的Gauge类型数据，与Counter不同，它既能增大也能变小。将正在处理的请求数量定义为Gauge类型是合适的。因此，我们新增的代码块如下：

```
...
var (
	...
	http_request_in_flight = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name:	"http_request_in_flight",
			Help:	"Current number of http requests in flight",
		},
	)
)
...
http.HandleFunc("/", func(http.ResponseWriter, *http.Request){
	http_request_in_flight.Inc()
	defer http_request_in_flight.Dec()
	http_request_total.Inc()
})
...
```



Gauge和Counter类型的数据操作起来的差别并不大，唯一的区别是Gauge支持`Dec()`或者`Sub()`方法减小指标的值。

### Histogram example

对于一个网络服务来说，能够知道它的平均时延是重要的，不过很多时候我们更想知道响应时间的分布状况。Prometheus中的Histogram类型就对此类需求提供了很好的支持。具体到需要新增的代码如下：

```
...
var (
	...
	http_request_duration_seconds = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:		"http_request_duration_seconds",
			Help:		"Histogram of lantencies for HTTP requests",
			// Buckets:	[]float64{.1, .2, .4, 1, 3, 8, 20, 60, 120},
		},
	)
)
...
http.HandleFunc("/", func(http.ResponseWriter, *http.Request){
	now := time.Now()

	http_request_in_flight.Inc()
	defer http_request_in_flight.Dec()
	http_request_total.Inc()
	
	time.Sleep(time.Duration(rand.Intn(1000)) * time.Millisecond)

	http_request_duration_seconds.Observe(time.Since(now).Seconds())
})
...
```



在访问了若干次上述HTTP Server的根路径之后，从`/metrics`路径得到的响应如下：

```
# HELP http_request_duration_seconds Histogram of lantencies for HTTP requests
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.005"} 0
http_request_duration_seconds_bucket{le="0.01"} 0
http_request_duration_seconds_bucket{le="0.025"} 0
http_request_duration_seconds_bucket{le="0.05"} 0
http_request_duration_seconds_bucket{le="0.1"} 3
http_request_duration_seconds_bucket{le="0.25"} 3
http_request_duration_seconds_bucket{le="0.5"} 5
http_request_duration_seconds_bucket{le="1"} 8
http_request_duration_seconds_bucket{le="2.5"} 8
http_request_duration_seconds_bucket{le="5"} 8
http_request_duration_seconds_bucket{le="10"} 8
http_request_duration_seconds_bucket{le="+Inf"} 8
http_request_duration_seconds_sum 3.238809838
http_request_duration_seconds_count 8
```



Histogram类型暴露的监控数据要比Counter和Gauge复杂得多，最后以`_sum`和`_count`开头的指标分别表示总的响应时间以及对于响应时间的计数。而它们之上的若干行表示：时延在0.005秒内的响应数目，0.01秒内的响应次数，0.025秒内的响应次数...最后的`+Inf`表示响应时间无穷大的响应次数，它的值和`_count`的值是相等的。显然，Histogram类型的监控数据很好地呈现了数据的分布状态。当然，Histogram默认的边界设置，例如0.005,0.01这类数值一般是用来衡量一个网络服务的时延的。对于具体的应用场景，我们也可以对它们进行自定义，类似于上述代码中被注释掉的那一行（最后的`+Inf`会自动添加）。

与Histogram类似，Prometheus中定义了一种类型Summary，从另一个角度描绘了数据的分布状况。对于响应时延，我们可能想知道它们的中位数是多少？九分位数又是多少？对于Summary类型数据的定义及使用如下：

```
...
var (
	...
	http_request_summary_seconds = promauto.NewSummary(
		prometheus.SummaryOpts{
			Name:	"http_request_summary_seconds",
			Help:	"Summary of lantencies for HTTP requests",
			// Objectives: map[float64]float64{0.5: 0.05, 0.9: 0.01, 0.99: 0.001, 0.999, 0.0001},
		},
	)
)
...
http.HandleFunc("/", func(http.ResponseWriter, *http.Request){
	now := time.Now()

	http_request_in_flight.Inc()
	defer http_request_in_flight.Dec()
	http_request_total.Inc()

	time.Sleep(time.Duration(rand.Intn(1000)) * time.Millisecond)

	http_request_duration_seconds.Observe(time.Since(now).Seconds())
	http_request_summary_seconds.Observe(time.Since(now).Seconds())
})
...
```



Summary的定义和使用与Histogram是类似的，最终我们得到的结果如下：

```
$ curl http://127.0.0.1:8080/metrics | grep http_request_summary
# HELP http_request_summary_seconds Summary of lantencies for HTTP requests
# TYPE http_request_summary_seconds summary
http_request_summary_seconds{quantile="0.5"} 0.31810446
http_request_summary_seconds{quantile="0.9"} 0.887116164
http_request_summary_seconds{quantile="0.99"} 0.887116164
http_request_summary_seconds_sum 3.2388269649999994
http_request_summary_seconds_count 8
```

同样，`_sum`和`_count`分别表示请求的总时延以及请求的数目，与Histogram不同的是，Summary其余的部分分别表示，响应时间的中位数是0.31810446秒，九分位数位0.887116164等等。我们也可以根据具体的需求对Summary呈现的分位数进行自定义，如上述程序中被注释的Objectives字段。令人疑惑的是，它是一个map类型，其中的key表示的是分位数，而value表示的则是误差。例如，上述的0.31810446秒是分布在响应数据的0.45~0.55之间的，而并非完美地落在0.5。

事实上，上述的Counter，Gauge，Histogram，Summary就是Prometheus能够支持的全部监控数据类型了（其实还有一种类型Untyped，表示未知类型）。一般使用最多的是Counter和Gauge这两种基本类型，结合PromQL对基础监控数据强大的分析处理能力，我们就能获取极其丰富的监控信息。

不过，有的时候，我们可能希望从更多的特征维度去衡量一个指标。例如，对于接收到的HTTP请求的数目，我们可能希望知道具体到每个路径接收到的请求数目。假设当前能够访问`/`和`/foo`目录，显然定义两个不同的Counter，比如http_request_root_total和http_request_foo_total，并不是一个很好的方法。一方面扩展性比较差：如果定义更多的访问路径就需要创建更多新的监控指标，同时，我们定义的特征维度往往不止一个，可能我们想知道某个路径且返回码为XXX的请求数目是多少，这种方法就无能为力了；另一方面，PromQL也无法很好地对这些指标进行聚合分析。

Prometheus对于此类问题的方法是为指标的每个特征维度定义一个label，一个label本质上就是一组键值对。一个指标可以和多个label相关联，而一个指标和一组具体的label可以唯一确定一条时间序列。对于上述分别统计每条路径的请求数目的问题，标准的Prometheus的解决方法如下：

```
...
var (
	http_request_total = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name:	"http_request_total",
			Help:	"The total number of processed http requests",
		},
		[]string{"path"},
	)
...
	http.HandleFunc("/", func(http.ResponseWriter, *http.Request){
		...
		http_request_total.WithLabelValues("root").Inc()
		...
	})

	http.HandleFunc("/foo", func(http.ResponseWriter, *http.Request){
		...
		http_request_total.WithLabelValues("foo").Inc()
		...
	})
)
```



此处以Counter类型的数据举例，对于其他另外三种数据类型的操作是完全相同的。此处我们在调用`NewCounterVec`方法定义指标时，我们定义了一个名为`path`的label，在`/`和`/foo`的Handler中，`WithLabelValues`方法分别指定了label的值为`root`和`foo`，如果该值对应的时间序列不存在，则该方法会新建一个，之后的操作和普通的Counter指标没有任何不同。而最终通过`/metrics`暴露的结果如下：

```
$ curl http://127.0.0.1:8080/metrics | grep http_request_total
# HELP http_request_total The total number of processed http requests
# TYPE http_request_total counter
http_request_total{path="foo"} 9
http_request_total{path="root"} 5
```

可以看到，此时指标`http_request_total`对应两条时间序列，分别表示path为`foo`和`root`时的请求数目。那么如果我们反过来想统计，各个路径的请求总和呢？我们是否需要定义个path的值为`total`，用来表示总体的计数情况？显然是不必的，PromQL能够轻松地对一个指标的各个维度的数据进行聚合，通过如下语句查询Prometheus就能获得请求总和：

```
sum(http_request_total)
```

label在Prometheus中是一个简单而强大的工具，理论上，Prometheus没有限制一个指标能够关联的label的数目。但是，label的数目也并不是越多越好，因为每增加一个label，用户在使用PromQL的时候就需要额外考虑一个label的配置。一般来说，我们要求添加了一个label之后，对于指标的求和以及求均值都是有意义的



### 2. 进阶

基于上文所描述的内容，我们就能很好地在自己的应用程序里面定义各种监控指标并且保证它能被Prometheus接收处理了。但是有的时候我们可能需要更强的定制化能力，尽管使用高度封装的API确实很方便，不过它附加的一些东西可能不是我们想要的，比如默认的Handler提供的Golang运行时相关以及进程相关的一些监控指标。另外，当我们自己编写Exporter的时候，该如何利用已有的组件，将应用原生的监控指标转化为符合Prometheus标准的指标。为了解决上述问题，我们有必要对Prometheus SDK内部的实现机理了解地更为深刻一些。

在Prometheus SDK中，Register和Collector是两个核心对象。Collector里面可以包含一个或者多个Metric，它事实上是一个Golang中的interface，提供如下两个方法：

```
type Collector interface {
	Describe(chan<- *Desc)
	
	Collect(chan<- Metric)
}
```

简单地说，Describe方法通过channel能够提供该Collector中每个Metric的描述信息，Collect方法则通过channel提供了其中每个Metric的具体数据。单单定义Collector还是不够的，我们还需要将其注册到某个Registry中，Registry会调用它的Describe方法保证新添加的Metric和之前已经存在的Metric并不冲突。而Registry则需要和具体的Handler相关联，这样当用户访问`/metrics`路径时，Handler中的Registry会调用已经注册的各个Collector的Collect方法，获取指标数据并返回。

在上文中，我们定义一个指标如此方便，根本原因是`promauto`为我们做了大量的封装，例如，对于我们使用的`promauto.NewCounter`方法，其具体实现如下：

```
http_request_total = promauto.NewCounterVec(
	prometheus.CounterOpts{
		Name:	"http_request_total",
		Help:	"The total number of processed http requests",
	},
	[]string{"path"},
)
---
// client_golang/prometheus/promauto/auto.go
func NewCounterVec(opts prometheus.CounterOpts, labelNames []string) *prometheus.CounterVec {
	c := prometheus.NewCounterVec(opts, labelNames)
	prometheus.MustRegister(c)
	return c
}
---
// client_golang/prometheus/counter.go
func NewCounterVec(opts CounterOpts, labelNames []string) *CounterVec {
	desc := NewDesc(
		BuildFQName(opts.Namespace, opts.Subsystem, opts.Name),
		opts.Help,
		labelNames,
		opts.ConstLabels,
	)
	return &CounterVec{
		metricVec: newMetricVec(desc, func(lvs ...string) Metric {
			if len(lvs) != len(desc.variableLabels) {
				panic(makeInconsistentCardinalityError(desc.fqName, desc.variableLabels, lvs))
			}
			result := &counter{desc: desc, labelPairs: makeLabelPairs(desc, lvs)}
			result.init(result) // Init self-collection.
			return result
		}),
	}
}
```

一个Counter（或者CounterVec，即包含label的Counter）其实就是一个Collector的具体实现，它的Describe方法提供的描述信息，无非就是指标的名字，帮助信息以及定义的Label的名字。`promauto`在对它完成定义之后，还调用`prometheus.MustRegister(c)`进行了注册。事实上，prometheus默认提供了一个Default Registry，`prometheus.MustRegister`会将Collector直接注册到Default Registry中。如果我们直接使用了`promhttp.Handler()`来处理`/metrics`路径的请求，它会直接将Default Registry和Handler相关联并且向Default Registry注册Golang Collector和Process Collector。所以，假设我们不需要这些自动注入的监控指标，只要构造自己的Handler就可以。

当然，Registry和Collector也都是能自定义的，特别在编写Exporter的时候，我们往往会将所有的指标定义在一个Collector中，根据访问应用原生监控接口的结果对所需的指标进行填充并返回结果。基于上述对于Prometheus SDK的实现机制的理解，我们可以实现一个最简单的Exporter框架如下所示：

```
package main

import (
	"net/http"
	"math/rand"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type Exporter struct {
	up	*prometheus.Desc
}

func NewExporter() *Exporter {
	namespace := "exporter"
	up := prometheus.NewDesc(prometheus.BuildFQName(namespace, "", "up"), "If scrape target is healthy", nil, nil)
	return &Exporter{
		up:	up,
	}
}

func (e *Exporter) Describe(ch chan<- *prometheus.Desc) {
	ch <- e.up
}

func (e *Exporter) Scrape() (up float64) {
	// Scrape raw monitoring data from target, may need to do some data format conversion here
	rand.Seed(time.Now().UnixNano())
	return float64(rand.Intn(2))
}

func (e *Exporter) Collect(ch chan<- prometheus.Metric) {
	up := e.Scrape()
	ch <- prometheus.MustNewConstMetric(e.up, prometheus.GaugeValue, up)
}

func main() {
	registry := prometheus.NewRegistry()

	exporter := NewExporter()

	registry.Register(exporter)

	http.Handle("/metrics", promhttp.HandlerFor(registry, promhttp.HandlerOpts{}))
	http.ListenAndServe(":8080", nil)
}
```

在这个Exporter的最简实现中，我们创建了新的Registry，手动对exporter这个Collector完成了注册并且基于这个Registry自己构建了一个Handler并且与`/metrics`相关联。在初始exporter的时候，我们仅仅需要调用`NewDesc()`方法填充需要监控的指标的描述信息。当用户访问`/metrics`路径时，经过完整的调用链，最后在进行Collect的时候，我们才会对应用的原生监控接口进行访问，获取监控数据。在真实的Exporter实现中，该步骤应该在`Scrape()`方法中完成。最后，根据返回的原生监控数据，利用`MustNewConstMetric()`构造出我们所需的Metric，返回给channel即可。访问该Exporter的`/metrics`得到的结果如下：

```
$ curl http://127.0.0.1:8080/metrics
# HELP exporter_up If scrape target is healthy
# TYPE exporter_up gauge
exporter_up 1
```



### Other Go client features

In this guide we covered just a small handful of features available in the Prometheus Go client libraries. You can also expose other metrics types, such as [gauges](https://godoc.org/github.com/prometheus/client_golang/prometheus#Gauge) and [histograms](https://godoc.org/github.com/prometheus/client_golang/prometheus#Histogram), [non-global registries](https://godoc.org/github.com/prometheus/client_golang/prometheus#Registry), functions for [pushing metrics](https://godoc.org/github.com/prometheus/client_golang/prometheus/push) to Prometheus [PushGateways](https://prometheus.io/docs/instrumenting/pushing/), bridging Prometheus and [Graphite](https://godoc.org/github.com/prometheus/client_golang/prometheus/graphite), and more.

### Summary

In this guide, you created two sample Go applications that expose metrics to Prometheus---one that exposes only the default Go metrics and one that also exposes a custom Prometheus counter---and configured a Prometheus instance to scrape metrics from those applications.





## 添加数据采集任务

当服务运行起来之后，需要进行如下操作让 Prometheus 监控服务发现并采集监控指标：

1. 使用lens 选择对应 Prometheus 实例进入管理页面。
2. 点击 【Custom Resource】 ---> 【monitoring.coreos.com】---->
3. 通过服务发现添加 `Service Monitor`，目前支持基于 `Labels` 发现对应的目标实例地址，因此可以对一些服务添加特定的 `K8S Labels`，可以使 `Labels` 下的服务都会被 Prometheus 服务自动识别出来，不需要再为每个服务一一添加采取任务，以上面的例子配置信息如下：

```
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: go-demo    # 填写一个唯一名称
  namespace: cm-prometheus  # namespace固定，不要修改
spec:
  endpoints:
  - interval: 30s
    # 填写service yaml中Prometheus Exporter对应的Port的Name
    port: 2112
    # 填写Prometheus Exporter对应的Path的值，不填默认/metrics
    path: /metrics
    relabelings:
    # ** 必须要有一个 label 为 application，这里假设 k8s 有一个 label 为 app，
    # 我们通过 relabel 的 replace 动作把它替换成了 application
    - action: replace
      sourceLabels:  [__meta_kubernetes_pod_label_app]
      targetLabel: application
  # 选择要监控service所在的namespace
  namespaceSelector:
    matchNames:
    - golang-demo
    # 填写要监控service的Label值，以定位目标service
  selector:
    matchLabels:
      app: golang-app-demo
```



## 项目实战

github address: https://github.com/chenjiandongx/ginprom



| label |      |      |
| ----- | ---- | ---- |
|       |      |      |
|       |      |      |
|       |      |      |



```
package prometheus

import (
	"fmt"
	"net/http"
	"regexp"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
)

const namespace = "service"

var (
	labels = []string{"status", "endpoint", "method"}

	uptime = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: namespace,
			Name:      "uptime",
			Help:      "HTTP service uptime.",
		}, nil,
	)

	reqCount = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: namespace,
			Name:      "http_request_count_total",
			Help:      "Total number of HTTP requests made.",
		}, labels,
	)

	reqDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Namespace: namespace,
			Name:      "http_request_duration_seconds",
			Help:      "HTTP request latencies in seconds.",
		}, labels,
	)

	reqSizeBytes = prometheus.NewSummaryVec(
		prometheus.SummaryOpts{
			Namespace: namespace,
			Name:      "http_request_size_bytes",
			Help:      "HTTP request sizes in bytes.",
		}, labels,
	)

	respSizeBytes = prometheus.NewSummaryVec(
		prometheus.SummaryOpts{
			Namespace: namespace,
			Name:      "http_response_size_bytes",
			Help:      "HTTP response sizes in bytes.",
		}, labels,
	)
)

// init registers the prometheus metrics
func init() {
	prometheus.MustRegister(uptime, reqCount, reqDuration, reqSizeBytes, respSizeBytes)
	go recordUptime()
}

// recordUptime increases service uptime per second.
func recordUptime() {
	for range time.Tick(time.Second) {
		uptime.WithLabelValues().Inc()
	}
}

// calcRequestSize returns the size of request object.
func calcRequestSize(r *http.Request) float64 {
	size := 0
	if r.URL != nil {
		size = len(r.URL.String())
	}

	size += len(r.Method)
	size += len(r.Proto)

	for name, values := range r.Header {
		size += len(name)
		for _, value := range values {
			size += len(value)
		}
	}
	size += len(r.Host)

	// r.Form and r.MultipartForm are assumed to be included in r.URL.
	if r.ContentLength != -1 {
		size += int(r.ContentLength)
	}
	return float64(size)
}

type RequestLabelMappingFn func(c *gin.Context) string

// PromOpts represents the Prometheus middleware Options.
// It is used for filtering labels by regex.
type PromOpts struct {
	ExcludeRegexStatus     string
	ExcludeRegexEndpoint   string
	ExcludeRegexMethod     string
	EndpointLabelMappingFn RequestLabelMappingFn
}

// NewDefaultOpts return the default ProOpts
func NewDefaultOpts() *PromOpts {
	return &PromOpts{
		EndpointLabelMappingFn: func(c *gin.Context) string {
			//by default do nothing, return URL as is
			return c.Request.URL.Path
		},
	}
}

// checkLabel returns the match result of labels.
// Return true if regex-pattern compiles failed.
func (po *PromOpts) checkLabel(label, pattern string) bool {
	if pattern == "" {
		return true
	}

	matched, err := regexp.MatchString(pattern, label)
	if err != nil {
		return true
	}
	return !matched
}

// PromMiddleware returns a gin.HandlerFunc for exporting some Web metrics
func PromMiddleware(promOpts *PromOpts) gin.HandlerFunc {
	// make sure promOpts is not nil
	if promOpts == nil {
		promOpts = NewDefaultOpts()
	}

	// make sure EndpointLabelMappingFn is callable
	if promOpts.EndpointLabelMappingFn == nil {
		promOpts.EndpointLabelMappingFn = func(c *gin.Context) string {
			return c.Request.URL.Path
		}
	}

	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		status := fmt.Sprintf("%d", c.Writer.Status())
		endpoint := promOpts.EndpointLabelMappingFn(c)
		method := c.Request.Method

		lvs := []string{status, endpoint, method}

		isOk := promOpts.checkLabel(status, promOpts.ExcludeRegexStatus) &&
			promOpts.checkLabel(endpoint, promOpts.ExcludeRegexEndpoint) &&
			promOpts.checkLabel(method, promOpts.ExcludeRegexMethod)

		if !isOk {
			return
		}
		// no response content will return -1
		respSize := c.Writer.Size()
		if respSize < 0 {
			respSize = 0
		}
		reqCount.WithLabelValues(lvs...).Inc()
		reqDuration.WithLabelValues(lvs...).Observe(time.Since(start).Seconds())
		reqSizeBytes.WithLabelValues(lvs...).Observe(calcRequestSize(c.Request))
		respSizeBytes.WithLabelValues(lvs...).Observe(float64(respSize))
	}
}
```

