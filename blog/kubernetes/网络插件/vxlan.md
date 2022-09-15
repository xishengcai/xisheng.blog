# vxlan

VXLAN（Virtual eXtensible Local Area Network，RFC7348）是IETF NVO3（Network Virtualization over Layer 3）定义的NVO3标准技术之一，采用MAC in UDP封装方式，将二层报文用三层协议进行封装，可对二层网络在三层范围进行扩展，同时支持24bits的VNI ID（16M租户能力），满足数据中心大二层VM迁移和多租户的需求。



最大用途

服务器的虚拟化技术(Vmware ESXI)能够大幅降低IT建设运维成本，提高业务部署灵活性。虚拟机在传统数据中心网络中只能在二层网络中进行无缝迁移，一旦在跨三层网络中进行迁移，就会造成业务中断。为了解决这个问题，为了构建一个基于三层网络的大二层网络架构，于是VXLAN技术应运而生，vxlan技术大大提高了虚拟机迁移的灵活性，使海量租户不受网络IP地址变更和广播域限制的影响，同时也大大降低了网络管理的难度。





vxlan是一种overlay技术，跟之前提到的udp模式思路是类似，但是具体实现不太一样:

vxlan是一种虚拟隧道通信技术，通过三层网络搭建虚拟的**二层网络**，与tap隧道有点相似，不过tap的虚拟交换机功能要在用户层实现。vxlan同样是基于udp的（为什么很少看到基于tcp的隧道？）

1. udp模式是在用户态实现的，数据会先经过tun网卡，到应用程序，应用程序再做隧道封装，再进一次内核协议栈，而vxlan是在内核当中实现的，只经过一次协议栈，在协议栈内就把vxlan包组装好
2. udp模式的tun网卡是三层转发，使用tun是在物理网络之上构建三层网络，属于ip in udp，vxlan模式是二层实现，overlay是二层帧，属于mac in udp
3. vxlan由于采用mac in udp的方式，所以实现起来会设计mac地址学习，arp广播等二层知识，udp模式主要关注路由

