---
title: "helm 入门实践"
date: 2019-10-04T16:10:09+08:00
draft: false
---

## 下载二进制文件
echo "Helm由客户端命helm令行工具和服务端tiller组成，Helm的安装十分简单。 下载helm命令行工具到master节点"
```
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.15.0-linux-amd64.tar.gz
tar -zxvf ../soft_package/helm-v2.15.0-linux-amd64.tar.gz
mv -f ./linux-amd64/helm /usr/local/bin/
rm -rf ./linux-amd64
```


## 创建RBAC角色
```
echo "apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system" > tiller_rbac.yaml
```

```
kubectl create -f tiller_rbac.yaml
```

### 创建 tiller deployment
```
helm init --service-account tiller --skip-refresh -i registry.cn-hangzhou.aliyuncs.com/launcher/tiller:v2.15.0
```


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
kubectl create secret tls frognew-com-tls-secret --cert=/etc/kubernetes/pki/ca.crt --key=/etc/kubernetes/pki/ca.key -n kube-system
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

### template key
    tpl
    dir
    template
    indent    # 左边空格
    
    helm模板语法嵌套在{{和}}之间，有三个常见的 
    .Values.* 
    从value.yaml文件中读取 
    .Release.* 
    从运行Release的元数据读取 
    .Template.* 
    .Chart.* 
    从Chart.yaml文件中读取 
    .Files.* 
    .Capabilities.*
    
### 获取helm渲染后的k8s可执行的yaml文件（只渲染不运行）。
    helm install --debug --dry-run ./mychart
    
    .Values.*的值可以来自以下 
    + values.yaml文件 
    + 如果是子chart，值来自父chart的values.yaml 
    + 通过helm install -f标志的文件 
    + 来自–-set中的配置
    
    顺序查找，下面找到的覆盖上面找到的值。
    
### 模板函数
>quote: 最常用的模板函数，它能把ABC转化为“ABC”。它带一个参数 
```
{{ quote .Values.favorite.drink }}
```

> "|":  管道，类似linux下的管道。
```
{{ quote .Values.favorite.drink }} 与 {{ .Values.favorite.drink | quote }} 效果一样。
``` 

>default: use default value .
如果在values中无法找到favorite.drink，则配置为“tea”。*
```
drink: {{ .Values.favorite.drink | default “tea” | quote }} 
```

>indent: 对左空出空格 
 
```
data:
  myvalue: "Hello World"
{{ include "mychart_app" . | indent 2 }}
会使渲染后的取值于左边空出两个空格，以符合yaml语法。
```

> overwrite map

    --set service.type=NodePort

> overwrite string

    --set image=.....

> overwrite array

    --set aaa[0].name=.. aaa[0].value=....



### helm 模板名词解释
#### Release.Name
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.

#### full name

#### name



### link
- [helm blog](https://changbo.tech/blog/29dc945b.html)
- [helm github](https://github.com/helm/helm)
- [helm blog2](https://blog.csdn.net/liukuan73/article/details/79319900)
- [supervisor install](https://www.chengxulvtu.com/supervisor-on-centos-7/)