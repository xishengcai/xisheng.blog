---
title: "CKA Certified Kubernetes Administrator"
date: 2020-4-21T16:08:36+08:00
draft: false
---

# [付钱，注册，预约]（https://training.linuxfoundation.cn/faq#14）
- 购买 认证考试 https://training.linuxfoundation.cn/
- 用上面买到的劵注册考试， 学员请到 https://identity.linuxfoundation.org/ 创建Linux Foundation ID（LFID）。
- 到PSI考试中心网站 www.examslocal.com/linuxfoundation 预约考试
- 顺便吐个槽：还是中国的网站友好。

# 考试范围
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



# 常识备忘录
## 自动命令补全
```
yum install bash-completion 
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc # 在您的 bash shell 中永久的添加自动补全
```
## label 查询

### show lable
```
[root@cn-hongkong ~]# kubectl get nodes -L beta.kubernetes.io/arch
NAME                                 STATUS   ROLES    AGE    VERSION   ARCH
cn-hongkong.i-j6c16vsekxqadodo9mhx   Ready    <none>   141m   v1.18.0   amd64
cn-hongkong.i-j6cfgd2b4spu7o30og89   Ready    master   144m   v1.18.0   amd64
```

### select label
```
[root@cn-hongkong ~]# kubectl get nodes -l beta.kubernetes.io/arch=amd64
NAME                                 STATUS   ROLES    AGE    VERSION
cn-hongkong.i-j6c16vsekxqadodo9mhx   Ready    <none>   143m   v1.18.0
cn-hongkong.i-j6cfgd2b4spu7o30og89   Ready    master   146m   v1.18.0
```


# etcd 备份
```
ETCDCTL_API=3 etcdctl --endpoints $ENDPOINT snapshot save /var/lib/etcd/snapshot-20200312.db

find / -name etcdctl
cd /etc/kubernetes/pki/
ETCDCTL_API=3 /data/docker/overlay2/93bc807c1818bcc408e7beabea91e3db2080a593051fa89a43ff5b3256d99fad/merged/usr/local/bin/etcdctl --cacert=ca.crt --cert=server.crt --key=server.key --endpoints=[127.0.0.1:2379] snapshot save snapshotdb
```

# 容器安全配置
```
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
```

```
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: tekton-pipelines
spec:
  privileged: false
  allowPrivilegeEscalation: false
  volumes:
  - 'emptyDir'
  - 'configMap'
  - 'secret'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'MustRunAs'
    ranges:
    - min: 1
      max: 65535
  fsGroup:
    rule: 'MustRunAs'
    ranges:
    - min: 1
      max: 65535
```

# deployment 滚动升级，暂停， 回滚
## 升级策略
```
strategy:
  type: rollingUpdate
  rollingUpdate:
    maxSurge: 1 #默认百分25%
    maxUnavailable: 1 #默认25%
```
## 升级镜像
```
kubectl set image deployment'/nginx nginx=nginx:19.1
```

## 设定资源限制
```
kubectl set resources deployment nginx --limits=cpu=200m,memory=512Mi --requests=cpu=100m,memory=256Mi
```

## 查询升级状态
```
kubectl rollout status deployment/nginx
```

## 升级版本不记录
```
kubectl rollout paus deployment/nginx
```

## 恢复版本升级记录
```
kubectl rollout resume deployment/nginx
```

## 查询历史版本
```
kubectl rollout history  deployment nginx
```

## 特定版本回滚
```
# 在 --to-revision 中指定您从步骤 1 中获取的版本序号
kubectl rollout undo deployment <daemonset-name> --to-revision=<revision>
```

## deployment 弹性伸缩
```
kubectl scale deployment nginx --replicas=10
kubectl autoscale deployment nginx --min=10 --max=15 --cpu-precent=80
```

# dns 查询
```
kubectl run busyboxy --image=busyboxy
```

# kubernetes config 生成
>集群证书配置， 上下文绑定， 用户客户端证书
```
kubectl  config set-cluster
```


# csr
```
tls bootstrap 
    kubelet sent token to api-server
    rbac--- csr
       nodeclient
       selfnodeclient
       selfnodeserver
kubernetes-controller-manager 自动签发证书
kubelet 使用签发的证书，私钥访问kube-apiserver
```

# schedule
```
# 驱逐pod from node
kubectl cordon node1
kubectl drain node1 --ignore-daemonsets=true

# 恢复可调度
kubectl uncordon node1
```

# pod 异常处理
## 2.pending
> check nodeSelect, taints, affifently
```
kubectl describe quota -n ${ns}
```

## 3.pod crashbackoff
> cehck log,command,liveness,readliness
```
# if network is ok
kubectl logs -f pod

# if network not work, ssh to node
docker logs -f containerID
```

## 4. waiting
```
check imagePullSecret, imagePullPolicy
```


# 10. service 异常排查
## 10.1 域名
    nslookup 判断域名解析是否正常

# 10.2 Endpoint
```
    kubectl -n ${ns} get endpoints ${service-name}
    kubectl -n ${ns} get pods --selector=${service-selector}
    query pod status 
    query service port isMatch pod port
ipvsadm -ln
```


# static pod
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

# 考试真题
1. https://blog.csdn.net/fly910905/article/details/103652034?utm_medium=distribute.pc_relevant.none-task-blog-BlogCommendFromBaidu-8&depth_1-utm_source=distribute.pc_relevant.none-task-blog-BlogCommendFromBaidu-8

### reference
- https://www.jianshu.com/p/629525af31c4
- https://github.com/walidshaari/Kubernetes-Certified-Administrator
