## docker 网络之网桥

linux网桥是一种虚拟网络设备，可以类比交换机，允许多个设备连接在其上，也就是交换机的PORT，网桥具备mac地址学习功能

- 在收到一个数据帧时，记录其源mac地址和对应的PORT的映射关系，进行一轮学习
- 在收到一个数据帧时，检查目的mac地址是否在本地缓存，如果在，则将数据帧转发到具体的PORT，如果不在，则进行泛洪，给除了入PORT之外的所有PORT都拷贝这个帧

那么，将veth桥接到网桥当中，这样通过网桥的自学习和泛洪功能，就可以将数据包从一个namespace发送到另外一个namespace当中。



### 用途

在[《docker网络之veth设备》](https://zhuanlan.zhihu.com/p/185686233)当中提出，veth在多个network namespace之间通信时，需要类似点对点的架构，整个管理会非常复杂，任意两个namespace之间都需要创建veth pair。使用linux网桥可以解决这种困扰。



基本使用： https://zhuanlan.zhihu.com/p/185783192