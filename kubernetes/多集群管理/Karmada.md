[toc]

#  Karmada

[Kamada](https://github.com/karmada-io/karmada) 是华为主导的开源 kubernetes 多云容器编排管理系统，可以跨多个kubernets集群和云运行你的云原生应用程序，而无需更改应用程序。通过kubernetes原声API并提供高级调度功能，Karmada可以实现真正的开放式多云集群管理。



## 1. 特性

- 兼容k8s 原生API
- 开箱即用
- 避免锁定供应商
- 集中化管理
- 高效的多集群调度策略
- 开放和中立



## 2. 架构

![image-20210428111218417](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/031220.png)

- ETCD：存储Karmada API对象。

- Karmada Scheduler：提供高级的多集群调度策略。

- Karmada Controller Manager: 包含多个Controller，Controller监听karmada对象并且与成员集群API server进行通信并创建成员集群的k8s对象。

  - Cluster Controller：成员集群的生命周期管理与对象管理。

  - Policy Controller：监听PropagationPolicy对象，创建ResourceBinding，配置资源分发策略。

  - Binding Controller：监听ResourceBinding对象，并创建work对象响应资源清单。

  - Execution Controller：监听work对象，并将资源分发到成员集群中。

    

### 2.1 控制面组件

- Karmada API server

- karmada scheduler

- karmada controller manager

  

  ETCD stores the karmada API objects, the API Server is the REST endpoint all other components talk to, and the Karmada Controller Manager perform operations based on the API objects you create through the API server.

  The Karmada Controller Manager runs the various controllers, the controllers watch karmada objects and then talk to the underlying clusters’ API servers to create regular Kubernetes resources.

  1. Cluster Controller: attach kubernetes clusters to Karmada for managing the lifecycle of the clusters by creating cluster object.
  2. Policy Controller: the controller watches PropagationPolicy objects. When PropagationPolicy object is added, it selects a group of resources matching the resourceSelector and create ResourceBinding with each single resource object.
  3. Binding Controller: the controller watches ResourceBinding object and create Work object corresponding to each cluster with single resource manifest.
  4. Execution Controller: the controller watches Work objects.When Work objects are created, it will distribute the resources to member clusters.

ETCD存储karmada API 对象，API 服务是其他组件通信的REST 终端，karmada 控制器执行操作的对象是基于用户通过API server创建的。

- 集群控制器： 将集群附着到 Karmada控制器，通过创建集群对象来管理集群的生命周期

- 策略控制器

- 角色绑定

- 执行控制器

  




## 3. 资源分发流程

**基本概念**

- 资源模板（Resource Template）：Karmada使用K8s原生API定义作为资源模板，便于快速对接K8s生态工具链。
- 分发策略（Propagaion Policy）：Karmada提供独立的策略API，用来配置资源分发策略。
- 差异化策略（Override Policy）：Karmada提供独立的差异化API，用来配置与集群相关的差异化配置。比如配置不同集群使用不同的镜像。



![image-20220623092105072](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20220623092105072.png)

## 4. 重要特性





## 5. roadmap



## 6. issue



