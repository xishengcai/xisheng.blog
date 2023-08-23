

# K8s: Horizontal Pod Autoscaler
Pod 水平自动伸缩（Horizontal Pod Autoscaler）特性， 可以基于CPU利用率自动伸缩 replication controller、deployment和 replica set 中的 pod 数量，（除了 CPU 利用率）也可以 基于其他应程序提供的度量指标custom metrics。 pod 自动缩放不适用于无法缩放的对象，比如 DaemonSets。

Pod 水平自动伸缩特性由 Kubernetes API 资源和控制器实现。资源决定了控制器的行为。 控制器会周期性的获取平均 CPU 利用率，并与目标值相比较后来调整 replication controller 或 deployment 中的副本数量。



## pod　水平扩缩实现机制

HPA　是一个周期采集指标后，通过指标对比算法，得出期望pod数，然后在时间窗口内根据建议信息进行平滑扩缩。

> - 指标

在 Kubernetes 1.6 支持了基于多个指标进行缩放。 你可以使用 autoscaling/v2beta2 API 来为 Horizontal Pod Autoscaler 指定多个指标。 Horizontal Pod Autoscaler 会跟据每个指标计算，并生成一个缩放建议。 幅度最大的缩放建议会被采纳。


每个周期内，controller manager 根据每个 HorizontalPodAutoscaler 定义中指定的指标查询资源利用率。 controller manager 可以从 resource metrics API（每个pod 资源指标）和 custom metrics API（其他指标）获取指标。

> - 周期

由 controller manager 的 --horizontal-pod-autoscaler-sync-period 参数 指定周期（默认值为15秒）

> - 算法

从最基本的角度来看，pod 水平自动缩放控制器跟据当前指标和期望指标来计算缩放比例。

期望副本数 = ceil[当前副本数 * ( 当前指标 / 期望指标 )]

例如，当前指标为200m，目标设定值为100m,那么由于200.0 / 100.0 == 2.0， 副本数量将会翻倍。 如果当前指标为50m，副本数量将会减半，因为50.0 / 100.0 == 0.5。 如果计算出的缩放比例接近1.0（跟据--horizontal-pod-autoscaler-tolerance 参数全局配置的容忍值，默认为0.1）， 将会放弃本次缩放。

> - 异常情况

由于受技术限制，pod 水平缩放控制器无法准确的知道 pod 什么时候就绪， 也就无法决定是否暂时搁置该 pod。 --horizontal-pod-autoscaler-initial-readiness-delay 参数（默认为30s），用于设置 pod 准备时间， 在此时间内的 pod 统统被认为未就绪。 --horizontal-pod-autoscaler-cpu-initialization-period参数（默认为5分钟），用于设置 pod 的初始化时间， 在此时间内的 pod，CPU 资源指标将不会被采纳。

如果有任何 pod 的指标缺失，我们会更保守地重新计算平均值， 在需要缩小时假设这些 pod 消耗了目标值的 100%， 在需要放大时假设这些 pod 消耗了0%目标值。 这可以在一定程度上抑制伸缩的幅度。

> - 建议信息

最后，在 HPA 控制器执行缩放操作之前，会记录缩放建议信息（scale recommendation）。 控制器会在操作时间窗口中考虑所有的建议信息，并从中选择得分最高的建议。 这个值可通过 kube-controller-manager 服务的启动参数 --horizontal-pod-autoscaler-downscale-stabilization 进行配置， 默认值为 5min。 这个配置可以让系统更为平滑地进行缩容操作，从而消除短时间内指标值快速波动产生的影响。

> - 冷却/延迟

当使用 Horizontal Pod Autoscaler 管理一组副本缩放时， 有可能因为指标动态的变化造成副本数量频繁的变化，有时这被称为 *抖动*。

1.6: --horizontal-pod-autoscaler-downscale-stabilization: 这个 kube-controller-manager 的参数表示缩容冷却时间。 即自从上次缩容执行结束后，多久可以再次执行缩容，默认时间是5min。



## HPA的配置

HPA通常会根据type从aggregated APIs (metrics.k8s.io, custom.metrics.k8s.io, external.metrics.k8s.io)的资源路径上拉取metrics

HPA支持的metrics类型有4种(下述为v2beta2的格式)：

- resource

- pods

- object

- external

  ---



