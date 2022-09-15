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
rs.add( { host: "mongo-rs-0.mongo-rs-svc:27017", priority: 6, votes: 0,hidden: true }
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
