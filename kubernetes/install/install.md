# Kubernetes (k8s 1.23) 安装与卸载

[萌褚](https://www.modb.pro/u/447581)2022-07-21



镜像下载、域名解析、时间同步请点击[ 阿里云开源镜像站](https://developer.aliyun.com/mirror/?utm_content=g_1000303593)

### 请注意k8s在1.24版本不支持docker容器，本文使用kubeadm进行搭建

![file](https://img-blog.csdnimg.cn/ab2bd1d8e6634d1587a47bcc8320243c.png)

### 1.查看系统版本信息以及修改配置信息

1.1 安装k8s时，临时关闭swap ，如果不关闭在执行kubeadm部分命令会报错

```
swapoff -a
```

或直接注释swap（需要重启生效）

```
[root@hhdcloudrd7 /]# cat /etc/fstab 
#
# /etc/fstab
# Created by anaconda on Tue Apr 19 11:43:17 2022
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/centos_hhdcloudrd6-root /                       xfs     defaults        0 0
UUID=13a8fe45-33c8-4258-a434-133ce183d3c3 /boot                   xfs     defaults        0 0
#/dev/mapper/centos_hhdcloudrd6-swap swap                    swap    defaults        0 0
```

1.2 安装k8s时，可以临时关闭selinux，减少额外配置

```
setenforce 0
```

或修改 /etc/sysconfig/selinux 文件 后重启

```
[root@localhost /]# cat /etc/sysconfig/selinux 

# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
SELINUX=disabled
# SELINUXTYPE= can take one of three values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected. 
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted
```

1.3 关闭防火墙

```
systemctl stop firewalld
systemctl disable firewalld
```

1.4 启用 bridge-nf-call-iptables 预防网络问题

```
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
```

1.5 设置网桥参数

```
cat << EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
```

1.6 修改hosts文件 方便查看域名映射

```
[root@hhdcloudrd7 /]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

192.168.34.7 k8s-master
192.168.5.129 k8s-node1
192.168.34.8 k8s-node2
```

1.7 查看系统版本信息 修改hostname

```
[root@localhost /]# hostnamectl
   Static hostname: localhost.localdomain
         Icon name: computer-vm
           Chassis: vm
        Machine ID: 5c2c4826a7cd442a85c37d3b4dba39e0
           Boot ID: 3f70bab69c37412da8eada29d50cc12c
    Virtualization: vmware
  Operating System: CentOS Linux 7 (Core)
       CPE OS Name: cpe:/o:centos:centos:7
            Kernel: Linux 3.10.0-1160.el7.x86_64
      Architecture: x86-64
hostnamectl set-hostname k8s-node1
su root
```

1.8 查看cpu信息 k8s安装至少需要2核2G的环境，否则会安装失败

```
lscpu
```

### 2. 安装docker

进入查看docker基础

2.1 使用阿里云安装

```
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
```

2.2 修改docker的 /etc/docker/daemon.json文件

```
[root@localhost /]# cat /etc/docker/daemon.json 
{
  "registry-mirrors": ["https://t81qmnz6.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
```

2.3 修改完成后 重启docker ，使docker与kubelet的cgroup 驱动一致

```
systemctl daemon-reload
systemctl restart docker
systemctl enable docker
```

2.4 查看kubelet驱动

```
cat /var/lib/kubelet/config.yaml |grep group
```

### 3.安装kubeadm kubelet kubectl

3.1 配置k8s下载资源配置文件

```
cat >> /etc/yum.repos.d/kubernetes.repo < EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

3.2 安装 kubelet kubeadm kubectl

```
yum install -y --nogpgcheck kubelet-1.23.5 kubeadm-1.23.5 kubectl-1.23.5
```

- kubelet ：运行在cluster，负责启动pod管理容器
- kubeadm ：k8s快速构建工具，用于初始化cluster
- kubectl ：k8s命令工具，部署和管理应用，维护组件

3.2.1 查看是否安装成功

```
kubelet --version
kubectl version
kubeadm version
```

3.3 启动kubelet

```
systemctl daemon-reload
systemctl start kubelet
systemctl enable kubelet
```

3.4 拉取init-config配置 并修改配置

ps. init-config 主要是由 api server、etcd、scheduler、controller-manager、coredns等镜像构成

```
kubeadm config print init-defaults > init-config.yaml
```

3.4.1 修改 刚才拉取的init-config.yaml文件

```
imageRepository: registry.aliyuncs.com/google_containers
[root@localhost /]# cat init-config.yaml 
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.34.7   #master节点IP地址
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  imagePullPolicy: IfNotPresent
  name: master   #master节点node的名称
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/google_containers   #修改为阿里云地址
kind: ClusterConfiguration
kubernetesVersion: 1.23.0
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
scheduler: {}
```

3.5 拉取k8s相关镜像

```
kubeadm config images pull --config=init-config.yaml
```

多次尝试都是超时,上网时找了很多方法依旧不行，之后找到一个命令可以查看需要拉取的镜像

![file](https://img-blog.csdnimg.cn/07f87449dd514afba3a6e8244500155f.png)

使用下边的命令可以查看 需要拉取的镜像

```
[root@localhost /]# kubeadm config images list --config init-config.yaml
registry.aliyuncs.com/google_containers/kube-apiserver:v1.23.0
registry.aliyuncs.com/google_containers/kube-controller-manager:v1.23.0
registry.aliyuncs.com/google_containers/kube-scheduler:v1.23.0
registry.aliyuncs.com/google_containers/kube-proxy:v1.23.0
registry.aliyuncs.com/google_containers/pause:3.6
registry.aliyuncs.com/google_containers/etcd:3.5.3-0
registry.aliyuncs.com/google_containers/coredns:v1.8.6
```

同理可得 以下脚本

```
#!/bin/bash

images=`kubeadm config images list --config init-config.yaml`

if [[ -n ${images} ]]
then
  echo "开始拉取镜像"
  for i in ${images};
    do 
      echo $i
      docker pull $i;
  done
else
 echo "没有可拉取的镜像"
fi
```

最终拉取镜像成功 注意我图片上是1.24版本 这个版本不支持docker容器 给大家提个醒

![file](https://img-blog.csdnimg.cn/ff69b46d545449fba1ad7ca3749831d9.png)

3.6 运行kubeadm init安装master节点 主要两种方法 2选一即可

主要是初始化master节点 其他node节点通过 kubeadm join 进来

```
#方法一
kubeadm init --config=init-config.yaml
#方法二
kubeadm init --apiserver-advertise-address=192.168.34.7 --apiserver-bind-port=6443 --pod-network-cidr=10.244.0.0/16  --service-cidr=10.96.0.0/12 --kubernetes-version=1.23.5 --image-repository registry.aliyuncs.com/google_containers
```

推荐使用第二种方法，我在使用第一种方法时候遇到了网络插件pod启动失败导致corndns的pod也创建失败的情况，我是用的是kube-flannel，他的状态一直是CrashLoopBackOff 经过查看log信息，需要去
/etc/kubernetes/manifests/kube-controller-manager.yaml下增加这两条信息

```
--allocate-node-cidrs=true
--cluster-cidr=10.244.0.0/16
```

下载完成后可以看到这个界面

ps. 如果下载失败执行 kubeadm reset ，重新执行kubeadm init

![file](https://img-blog.csdnimg.cn/17c2021bb0734998b14e90985762efa9.png)

之前有使用kubeadm安装过，需要提前把之前的kube文件删除掉

```
rm -rf $HOME/.kube
```

在master节点运行以下三行命令 执行完成后可以通过 kubeadm token list获取token

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

如果是使用1.24版本需要安装对应的CRI容器要不然就会报这个错误
[ERROR CRI]: container runtime is not running: output: time=“2022-05-19T16:02:33+08:00” level=fatal msg=“getting status of runtime: rpc error: code = Unimplemented desc = unknown service runtime.v1alpha2.RuntimeService”
, error: exit status 1

![file](https://img-blog.csdnimg.cn/ac2bbdf445bb492c947d2c9312d871e1.png)

3.7 查看token信息 以及生成 永久token

3.7.1 查看存在的token

```
kubeadm token list
```

3.7.2 生成永久token

```
kubeadm token create --ttl 0
```

3.7.3 生成 Master 节点的 ca 证书 sha256 编码 hash 值

```
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed  's/^.* //'
```

3.7.4 在node节点 执行加入master命令

```
kubeadm join 192.168.34.7:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:d06b56614f1fcbf3e852bc440ab96a9c8846f7b2f1efd740fe320dc22705f485 
```

3.7.5 在master节点查看 加入的node节点 或删除节点

```
kubectl get nodes
kubectl delete nodes 节点名称
```

![file](https://img-blog.csdnimg.cn/36e670d34d224a558c90bbb4de39579e.png)

![file](https://img-blog.csdnimg.cn/02846699b5bb4aa88b374a03bbbe1b60.png)

3.7.6 master节点删除node节点后，node节点再次加入需要在node节点执行 kubeadm reset

3.7.7 部署网络插件 kube-flannel.yml 并 应用获取运行中容器

```
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f kube-flannel.yml 
```

![file](https://img-blog.csdnimg.cn/a0ffab673fb94c5cb67f6a1fe075f2c3.png)

3.7.8 或使用 weave 网络插件 和 kube-flannel 2选一就可以

```
wget http://static.corecore.cn/weave.v2.8.1.yaml
kubectl apply -f weave.v2.8.1.yaml
```

3.8 查看kubelet日志

```
journalctl -xefu kubelet
```

3.9 kubernetes中文文档

Kubernetes中文社区 | 中文文档

4.卸载k8s

```
yum -y remove kubelet kubeadm kubectl
sudo kubeadm reset -f
sudo rm -rvf $HOME/.kube
sudo rm -rvf ~/.kube/
sudo rm -rvf /etc/kubernetes/
sudo rm -rvf /etc/systemd/system/kubelet.service.d
sudo rm -rvf /etc/systemd/system/kubelet.service
sudo rm -rvf /usr/bin/kube*
sudo rm -rvf /etc/cni
sudo rm -rvf /opt/cni
sudo rm -rvf /var/lib/etcd
sudo rm -rvf /var/etcd
```

原文链接：https://blog.csdn.net/weixin_47752736/article/details/124855784