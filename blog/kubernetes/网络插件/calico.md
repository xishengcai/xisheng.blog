## 1、Calico概述

`Calico`是`Kubernetes`生态系统中另一种流行的网络选择。虽然`Flannel`被公认为是最简单的选择，但`Calico`以其性能、灵活性而闻名。`Calico`的功能更为全面，不仅提供主机和`pod`之间的网络连接，还涉及[网络安全](https://cloud.tencent.com/product/ns?from=10680)和管理。`Calico CNI`插件在`CNI`框架内封装了`Calico`的功能。

`Calico`是一个基于`BGP`的纯三层的网络方案，与`OpenStack`、`Kubernetes`、`AWS`、`GCE`等云平台都能够良好地集成。`Calico`在每个计算节点都利用`Linux Kernel`实现了一个高效的虚拟路由器`vRouter`来负责数据转发。每个`vRouter`都通过`BGP1`协议把在本节点上运行的容器的路由信息向整个`Calico`网络广播，并自动设置到达其他节点的路由转发规则。`Calico`保证所有容器之间的数据流量都是通过`IP`路由的方式完成互联互通的。`Calico`节点组网时可以直接利用数据中心的网络结构（L2或者L3），不需要额外的`NAT`、隧道或者`Overlay Network`，没有额外的封包解包，能够节约`CPU`运算，提高网络效率。

<img src="/Users/xishengcai/Library/Application Support/typora-user-images/image-20210430141738085.png" alt="image-20210430141738085" style="zoom:50%;" />







## 2 工具

**1. 下载二进制文件**

```
wget https://github.com/projectcalico/calicoctl/releases/download/v3.14.1/calicoctl
chmod +x calicoctl
mv calicoctl /usr/local/bin
```



**2. 添加calicoctl配置文件**

calicoctl通过读写calico的数据存储系统（datastore）进行查看或者其他各类管理操作，通常，它需要提供认证信息经由相应的数据存储完成认证。在使用Kubernetes API数据存储时，需要使用类似kubectl的认证信息完成认证。它可以通过环境变量声明的DATASTORE_TYPE和KUBECONFIG接入集群，例如以下命令格式运行calicoctl：

```
[root@k8s-master ~]# DATASTORE_TYPE=kubernetes KUBECONFIG=~/.kube/config calicoctl get nodes
NAME         
k8s-master   
k8s-node1    
k8s-node2    
```



 也可以直接将认证信息等保存于配置文件中，calicoctl默认加载 /etc/calico/calicoctl.cfg 配置文件读取配置信息，如下所示：

```
[root@k8s-master ~]# cat /etc/calico/calicoctl.cfg
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "kubernetes"
  kubeconfig: "/root/.kube/config"
```



```
[root@k8s-master ~]# calicoctl get nodes
NAME         
k8s-master   
k8s-node1    
k8s-node2  
```

 

**3. 测试calicoctl命令**

```
[root@k8s-master ~]# calicoctl node status
Calico process is running.

IPv4 BGP status
+---------------+-------------------+-------+----------+-------------+
| PEER ADDRESS  |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+---------------+-------------------+-------+----------+-------------+
| 138.138.82.15 | node-to-node mesh | up    | 09:03:56 | Established |
| 138.138.82.16 | node-to-node mesh | up    | 09:04:08 | Established |
+---------------+-------------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.
```



```
[root@k8s-master ~]# calicoctl get ipPool -o yaml
apiVersion: projectcalico.org/v3
items:
- apiVersion: projectcalico.org/v3
  kind: IPPool
  metadata:
    creationTimestamp: 2019-04-28T08:53:12Z
    name: default-ipv4-ippool
    resourceVersion: "1799"
    uid: 0df17422-6993-11e9-bde3-005056918222
  spec:
    blockSize: 26
    cidr: 192.168.0.0/16
    ipipMode: Always
    natOutgoing: true
    nodeSelector: all()
kind: IPPoolList
metadata:
  ……
```

