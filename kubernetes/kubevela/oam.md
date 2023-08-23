## 1. 什么是OAM ？
OAM（open application model), 是一种新的服务治理规范。其核心诉求是将开发，运维和基础设施管理人员的职责分离。开发人员负责描述微服务或组件的功能，
以及如何配置它；运维负责配置其中一个或多个微服务的运行时环境；基础设施工程师负责建立和维护应用程序运行的基础设施。
Github 项目地址：https://github.com/oam-dev/spec

OAM 模型中包含以下基本对象:
- Workload 模型参照 Kubernetes 规范定义，理论上，平台商可以定义如容器、Pod、Serverless 函数、虚拟机、数据库、消息队列等任何类型的 Workload。
- Component：OAM 中最基础的对象，该配置与基础设施无关，定义负载实例的运维特性。例如一个微服务 workload 的定义。
- TraitDefinition：一个组件所需的运维策略与配置，例如环境变量、Ingress、AutoScaler、Volume 等
- ScopeDefinition：多个 Component 的共同边界。可以根据组件的特性或者作用域来划分 Scope，一个 Component 可能同时属于多个 Scope。
- ApplicationConfiguration：将 Component（必须）、Trait（必须）、Scope（非必须）等组合到一起形成一个完整的应用配置。

![oam-arch](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/161607.png)


## 2. oam-kubernetes-runtime
该项目是kubernetes官方对OAM支持的插件，git地址：: https://github.com/crossplane/oam-kubernetes-runtime
OAM Kubernetes Runtime 实现了OAM规范，为任意kubernetes 暴露以应用程序为中心的API。
其最终目的是在kubernetes 上构建OAM平台，用户可以通过OAM中熟悉的概念去创建应用。

## 3. oam-kubernetes-runtime 实践
### 3.1 install crd
```
kubectl apply -f https://github.com/crossplane/oam-kubernetes-runtime/tree/master/charts/oam-kubernetes-runtime/crds
```

### 3.2 注册trait, workload
```yaml
apiVersion: core.oam.dev/v1alpha2
kind: TraitDefinition
metadata:
  name: manualscalertraits.core.oam.dev
spec:
  workloadRefPath: spec.workloadRef
  definitionRef:
    name: manualscalertraits.core.oam.dev
```

```yaml
apiVersion: core.oam.dev/v1alpha2
kind: WorkloadDefinition
metadata:
  name: containerizedworkloads.core.oam.dev
spec:
  definitionRef:
    name: containerizedworkloads.core.oam.dev
  childResourceKinds:
    - apiVersion: apps/v1
      kind: Deployment
    - apiVersion: v1
      kind: Service
    - apiVersion: apps/v1
      kind: StatefulSet
```

### 3.3 创建component
```yaml
apiVersion: core.oam.dev/v1alpha2
kind: Component
metadata:
  name: example-component
spec:
  workload:
    apiVersion: core.oam.dev/v1alpha2
    kind: ContainerizedWorkload
    spec:
      containers:
        - name: wordpress
          image: wordpress:4.6.1-apache
          ports:
            - containerPort: 80
              name: wordpress
          env:
            - name: TEST_ENV
              value: test
  parameters:
    - name: instance-name
      required: true
      fieldPaths:
        - metadata.name
    - name: image
      fieldPaths:
        - spec.containers[0].image
```

### 3.4 创建applicationConfigComponent
```yaml
apiVersion: core.oam.dev/v1alpha2
kind: ApplicationConfiguration
metadata:
  name: example-appconfig
spec:
  components:
    - componentName: example-component
      parameterValues:
        - name: instance-name
          value: example-appconfig-workload1
        - name: image
          value: wordpress:php7.2
      traits:
        - trait:
            apiVersion: core.oam.dev/v1alpha2
            kind: ManualScalerTrait
            metadata:
              name: example-appconfig-trait
            spec:
              replicaCount: 2
```
## 4.oam-kubernetes-runtime 工作流程
### 4.1 注册 trait 和 workload
通过 TraitDefinition 和 WorkloadDefinition 可以注册运维特征和工作负载，这里的trait可以是oam-kubernetes-runtime提供manualscalertraits，
也可以是你自己写的trait。 workloadDefinition 可以是deployment， statefulSet 或者是 oam-kubernetes-runtime提供的ContainerizedWorkload

### 4.2component 配置workload
一个component只能配置一个workload

假设你的component是一个deployment， 那么在component.spec里面填写deployment即可

### 4.3applicationComponentConfig（简称appConfig）
应用配置（appConfig）创建后可以实例化所有组件（component）

这里的应用配置可以看成是多个组件组成的应用。

**appConfig 协调器工作原理**：
- 1. 转化并创建 workload对象， 如果 workload 是 ContainerizedWorkload， 则ContainerizedWorkload的控制器会根据其对象定义创建deployment和service。
- 2. 转化并创建 trait， trait 控制器发现被创建的trait，根据trait定义的属性修改workload（比如manualscalertrait控制器会去修改workload的spec.replicas)
- 3. get all workload and patch scope （比如healthScope 会去查询workload，如果都查询到了，则修改healthScope对象为health。
这里是有问题的，应该通过检查workload的status来决定是否健康）
- 4. 子资源回收机制： 1)在创建的控制里面通过Owns里面添加需要回收的子资源。 2)cleanupResources, 比如volumeTrait控制器创建了新的pvc,
然后将新创的pvc uid 和 volumeTrait Status 里面的pvc uid 做对比，如果不相同，这删除status 里面的pvc。
```go
	return ctrl.NewControllerManagedBy(mgr).
		Named(name).
		For(&oamv1alpha2.VolumeTrait{}).
		Owns(&v1.PersistentVolumeClaim{}, builder.WithPredicates(predicate.GenerationChangedPredicate{})).
		Watches(&source.Kind{Type: &oamv1alpha2.VolumeTrait{}}, &VolumeHandler{
			Client:     mgr.GetClient(),
			Logger:     log,
			AppsClient: clientappv1.NewForConfigOrDie(mgr.GetConfig()),
		}).
		Complete(r)
```

## 5. 已有的扩展插件
可以理解为非OAM Runtime必须实现的OAM插件和扩展 https://github.com/oam-dev/catalog
- trait-injector（资源注入器）
- ServiceExpose（服务导出）
- IngressTrait（Ingress）
- HPATrait（自动伸缩）
- CronHPATrait（基于Cron表达式的定时伸缩）
- MetricHPATrait（基于指标的自动伸缩）
- SimpleRolloutTrait（简单的滚动更新）
- ServiceMonitor（服务监控器，还在PR中）


## 6. 还需要添加的特性及改善点
- volumeTrait （实现WorkloadDefinition的多态）
- config && secret mount （kubevela在实现中）
- health scope 缺少对资源对象的状态检查


