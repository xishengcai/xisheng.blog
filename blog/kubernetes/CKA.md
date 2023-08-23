# CKA 考试认证



## 付钱，注册，预约

- 购买 认证考试 https://training.linuxfoundation.cn/
- 用上面买到的劵注册考试， 学员请到 https://identity.linuxfoundation.org/ 创建Linux Foundation ID（LFID）。
- 到PSI考试中心网站 www.examslocal.com/linuxfoundation 预约考试
- 顺便吐个槽：还是中国的网站友好。



## 考试范围

- Application Lifecycle Management 8%
- Installation, Configuration & Validation 12%
- Core Concepts 19%
- Networking 11%
- Scheduling 5%
- Security 12%
- Cluster Maintenance 11%
- Logging / Monitoring 5%
- Storage 7%
- Troubleshooting 10%
- 可以忽略直接看真题




## 自动命令补全
```
yum install bash-completion 
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc # 在您的 bash shell 中永久的添加自动补全
```



## show lable

```
[root@cn-hongkong ~]# kubectl get nodes -L beta.kubernetes.io/arch
NAME                                 STATUS   ROLES    AGE    VERSION   ARCH
cn-hongkong.i-j6c16vsekxqadodo9mhx   Ready    <none>   141m   v1.18.0   amd64
cn-hongkong.i-j6cfgd2b4spu7o30og89   Ready    master   144m   v1.18.0   amd64
```



## select label

```
[root@cn-hongkong ~]# kubectl get nodes -l beta.kubernetes.io/arch=amd64
NAME                                 STATUS   ROLES    AGE    VERSION
cn-hongkong.i-j6c16vsekxqadodo9mhx   Ready    <none>   143m   v1.18.0
cn-hongkong.i-j6cfgd2b4spu7o30og89   Ready    master   146m   v1.18.0
```



## etcd 备份

```
ETCDCTL_API=3 etcdctl --endpoints $ENDPOINT snapshot save /var/lib/etcd/snapshot-20200312.db

find / -name etcdctl
cd /etc/kubernetes/pki/
ETCDCTL_API=3 /data/docker/overlay2/93bc807c1818bcc408e7beabea91e3db2080a593051fa89a43ff5b3256d99fad/merged/usr/local/bin/etcdctl --cacert=ca.crt --cert=server.crt --key=server.key --endpoints=[127.0.0.1:2379] snapshot save snapshotdb
```



## 升级镜像

```
kubectl set image deployment'/nginx nginx=nginx:19.1
```



## 升级版本不记录

```
kubectl rollout paus deployment/nginx
```



## 恢复版本升级记录

```
kubectl rollout resume deployment/nginx
```



## 特定版本回滚

```
# 在 --to-revision 中指定您从步骤 1 中获取的版本序号
kubectl rollout undo deployment <daemonset-name> --to-revision=<revision>
```



## dns 查询

```
kubectl run busyboxy --image=busyboxy
nslookup svc-name
nslookup podip
```



## schedule

```
# 驱逐pod from node
kubectl cordon node1
kubectl drain node1 --ignore-daemonsets=true

## 恢复可调度
kubectl uncordon node1
```



## Endpoint

```
kubectl -n ${ns} get endpoints ${service-name}
kubectl -n ${ns} get pods --selector=${service-selector}
```



## static pod

```
# 1.进入 wk8s-node-1 节点
ssh wk8s-node-1
 
# 2. 在/etc/kubernetes/manifests 定义pod的yaml文件
#使用下面的参考命令生成pod文件
kubectl run myservice --image=nginx --generator=run-pod/v1 --dry-run -o yaml >21.yml
 
# 3. 在 wk8s-node-1 节点上配置kubelet 
# 3.1 方式一：编辑kubelet配置（ /usr/lib/systemd/system/kubelet.service.d）
# 添加参数 --pod-manifest-path=/etc/kubernetes/manifests 
 
KUBELET_ARGS="--cluster-dns=10.254.0.10 --cluster-domain=kube.local --pod-manifest-path=/etc/kubernetes/manifests"
 
# 3.2 方式二： 在kubelet配置（--config=/var/lib/kubelet/config.yaml）文件中
# 添加   staticPodPath: /etc/kubernetes/manifests
 
 
#4. 重启服务
systemctl daemon-reload
systemctl restart kubelet
systemctl enable kubelet

```



## 考试技巧

```
根据真题范围，将kubernetes.io/doc 上的考点页面添加到收藏夹，方便复制粘贴yaml
如果你的macos 系统是10.15以上 请下载浏览器 vivaldi
准备好护照，看完护照后的考官发的都是考试规则信息， 都是考试手册上的东西，如果英文不好就不要再浪费时间看了
答题过程只需要保持头在摄像头内，考场安静，然后就可以安心答题了。
```



# 考试真题

1. https://blog.csdn.net/fly910905/article/details/103652034?utm_medium=distribute.pc_relevant.none-task-blog-BlogCommendFromBaidu-8&depth_1-utm_source=distribute.pc_relevant.none-task-blog-BlogCommendFromBaidu-8

### reference
- https://www.jianshu.com/p/629525af31c4
- https://github.com/walidshaari/Kubernetes-Certified-Administrator

