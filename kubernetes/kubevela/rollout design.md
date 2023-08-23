# rollout design

<!--toc-->

## 原则和目标
1. 所有rollout 共享同一个逻辑
2. 所有的rollout 相关逻辑可扩展，支持不同的工作负载类型
3. 核心rollout 逻辑对那些明确的状态转化具有完善的状态机
4. 支持生成环境



## 提案

1. 提供rollout CRD
2. 给出实现控制器的高级设计
3. 提供状态机和转化事件
4. 列出常见的使用场景，我们相关的经验和实现细节



## 用户体验工作流

**roullout workflows**

2个级别的rollout 控制器，最终都会在内存中发出一个rollout计划对象，该对象包括将要执行的目标和源k8s资源。例如，从一个applicationDeployment中提取出实际的工作负载，发送给rollout 计划对象。

**Application inplace upgrade workflow**
最自然的升级就是原地升级，用户只需要改变application。

- applicationConfiguration创建哈希值， 使用组件的修订名称
- AC修改哈希值，预设注解

**ApplicationDeployment workflow**
- 添加注解
- 移除其他运维特征
- 修改svc的选择器
- 使用webhook确保注解删除后不会被再次添加
- 回滚失败，会有不可预知的情况，old and new all exist
- 引入字段‘revertOnDelete’，以便用户可以删除appDeployment并期望旧应用程序完好无损，而新应用程序不起作用。

**Rollout trait workflow**
- 组件控制器发射新的组件版本，当组件发射创建或修改的时候
- 当source 和 target rollout，会创建新组件并分配新的修订版本

**Rollout plan work with different type of workloads**
不同的工作负载要使用相同的回滚逻辑

**Rollout plan works with deployment**


**Rollout plan works with cloneset**


**控制器具有一下扩展点设置**
- workloads. Each workload handler needs to implement the following operations:
    - scale the resources
    - determine the health of the workload
    - report how many replicas are upgraded/ready/available

**State Transition**

top-level states of rollout
```
Verifying
Initializing
Rolling
Finalising
Succeed
Failed
```

sub-status of rollout
```
BatchRolling
BatchStopped
BatchReady
BatchVerifying
BatchAvailable
```