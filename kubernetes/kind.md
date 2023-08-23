

kind

CD+delegation: 产品 蔡锡生， 后端开发 吴江法， 前端开发 孙玉杰

## 1.install kind

```
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.0/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/local/bin
```



## 2. install cluster

```
kind create cluster --name kind-2
```



## 3. Install docker

```
#!/usr/bin/env bash
echo "clean env"
yum remove -y docker docker-common container-selinux docker-selinux docker-engine
rm -rf /var/lib/docker

echo "install docker 18.09.8"
yum install -y yum-utils

yum-config-manager \
    --add-repo \
    https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum clean packages
#查看docker-ce版本并且安装
yum list docker-ce --showduplicates | sort -r  
yum install -y docker-ce-19.03.14  docker-ce-cli containerd.io


echo "config docker daemon"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "/data/docker",
  "storage-driver": "overlay2",
  "exec-opts": [
    "native.cgroupdriver=systemd",
    "overlay2.override_kernel_check=true"
  ],
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  }
}
EOF

systemctl enable docker.service
systemctl daemon-reload
systemctl enable docker
systemctl restart docker

docker info

```



## 4. install kubectl

```
#!/usr/bin/env bash
# made by Caixisheng  Fri Nov 9 CST 2018

#chec user
[[ $UID -ne 0 ]] && { echo "Must run in root user !";exit; }

set -e

echo "添加kubernetes国内yum源"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
       http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# Set SELinux in permissive mode (effectively disabling it)
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness=0
EOF

sysctl --system
swapoff -a


yum -y  remove kubeadm kubectl kubelet
yum -y install kubectl

```



## 5. Install nginx

```
kubectl run nginx --image=nginx
```







- https://www.cnblogs.com/charlieroro/p/13711589.html#%E5%B0%86%E9%95%9C%E5%83%8F%E5%8A%A0%E8%BD%BD%E5%88%B0kind%E7%9A%84node%E4%B8%AD

