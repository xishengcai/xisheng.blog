[toc]

------

# 解决 Kubernetes 中 Kubelet 组件报 failed to get cgroup 错误

摘自： http://www.mydlq.club/article/80/

作者：超级小豆丁

**系统环境：**

- Kubernetes 版本：1.18.1
- 操作系统版本：CentOS 7.8

## 一、问题描述

最近查看 Kubelet 日志，发现日志中一堆错误信息，内容如下：

- -n：指定获取最后指定行数的日志信息。

```bash
$ journalctl -u kubelet -n 10

19 02:40:17 k8s-node-2-14 kubelet[1291]: E0419 02:40:17.749145    1291 summary_sys_containers.go:47] Failed to get system container stats for "/system.slice/docker.service": failed to get cgroup stats for "/system.slice/docker.service
19 02:40:27 k8s-node-2-14 kubelet[1291]: E0419 02:40:27.772168    1291 summary_sys_containers.go:47] Failed to get system container stats for "/system.slice/docker.service": failed to get cgroup stats for "/system.slice/docker.service
19 02:40:32 k8s-node-2-14 kubelet[1291]: E0419 02:40:32.377548    1291 summary_sys_containers.go:82] Failed to get system container stats for "/system.slice/docker.service": failed to get cgroup stats for "/system.slice/docker.service
19 02:40:37 k8s-node-2-14 kubelet[1291]: E0419 02:40:37.800210    1291 summary_sys_containers.go:47] Failed to get system container stats for "/system.slice/docker.service": failed to get cgroup stats for "/system.slice/docker.service
```



BASH

可以观察到提示 failed to get cgroup stats for "/system.slice/docker.service" 错误，下面是分析与解决该问题的过程。

## 二、问题分析

首先呢，参考几个 Kubernetes Github 上的 issue：

- https://github.com/kubernetes/kubernetes/issues/56850
- https://github.com/kubermatic/machine-controller/pull/476
- https://github.com/kubernetes/kubernetes/issues/56850#issuecomment-406241077

从上面各个 issue 中，本人综合其中的问题探讨猜测，该问题只会发生在 CentOS 系统上，而引起上面的问题的原因是 kubelet 启动时，会执行节点资源统计，需要 systemd 中开启对应的选项，如下：

- CPUAccounting：是否开启该 unit 的 CPU 使用统计，bool 类型，可配置 true 或者 false。
- MemoryAccounting：是否开启该 unit 的 Memory 使用统计，bool 类型，可配置 true 或者 false。

如果不设置这两项，kubelet 是无法执行该统计命令，导致 kubelet 一直报上面的错误信息。

## 三、解决问题

解决上面问题也很简单，直接编辑 systemd 中的 kubelet 服务配置文件中，添加 CPU 和 Memory 配置，可以按下面操作进行更改。

### 1、编辑配置文件并添加对应配置项

编辑 /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf 文件，并添加下面配置：

```bash
CPUAccounting=true
MemoryAccounting=true
```



BASH

具体操作如下：

```bash
$ vi /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf

[Service]
CPUAccounting=true              ## 添加 CPUAccounting=true 选项，开启 systemd CPU 统计功能
MemoryAccounting=true           ## 添加 MemoryAccounting=true 选项，开启 systemd Memory 统计功能
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
```



BASH

### 2、重启 Kubelet 服务

重启 kubelet 服务，让 kubelet 重新加载配置。

```bash
$ systemctl daemon-reload
$ systemctl restart kubelet
```



BASH

### 3、观察 kubelet 日志

重启完 kubelet 后等一段时间，再次观察 kubelet 日志信息：

```bash
$ journalctl -u kubelet -n 10

19 02:48:11 k8s-node-2-14 kubelet[1308]: I0419 02:48:11.875632    1308 clientconn.go:933] ClientConn switching balancer to "pick_first"
19 02:48:11 k8s-node-2-14 kubelet[1308]: I0419 02:48:11.875655    1308 clientconn.go:882] blockingPicker: the picked transport is not ready, loop back to repick
19 02:48:12 k8s-node-2-14 kubelet[1308]: I0419 02:48:12.361764    1308 topology_manager.go:219] [topologymanager] RemoveContainer - Container ID: a2a3780a36a823317821f27871dc2572f5236be1ae7244b91c29f4fd0dfd7c25
19 02:48:12 k8s-node-2-14 kubelet[1308]: I0419 02:48:12.365887    1308 kubelet_resources.go:45] allocatable: map[cpu:{{8 0} {<nil>} 8 DecimalSI} ephemeral-storage:{{45389555637 0} {<nil>} 45389555637 DecimalSI} hugepages-1Gi:{{0 0} {<
19 02:48:12 k8s-node-2-14 kubelet[1308]: I0419 02:48:12.365963    1308 kubelet_resources.go:45] allocatable: map[cpu:{{8 0} {<nil>} 8 DecimalSI} ephemeral-storage:{{45389555637 0} {<nil>} 45389555637 DecimalSI} hugepages-1Gi:{{0 0} {<
19 02:48:12 k8s-node-2-14 kubelet[1308]: I0419 02:48:12.365995    1308 kubelet_resources.go:45] allocatable: map[cpu:{{8 0} {<nil>} 8 DecimalSI} ephemeral-storage:{{45389555637 0} {<nil>} 45389555637 DecimalSI} hugepages-1Gi:{{0 0} {<
19 02:48:12 k8s-node-2-14 kubelet[1308]: I0419 02:48:12.366018    1308 kubelet_resources.go:45] allocatable: map[cpu:{{8 0} {<nil>} 8 DecimalSI} ephemeral-storage:{{45389555637 0} {<nil>} 45389555637 DecimalSI} hugepages-1Gi:{{0 0} {<
```



BASH

可以看到系统已经没有之前的错误日志信息了。

---END---