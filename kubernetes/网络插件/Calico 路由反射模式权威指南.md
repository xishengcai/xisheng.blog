# Calico 路由反射模式权威指南

## 背景介绍

Calico 作为k8s的一种网络插件，具有很强的扩展性，较优的资源利用和较少的依赖。

为了提高网络的性能和灵活性，需要将k8s的工作节点和物理节点中的leaf交换机简历bgp邻居关系，同步bugp路由信息，可以将pod网路的路由发布到无力网络中。Calico 给出了三种类型的 BGP 互联方案，分别是 **Full-mesh**、**Route reflectors** 和 **Top of Rack (ToR)**。



> **FUll-mesh**

全互联模式，启用了 BGP 之后，Calico 的默认行为是在每个节点彼此对等的情况下创建完整的内部 BGP（iBGP）连接，这使 Calico 可以在任何 L2 网络（无论是公有云还是私有云）上运行，或者说（如果配了 IPIP）可以在任何不禁止 IPIP 流量的网络上作为 overlay 运行。对于 vxlan overlay，Calico 不使用 BGP。

Full-mesh 模式对于 100 个以内的工作节点或更少节点的中小规模部署非常有用，但是在较大的规模上，Full-mesh 模式效率会降低，较大规模情况下，Calico 官方建议使用 Route reflectors。



> **Route reflectors**

如果想构建内部 BGP（iBGP）大规模集群，可以使用 BGP 路由反射器来减少每个节点上使用 BGP 对等体的数量。在此模型中，某些节点充当路由反射器，并配置为在它们之间建立完整的网格。然后，将其他节点配置为与这些路由反射器的子集（通常为冗余，通常为 2 个）进行对等，从而与全网格相比减少了 BGP 对等连接的总数。



> Top of Rack (ToR)

在本地部署中，可以将 Calico 配置为直接与物理网络基础结构对等。通常，这需要涉及到禁用 Calico 的默认 Full-mesh 行为，将所有 Calico 节点与 L3 ToR 路由器对等。

本篇文章重点会介绍如何在 BGP 网络环境下配置 Calico 路由反射器，本篇主要介绍将 K8S 工作节点作为路由反射器和物理交换机建立 BGP 连接。配置环境拓扑如下：