- resource：目前仅支持cpu和memory。target可以指定数值(targetAverageValue)和比例(targetAverageUtilization)进行扩缩容
  ```
  kind: HorizontalPodAutoscaler
  apiVersion: autoscaling/v2beta1
  metadata:
    name: app-3412287192
    namespace: app-1683527219
  spec:
    scaleTargetRef:
      kind: StatefulSet
      name: app-3412287192
      apiVersion: apps/v1
    minReplicas: 1
    maxReplicas: 3
    metrics:
      - type: Resource
        resource:
          name: memory
          targetAverageUtilization: 20
      - type: Resource
        resource:
          name: cpu
          targetAverageUtilization: 20
  ```

- pods：custom metrics，这类metrics描述了pod类型，target仅支持按指定数值(targetAverageValue)进行扩缩容。targetAverageValue 用于计算所有相关pods上的metrics的平均值
	```
  ...
	type: Pods
	pods:
	  metric:
	    name: packets-per-second
	  target:
	    type: AverageValue
	    averageValue: 1k
	```


- object：custom metrics，这类metrics描述了相同命名空间下的(非pod)类型。target支持通过value和AverageValue进行扩缩容，前者直接将metric与target比较进行扩缩容，后者通过metric相关的pod数目与target比较进行扩缩容
	```
  ...
	type: Object
	object:
	  metric:
	    name: requests-per-second
	  describedObject:
	    apiVersion: extensions/v1beta1
	    kind: Ingress
	    name: main-route
	  target:
	    type: Value
	    value: 2k
	```

- external：kubernetes 1.10+。这类metrics与kubernetes集群无关(pods和object需要与kubernetes中的某一类型关联)。与object类似，target支持通过value和AverageValue进行扩缩容。由于external会尝试匹配所有kubernetes资源的metrics，因此实际中不建议使用该类型。

	```
  ...
	- type: External
	  external:
	    metric:
	      name: queue_messages_ready
	      selector: "queue=worker_tasks"
	    target:
	      type: AverageValue
	      averageValue: 30
	```
注：target的value的一个单位可以划分为1000份，每一份以m为单位，如500m表示1/2个单位。参见Quantity

kubernetes HPA的算法如下：
```
desiredReplicas = ceil[currentReplicas * ( currentMetricValue / desiredMetricValue )]
```

当使用targetAverageValue 或targetAverageUtilization时，currentMetricValue会取HPA指定的所有pods的metric的平均值



## 操作实践

### 前提条件

- API aggregation layer 已开启
- 相应的 API 已注册
  - 资源指标会使用 metrics.k8s.io API，一般由 metrics-server 提供。 它可以做为集群组件启动。
  - 用户指标会使用 custom.metrics.k8s.io API。 它由其他厂商的“适配器”API 服务器提供。 确认你的指标管道，或者查看 list of known solutions。
  - 外部指标会使用 external.metrics.k8s.io API。可能由上面的用户指标适配器提供。
- --horizontal-pod-autoscaler-use-rest-clients 参数设置为 true 或者不设置。 如果设置为 false，则会切换到基于 Heapster 的自动缩放，这个特性已经被弃用了。

### deploy metric-server

https://github.com/kubernetes-sigs/metrics-server

```yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
```

安装后会报错，修改成如下参数
```yaml
 containers:
 - args:
 - --cert-dir=/tmp
 - --kubelet-insecure-tls
 - --secure-port=4443
 - --kubelet-preferred-address-types=InternalIP
```
一分钟后，度量服务器开始报告节点和pod的CPU和内存使用情况。

查看nodes metrics：
```
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq .
```


## 一）Resource 类型的HPA

**deploy one deployment**
```
kubectl run php-apache --image=k8s.gcr.io/hpa-example --requests=cpu=200m --expose --port=80
```

**创建 Horizontal Pod Autoscaler**

```
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
kubectl get hpa
```

**add workload**

```
kubectl run -i --tty load-generator --image=busybox /bin/sh

Hit enter for command prompt

while true; do wget -q -O- http://php-apache.default.svc.cluster.local; done
```



## 二）Customer Metric HPA

自定义metric HPA原理：
首选需要注册一个apiservice(custom metrics API)。

当HPA请求metrics时，kube-aggregator(apiservice的controller)会将请求转发到adapter，adapter作为kubernentes集群的pod，实现了Kubernetes resource metrics API 和custom metrics API，它会根据配置的rules从Prometheus抓取并处理metrics，在处理(如重命名metrics等)完后将metric通过custom metrics API返回给HPA。最后HPA通过获取的metrics的value对Deployment/ReplicaSet进行扩缩容。

