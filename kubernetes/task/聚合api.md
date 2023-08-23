# 聚合PAI



CRD

```yaml
apiVersion: apiregistration.k8s.io/v1beta1
kind: APIService
metadata:
  name: v1.custom-gateway
spec:
  insecureSkipTLSVerify: true
  group: custom-gateway
  groupPriorityMinimum: 1000
  versionPriority: 5
  service:
    name: canary
    namespace: default
  version: v1
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: canary
      version: v1
  template:
    metadata:
      labels:
        app: canary
        version: v1
    spec:
      containers:
        - image: xishengcai/canary
          imagePullPolicy: IfNotPresent
          name: canary
          ports:
            - containerPort: 80
              name: port
              protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: canary
  namespace: default
spec:
  ports:
    - name: port
      port: 443
      protocol: TCP
      targetPort: 443
  selector:
    app: canary
  sessionAffinity: None
  type: NodePort


```



required：

后端服务 必须开通https 服务

后端服务的api 必须以 “/apis/{group}.{version}/v1/" 开头



后端服务的API

<img src="https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/063646.png" alt="image-20210508143641671" style="zoom:50%;" />





通过k8s API 访问效果：

> 注意后端服务的api路径必须符合规范： /apis/group/version/。。。。

```bash
curl localhost:8080/apis/custom-gateway/v1/hello2
```



<img src="https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/064106.png" alt="image-20210508144101521"  />





实验1:

​	场景：后端服务 自带https

​	结果： 可行

实验2:

​	场景：后端服务只有http，通过nginx 转发

​	结果： 不可行



疑问：

	1. 聚合api 背后的实现原理

​			
