# kubernetes swagger



## 标准k8s配置
## open swap ui
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```
- --enable-swagger-ui=true
- --insecure-bind-address=0.0.0.0
- --insecure-port=30010
```

## deploy swagger ui
```
kubectl run swagger-ui --image=swaggerapi/swagger-ui:latest hostport=8080
```
## install nginx
```
yum install nginx -y

modify config
        location /openapi/v2{
           proxy_pass  http://localhost:30010/openapi/v2;
        }
        location /{
           proxy_pass  http://localhost:8080;
        }
```
swagger-ui 不支持跨域（同host， 同端口），所以这里用nginx 代理，将两个服务都映射到了80端口。
- https://blog.schwarzeni.com/2019/09/16/Minikube%E4%BD%BF%E7%94%A8Swagger%E6%9F%A5%E7%9C%8BAPI/

