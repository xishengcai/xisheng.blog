---
title: "Pod 水平自动伸缩"
date: 2020-3-26T09:05:09+08:00
draft: false
---

what is HPA
-------
  Pod 水平自动伸缩（Horizontal Pod Autoscaler）特性， 可以基于CPU利用率自动伸缩 replication controller、deployment和 replica set 中的 pod 数量，（除了 CPU 利用率）也可以 基于其他应程序提供的度量指标custom metrics。 pod 自动缩放不适用于无法缩放的对象，比如 DaemonSets。
  
  Pod 水平自动伸缩特性由 Kubernetes API 资源和控制器实现。资源决定了控制器的行为。 控制器会周期性的获取平均 CPU 利用率，并与目标值相比较后来调整 replication controller 或 deployment 中的副本数量。

### pod　水平扩缩实现机制
　HPA　是一个周期采集指标后，通过指标对比算法，得出期望pod数，然后在时间窗口内根据建议信息进行平滑扩缩。

> - 指标

  cpu, 自定义指标
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

    1.6: --horizontal-pod-autoscaler-downscale-stabilization: 这个 kube-controller-manager 的参数表示缩容冷却时间。 即自从上次缩容执行结束后，多久可以再次执行缩容，默认时间是5分钟(5m0s)。
    
    1.12 不需要参数

### 操作实践

#### 前提条件
- API aggregation layer 已开启
- 相应的 API 已注册
  - 资源指标会使用 metrics.k8s.io API，一般由 metrics-server 提供。 它可以做为集群组件启动。
  - 用户指标会使用 custom.metrics.k8s.io API。 它由其他厂商的“适配器”API 服务器提供。 确认你的指标管道，或者查看 list of known solutions。
  - 外部指标会使用 external.metrics.k8s.io API。可能由上面的用户指标适配器提供。
- --horizontal-pod-autoscaler-use-rest-clients 参数设置为 true 或者不设置。 如果设置为 false，则会切换到基于 Heapster 的自动缩放，这个特性已经被弃用了。

**deploy metric-server**

https://github.com/kubernetes-sigs/metrics-server

**deploy one deployment**
```shell script
kubectl run php-apache --image=k8s.gcr.io/hpa-example --requests=cpu=200m --expose --port=80
```

**创建 Horizontal Pod Autoscaler**
```shell script
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
kubectl get hpa
```

**add workload**
```shell script
kubectl run -i --tty load-generator --image=busybox /bin/sh

Hit enter for command prompt

while true; do wget -q -O- http://php-apache.default.svc.cluster.local; done
```

参考连接:
- https://kubernetes.io/zh/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/