![图片](https://mmbiz.qpic.cn/mmbiz_png/u5Pibv7AcsEVCXyXrEH6yekoq1HIia1ENe6JoricHGPVGtA4P6Kf8km6hd9zxUPaBRg1ys5SZiabTuAibBcicricOy2ibw/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

在本次环境中，分别有一台 spine 交换机和两台 leaf 交换机来建立 EBGP 连接。所有 leaf 交换机都属于一个独立的自治系统，所有 leaf 交换机下的 node 都属于一个独立的自治系统。Kubernetes 集群节点中每个 leaf 下由两台工作节点作为 CalicoRR（路由反射器），之所以用两台 node 作为路由反射器是考虑冗余性，所有 Calico RR 都跟自己上联的 leaf 交换机建立 EBGP 连接。Calico RR 和自己所属的 node 之间建立 iBGP 连接。



> 安装 calicoctl

---

Calico RR 所有配置操作都需要通过 calicoctl 工具来完成， calicoctl 允许从命令创建，读取，更新和删除 Calico 对象，所以我们首先需要在 Kubernetes 所有的工作节点上安装 calicoctl 工具。

采用二进制方式安装 calicoctl 工具。

登录到主机，打开终端提示符，然后导航到安装二进制文件位置，一般情况下 calicoctl 安装到 /usr/local/bin/。

使用以下命令下载 calicoctl 二进制文件，版本号选择自己 calico 的版本。

```
curl -O -L  https://github.com/projectcalico/calicoctl/releases/download/v3.17.2/calicoctl
```



将文件设置为可执行文件。

```
chmod +x calicoctl
```



每次执行 calicoctl 之前需要设置环境变量。

```bash
export DATASTORE_TYPE=kubernetes
export KUBECONFIG=~/.kube/config
```



如果不希望每次执行 calicoctl 之前都需要设置环境变量，可以将环境变量信息写到永久写入到/etc/calico/calicoctl.cfg 文件里，calicoctl.cfg 配置文件编辑如下

```yaml
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "kubernetes"
  kubeconfig: "/root/.kube/config"
```



> 关闭 Full-mesh 模式

---

Calico 默认是 Full-mesh 全互联模式，Calico 集群中的的节点之间都会建立连接，进行路由交换。但是随着集群规模的扩大，mesh 模式将形成一个巨大服务网格，连接数成倍增加。这时就需要使用 Route Reflector（路由器反射）模式解决这个问题。确定一个或多个 Calico 节点充当路由反射器，让其他节点从这个 RR 节点获取路由信息。

关闭 node-to-node BGP 网络，具体操作步骤如下：

添加 default BGP 配置，调整 nodeToNodeMeshEnabled 和 asNumber：

```
[root@node1 calico]# cat bgpconf.yaml
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: false
  asNumber: 64512
```



直接应用一下，应用之后会马上禁用 Full-mesh，

```
[root@node1 calico]# calicoctl apply -f bgpconf.yaml
Successfully applied 1 'BGPConfiguration' resource(s)
```



查看 bgp 网络配置情况，false 为关闭

```
[root@node1 calico]# calicoctl get bgpconfig
NAME      LOGSEVERITY   MESHENABLED   ASNUMBER
default   Info          false         64512
```



> 修改工作节点的calico 配置

通过 calicoctl get nodes --output=wide 可以获取各节点的 ASN 号，

```
[root@node1 calico]# calicoctl get nodes --output=wide
NAME    ASN      IPV4             IPV6
node1   (64512)   172.20.0.11/24
node2   (64512)   172.20.0.12/24
node3   (64512)   172.20.0.13/24
node4   (64512)   173.20.0.11/24
node5   (64512)   173.20.0.12/24
node6   (64512)   173.20.0.13/24
```



可以看到获取的 ASN 号都是“（64512）”，这是因为如果不给每个节点指定 ASN 号，默认都是 64512。我们可以按照拓扑图配置各个节点的 ASN 号，不同 leaf 交换机下的节点，ASN 号不一样，每个 leaf 交换机下的工作节点都是一个独立自治系统。

通过如下命令，获取工作节点的 calico 配置信息：

```
calicoctl get node node1 -o yaml > node1.yaml
```



每一个工作节点的 calico 配置信息都需要获取一下，输出为 yaml 文件，“node1”为 calico 节点的名称。

按照如下格式进行修改：

```
[root@node1 calico]# cat node1.yaml
apiVersion: projectcalico.org/v3
kind: Node
metadata:
  annotations:
    projectcalico.org/kube-labels: '{"beta.kubernetes.io/arch":"amd64","beta.kubernetes.io/os":"linux","kubernetes.io/arch":"amd64","kubernetes.io/hostname":"node1","kubernetes.io/os":"linux","node-role.kubernetes.io/master":"","node-role.kubernetes.io/worker":"","rr-group":"rr1","rr-id":"rr1"}'
  creationTimestamp: null
  labels:
    beta.kubernetes.io/arch: amd64
    beta.kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    kubernetes.io/hostname: node1
    kubernetes.io/os: linux
    node-role.kubernetes.io/master: ""
    node-role.kubernetes.io/worker: ""
  name: node1
spec:
  bgp:
    asNumber: 64512                           ## asNumber根据自己需要进行修改

    ipv4Address: 172.20.0.11/24
    routeReflectorClusterID: 172.20.0.11      ## routeReflectorClusterID一般改成自己节点的IP地址
  orchRefs:
  - nodeName: node1
    orchestrator: k8s
status:
  podCIDRs:
  - ""
  - 10.233.64.0/24
```



> 为node 节点进行分组（添加label）

为方便让 BGPPeer 轻松选择节点，在 Kubernetes 集群中，我们需要将所有节点通过打 label 的方式进行分组，这里，我们将 label 标签分为下面几种：

rr-group 这里定义为节点所属的 Calico RR 组，主要有 rr1 和 rr2 两种，为不同 leaf 交换机下的 Calico RR rr-id 这里定义为所属 Calico RR 的 ID，节点添加了该标签说明该节点作为了路由反射器，主要有 rr1 和 rr2 两种，为不同 leaf 交换机下的 Calico RR

![图片](https://mmbiz.qpic.cn/mmbiz_png/u5Pibv7AcsEVCXyXrEH6yekoq1HIia1ENe8Bl93ato4s8YKj2pNdHgoxicWoS7T98GRVQk1KxzGxHu6aps3vYFTYw/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1)

