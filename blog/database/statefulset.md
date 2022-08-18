# 准备工作

- 几个副本需要几个node节点
- 设置pod 亲和度
- 设置 node label
- 初始化
- set password



```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongo-rs-svc
  labels:
    name: mongo
  namespace: 'default'
spec:
  ports:
    - port: 27017
      targetPort: 27017
  selector:
    app: mongo-rs
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongo-rs
  namespace: 'default'
spec:
  serviceName: mongo-rs-svc
  replicas: 3
  selector:
    matchLabels:
      app: mongo-rs
  template:
    metadata:
      labels:
        app: mongo-rs
    spec:
      hostNetwork: true
      terminationGracePeriodSeconds: 10
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - mongo-rs
              topologyKey: kubernetes.io/hostname
      containers:
        - env:
            - name: MONGO_INITDB_DATABASE
              value: admin
            - name: MONGO_INITDB_ROOT_USERNAME
              value: root
            - name: MONGO_INITDB_ROOT_PASSWORD
              value: "123456"
          name: mongod
          image: registry.cn-hangzhou.aliyuncs.com/launcher/mongo:4.2.1
          command: ["sh", "-c", "numactl --interleave=all mongod -f /etc/conf.d/mongodb --replSet rs"]
          resources:
            requests:
              cpu: 500m
              memory: 500m
          volumeMounts:
            - name: mongodb-data
              mountPath: /var/lib/mongodb
            - name: mongo-config
              mountPath: /etc/conf.d
          ports:
            - containerPort: 27017
      volumes:
        - name: mongo-config
          configMap:
            name: mongodb-rs-config
        - hostPath:
            path: /usr/local/mongodb
            type: ""
          name: mongodb-data
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-rs-config
  namespace: 'default'
data:
  mongodb: |
    processManagement:
      fork: false
    net:
      port: 27017
      bindIp: 0.0.0.0
    storage:
      dbPath: /var/lib/mongodb
```





## 初始化

```
rs.initiate({
        _id: "rs",
        version: 1,
        members: [
             { _id: 0, host : "10.168.12.208:27017" },
	           { _id: 1, host : "10.168.12.117:27017" },
	           { _id: 2, host : "10.168.12.236:27017" },
 ]});
 
 rs.initiate({
        _id: "rs",
        version: 1,
        members: [
            { _id: 0, host : "10.168.12.176:27017" },
            { _id: 1, host : "mongo-rs-1.mongo-rs-svc.test-345627352593600512.svc.cluster.local:27017" },
            { _id: 2, host : "mongo-rs-2.mongo-rs-svc.test-345627352593600512.svc.cluster.local:27017" },
 ]});


rs.reconfig({_id: "rs",
            version: 1,
            protocolVersion: 1,
        members: [
            { _id: 0, host : "10.168.12.176:27017" },
            { _id: 1, host : "mongo-rs-1.mongo-rs-svc.test-345627352593600512.svc.cluster.local:27017" },
            { _id: 2, host : "mongo-rs-2.mongo-rs-svc.test-345627352593600512.svc.cluster.local:27017" }, {"force":true});

 use admin

 db.createUser(
   {
     user: "root",
     pwd: "123456",
     roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
   }
 )



```





## set password

```
 use admin

 db.createUser(
   {
     user: "root",
     pwd: "password",
     roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
   }
 )

 db.auth("root","password")
```