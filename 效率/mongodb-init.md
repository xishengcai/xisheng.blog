# mongodb init



### Initiate

```json
rs.initiate({
        _id: "rs",
        version: 1,
        members: [
            { _id: 0, host : "mongo-rs-0:27017" },
            { _id: 1, host : "mongo-rs-1:27017" },
            { _id: 2, host : "mongo-rs-2:27017" }
 ]});

```



### reconfig

```json
rs.reconfig({_id: "rs",
            version: 4,
            protocolVersion: 1,
            members: [
           	 	{ _id: 0, host : "mongo-rs-0.mongo-rs-svc:27017" },
              { _id: 1, host : "mongo-rs-1.mongo-rs-svc:27017" },
             ]}, {"force":true});
```



### add new node

```
rs.add( { host: "mongo-rs-2.mongo-rs-svc:27017", priority: 0, votes: 0,hidden: true }  10.168.12.20
```



### 查询

```
rs.status()
```



### nslookup 查询mongo

```
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: default
spec:
  containers:
  - name: busybox
    image: busybox:1.28.4
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
  restartPolicy: Always
```



```bash
XishengdeMacBook-Pro:~ xishengcai$ kubectl exec -it busybox sh
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl exec [POD] -- [COMMAND] instead.
/ # nslookup
BusyBox v1.28.4 (2018-05-22 17:00:17 UTC) multi-call binary.

Usage: nslookup [HOST] [SERVER]

Query the nameserver for the IP address of the given HOST
optionally using a specified DNS server
/ # nslookup mongo-rs-svc
Server:    50.96.0.10
Address 1: 50.96.0.10 kube-dns.kube-system.svc.cluster.local

nslookup: can't resolve 'mongo-rs-svc'
/ # nslookup mongo-rs-svc.322488871377965056
Server:    50.96.0.10
Address 1: 50.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      mongo-rs-svc.322488871377965056
Address 1: 50.96.107.246 mongo-rs-svc.322488871377965056.svc.cluster.local
/ # nslookup mongo-rs-0.mongo-rs-svc.322488871377965056
Server:    50.96.0.10
Address 1: 50.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      mongo-rs-0.mongo-rs-svc.322488871377965056
Address 1: 10.0.1.45 10-0-1-45.lsh-mcp-mongo.322488871377965056.svc.cluster.local
/ # 
```



### connect

```
mongo localhost:27017/admin -u user -p password
```



## 使用场景

### mongodb 重启后服务初始化

解决方案： 在原先的master 节点， rs.add("host:port")





本周工作：

1. 修复helm-operator 非安全证书的https charts 包bug
2. 前后端联调：获取所有资源yaml及工作负载状态
3. 完成helm 升级
4. 面试golang 超聚变项目候选人
5. 代码codereview



下周功能：

1. 完成helm 回滚
2. 修复安全漏洞

3. 测试 pod webshell 和实时日志功能
4. 代码cdoereview