adapter作为extension-apiserver(即自己实现的pod)，充当了代理kube-apiserver请求Prometheus的功能。

![](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/161204.png)


如下是k8s-prometheus-adapter apiservice的定义，kube-aggregator通过下面的service将请求转发给adapter。v1beta1.custom.metrics.k8s.io是写在k8s-prometheus-adapter代码中的，因此不能任意改变。

```
apiVersion: apiregistration.k8s.io/v1beta1
kind: APIService
metadata:
  name: v1beta1.custom.metrics.k8s.io
spec:
  service:
    name: custom-metrics-apiserver
    namespace: custom-metrics
  group: custom.metrics.k8s.io
  version: v1beta1
  insecureSkipTLSVerify: true
  groupPriorityMinimum: 100
  versionPriority: 100
```

除了基于 CPU 和内存来进行自动扩缩容之外，我们还可以根据自定义的监控指标来进行。这个我们就需要使用 Prometheus Adapter，Prometheus 用于监控应用的负载和集群本身的各种指标，Prometheus Adapter 可以帮我们使用 Prometheus 收集的指标并使用它们来制定扩展策略，这些指标都是通过 APIServer 暴露的，而且 HPA 资源对象也可以很轻易的直接使用

![](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/161207.png)

**实践目标：**
-  对开启服务网格的应用根据请求数进行自动扩缩
- 原始指标： istio_requests_total
- 采集时间间隔： 1min
- HPA中采集的指标名称：istio_requests_per_min

**思考：**
- prometheus 中是否需要添加类似 istio_request__count 的指标收集？怎么添加指标？
- HPA 是怎么锁定service级别的指标收集，而不是单个pods的？
- HPA 采样达标多久后开始执行扩容？



### 1. 根据 service 请求指标进行自动扩缩

```
cd $GOPATH
git clone https://github.com/stefanprodan/k8s-prom-hpa
```



### 2. 制作证书

```
#!/bin/bash

# 生成根秘钥及证书
openssl req -x509 -sha256 -newkey rsa:2048 -keyout ca.key -out ca.crt -days 3560 -nodes -subj '/CN=custom-metrics-apiserver LStack Authority'

# 生成服务器密钥，证书并使用CA证书签名
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/CN=custom-metrics-apiserver" -out server.csr
#echo subjectAltName = IP:oam.lstack.com.cn > extfile.cnf
#openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out server.crt -days 3650
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3650

kubectl create secret generic cm-adapter-serving-certs \
  --from-file=server.crt=server.crt \
  --from-file=server.key=server.key \
  --from-file=ca.crt=ca.crt \
  -n monitoring
```



### 3. 创建k8s-prometheus-adapter

#### 3.1 查看当前集群中的namespace 和 pod labels

![](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/161212.png)



#### 3.2 set custom metrics deployment configmap

```
    rules:
    - seriesQuery: '{__name__=~"istio_requests_total"}'
      seriesFilters: []
      resources:
        overrides:
          kubernetes_namespace:
            resource: namespace
          kubernetes_pod_name:
            resource: pod
          destination_service_name:
            resource: service
      name:
        matches: "^(.*)_total"
        as: "${1}_per_min"
      metricsQuery: sum(increase(<<.Series>>{<<.LabelMatchers>>}[1m])) by (<<.GroupBy>>)
```
- seriesQuery：查询 Prometheus 的语句，通过这个查询语句查询到的所有指标都可以用于 HPA
- seriesFilters：查询到的指标可能会存在不需要的，可以通过它过滤掉。
- resources：通过 seriesQuery 查询到的只是指标，如果需要查询某个 Pod 的指标，肯定要将它的名称和所在的命名空间作为指标的标签进行查询，resources 就是将指标的标签和 k8s 的资源类型关联起来，最常用的就是 pod 和 namespace。有两种添加标签的方式，一种是 overrides，另一种是 template。

