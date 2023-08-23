# 流水线引擎tekton介绍

Tekton 是一个 Kubernetes 原生的构建 CI/CD Pipeline 的解决方案，能够以 Kubernetes 扩展的方式安装和运行。它提供了一组 Kubernetes 自定义资源（custom resource），借助这些自定义资源，我们可以为 Pipeline 创建和重用构建块。



**相关概念**

Tekton 最主要的四个概念为：Task、TaskRun、Pipeline 以及 PipelineRun。

![img](https://ask.qcloudimg.com/http-save/yehe-1487868/w7wcfof1fk.png?imageView2/2/w/1620)

- **Task**: Task 为构建任务，是 Tekton 中不可分割的最小单位，正如同 Pod 在 Kubernetes 中的概念一样。在 Task 中，可以有多个 Step，每个 Step 由一个 Container 来执行。

- **Pipeline**: Pipeline 由一个或多个 Task 组成。在 Pipeline 中，用户可以定义这些 Task 的执行顺序以及依赖关系来组成 DAG（有向无环图）。

- **PipelineRun**: PipelineRun 是 Pipeline 的实际执行产物，当用户定义好 Pipeline 后，可以通过创建 PipelineRun 的方式来执行流水线，并生成一条流水线记录。

- **TaskRun**: PipelineRun 被创建出来后，会对应 Pipeline 里面的 Task 创建各自的 TaskRun。一个 TaskRun 控制一个 Pod，Task 中的 Step 对应 Pod 中的 Container。当然，TaskRun 也可以单独被创建。

  

### 社区开源tekton落地生产还有许多不足，Lstack做了如下优化

1. 流水线运行记录转储：由于面向 k8s 的设计，tekton 所有的实例数据都只存在 etcd 上，面临着 pod 数据会被gc和集群稳定性等风险。我们基于社区result api方案深度改写，将流水线历史记录存储到sql数据库中实现持久化，释放集群资源。

2. 构建日志上云：原生tekton流水线日志展示的是集群中pod的日志，而流水线每次运行都会产生大量pod，运行过多将导致资源被迅速耗尽。我们通过自己实现日志代理完成流水线日志的收集与上报，释放集群资源。

3. 编译性能提升：每次构建时,会把下载依赖包缓存起来,以后构建无需重复拉取,可有效提高构建速度。

4. 自定义流水线语法：重新定义一套yaml流水线语法，提高扩展性，使得流水线可交由多种ci/cd引擎来解释执行。例如在k8s上使用tekton来运行。

5. 丰富的模版：提供多语言、多流程的原子模版，例如门禁、通知等

6. 指标可视化：流水线每次运行都会上报指标















