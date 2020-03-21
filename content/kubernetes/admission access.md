---
title: "Admission access"
date: 2020-03-21T09:50:59+08:00
draft: false
---

### API 请求认证
#### 认证流程
- step1: Authentication 请求用户是否为能够访问集群的合法用户

- step2: Authorization 用户是否有权限进行请求中的操作

- step3: Admission Control 请求是否安全合规

#### 证书位置
> X509认证:
  公钥: /etc/kubernetes/pki/ca.crt
  私钥: /etc/kubernetes/pki/ca.key

集群组件间通讯用证书都是由集群根CA签发

在证书中有两个身份证凭证相关的重要字段:

> Comman Name(CN)：apiserver在认证过程中将其作为用户user
  Organization(O)：apiserver在认证过程中将其作为组(group)

#### 客户端证书

>每个kubernetes系统组件都在集群创建时签发了自身对应的客户端证书
controller-manager  system: kube-controller-manager<br>
scheduler                      system:kube-scheduler<br>
kube-proxy                   system-kube-proxy  <br>
kubelet                           system:node:$(node-hostname)         system:nodes<br>

#### 通过kubernetes　api　签发证书
  
>证书签发API:
>  Kubernets 提供了证书签发的API:  certificates.k8s.io/v1beta1
>  客户端证书的签发请求发送到API server
>  签发请求会以csr资源模型的形式持久化
>  新创建好的csr模型会保持pending的状态,直到有权限管理员对其approve
>  一旦csr完成approved, 请求对应的证书即被签发

```
cat <<EOF | kubectl apply -f - 
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: my-svc.my-namespace
spec:
  request: $(cat server.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF
```

#### 签发用户证书
- 生成私钥:
    ```
    openssl genrsa -out test.key 2048
    ```

- 生成csr
> CN: user<br>
O: group
    ```
    openssl req -new -key test.key -out test.csr -subj "/CN=dahu/O=devs"
    ```

- 通过API创建k8s csr 实例并等待管理员的审批

  基于csr文件或实例通过集群 ca keypair　签发证书，下面是openssl签发实例

    ```
    openssl x509 --req --in admin.scr --CA CA_LOCATION/ca.crt --Cakey CA_LOCATION/ca.key --Cacreateserial --out admin.crt --days 365
    ```

### ServiceAccount

#### secret
```
apiVersion: v1
data:
  ca.crt: $(CA)
  namespace: default
  token: $(JSON web Token signed by API server)
kind: Secret
type: kubernetes.io/service-account-token
metadata:
....
```

###　kubeconfig

#### generate kubeconfig

在本地进行kubeconfig 的配置

- 生成证书和秘钥
```
cat > admin-csr.json << EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Beijing",
      "L": "Beijing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF
```

```
cfssl gencert -ca=/opt/ssl/ca.pem \
  -ca-key=/opt/ssl/ca-key.pem \
  -config=/opt/ssl/ca-config.json \
  -profile=kubernetes admin-csr.json | cfssljson -bare admin
```

- 查看生成的admin证书
```
ls admin*
admin.csr  admin-csr.json  admin-key.pem  admin.pem
```

- add cluster connection info by kubectl
```
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=https://10.39.7.51:6443
  #--server=https://paas.enncloud.cn:6443  如果用的lb做负载均衡 就写lb的地址
```

- 配置客户端认证 
```
kubectl config set-credentials admin \
  --client-certificate=/etc/kubernetes/ssl/admin.pem \
  --embed-certs=true \
  --client-key=/etc/kubernetes/ssl/admin-key.pem
```

- 添加新的context入口到kubectl配置中
```
kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin


kubectl config use-context kubernetes
```

- certificate-authority-data

- client-certificate-data"

- client-key-data

#### use kubeconfig
- set kubeconfig env
```
export KUBECONFIG_SAVED=$KUBECONFIG
export KUBECONFIG=$KUBECONFIG:config-demo:config-demo-2
kubectl config view
```

- 将$HOME/.kube/config　append KUBECONFIG 环境变量设置中
```
export KUBECONFIG=$KUBECONFIG:$HOME/.kube/config
```

- 多集群config的合并和切换
```
KUBECONFIG=file1:file2:file3
kubectl config view --merge --flatten > ~/.kubectl/all-config export
KUBECONFIG = ~/.kube/all-config
kubectl config get-context
kubectl config use-context {your-contexts}
```

### kubernetes RBAC
role,                            
roleBinding,                     
roleRef:
subjects:
  kind: User/group/serviceAccount


>clusterRole 是针对allNamespaces
role 是针对单个namespace的权限定义


subjects: developer, kubectl, pods process, components

api resources: pods, nodes, services

verbs: get, list, create, watch, patch, delete



#### ClusterRole
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admission-webhook-example-cr
  labels:
    app: admission-webhook-example
rules:
- apiGroups:
  - qikqiak.com
  resources:
  - "*"
  verbs:
  - "*"
```

#### ClusterRoleBinding
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: lau-controller
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admission-webhook-example-cr
subjects:
  - kind: ServiceAccount
    name: lau-controller
    namespace: kube-system
  - kind: User
    name: dev
    apiGroup: rbac.authorization.k8s.io
```

#### Security Context的使用
> 漏洞　CVE-2019-5736

**ＲunTime　安全策略**

- pod or container　set Security Context
- Pod Secruity Policy
- use admission controllers
  - "imagePolicyWebhook"
  - "AlwaysPullImages"


SecurityContext -> runAsNonRoot
SecurityContext -> Capabilities
SecurityContext -> readOnlyRootFilesystem
PodSecurityContext -> MustRunAsNonRoot