- overrides：它会将指标中的标签和 k8s 资源关联起来。上面示例中就是将指标中的 pod 和 namespace 标签和 k8s 中的 pod 和 namespace 关联起来，因为 pod 和 namespace 都属于核心 api 组，所以不需要指定 api 组。当我们查询某个 pod 的指标时，它会自动将 pod 的名称和名称空间作为标签加入到查询条件中。比如 nginx: {group: "apps", resource: "deployment"} 这么写表示的就是将指标中 nginx 这个标签和 apps 这个 api 组中的 deployment 资源关联起来；
- template：通过 go 模板的形式。比如template: "kube_<<.Group>>_<<.Resource>>" 这么写表示，假如 <<.Group>> 为 apps，<<.Resource>> 为 deployment，那么它就是将指标中 kube_apps_deployment 标签和 deployment 资源关联起来。
- name：用来给指标重命名的，之所以要给指标重命名是因为有些指标是只增的，比如以 total 结尾的指标。这些指标拿来做 HPA 是没有意义的，我们一般计算它的速率，以速率作为值，那么此时的名称就不能以 total 结尾了，所以要进行重命名。

- matches：通过正则表达式来匹配指标名，可以进行分组
as：默认值为 $1，也就是第一个分组。as 为空就是使用默认值的意思。
- metricsQuery：这就是 Prometheus 的查询语句了，前面的 seriesQuery 查询是获得 HPA 指标。当我们要查某个指标的值时就要通过它指定的查询语句进行了。可以看到查询语句使用了速率和分组，这就是解决上面提到的只增指标的问题。

- Series：表示指标名称
- LabelMatchers：附加的标签，目前只有 pod 和 namespace 两种，因此我们要在之前使用 resources 进行关联
- GroupBy：就是 pod 名称，同样需要使用 resources 进行关联。



#### 3.3 执行部署prometheus-adapter命令

```
kubectl create -f ./custom-metrics-api
```


#### 3.4 List the custom metrics provided by Prometheus:

```
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq .
```
response:
```
{
  "kind": "APIResourceList",
  "apiVersion": "v1",
  "groupVersion": "custom.metrics.k8s.io/v1beta1",
  "resources": [
    {
      "name": "namespaces/istio_requests_per_min",
      "singularName": "",
      "namespaced": false,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    },
    {
      "name": "pods/istio_requests_per_min",
      "singularName": "",
      "namespaced": true,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    },
    {
      "name": "services/istio_requests_per_min",
      "singularName": "",
      "namespaced": true,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    }
  ]
}
```
由于我们在prometheus规则中复写了3种资源，所以这里显示同一个指标（istio_requests_per_min），对应三种资源（namespaces，pods，services）的采集



### 4.创建要自动扩缩的应用和HPA

下们我们为istio bookinfo 中的 productpage创建HPA，当productpage 服务在1分钟内请求达到100次的时候启动pod扩容机制
```
apiVersion: autoscaling/v2beta1
kind: HorizontalPodAutoscaler
metadata:
  name: productpage
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: productpage-v1
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Pods
      pods:
        metricName: istio_requests_per_min
        targetAverageValue: 100  # 只支持平均值
```



### 5.prometheus 观察 istio_requests_total 1min连接数指标

查询公式： sum(increase(istio_request_bytes_count{destination_service_name="productpage-v1"}[1m]))

![](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/161218.png)



### 6.压力测试
```
为了增加CPU使用率，请使用rakyll / hey运行负载测试：

#install hey
go get -u github.com/rakyll/hey

#do 10K requests
hey -n 10000 -q 10 -c 5 http://<ingress-gateway NodeIP> <NodePort>/productpage
```

思考解答：

1）prometheus 需要修改配置，添加 单位时间内采样指标名称和规则。

2 )  修改 prometheus-adapter 的配置文件，rules[index].resources.overrides,   其中key 是 prometheus中的label，value 是k8s中的资源名称。[详细配置请看上面的3.2]

3）自动缩放器不会立即对使用峰值做出反应。默认情况下，度量标准同步每30秒发生一次，只有在最后3-5分钟内没有重新缩放时才能进行扩展/缩小。通过这种方式，HPA可以防止快速执行冲突的决策，并为Cluster Autoscaler提供时间。



## 三）External  Metric HPA

[github 阿里云 扩展指标项目](https://github.com/AliyunContainerService/alibaba-cloud-metrics-adapter)

*参考连接:*
- [官方文档](https://kubernetes.io/zh/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)

- [自定义指标 适配器](https://github.com/DirectXMan12/k8s-prometheus-adapter/blob/master/docs/walkthrough.md)

- [开发自定义指标适配器指南](https://github.com/kubernetes-sigs/custom-metrics-apiserver/blob/master/docs/getting-started.md)

- [github HPA 测试demo](https://github.com/stefanprodan/k8s-prom-hpa)

- [custom-metrics-api 设计提案](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/custom-metrics-api.md)
