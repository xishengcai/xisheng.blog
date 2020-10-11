---
title: "kubernetes 灾备"
date: 2020-7-15T09:05:09+08:00
draft: false
---

# 背景介绍
正常的生产环境一般都是要做数据备份和还原操作，kubernetes的etcd集群本身具有高可用的特性，我们正常情况下是不需要做数据备份的。
下面主要正对如下场景做灾备恢复(集群是通过kubeadm创建的，并且etcd也是在集群内运行的)

- 集群被误删除
- 集群数据回退到历史的某一天

# 恢复被误删除的集群（非高可用集群）
## backup etcd
```
yum install etcdctl
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/peer.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/peer.key
etcdctl snapshot save /backup/backup.db
```
## backup kubernetes'pki
```
cp /etc/kuberentes/pki /backup/pki
```

## kubeadm rebuild cluster
```
kubeadm reset
cp -r /backup/pki/. /etc/kubernetes/pki/
kubeadm init  --cert-dir=/etc/kubernetes/pki \
--image-repository=registry.aliyuncs.com/launcher \
--pod-network-cidr=10.56.0.0/16 --upload-certs
```

## stop kubelet && docker
```
systemctl stop kubelet docker
```

## etcd restore data
```
rm -rf /var/lib/etcd
etcdctl snapshot restore /backup/backup.db --data-dir=/var/lib/etcd
```

## restart kubelet and docker
```
systemctl start kubelet docker
kubectl get nodes
```
# 集群恢复到历史的某一天
## 在master节点上stop kubelet and docker
```
rm -rf /var/lib/etcd
etcdctl snapshot restore /backup/backup.db --data-dir=/var/lib/etcd
```

## restart kubelet and docker
```
systemctl start kubelet docker
kubectl get nodes
```

## cronjob
```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: etcd-backup-test
spec:
  concurrencyPolicy: Forbid
  failedJobsHistoryLimit: 3
  successfulJobsHistoryLimit: 1
  schedule: "0 */1 * * *"
  jobTemplate:
    spec:
      backoffLimit: 3
      template:
        spec:
          containers:
            - name: etcd
              image: registry.aliyuncs.com/launcher/etcd:3.3.10
              command:
                - etcdctl
                - snapshot
                - save
                - /snapshots/snapshot.db
              env:
                - name: ETCDCTL_API
                  value: "3"
                - name: ETCDCTL_ENDPOINTS
                  value: "https://127.0.0.1:2379"
                - name: ETCDCTL_CACERT
                  value: "/etc/kubernetes/pki/etcd/ca.crt"
                - name: ETCDCTL_CERT
                  value: "/etc/kubernetes/pki/etcd/peer.crt"
                - name: ETCDCTL_KEY
                  value: "/etc/kubernetes/pki/etcd/peer.key"
              volumeMounts:
                - mountPath: /etc/kubernetes/pki/etcd
                  name: etcd-certs
                - mountPath: /snapshots
                  name: snapshots
          volumes:
            - name: etcd-certs
              hostPath:
                path: /etc/kubernetes/pki/etcd
                type: Directory
            - name: snapshots
              hostPath:
                path: /backup
                type: Directory
          hostNetwork: true
          nodeSelector:
            node-role.kubernetes.io/master: ""
          tolerations:
            - operator: Exists
          restartPolicy: Never
```
# link
- https://cloud.google.com/anthos/gke/docs/on-prem/archive/1.2/how-to/backing-up?hl=zh-cn
- https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/recovery.md
