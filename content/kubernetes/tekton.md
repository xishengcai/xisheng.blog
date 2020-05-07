
# CICD： Tekton Pipline 入门
Tekton 是 Google 开源的 Kubernetes 原生CI/CD 系统, 功能强大扩展性强. 前身是 Knavite 里的 build-pipeline 项目, 后期孵化成独立的项目. 并成为 CDF 下的四个项目之一, 其他三个分别是 Jenkins, Jenkins X, Spinnaker

# CRD 介绍
- Task: 构建任务, 可以定义一些列的 steps. 每个 step 由一个 container 执行.
- TaskRun: task 实际的执行, 并提供执行所需的参数. 这个对象创建后, 就会有 pod 被创建.
- Pipeline: 定义一个或者多个 task 的执行, 以及 PipelineResource 和各种定义参数的集合
- PipelineRun: 类似 task 和 taskrun 的关系: 一个定义一个执行. PipelineRun 则是 pipeline 的实际执行. 创建后也会创建 pod 来执行各个 task.
- PipelineResource: 流水线的输入资源, 比如 github/gitlab 的源码, 某种存储服务的文件, 或者镜像等. 执行时, 也会作为 pod 的其中一个 container 来运行(比如拉取代码).
- Condition: 在 pipeline 的 task 执行时通过添加 condition 来对条件进行评估, 进而判断是否执行 task. 目前是WIP的状态, 待#1137的完成.

# 组件
- tekton-pipelines-controller: 监控 CRD 对象(TaskRun, PipelineRun)的创建, 为该次执行创建 pod.
- tekton-pipelines-webhook: 对 apiserver 提供 http 接口做 CRD 对象的校验.

# 实践
# 0x00 add Dockerfile and yaml


# 0x01 pull code


# 0x02 编译 


# 0x03 build and push image


# 0x04 部署


# 0x05 组装流水线

# 0x07 执行流水线


