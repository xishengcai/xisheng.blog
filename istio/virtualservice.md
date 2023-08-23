## virtualservice
虚拟服务（Virtual Service）以及目标规则（Destination Rule）是 Istio 流量路由的两大基石。虚拟服务可以将流量路由到 Istio 服务网格中的服务。每个虚拟服务由一组路由规则组成，这些路由规则按顺序进行评估。

如果没有 Istio virtual service，仅仅使用 k8s service 的话，那么只能实现最基本的流量负载均衡转发，但是就不能实现类似按百分比来分配流量等更加复杂、丰富、细粒度的流量控制了。

备注：虚拟服务相当于 K8s 服务的 sidecar，在原本 K8s 服务的功能之上，提供了更加丰富的路由控制。



### virtualService 的路由规则

创建 两个deployment， nginx 和 tomcat, 
```
kubectl create ns test
```
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  namespace: test
spec:
  replicas: 1
  selector:
    matchLabels:
      type: web
      app: nginx
  template:
    metadata:
      labels:
        type: web
        app: nginx
    spec:
      containers:
        - image: nginx:1.14-alpine
          imagePullPolicy: IfNotPresent
          name: nginx
          ports:
            - containerPort: 80
              name: port
              protocol: TCP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tomcat-deploy
  namespace: test
spec:
  replicas: 1
  selector:
    matchLabels:
      type: web
      app: tomcat
  template:
    metadata:
      labels:
        type: web
        app: tomcat
    spec:
      containers:
        - image: docker.io/kubeguide/tomcat-app:v1
          imagePullPolicy: IfNotPresent
          name: tomcat
          ports:
            - containerPort: 8080
              name: port
              protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: test
spec:
  ports:
    - name: port
      port: 8080
      protocol: TCP
      targetPort: 8080
  selector:
    type: web
  sessionAffinity: None
  type: NodePort
```
创建完nginx ，需要进入容器修改监听端口 80->8080, nginx -s reload


**创建istio 路由规则**
```
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: test-dr
  namespace: test
spec:
  host: web-svc
  subsets:
    - name: tomcat
      labels:
        app: tomcat
    - name: nginx
      labels:
        app: nginx
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: test-virtual-svc
  namespace: test
spec:
  gateways:
    - test-web
    - mesh # 对所有网格内服务有效
  hosts:
    - web-svc
    - www.cai.com # 因为有了网格内的服务主机的定义，这里就不能用 * 了
  http:
    - route:
        - destination:
            host: web-svc
            subset: nginx
          weight: 90
        - destination:
            host: web-svc
            subset: tomcat
          weight: 10
      match:
        - gateways:
            - test-web # 限制只对 Ingress 网关的流量有效
          uri:
            exact: /
    - route:
        - destination:
            host: web-svc
            subset: nginx
          weight: 10
        - destination:
            host: web-svc
            subset: tomcat
          weight: 90
      match:
        - gateways:
            - mesh # 对所有网格内服务有效
          uri:
            exact: /
---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: test-web
  namespace: test
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "*"
```

**访问测试：**
1. nginx ingress controller 访问
```
for i in {1..1000};do curl -H "host: www.cai.com" http://8.210.125.72:31425;done
```
*测试结果*： virtualService 规则没有生效

2. 未注入istio sidecar 容器内访问
```
kubectl run busybox --rm -ti --image busybox /bin/sh
wget -q -O - http://web-svc:8080
```
*测试结果*： virtualService 规则没有生效

3. 注入istio sidecar 容器访问web-svc测试
*测试结果*： virtualService 规则有效

4.  ingressGateway Controller 访问测试
*测试结果*： virtualService 规则有效

###  Question
Q1.  进入 busy 容器对 已经创建virtualservice 分流的服务进行curl 访问测试， virtualservice 比例是1:4， 但是 实际确实 1：1， busy 容器没有注入istio

答：VirtualService.Spec.Hosts  域名可以是服务的svc 名称或者是 外部的域名。
	如果填写的是外部域名，那么路由策略只针对 ingressGateway有效
	如果填写的是内部服务名称，路由策略则对网格内的所有容器有效，非网格内的无效。
	
Q2.  ingressController 代理service web-svc  流量没有按virtualService 的比例分流

答：virtaulService 的网关路由策略只对ingressGateway 有效。

Q3.  [2020-12-25T12:36:09.713Z] "GET /tomcat.png HTTP/1.1" 404 NR "-" 0 0 0 - "172.31.221.208" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36" "ed3f2774-d8cb-9f89-a1a0-44cbcdb6a747" "www.cai.com:31425" "-" - - 10.244.101.116:8080 172.31.221.208:1988 - -

答： 路由匹配规则， exact -> prefix
```
      match:
        - gateways:
            - test-web # 限制只对 Ingress 网关的流量有效
          uri:
            exact: /
```

### link
[入门到放弃](https://my.oschina.net/u/4393870/blog/4283422)
[网络故障排查](https://istio.io/v1.2/zh/docs/ops/traffic-management/troubleshooting/)







```do 
connector:
  name: lstack-production-62de1a9fd0b8414ab6595fe1
  maxConnection: 0
  providerSource: db
  version: release-V0.8.0
  serverAddr: https://lstack.lstack-pre.cn
  database:
    type: mysql
    mysql:
      username: idp
      password: Nz9Vy4EQ75NLseuYTien
      host: 10.168.12.229
      database: idp
      port: 3306
  externalPlugins:
  - name: tekton
    version: 0.20.1
    chartAddr: https://lstack-helm-chart.oss-cn-hangzhou.aliyuncs.com/product/charts/tekton-0.20.1.tgz
    namespace: lstack-system
    readinessProbe:
      targets:
      - resource: "Deployment"
        Name: "tekton-pipelines-controller"
    values: '{}'
  - name: oam-kubernetes-runtime
    chartAddr: https://lstack-helm-chart.oss-cn-hangzhou.aliyuncs.com/product/charts/oam-kubernetes-runtime-1.0.81.tgz
    version: 1.0.81
    namespace: lstack-system
    values: '{}'
    readinessProbe:
      targets:
      - resource: "Deployment"
        Name: "oam-kubernetes-runtime"
  - name: idp-logagent
    chartAddr: https://lstack-helm-chart.oss-cn-hangzhou.aliyuncs.com/product/charts/idp-logagent-0.1.0.tgz
    version: 0.1.0
    namespace: lstack-idp
    values: '{"env":{"httpEndpointPrefix": "https://lstack.lstack-pre.cn" }}'
    readinessProbe:
      targets:
      - resource: "DaemonSet"
        Name: "idp-logagent"
  - name: helm-operator
    chartAddr: https://lstack-helm-chart.oss-cn-hangzhou.aliyuncs.com/product/charts/helm-operator-0.7.3.tgz
    version: 0.7.3
    namespace: lstack-system
    values: '{}'
    readinessProbe:
      targets:
      - resource: "Deployment"
        Name: "helm-operator"you what 
```

