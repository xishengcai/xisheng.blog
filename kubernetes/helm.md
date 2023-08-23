# Helm


### 使用默认仓库创建应用
```
helm repo list
helm search redis
helm install stable/redis
```

### helm 部署 dashboard

```
# 当使用Ingress将HTTPS的服务暴露到集群外部时，需要HTTPS证书，这里将*.frognew.com的证书和秘钥配置到Kubernetes中。
# 后边部署在kube-system命名空间中的dashboard要使用这个证书，因此这里先在kube-system中创建证书的secret
kubectl create secret tls frognew-com-tls-secret \
--cert=/etc/kubernetes/pki/ca.crt \
--key=/etc/kubernetes/pki/ca.key \
-n kube-system

helm del --purge kubernetes-dashboard

cat <<EOF > kubernetes-dashboard.yaml
ingress:
  enabled: true
  hosts:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/secure-backends: "true"
  tls:
    - secretName: frognew-com-tls-secret
      hosts:
rbac:
  clusterAdminRole: true
EOF

helm install ./charts/stable/kubernetes-dashboard \
-n kubernetes-dashboard \
--namespace kube-system  \
-f kubernetes-dashboard.yaml

```



### 创建私有charts 仓库

```
yum install supervisor -y

cat  <<EOF> /etc/supervisord.d/helm-server.ini
[program:helm]
command = helm serve --address 0.0.0.0:8881 --repo-path /data/loca-char-repo
autostart = true
autorestart = true
user = root
startretries = 3
stdout_logfile_maxbytes = 20MB
stdout_logfile_maxbytes = 10
stdout_logfile = /var/log/helm.log
EOF

systemctl restart supervisord

mkdir -p /data/loca-char-repo

```



### 在私有helm 仓库添加应用

```
cd /data/loca-char-repo
helm create myapp   # 创建一个应用的char包
helm lint ./myapp   # 语法校验
helm package myapp/   # 生成tar包
helm repo index myapp --url=http://xxxxx:8881 

## 官方示例git clone https://github.com/XishengCai/charts.git
```



### helm 通过私有仓库创建应用
```
helm repo add local-repo http://xxxx:8881
helm update
helm search redis
helm install local-repo/myapp
```

### 获取helm渲染后的k8s可执行的yaml文件（只渲染不运行）。
```bash
helm install --debug --dry-run ./mychart
```

### 模板函数

> quote: 最常用的模板函数，它能把ABC转化为“ABC”。它带一个参数 

```yaml
{{ quote .Values.favorite.drink }}
```

> "|":  管道，类似linux下的管道

```yaml
{{ quote .Values.favorite.drink }} 与 {{ .Values.favorite.drink | quote }} 效果一样
```

> default: use default value
> 如果在values中无法找到favorite.drink，则配置为“tea”。*

```yaml
drink: {{ .Values.favorite.drink | default “tea” | quote }} 
```

> indent: 对左空出空格 

```yaml
data:
  myvalue: "Hello World"
{{ include "mychart_app" . | indent 2 }}
会使渲染后的取值于左边空出两个空格，以符合yaml语法。
```

> overwrite map
```yaml
--set service.type=NodePort
```


> overwrite string
```yaml
--set image=.....
```

> overwrite array
```yaml
--set aaa[0].name=.. aaa[0].value=....
```



### helm 模板名词解释
#### Release.Name
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.

### link
- [helm blog](https://changbo.tech/blog/29dc945b.html)
- [helm github](https://github.com/helm/helm)
- [helm blog2](https://blog.csdn.net/liukuan73/article/details/79319900)
- [supervisor install](https://www.chengxulvtu.com/supervisor-on-centos-7/)
