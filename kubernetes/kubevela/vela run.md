# Application 是如何转换为对应 K8s 资源对象

<!--toc-->

## 1. Application

```
# 获取集群中的 Application
$ kubectl get application
NAMESPACE   NAME   AGE
default     test   24h
```

## 2. ApplicationConfiguration 和 Component

当 application controller 获取到 Application 资源对象之后，会根据其内容创建出对应的 ApplicationConfiguration 和 Component。

```
# 获取 ApplicationConfiguration 和 Component
$ kubectl get ApplicationConfiguration,Component
NAME                                         AGE
applicationconfiguration.core.oam.dev/test   24h

NAME                           WORKLOAD-KIND   AGE
component.core.oam.dev/nginx   Deployment      24h
```

ApplicationiConfiguration 中以名字的方式引入 Component：

![3.png](https://ucc.alicdn.com/pic/developer-ecology/34831b121ab645cd97a902176383c3c9.png)

## 3. application controller

### 基本逻辑：
- 获取一个 Application 资源对象。
- 将 Application 资源对象渲染为 ApplicationConfiguration 和 Component。
- 创建 ApplicationConfiguration 和 Component 资源对象。

流程
- 起点：Application
- 中点：ApplicationConfiguration, Component
- 终点：Deployment, Service
- 路径：
  - application_controller
  - applicationconfiguration controller

### 代码：

```
// pkg/controller/core.oam.dev/v1alpha2/application/application_controller.go

// Reconcile process app event
func (r *Reconciler) Reconcile(req ctrl.Request) (ctrl.Result, error) {
  ctx := context.Background()
  applog := r.Log.WithValues("application", req.NamespacedName)
  
  // 1. 获取 Application
  app := new(v1alpha2.Application)
  if err := r.Get(ctx, client.ObjectKey{
    Name:      req.Name,
    Namespace: req.Namespace,
  }, app); err != nil {
    ...
  }

  ...

  // 2. 将 Application 转换为 ApplicationConfiguration 和 Component
  handler := &appHandler{r, app, applog}
  ...
  appParser := appfile.NewApplicationParser(r.Client, r.dm)
  ...
  appfile, err := appParser.GenerateAppFile(ctx, app.Name, app)
  ...
  ac, comps, err := appParser.GenerateApplicationConfiguration(appfile, app.Namespace)
  ...
  
  // 3. 在集群中创建 ApplicationConfiguration 和 Component 
  // apply appConfig & component to the cluster
  if err := handler.apply(ctx, ac, comps); err != nil {
    applog.Error(err, "[Handle apply]")
    app.Status.SetConditions(errorCondition("Applied", err))
    return handler.handleErr(err)
  }

  ...
  return ctrl.Result{}, r.UpdateStatus(ctx, app)
}
```

## 4. applicationconfiguration controller

### 基本逻辑：

- 获取 ApplicationConfiguration 资源对象。
- 循环遍历，获取每一个 Component 并将 workload 和 trait 渲染为对应的 K8s 资源对象。
- 创建对应的 K8s 资源对象。

### 代码：

```
// pkg/controller/core.oam.dev/v1alpha2/applicationcinfiguratioin/applicationconfiguratioin.go

// Reconcile an OAM ApplicationConfigurations by rendering and instantiating its
// Components and Traits.
func (r *OAMApplicationReconciler) Reconcile(req reconcile.Request) (reconcile.Result, error) {
  ...
  ac := &v1alpha2.ApplicationConfiguration{}
  // 1. 获取 ApplicationConfiguration
  if err := r.client.Get(ctx, req.NamespacedName, ac); err != nil {
    ...
  }
  return r.ACReconcile(ctx, ac, log)
}

// ACReconcile contains all the reconcile logic of an AC, it can be used by other controller
func (r *OAMApplicationReconciler) ACReconcile(ctx context.Context, ac *v1alpha2.ApplicationConfiguration,
  log logging.Logger) (result reconcile.Result, returnErr error) {
  
  ...
  // 2. 渲染
  // 此处 workloads 包含所有Component对应的的 workload 和 tratis 的 k8s 资源对象
  workloads, depStatus, err := r.components.Render(ctx, ac)
  ...
  
  applyOpts := []apply.ApplyOption{apply.MustBeControllableBy(ac.GetUID()), applyOnceOnly(ac, r.applyOnceOnlyMode, log)}
  
  // 3. 创建 workload 和 traits 对应的 k8s 资源对象
  if err := r.workloads.Apply(ctx, ac.Status.Workloads, workloads, applyOpts...); err != nil {
    ...
  }
  
  ...

  // the defer function will do the final status update
  return reconcile.Result{RequeueAfter: waitTime}, nil
}
```

## 5. 总结

当 vela up 将一个 AppFile 渲染为一个 Application 后，后续的流程由 application controller 和 applicationconfiguration controller 完成。

![4.png](https://ucc.alicdn.com/pic/developer-ecology/9469b9cfd6d042fb9e8b108b1c4cce81.png)

## 作者简介

樊大勇，华胜天成研发工程师，GitHub ID：@just-do1。

## 加入 OAM

- OAM 官网：

*[https://oam.dev](https://oam.dev/)*

- KubeVela GitHub 项目地址：

*https://github.com/oam-dev/kubevela*

- 社区交流钉群：

![5.png](https://ucc.alicdn.com/pic/developer-ecology/4973c80cc941457eadd83d104d1754d5.png)

link：

- [源码解读：KubeVela 是如何将 appfile 转换为 K8s 特定资源对象的](https://developer.aliyun.com/article/783169)

