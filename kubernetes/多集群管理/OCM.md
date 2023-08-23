# OCM

为了让开发者、用户在多集群和混合环境下也能像在单个 Kubernetes 集群平台上一样，使用自己熟悉的开源项目和产品轻松开发功能，RedHat 和蚂蚁、阿里云共同发起并开源了 OCM（Open Cluster Management）旨在解决多集群、混合环境下资源、应用、配置、策略等对象的生命周期管理问题。目前，OCM 已向 CNCF TOC 提交 Sandbox 级别项目的孵化申请。



项目官网：https://open-cluster-management.io/



## OCM 的主要功能和架构

OCM 旨在简化部署在混合环境下的多 Kubernetes 集群的管理工作。可以用来为 Kubernetes 生态圈不同管理工具拓展多集群管理能力。OCM 总结了多集群管理所需的基础概念，认为在多集群管理中，任何管理工具都需要具备以下几点能力：

1.理解集群的定义；

2.通过某种调度方式选择一个或多个集群；

3.分发配置或者工作负载到一个或多个集群；

4.治理用户对集群的访问控制；

5.部署管理探针到多个集群中。



OCM 采用了 hub-agent 的架构，包含了几项多集群管理的原语和基础组件来达到以上的要求：

●通过 ManagedCluster API 定义被管理的集群，同时 OCM 会安装名为 Klusterlet 的 agent 在每个集群里来完成集群注册，生命周期管理等功能。

●通过 Placement API 定义如何将配置或工作负载调度到哪些集群中。调度结果会存放在 PlacementDecision API 中。其他的配置管理和应用部署工具可以通过 PlacementDecisiono 决定哪些集群需要进行配置和应用部署。

●通过 ManifestWork API 定义分发到某个集群的配置和资源信息。

●通过 ManagedClusterSet API 对集群进行分组，并提供用户访问集群的界限。

●通过 ManagedClusterAddon API 定义管理探针如何部署到多个集群中以及其如何与 hub 端的控制面进行安全可靠的通信。

架构如下图所示，其中 registration 负责集群注册、集群生命周期管理、管理插件的注册和生命周期管理；work 负责资源的分发；placement 负责集群负载的调度。在这之上，开发者或者 SRE 团队能够基于 OCM 提供的 API 原语在不同的场景下方便的开发和部署管理工具。