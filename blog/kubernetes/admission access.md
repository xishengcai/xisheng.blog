# K8s: admission access

### API 请求认证
#### 认证流程
![client-go](http://xisheng.vip/images/access-control-overview.svg)
- step1: Authentication 请求用户是否为能够访问集群的合法用户
> * Authentication：即身份验证，这个环节它面对的输入是整个http request，它负责对来自client的请求进行身份校验，
>支持的方法包括：client证书验证（https双向验证）、basic auth、普通token以及jwt token(用于serviceaccount)。
>APIServer启动时，可以指定一种Authentication方法，也可以指定多种方法。如果指定了多种方法，那么APIServer将会逐
>个使用这些方法对客户端请求进行验证，只要请求数据通过其中一种方法的验证，APIServer就会认为Authentication成功；
>在较新版本kubeadm引导启动的k8s集群的apiserver初始配置中，默认支持client证书验证和serviceaccount两种身份验证
>方式。在这个环节，apiserver会通过client证书或http header中的字段(比如serviceaccount的jwt token)来识别出请
>求的“用户身份”，包括”user”、”group”等，这些信息将在后面的authorization环节用到。
- step2: Authorization 用户是否有权限进行请求中的操作
> * Authorization：授权。这个环节面对的输入是http request context中的各种属性，包括：user、group、request
> path（比如：/api/v1、/healthz、/version等）、request verb(比如：get、list、create等)。APIServer会将这些属性值
>与事先配置好的访问策略(access policy）相比较。APIServer支持多种authorization mode，包括Node、RBAC、Webhook等。
>APIServer启动时，可以指定一种authorization mode，也可以指定多种authorization mode，如果是后者，只要Request
>通过了其中一种mode的授权，那么该环节的最终结果就是授权成功。在较新版本kubeadm引导启动的k8s集群的apiserver初始配置中
>，authorization-mode的默认配置是”Node,RBAC”。Node授权器主要用于各个node上的kubelet访问apiserver时使用的，其
>他一般均由RBAC授权器来授权。
- step3: Admission Control 请求是否安全合规

#### 证书位置
X509认证:
> * 公钥:/etc/kubernetes/pki/ca.crt
> * 私钥:/etc/kubernetes/pki/ca.key

集群组件间通讯用证书都是由集群根CA签发

在证书中有两个身份证凭证相关的重要字段:

> * Comman Name(CN)：apiserver在认证过程中将其作为用户user
> * Organization(O)：apiserver在认证过程中将其作为组(group)

#### 客户端证书

每个kubernetes系统组件都在集群创建时签发了自身对应的客户端证书
> * controller-manager  system: kube-controller-manager
> * scheduler                      system:kube-scheduler
> * kube-proxy                   system-kube-proxy
> * kubelet                           system:node:$(node-hostname)         system:nodes<br>

#### 通过kubernetes　api　签发证书

证书签发API:
> * Kubernets 提供了证书签发的API:  certificates.k8s.io/v1beta1
> * 客户端证书的签发请求发送到API server
> * 签发请求会以csr资源模型的形式持久化
> * 新创建好的csr模型会保持pending的状态,直到有权限管理员对其approve
> * 一旦csr完成approved, 请求对应的证书即被签发

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
Role-Based Access Control即Role-Based Access Control，它使用”rbac.authorization.k8s.io”
实现授权决策，允许管理员通过Kubernetes API动态配置策略。在RBAC API中，一个角色(Role)包含了
一组权限规则。Role有两种：Role和ClusterRole。一个Role对象只能用于授予对某一单一命名空间
（namespace）中资源的访问权限。ClusterRole对象可以授予与Role对象相同的权限，但由于它
们属于集群范围对象， 也可以使用它们授予对以下几种资源的访问权限

> * 集群范围资源（例如节点，即node）
> * 非资源类型endpoint（例如”/healthz”）
> * 跨所有命名空间的命名空间范围资源（例如所有命名空间下的pod资源)

rolebinding，角色绑定则是定义了将一个角色的各种权限授予一个或者一组用户。 角色绑定包含了一组相关主体（即subject,
包括用户——User、用户组——Group、或者服务账户——Service Account）以及对被授予角色的引用。
在命名空间中可以通过RoleBinding对象进行用户授权，而集群范围的用户授权则可以通过ClusterRoleBinding对象完成

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

**RunTime　安全策略**

- pod or container　set Security Context
- Pod Secruity Policy
- use admission controllers
  - "imagePolicyWebhook"
  - "AlwaysPullImages"


> * SecurityContext -> runAsNonRoot
> * SecurityContext -> Capabilities
> * SecurityContext -> readOnlyRootFilesystem
> * PodSecurityContext -> MustRunAsNonRoot
