# [kubernetes故障现场一之Orphaned pod](https://www.cnblogs.com/tylerzhou/p/11075185.html)

摘自： https://www.cnblogs.com/tylerzhou/p/11075185.html 

作者： 周国通

> [系列目录](https://www.cnblogs.com/tylerzhou/p/10969041.html)

问题描述:周五写字楼整体停电,周一再来的时候发现很多pod的状态都是`Terminating`,经排查是因为测试环境kubernetes集群中的有些节点是PC机,停电后需要手动开机才能起来.起来以后节点恢复正常,但是通过`journalctl -fu kubelet`查看日志不断有以下错误

```bash
[root@k8s-node4 pods]# journalctl -fu kubelet
-- Logs begin at 二 2019-05-21 08:52:08 CST. --
5月 21 14:48:48 k8s-node4 kubelet[2493]: E0521 14:48:48.748460    2493 kubelet_volumes.go:140] Orphaned pod "d29f26dc-77bb-11e9-971b-0050568417a2" found, but volume paths are still present on disk : There were a total of 1 errors similar to this. Turn up verbosity to see them.
```

我们通过cd进入`/var/lib/kubelet/pods`目录,使用ls查看

```bash
[root@k8s-node4 pods]# ls
36e224e2-7b73-11e9-99bc-0050568417a2  42e8cd65-76b1-11e9-971b-0050568417a2  42eaca2d-76b1-11e9-971b-0050568417a2
36e30462-7b73-11e9-99bc-0050568417a2  42e94e29-76b1-11e9-971b-0050568417a2  d29f26dc-77bb-11e9-971b-0050568417a2
```

可以看到,错误信息里的pod的ID在这里面,我们cd进入它(d29f26dc-77bb-11e9-971b-0050568417a2),可以看到里面有以下文件

```bash
[root@k8s-node4 d29f26dc-77bb-11e9-971b-0050568417a2]# ls
containers  etc-hosts  plugins  volumes
```

我们查看`etc-hosts`文件

```bash
[root@k8s-node4 d29f26dc-77bb-11e9-971b-0050568417a2]# cat etc-hosts
# Kubernetes-managed hosts file.
127.0.0.1       localhost
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
fe00::0 ip6-mcastprefix
fe00::1 ip6-allnodes
fe00::2 ip6-allrouters
10.244.7.7      sagent-b4dd8b5b9-zq649
```

我们在主节点上执行`kubectl get pod|grep sagent-b4dd8b5b9-zq649`发现这个pod已经不存在了.

问题的讨论查看[这里](https://github.com/kubernetes/kubernetes/issues/60987)有人在pr里提交了来解决这个问题,截至目前PR仍然是未合并状态.

目前解决办法是先在问题节点上进入`/var/lib/kubelet/pods`目录,删除报错的pod对应的hash(`rm -rf 名称`),然后从集群主节点删除此节点(kubectl delete node),然后在问题节点上执行

```bash
kubeadm reset
systemctl stop kubelet
systemctl stop docker
systemctl start docker
systemctl start kubelet
```

执行完成以后此节点重新加入集群