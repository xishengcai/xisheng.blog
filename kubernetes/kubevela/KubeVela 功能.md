# KubeVela 功能

<!--toc-->

## 项目结构

1. CRD定义

   core.oam.dev

   V1alpha2

   V1beta1

   	- appdeployment
   	- application
   	- Approllout
   	- Cluster
   	- convertion
   	- 

2. stand.oam.dev

   - groupversion
   - Pod specworkload
   - Rollout_plan
   - Rollouttrait



## 当前支持的workload type

- webservice
- task
- Helm chart
- worker

<img src="https://tva1.sinaimg.cn/large/008i3skNly1grc5uzaw3rj31a608qago.jpg" alt="image-20210512094823808" style="zoom:50%;" />

## 当前支持的Trait

1. init-container
2. ingress
3. expose
4. scaler
5. sidecar
6. kservice



## Application

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: testapp
spec:
  components:
    - name: express-server
      properties:
        cmd:
          - node
          - server.js
        image: oamdev/testapp:v1
        port: 8080
      traits:
        - type: ingress
          properties:
            domain: test.my.domain
            http:
              "/api": 8080
      type: webservice
```





## CUE

1. kubevela 为什么要引入CUE

   为了让用户可以自己对当前任意已有的对象再抽象，因为vlea设计者认为用户的需求是时刻变化的，会一天一个样。

   CUE 可以将已有对象封装成只暴露自己想要暴露的参数。

   

   实际上，大多数社区能力虽然很强大，但对于最终用户来都比较复杂，学习和上手非常困难。所以在 KubeVela 中，它允许平台管理员对能力做进一步封装以便对用户暴露简单易用的使用接口，在绝大多数场景下，这些使用接口往往只有几个参数就足够了。在能力封装这一步，KubeVela 选择了 CUE 模板语言，来连接用户界面和后端能力对象，并且天然就支持完全动态的模板绑定（即变更模板不需要重启或者重新部署系统）。下面就是 KubeWatch Trait 的模板例子：



​		个人认为Pass 平台的参数应该是最简单，最傻瓜化。就像苹果的使用者，无需调整苹果参数，因为设计者已经将参数最优化，普适各种使用场景。



## Rollout

![img](https://kubevela.io/zh/assets/images/approllout-status-transition-78db00cbc539d19e6c5d3feeead31b16.jpg)

https://kubevela.io/zh/docs/rollout/appdeploy#cluster



## multi-cluster deployment

Modern application infrastructure involves multiple clusters to ensure high availability and maximize service throughput. In this section, we will introduce how to use KubeVela to achieve application deployment across multiple clusters with following features supported:

- Rolling Upgrade: To continuously deploy apps requires to rollout in a safe manner which usually involves step by step rollout batches and analysis.
- Traffic shifting: When rolling upgrade an app, it needs to split the traffic onto both the old and new revisions to verify the new version while preserving service availability.

```yaml
apiVersion: core.oam.dev/v1beta1
kind: AppDeployment
metadata:
  name: sample-appdeploy
spec:
  traffic:
    hosts:
      - example.com

    http:
      - match:
          # match any requests to 'example.com/example-app'
          - uri:
              prefix: "/example-app"

        # split traffic 50/50 on v1/v2 versions of the app
        weightedTargets:
          - revisionName: example-app-v1
            componentName: testsvc
            port: 80
            weight: 50
          - revisionName: example-app-v2
            componentName: testsvc
            port: 80
            weight: 50

  appRevisions:
    - # Name of the AppRevision.
      # Each modification to Application would generate a new AppRevision.
      revisionName: example-app-v1
      # Cluster specific workload placement config
      placement:
        - clusterSelector:
            # You can select Clusters by name or labels.
            # If multiple clusters is selected, one will be picked via a unique hashing algorithm.
            labels:
              tier: production
            name: prod-cluster-1
          distribution:
            replicas: 5

        - # If no clusterSelector is given, it will use the host cluster in which this CR exists
          distribution:
            replicas: 5

    - revisionName: example-app-v2
      placement:
        - clusterSelector:
            labels:
              tier: production
            name: prod-cluster-1
          distribution:
            replicas: 5
        - distribution:
            replicas: 5
```



The clusters selected in the `placement` part from above is defined in Cluster CRD. Here's what it looks like:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Cluster
metadata:
  name: prod-cluster-1
  labels:
    tier: production
spec:
  kubeconfigSecretRef:
    name: kubeconfig-cluster-1 # the secret name
```



The secret must contain the kubeconfig credentials in `config` field:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kubeconfig-cluster-1
data:
  config: ... # kubeconfig data
```



## helm charts support

vela 通过创建 helm-operator crd 实现对helm charts 的支持



## FAQ

Q1: 多集群部署的时候，为什么会有针对应用版本的副本数？和组件的副本数有冲突吗？

A：



link

​	-[vela 可以干什么](https://zhuanlan.zhihu.com/p/350336956)