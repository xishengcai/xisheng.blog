# [Flannel的两种模式解析（VXLAN、host-gw)](https://blog.csdn.net/yuemancanyang/article/details/123320432)

作者：[yuemancanyang](https://blog.csdn.net/yuemancanyang)![img](https://csdnimg.cn/release/blogv2/dist/pc/img/newCurrentTime2.png)于 2022-03-06 23:57:20 发布![img](https://csdnimg.cn/release/blogv2/dist/pc/img/articleReadEyes2.png)



Flannel是为[Kubernetes](https://so.csdn.net/so/search?q=Kubernetes&spm=1001.2101.3001.7020)设计的一种简单易用的容器网络解决方案，将所有的Pod都组织在同一个子网的虚拟大二层网络中。Flannel支持的后端转发方式有许多种，本文将介绍其中两种，VXLAN以及host-gw。



# VXLAN 简介

VXLAN (Virtual Extensible LAN)是一种网络[虚拟化技术](https://so.csdn.net/so/search?q=虚拟化技术&spm=1001.2101.3001.7020)，它使用一种隧道协议，将二层以太网帧封装在四层UDP报文中，通过三层网络传输，组成一个虚拟大二层网络。VXLAN的报文格式如下： 

![img](https://img-blog.csdnimg.cn/img_convert/a70f15d7917d714e687fdce9baab0ad3.webp?x-oss-process=image/format,png)

 VXLAN使用VTEP（VXLAN Tunnel Endpoint）来进行封包和解包，它是VXLAN隧道的起点或终点：

- 在发送端，源VTEP将原始报文封装成VXLAN报文，通过UDP发送到对端VTEP。
- 在接收端，VTEP将解开VXLAN报文，将原始的2层数据帧转发给目的的接收方。

VTEP可以是独立的网络设备，例如交换机，也可以是部署在服务器上的虚拟设备。例如使用置顶交换机（TOR）作为VTEP时，VXLAN的网络模型如下图：

![img](https://img-blog.csdnimg.cn/img_convert/c3dff611a7dce004de609cd33cbe5b93.webp?x-oss-process=image/format,png)

> 图例来源：[support.huawei.com/enterprise/…](https://link.juejin.cn/?target=https%3A%2F%2Fsupport.huawei.com%2Fenterprise%2Fen%2Fdoc%2FEDOC1100086966%23EN-US_TOPIC_0259820545)

但显然，在flannel中，VTEP的能力是通过linux的虚机网络设备实现的。在VXLAN模式下，VTEP的角色由 `flannel.1` 虚拟网卡充当。

# VXLAN模式

VXLAN是Flannel默认和推荐的模式。当我们使用默认配置安装Flannel时，它会为每个节点分配一个24位[子网](https://so.csdn.net/so/search?q=子网&spm=1001.2101.3001.7020)，并在每个节点上创建两张虚机网卡： `cni0` 和 `flannel.1` 。 `cni0` 是一个网桥设备，类似于 `docker0` ，节点上所有的Pod都通过veth pair的形式与 `cni0` 相连。 `flannel.1` 则是一个VXLAN类型的设备，充当VTEP的角色，实现对VXLAN报文的封包解包。

> 从内核3.7版本开始，Linux就开始支持VXLAN，到3.12版本，支持已经完备。

## 节点内通信

显然，节点内的容器间通信通过 `cni0` 网桥就能完成，不涉及任何VXLAN报文的封包解包。例如在下面的图例中，Node1的子网为10.244.0.1/24， PodA 10.244.0.20 和 PodB 10.224.0.21通过 `cni0` 网桥实现互通。

![img](https://img-blog.csdnimg.cn/img_convert/47158c8c24484ad0a8b0e965d3a38c10.webp?x-oss-process=image/format,png)

## 跨节点通信

下面重点分析一下跨节点的容器通信过程。假设有两个节点Node1和Node2，其中Node1的PodA要跟Node2的PodB通信，则它们之间的通信过程如下图所示：

![img](https://img-blog.csdnimg.cn/img_convert/cfccff09c96925a678434da40aa0f4a1.webp?x-oss-process=image/format,png)

 大致概括一下整个过程：

- 发送端：在PodA中发起 `ping 10.244.1.21` ，`ICMP` 报文经过 `cni0` 网桥后交由 `flannel.1` 设备处理。 `flannel.1` 设备是一个VXLAN类型的设备，负责VXLAN封包解包。 因此，在发送端，`flannel.1` 将原始L2报文封装成VXLAN UDP报文，然后从 `eth0` 发送。
- 接收端：Node2收到UDP报文，发现是一个VXLAN类型报文，交由 `flannel.1` 进行解包。根据解包后得到的原始报文中的目的IP，将原始报文经由 `cni0` 网桥发送给PodB。

### 哪些IP要交由 `flannel.1` 处理

`flanneld` 从 `etcd` 中可以获取所有节点的子网情况，以此为依据为各节点配置路由，将属于非本节点的子网IP都路由到 `flannel.1` 处理，本节点的子网路由到 `cni0` 网桥处理。

```perl
[root@Node1 ~]# ip r

...

10.244.0.0/24 dev cni0 proto kernel scope link src 10.244.0.1 # Node1子网为10.224.0.0/24， 本机PodIP都交由cni0处理

10.244.1.0/24 via 10.244.1.0 dev flannel.1 onlink # Node2子网为10.224.1.0/24，Node2的PodID都交由flannel.1处理

复制代码
```

如果节点信息有变化， `flanneld` 也会同步的对路由信息做修改。

### `flannel.1` 的封包过程

VXLAN的封包是将二层以太网帧封装到四层[UDP](https://so.csdn.net/so/search?q=UDP&spm=1001.2101.3001.7020)报文中的过程。

原始L2帧

要生成原始的L2帧， `flannel.1` 需要得知：

- 内层源/目的IP地址
- 内层源/目的MAC地址

内层的源/目的IP地址是已知的，即为PodA/PodB的PodIP，在图例中，分别为10.224.0.20和10.224.1.20。 内层源/目的MAC地址要结合路由表和ARP表来获取。根据路由表①得知：

1. 下一跳地址是10.224.1.0，关联ARP表②，得到下一跳的MAC地址，也就是目的MAC地址：`Node2_flannel.1_MAC`；
2. 报文要从 `flannel.1` 虚拟网卡发出，因此源MAC地址为 `flannel.1` 的MAC地址。

要注意的是，这里ARP表的表项②并不是通过ARP学习得到的，而是 `flanneld` 预先为每个节点设置好的，由 `flanneld`负责维护，没有过期时间。

```ruby
# 查看ARP表
[root@Node1 ~]# ip n | grep flannel.1

10.244.1.0 dev flannel.1 lladdr ba:74:f9:db:69:c1 PERMANENT # PERMANENT 表示永不过期

```

有了上面的信息， `flannel.1` 就可以构造出内层的2层以太网帧： 

![img](https://img-blog.csdnimg.cn/img_convert/d443f62be175006645ad85222f299999.webp?x-oss-process=image/format,png)

外层VXLAN UDP报文

要将原始L2帧封装成VXLAN UDP报文， `flannel.1` 还需要填充源/目的IP地址。前面提到，VTEP是VXLAN隧道的起点或终点。因此，目的IP地址即为对端VTEP的IP地址，通过FDB表获取。在FDB表③中，dst字段表示的即为VXLAN隧道目的端点（对端VTEP）的IP地址，也就是VXLAN DUP报文的目的IP地址。FDB表也是由 `flanneld` 在每个节点上预设并负责维护的。

> FDB表（Forwarding database）用于保存二层设备中MAC地址和端口的关联关系，就像交换机中的MAC地址表一样。在二层设备转发二层以太网帧时，根据FDB表项来找到对应的端口。例如cni0网桥上连接了很多veth pair网卡，当网桥要将以太网帧转发给Pod时，FDB表根据Pod网卡的MAC地址查询FDB表，就能找到其对应的veth网卡，从而实现联通。

可以使用 `bridge fdb show` 查看FDB表：

```ruby
[root@Node1 ~]# bridge fdb show | grep flannel.1



ba:74:f9:db:69:c1 dev flannel.1 dst 192.168.50.3 self permanent



复制代码
```

源IP地址信息来自于 `flannel.1` 网卡设置本身，根据 `local 192.168.50.2` 可以得知源IP地址为192.168.50.2。

```sql
[root@Node1 ~]# ip -d a show flannel.1



6: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default



    link/ether 32:02:78:2f:02:cb brd ff:ff:ff:ff:ff:ff promiscuity 0



    vxlan id 1 local 192.168.50.2 dev eth0 srcport 0 0 dstport 8472 nolearning ageing 300 noudpcsum noudp6zerocsumtx noudp6zerocsumrx numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535



    inet 10.244.0.0/32 brd 10.244.0.0 scope global flannel.1



       valid_lft forever preferred_lft forever



    inet6 fe80::3002:78ff:fe2f:2cb/64 scope link



       valid_lft forever preferred_lft forever



复制代码
```

至此， `flannel.1` 已经得到了所有完成VXLAN封包所需的信息，最终通过 `eth0` 发送一个VXLAN UDP报文： 

![img](https://img-blog.csdnimg.cn/img_convert/4e88930c92fd6eaca22beb1f58d30334.webp?x-oss-process=image/format,png)

 Flannel的VXLAN模式通过静态配置路由表，ARP表和FDB表的信息，结合VXLAN虚拟网卡 `flannel.1` ，实现了一个所有Pod同属一个大二层网络的VXLAN网络模型。

# host-gw模式

在上述的VXLAN的示例中，Node1和Node2其实是同一宿主机中的两台使用桥接模式的虚机，也就是说它们在一个二层网络中。在二层网络互通的情况下，直接配置节点的三层路由即可互通，不需要使用VXLAN隧道。要使用host-gw模式，需要修改 ConfigMap `kube-flannel-cfg` ，将 `Backend.Type` 从vxlan改为host-gw，然后重启所有kube-flannel Pod即可：

```erlang
...



  net-conf.json: |



    {



      "Network": "10.244.0.0/16",



      "Backend": {



        "Type": "host-gw" // <- 改成host-gw



      }



    }



 ...



复制代码
```

host-gw模式下的通信过程如下图所示：

![img](https://img-blog.csdnimg.cn/img_convert/318c559998a33c0d05baa04bdd34d891.webp?x-oss-process=image/format,png)

 在host-gw模式下，由于不涉及VXLAN的封包解包，不再需要`flannel.1`虚机网卡。 `flanneld` 负责为各节点设置路由 ，将对应节点Pod子网的下一跳地址指向对应的节点的IP，如图中路由表①所示。

```perl
[root@Node1 ~]# ip r



...



10.244.0.0/24 dev cni0 proto kernel scope link src 10.244.0.1



10.244.1.0/24 via 192.168.50.3 dev eth0 # Node2子网的下一跳地址指向Node2的public ip。



...



复制代码
```

由于没有封包解包带来的消耗，host-gw是性能最好的。不过一般在云环境下，都不支持使用host-gw的模式，在私有化部署的场景下，可以考虑。
