# argo-workflow 入门

## what is argo workflows

Argo Workflows is an open source container-native workflow engine for orchestrating parallel jobs on Kubernetes. Argo Workflows is implemented as a Kubernetes CRD (Custom Resource Definition).

- Define workflows where each step in the workflow is a container.
- Model multi-step workflows as a sequence of tasks or capture the dependencies between tasks using a directed acyclic graph (DAG).
- Easily run compute intensive jobs for machine learning or data processing in a fraction of the time using Argo Workflows on Kubernetes.

Argo is a [Cloud Native Computing Foundation (CNCF)](https://cncf.io/) hosted project.

[源码位置]() https://github.com/argoproj/argo-workflows)

[![Argo Workflows in 5 minutes](https://img.youtube.com/vi/TZgLkCFQ2tk/0.jpg)](https://www.youtube.com/watch?v=TZgLkCFQ2tk)



## Use Cases

- [Machine Learning pipelines](https://argoproj.github.io/argo-workflows/use-cases/machine-learning/)
- [Data and batch processing](https://argoproj.github.io/argo-workflows/use-cases/data-processing/)
- [Infrastructure automation](https://argoproj.github.io/argo-workflows/use-cases/infrastructure-automation/)
- [CI/CD](https://argoproj.github.io/argo-workflows/use-cases/ci-cd/)
- ETL
- [Other use cases](https://argoproj.github.io/argo-workflows/use-cases/other/)

## Why Argo Workflows?

- Argo Workflows is the most popular workflow execution engine for Kubernetes.
- It can run 1000s of workflows a day, each with 1000s of concurrent tasks.
- Our users say it is lighter-weight, faster, more powerful, and easier to use
- Designed from the ground up for containers without the overhead and limitations of legacy VM and server-based environments.
- Cloud agnostic and can run on any Kubernetes cluster.



## 相关概念介绍

对任何工具的基本概念有一致的认识和理解，是我们学习以及与他人交流的基础。

以下是本文涉及到的概念：

- WorkflowTemplate，工作流模板
- Workflow，工作流

为方便读者理解，下面就几个同类工具做对比：

| Argo Workflow    | Jenkins  |
| ---------------- | -------- |
| WorkflowTemplate | Pipeline |
| Workflow         | Build    |





## 安装

Prerequisites



- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure
- ReadWriteMany volumes for deployment scaling

helm charts： https://artifacthub.io/packages/helm/bitnami/argo-workflows



add repo

```shell
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Install chart

```shell
helm install my-argo-workflows bitnami/argo-workflows --version 5.1.14
```

If you have loadbalancer Modify values

```
  --set ingress.enabled=true \
  --set argo-workflowsUsername=admin \
  --set argo-workflowsPassword=password \
```



## 访问设置

我们可以用下面的方式或者其他方式来设置 Argo Workflows 的访问端口：

```
kubectl -n argo port-forward deploy/argo-server --address 0.0.0.0 2746:2746
```

> 需要注意的是，这里默认的配置下，服务器设置了自签名的证书提供 HTTPS 服务，因此，确保你使用 `https://` 协议进行访问。

例如，地址为：`https://10.121.218.242:2746/`

Argo Workflows UI 提供了多种认证登录方式，对于学习、体验等场景，我们可以通过下面的命令直接设置绕过登录：

```
kubectl patch deployment \
  argo-server \
  --namespace argo \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
  "server",
  "--auth-mode=server"
]}]'
```



## login

get token

```
kubectl exec -it argo-workflow-argo-workflows-server-6768f75c54-g5n2x -- argo auth token
```



![image-20230425235307118](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20230425235307118.png)





## Create workflowTemplate

```yaml
metadata:
  name: golang-ci-cd
  namespace: default
  labels:
    example: 'true'
spec:
  templates:
    - name: main
      inputs: {}
      outputs: {}
      metadata: {}
      steps:
        - - name: checkout
            template: checkout
            arguments: {}
        - - name: build
            template: build
            arguments: {}
        - - name: buildImage
            template: build-image
            arguments: {}
        - - name: deploy
            template: deploy
            arguments: {}
    - name: checkout
      inputs: {}
      outputs: {}
      metadata: {}
      script:
        name: ''
        image: swr.cn-north-4.myhuaweicloud.com/lstack-common/git-init:v0.29.2
        command:
          - sh
        workingDir: /work
        resources: {}
        volumeMounts:
          - name: work
            mountPath: /work
        source: >-
          git clone --branch {{workflow.parameters.branch}}
          http://{{workflow.parameters.gitRepoUser}}:{{workflow.parameters.gitRepoPassword}}@{{workflow.parameters.repo}}
          .
    - name: build
      inputs: {}
      outputs: {}
      metadata: {}
      script:
        name: ''
        image: golang:latest
        command:
          - sh
        workingDir: /work
        resources: {}
        volumeMounts:
          - name: work
            mountPath: /work
        source: >-
          GOPROXY=https://goproxy.cn CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go
          build -o  ./bin/cloud ./main.go
    - name: build-image
      inputs: {}
      outputs: {}
      metadata: {}
      container:
        name: ''
        image: registry.cn-hangzhou.aliyuncs.com/rookieops/kaniko-executor:v1.5.0
        args:
          - '--context=.'
          - '--dockerfile={{workflow.parameters.dockerfile}}'
          - '--destination={{workflow.parameters.image}}'
          - '--skip-tls-verify'
          - '--reproducible'
          - '--cache=true'
        workingDir: /work
        resources: {}
        volumeMounts:
          - name: work
            mountPath: /work
          - name: docker-config
            mountPath: /kaniko/.docker/
    - name: deploy
      inputs: {}
      outputs: {}
      metadata: {}
      container:
        name: ''
        image: bitnami/kubectl:1.21
        command: ["kubectl", "--kubeconfig=./config", "get", "ns"]
        workingDir: /work
        resources: {}
        volumeMounts:
          - name: work
            mountPath: /work
          - name: kube-config
            mountPath: /root/.kube/docker
      volumes:
        - name: docker-config
          secret:
            secretName: docker-config
  entrypoint: main
  arguments:
    parameters:
      - name: repo
        value: gitee.com/caixisheng/cloud.git
      - name: branch
        value: master
      - name: image
        value: xishengcai/cloud:test-123
      - name: dockerfile
        value: Dockerfile
      - name: gitRepoUser
        value: devops
      - name: gitRepoPassword
        value: devops123456
  # Volume 模板申明，用于工作流中多个 Pod 之间共享存储
  # 例如：克隆代码、构建代码的 Pod 之间共享目录
  # 动态创建 Volume，与当前工作流的生命流程保持一致
  volumeClaimTemplates:
    - metadata:
        name: work
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
        storageClassName: alibabacloud-cnfs-nas
      status: {}
  ttlStrategy:
    secondsAfterCompletion: 300
  workflowMetadata:
    labels:
      example: 'true'

```



## ref

- [](https://medium.com/axons/ci-cd-with-argo-on-kubernetes-28c1a99616a9)

- [Argo Workflows 中文快速指南](https://mp.weixin.qq.com/s/OdJFCvCjH1IZjFBkl0kDaA)
- [argo使用体验](https://www.cnblogs.com/kirito-c/p/14336591.html)
