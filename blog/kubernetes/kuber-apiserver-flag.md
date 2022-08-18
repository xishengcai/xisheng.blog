---
title: "kubernetes api server flag"
date: 2020-6-28T16:10:09+08:00
draft: false
---

# 重点参数解读
- 1.advertise-address
`向集群成员通知 apiserver 消息的 IP 地址。这个地址必须能够被集群中其他成员访问。如果 IP 地址为空，
将会使用 --bind-address，如果未指定 --bind-address，将会使用主机的默认接口地址。
`
- 2.allow-privileged
`如果为 true, 将允许特权容器。
`

- 3.uthorization-mode=Node,RBAC
`在安全端口上进行权限验证的插件的顺序列表。以逗号分隔的列表，包括：AlwaysAllow,AlwaysDeny,ABAC,Webhook,RBAC,Node.
（默认值 "AlwaysAllow"）
`

- 4.client-ca-file=/etc/kubernetes/pki/ca.crt
`如果设置此标志，对于任何请求，如果存包含 client-ca-file 中的 authorities 签名的客户端证书，将会使用客户端证书中的 
CommonName 对应的身份进行认证。
`

- 5.enable-admission-plugins=NodeRestriction
`激活准入控制插件
 AlwaysAdmit, AlwaysDeny, AlwaysPullImages, DefaultStorageClass, DefaultTolerationSeconds, 
 DenyEscalatingExec, DenyExecOnPrivileged, EventRateLimit, ExtendedResourceToleration,
 ImagePolicyWebhook, LimitPodHardAntiAffinityTopology, LimitRanger, 
 MutatingAdmissionWebhook, NamespaceAutoProvision, NamespaceExists, NamespaceLifecycle, 
 NodeRestriction, OwnerReferencesPermissionEnforcement, PersistentVolumeClaimResize, 
 PersistentVolumeLabel, PodNodeSelector, PodPreset, PodSecurityPolicy, PodTolerationRestriction,
 Priority, ResourceQuota, SecurityContextDeny, ServiceAccount, StorageObjectInUseProtection, 
 TaintNodesByCondition, ValidatingAdmissionWebhook.
`
 
- 6.enable-bootstrap-token-auth=true
`启用此选项以允许 'kube-system' 命名空间中的 'bootstrap.kubernetes.io/token' 类型密钥可以被用于 TLS 的启动认证。
`

- 7.etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
`用于保护 etcd 通信的 SSL CA 文件
`
 
- 8.etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
`用于保护 etcd 通信的的 SSL 证书文件`

- 9.etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
`用于保护 etcd 通信的 SSL 密钥文件`
 
- 10.etcd-servers=https://127.0.0.1:2379
`连接的 etcd 服务器列表 , 形式为（scheme://ip:port)，使用逗号分隔。`
 
- 11.insecure-port=0
`用于监听不安全和为认证访问的端口。这个配置假设你已经设置了防火墙规则，使得这个端口不能从集群外访问。对集群的公共地址的 443
 端口的访问将被代理到这个端口。默认设置中使用 nginx 实现。（默认值 8080）`

- 13.kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
`用于 kubelet 连接的首选 NodeAddressTypes 列表。 ( 默认值[Hostname,InternalDNS,InternalIP,ExternalDNS,ExternalIP])
`

- 17.requestheader-allowed-names=front-proxy-client
`使用 --requestheader-username-headers 指定的，允许在头部提供用户名的客户端证书通用名称列表。如果为空，任何通过 
--requestheader-client-ca-file 中 authorities 验证的客户端证书都是被允许的。`

- 19.requestheader-extra-headers-prefix=X-Remote-Extra-
`用于检查的请求头的前缀列表。建议使用 X-Remote-Extra-。`
 
- 20.requestheader-group-headers=X-Remote-Group
`用于检查群组的请求头列表。建议使用 X-Remote-Group.`

- 21.requestheader-username-headers=X-Remote-User
`用于检查用户名的请求头列表。建议使用 X-Remote-User。`

- 23.service-account-key-file=/etc/kubernetes/pki/sa.pub
`包含 PEM 加密的 x509 RSA 或 ECDSA 私钥或公钥的文件，用于验证 ServiceAccount 令牌。如果设置该值，--tls-private-key-file 将会被使用。
指定的文件可以包含多个密钥，并且这个标志可以和不同的文件一起多次使用。`

- 24.service-cluster-ip-range=20.96.0.0/12
` CIDR 表示的 IP 范围，服务的 cluster ip 将从中分配。 一定不要和分配给 nodes 和 pods 的 IP 范围产生重叠。`


Generic flags:

    --advertise-address ip                                                                                                                           
              The IP address on which to advertise the apiserver to members of the cluster. This address must be reachable by the rest of the cluster.
              If blank, the --bind-address will be used. If --bind-address is unspecified, the host's default interface will be used.
              # 向集群成员发布apiserver的IP地址，该地址必须能够被集群的成员访问。如果为空，则使用 --bind-address，如果 --bind-address未指定，那么使用主机的默认接口(IP)。
              
    --cloud-provider-gce-lb-src-cidrs cidrs                                                                                                          
              CIDRs opened in GCE firewall for LB traffic proxy & health checks (default 130.211.0.0/22,209.85.152.0/22,209.85.204.0/22,35.191.0.0/16)
              # GCE防火墙中开放的L7 LB traffic proxy&health检查的CIDRs设置
              # 默认值为130.211.0.0/22, 35.191.0.0/16
              
    --cors-allowed-origins strings                                                                                                                   
              List of allowed origins for CORS, comma separated.  An allowed origin can be a regular expression to support subdomain matching. If this
              list is empty CORS will not be enabled.
              # 跨域数组，使用逗号间隔。支持正则表达进行子域名匹配，如果参数为空，则不启用。
    --default-not-ready-toleration-seconds int                                                                                                       
              Indicates the tolerationSeconds of the toleration for notReady:NoExecute that is added by default to every pod that does not already have
              such a toleration. (default 300)
              # 指定notReady:NoExecute toleration的值，默认值为300
              # 若pod中未为notReady:NoExecute toleration设定值，则使用该值
              
    --default-unreachable-toleration-seconds int                                                                                                     
              Indicates the tolerationSeconds of the toleration for unreachable:NoExecute that is added by default to every pod that does not already
              have such a toleration. (default 300)
              # 指定unreachable:NoExecute的tolerationSeconds值，默认值为300
              # 若pod中未为unreachable:NoExecute tolerationSeconds设定值，则使用该值
              
    --enable-inflight-quota-handler                                                                                                                  
              If true, replace the max-in-flight handler with an enhanced one that queues and dispatches with priority and fairness
              # 若为true，则以增强版的优先/公平列队及分发功能来替换max-in-flight handler
              
    --external-hostname string                                                                                                                       
              The hostname to use when generating externalized URLs for this master (e.g. Swagger API Docs).
              # 为此主机生成外部化URL时要使用的主机名（例如Swagger API文档）
              
    --feature-gates mapStringBool                                                                                                                    
              A set of key=value pairs that describe feature gates for alpha/experimental features. Options are:
              APIListChunking=true|false (BETA - default=true)
              APIResponseCompression=true|false (ALPHA - default=false)
              AllAlpha=true|false (ALPHA - default=false)
              AppArmor=true|false (BETA - default=true)
              AttachVolumeLimit=true|false (BETA - default=true)
              BalanceAttachedNodeVolumes=true|false (ALPHA - default=false)
              BlockVolume=true|false (BETA - default=true)
              BoundServiceAccountTokenVolume=true|false (ALPHA - default=false)
              CPUManager=true|false (BETA - default=true)
              CRIContainerLogRotation=true|false (BETA - default=true)
              CSIBlockVolume=true|false (BETA - default=true)
              CSIDriverRegistry=true|false (BETA - default=true)
              CSIInlineVolume=true|false (ALPHA - default=false)
              CSIMigration=true|false (ALPHA - default=false)
              CSIMigrationAWS=true|false (ALPHA - default=false)
              CSIMigrationAzureDisk=true|false (ALPHA - default=false)
              CSIMigrationAzureFile=true|false (ALPHA - default=false)
              CSIMigrationGCE=true|false (ALPHA - default=false)
              CSIMigrationOpenStack=true|false (ALPHA - default=false)
              CSINodeInfo=true|false (BETA - default=true)
              CustomCPUCFSQuotaPeriod=true|false (ALPHA - default=false)
              CustomResourceDefaulting=true|false (ALPHA - default=false)
              CustomResourcePublishOpenAPI=true|false (BETA - default=true)
              CustomResourceSubresources=true|false (BETA - default=true)
              CustomResourceValidation=true|false (BETA - default=true)
              CustomResourceWebhookConversion=true|false (BETA - default=true)
              DebugContainers=true|false (ALPHA - default=false)
              DevicePlugins=true|false (BETA - default=true)
              DryRun=true|false (BETA - default=true)
              DynamicAuditing=true|false (ALPHA - default=false)
              DynamicKubeletConfig=true|false (BETA - default=true)
              ExpandCSIVolumes=true|false (ALPHA - default=false)
              ExpandInUsePersistentVolumes=true|false (BETA - default=true)
              ExpandPersistentVolumes=true|false (BETA - default=true)
              ExperimentalCriticalPodAnnotation=true|false (ALPHA - default=false)
              ExperimentalHostUserNamespaceDefaulting=true|false (BETA - default=false)
              HyperVContainer=true|false (ALPHA - default=false)
              KubeletPodResources=true|false (BETA - default=true)
              LocalStorageCapacityIsolation=true|false (BETA - default=true)
              LocalStorageCapacityIsolationFSQuotaMonitoring=true|false (ALPHA - default=false)
              MountContainers=true|false (ALPHA - default=false)
              NodeLease=true|false (BETA - default=true)
              NonPreemptingPriority=true|false (ALPHA - default=false)
              PodShareProcessNamespace=true|false (BETA - default=true)
              ProcMountType=true|false (ALPHA - default=false)
              QOSReserved=true|false (ALPHA - default=false)
              RemainingItemCount=true|false (ALPHA - default=false)
              RequestManagement=true|false (ALPHA - default=false)
              ResourceLimitsPriorityFunction=true|false (ALPHA - default=false)
              ResourceQuotaScopeSelectors=true|false (BETA - default=true)
              RotateKubeletClientCertificate=true|false (BETA - default=true)
              RotateKubeletServerCertificate=true|false (BETA - default=true)
              RunAsGroup=true|false (BETA - default=true)
              RuntimeClass=true|false (BETA - default=true)
              SCTPSupport=true|false (ALPHA - default=false)
              ScheduleDaemonSetPods=true|false (BETA - default=true)
              ServerSideApply=true|false (ALPHA - default=false)
              ServiceLoadBalancerFinalizer=true|false (ALPHA - default=false)
              ServiceNodeExclusion=true|false (ALPHA - default=false)
              StorageVersionHash=true|false (BETA - default=true)
              StreamingProxyRedirects=true|false (BETA - default=true)
              SupportNodePidsLimit=true|false (BETA - default=true)
              SupportPodPidsLimit=true|false (BETA - default=true)
              Sysctls=true|false (BETA - default=true)
              TTLAfterFinished=true|false (ALPHA - default=false)
              TaintBasedEvictions=true|false (BETA - default=true)
              TaintNodesByCondition=true|false (BETA - default=true)
              TokenRequest=true|false (BETA - default=true)
              TokenRequestProjection=true|false (BETA - default=true)
              ValidateProxyRedirects=true|false (BETA - default=true)
              VolumePVCDataSource=true|false (ALPHA - default=false)
              VolumeSnapshotDataSource=true|false (ALPHA - default=false)
              VolumeSubpathEnvExpansion=true|false (BETA - default=true)
              WatchBookmark=true|false (ALPHA - default=false)
              WinDSR=true|false (ALPHA - default=false)
              WinOverlay=true|false (ALPHA - default=false)
              WindowsGMSA=true|false (ALPHA - default=false)
              # 特性门控， [具体参考连接](https://kubernetes.io/zh/docs/reference/command-line-tools-reference/feature-gates/)
              # Alpha,Beta 特性代表：默认禁用。
              # General Availability (GA) 特性也称为稳定特性,此特性会一直启用；你不能禁用它。
    --master-service-namespace string                                                                                                                
              DEPRECATED: the namespace from which the kubernetes master services should be injected into pods. (default "default")
              # --namespace 默认命名空间设置， 实验为生效
    --max-mutating-requests-inflight int                                                                                                             
              The maximum number of mutating requests in flight at a given time. When the server exceeds this, it rejects requests. Zero for no limit.
              (default 200)
              # 给定时间内变更请求队列（mutating requests in flight）的最大值，默认值为200
              # 当服务器超过该值时，将拒绝请求
              # 0为没有限制
    --max-requests-inflight int                                                                                                                      
              The maximum number of non-mutating requests in flight at a given time. When the server exceeds this, it rejects requests. Zero for no
              limit. (default 400)
              # 给定时间内的非变更请求队列（non-mutating requests inflight）的最大值，默认值为400
              # 当服务器超过该值，将拒绝请求
              # 0为没有限制
    --min-request-timeout int                                                                                                                        
              An optional field indicating the minimum number of seconds a handler must keep a request open before timing it out. Currently only honored
              by the watch request handler, which picks a randomized value above this number as the connection timeout, to spread out load. (default 1800)
              # 可选，默认值为1800
              # 表示在一个请求超时之前，handler必须保持该请求打开状态的最小秒数
              # 当前仅被watch request handler支持，handler将随机数设为链接的超时值，以保持负荷
    --request-timeout duration                                                                                                                       
              An optional field indicating the duration a handler must keep a request open before timing it out. This is the default request timeout for
              requests but may be overridden by flags such as --min-request-timeout for specific types of requests. (default 1m0s)
              # 可选参数
              # 一个请求超时前handler保持该请求打开状态的持续时间，默认值为10s
              # 该参数为默认的请求超时时间，但可能会被其他参数覆盖，比如--min-request-timeout
    --target-ram-mb int                                                                                                                              
              Memory limit for apiserver in MB (used to configure sizes of caches, etc.)
              # 限制apiserver使用的内存大小，单位MB，（用来配置缓存大小等等）
Etcd flags:

      --default-watch-cache-size int                                                                                                                   
                Default watch cache size. If zero, watch cache will be disabled for resources that do not have a default watch size set. (default 100)
                # 默认的watch缓存大小，默认值为100
                # 若为0，未设置默认watch size的资源的watch缓存将关闭
      --delete-collection-workers int                                                                                                                  
                Number of workers spawned for DeleteCollection call. These are used to speed up namespace cleanup. (default 1)
                # 设定调用DeleteCollection的worker数量，workers被用来加速清理namespace
                # 默认值为1
      --enable-garbage-collector                                                                                                                       
                Enables the generic garbage collector. MUST be synced with the corresponding flag of the kube-controller-manager. (default true)
                # 是否启用通用garbage collector，默认值为true
                # 必须与kube-controller-manager对应参数一致
      --encryption-provider-config string                                                                                                              
                The file containing configuration for encryption providers to be used for storing secrets in etcd
                # 存储secrets到etcd内的encryption provider的配置文件路径
      --etcd-cafile string                                                                                                                             
                SSL Certificate Authority file used to secure etcd communication.
                # etcd 授权文件
      --etcd-certfile string                                                                                                                           
                SSL certification file used to secure etcd communication.
                # etcd 证书文件
      --etcd-compaction-interval duration                                                                                                              
                The interval of compaction requests. If 0, the compaction request from apiserver is disabled. (default 5m0s)
                # 压缩请求间隔，默认值为5m0s
                # 若为0，则关闭API Server的压缩请求
      --etcd-count-metric-poll-period duration                                                                                                         
                Frequency of polling etcd for number of resources per type. 0 disables the metric collection. (default 1m0s)
                # 调查etcd中每种资源的数量的频率，默认值为1m0s
                # 若为0，则关闭metric的收集
      --etcd-keyfile string                                                                                                                            
                SSL key file used to secure etcd communication.
                # etch 证书key文件
      --etcd-prefix string                                                                                                                             
                The prefix to prepend to all resource paths in etcd. (default "/registry")
                # 设定etcd中所有资源路径的前缀
                # 默认值为/registry
      --etcd-servers strings                                                                                                                           
                List of etcd servers to connect with (scheme://ip:port), comma separated.
                # 设定etcd server列表（scheme://ip:port），以逗号分隔
      --etcd-servers-overrides strings                                                                                                                 
                Per-resource etcd servers overrides, comma separated. The individual override format: group/resource#servers, where servers are URLs,
                semicolon separated.
                # 以每种资源来重写（分隔？）etcd server，以逗号分隔
                # 单个重写格式：group/resorce#servers，servers需为URLs，以分号分隔
      --storage-backend string                                                                                                                         
                The storage backend for persistence. Options: 'etcd3' (default).
                # 持久化存储后端的名称，可选项：etcd3（默认）
      --storage-media-type string                                                                                                                      
                The media type to use to store objects in storage. Some resources or storage backends may only support a specific media type and will
                ignore this setting. (default "application/vnd.kubernetes.protobuf")
                # 仓库中存储对象的媒介类型，默认值为application/vnd.kubernetes.protobuf
                # 某些资源或存储后端可能只支持特定的媒介类型，将忽略此参数设定
      --watch-cache                                                                                                                                    
                Enable watch caching in the apiserver (default true)
      --watch-cache-sizes strings                                                                                                                      
                Watch cache size settings for some resources (pods, nodes, etc.), comma separated. The individual setting format: resource[.group]#size,
                where resource is lowercase plural (no version), group is omitted for resources of apiVersion v1 (the legacy core API) and included for
                others, and size is a number. It takes effect when watch-cache is enabled. Some resources (replicationcontrollers, endpoints, nodes, pods,
                services, apiservices.apiregistration.k8s.io) have system defaults set by heuristics, others default to default-watch-cache-size
                # 根据资源类型设定watch缓存，以逗号分隔
                # 设置格式resource[.group]#size，资源类型需小写（无版本号），apiVersionV1（legacy core API）可省略group，其他apiVersion不可省略group，size为数字。
                # 当--watch-cache开启时生效
                # 某些资源（replicationcontrollers, endpoints, nodes, pods, services, apiservices.apiregistration.k8s.io）具有默认的系统设置，其他资源以--default-watch-cache-size为默认值
Secure serving flags:

      --bind-address ip                                                                                                                                
                The IP address on which to listen for the --secure-port port. The associated interface(s) must be reachable by the rest of the cluster,
                and by CLI/web clients. If blank, all interfaces will be used (0.0.0.0 for all IPv4 interfaces and :: for all IPv6 interfaces). (default
                0.0.0.0)
                # 监听--secure-port端口的IP地址
                # 该接口必须被集群中的其他成员、CLI/web客户端可达
                # 如果为空，则所有接口将默认使用0.0.0.0(IPV4), ::(IPV6)
      --cert-dir string                                                                                                                                
                The directory where the TLS certs are located. If --tls-cert-file and --tls-private-key-file are provided, this flag will be ignored.
                (default "/var/run/kubernetes")
                # TLS certs文件路径
                # 默认值为/var/run/kubernetes
                # 若已设置--tls-cert-file和--tls-private-key-file，该参数将被忽略
      --http2-max-streams-per-connection int                                                                                                           
                The limit that the server gives to clients for the maximum number of streams in an HTTP/2 connection. Zero means to use golang's default.
                # 服务器提供给客户端的最大HTTP/2连接流数量限制
                # 0表示使用golang默认值
      --secure-port int                                                                                                                                
                The port on which to serve HTTPS with authentication and authorization.It cannot be switched off with 0. (default 6443)
                # https安全端口号，默认值为6443
                # 无法通过设为0来关闭此端口
      --tls-cert-file string                                                                                                                           
                File containing the default x509 Certificate for HTTPS. (CA cert, if any, concatenated after server cert). If HTTPS serving is enabled,
                and --tls-cert-file and --tls-private-key-file are not provided, a self-signed certificate and key are generated for the public address
                and saved to the directory specified by --cert-dir.
                # https 证书
      --tls-cipher-suites strings                                                                                                                      
                Comma-separated list of cipher suites for the server. If omitted, the default Go cipher suites will be use.  Possible values:
                TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_RC4_128_SHA,TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_RC4_128_SHA,TLS_RSA_WITH_3DES_EDE_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_RC4_128_SHA
                # 服务器的密码套件的逗号分隔列表。 如果省略，将使用默认的Go密码套件。 可能的值：
      --tls-min-version string                                                                                                                         
                Minimum TLS version supported. Possible values: VersionTLS10, VersionTLS11, VersionTLS12, VersionTLS13
                # 支持的最低TLS版本。 可能的值：VersionTLS10，VersionTLS11，VersionTLS12，VersionTLS13
      --tls-private-key-file string                                                                                                             
                File containing the default x509 private key matching --tls-cert-file.
                # 与--tls-cert-file匹配的x509私钥文件路径
      --tls-sni-cert-key namedCertKey                                                                                                                  
                A pair of x509 certificate and private key file paths, optionally suffixed with a list of domain patterns which are fully qualified domain
                names, possibly with prefixed wildcard segments. If no domain patterns are provided, the names of the certificate are extracted.
                Non-wildcard matches trump over wildcard matches, explicit domain patterns trump over extracted names. For multiple key/certificate pairs,
                use the --tls-sni-cert-key multiple times. Examples: "example.crt,example.key" or "foo.crt,foo.key:*.foo.com,foo.com". (default [])
                # 含有x509证书和私钥对的文件路径，可以以FQDN格式的域名列表作为后缀（支持以通配符为前缀），若未提供域名，将提取证书的文件名
                # 优先无通配符的配对而非有通配符的配对，优先有明确的域名格式而非提取的文件名
                # 若有多个key/cerficate对，可设置多个--tls-sni-cert-key
                # 例如："example.crt,example.key" or "foo.crt,foo.key:*.foo.com,foo.com"
                
Insecure serving flags:

      --address ip                                                                                                                                     
                The IP address on which to serve the insecure --port (set to 0.0.0.0 for all IPv4 interfaces and :: for all IPv6 interfaces). (default
                127.0.0.1) (DEPRECATED: see --bind-address instead.)
                # 安全的ip地址服务
      --insecure-bind-address ip                                                                                                                       
                The IP address on which to serve the --insecure-port (set to 0.0.0.0 for all IPv4 interfaces and :: for all IPv6 interfaces). (default
                127.0.0.1) (DEPRECATED: This flag will be removed in a future version.)
                # 绑定不安全的ip地址服务
      --insecure-port int                                                                                                                              
                The port on which to serve unsecured, unauthenticated access. (default 8080) (DEPRECATED: This flag will be removed in a future version.)
                # 不安全的端口暴露
      --port int                                                                                                                                       
                The port on which to serve unsecured, unauthenticated access. Set to 0 to disable. (default 8080) (DEPRECATED: see --secure-port instead.)
                # 安全的端口暴露
Auditing flags:

      --audit-dynamic-configuration                                                                                                                    
                Enables dynamic audit configuration. This feature also requires the DynamicAuditing feature flag
                # 是否启用dynamic audit configuration
                # 该参数需要先设置DynamicAuditing参数
      --audit-log-batch-buffer-size int                                                                                                                
                The size of the buffer to store events before batching and writing. Only used in batch mode. (default 10000)
                # 批量写入audit-log前存储的事件的缓存大小，默认值10000
                # 仅batch模式可用
      --audit-log-batch-max-size int                                                                                                                   
                The maximum size of a batch. Only used in batch mode. (default 1)
                # audit-log-batch的最大值，默认值为1
                # 仅batch模式可用
      --audit-log-batch-max-wait duration                                                                                                              
                The amount of time to wait before force writing the batch that hadn't reached the max size. Only used in batch mode.
                # 若一直未达到audit-log-batch的最大值，强制写入的等待时间周期
                # 仅在batch模式可用
      --audit-log-batch-throttle-burst int                                                                                                             
                Maximum number of requests sent at the same moment if ThrottleQPS was not utilized before. Only used in batch mode.
                # 在ThrottleQPS未被使用前，同一时间可发送的请求的最大值
                # 仅batch模式可用
      --audit-log-batch-throttle-enable                                                                                                                
                Whether batching throttling is enabled. Only used in batch mode.
                # 打开audit-log-batch的throttle模式
                # 仅batch模式可用
      --audit-log-batch-throttle-qps float32                                                                                                           
                Maximum average number of batches per second. Only used in batch mode.
                # 设置audit-log-batch的throttle QPS值
                # 仅batch模式可用
      --audit-log-format string                                                                                                                        
                Format of saved audits. "legacy" indicates 1-line text format for each event. "json" indicates structured json format. Known formats are
                legacy,json. (default "json")
                # audit-log的文件保存格式，默认值为json
                # "legacy"为一个事件一行
                # "json"为json结构格式
                # 现有值为legacy和json
      --audit-log-maxage int                                                                                                                           
                The maximum number of days to retain old audit log files based on the timestamp encoded in their filename.
                # audit-log的最大保留天数，以文件名中的时间戳为基础计算
      --audit-log-maxbackup int                                                                                                                        
                The maximum number of old audit log files to retain.
                # audit-log文件的最大保留数量
      --audit-log-maxsize int                                                                                                                          
                The maximum size in megabytes of the audit log file before it gets rotated.
                # rotated前单个audit-log文件的最大值，单位megabytes
      --audit-log-mode string                                                                                                                          
                Strategy for sending audit events. Blocking indicates sending events should block server responses. Batch causes the backend to buffer and
                write events asynchronously. Known modes are batch,blocking,blocking-strict. (default "blocking")
                # 发送audit-log事件的策略
                # blocking为发送事件时阻塞服务器响应
                # batch为backend异步缓冲和写事件
                # 现有模式为batch, blocking, blocking-stric
      --audit-log-path string                                                                                                                          
                If set, all requests coming to the apiserver will be logged to this file.  '-' means standard out.
                # audit-log文件的保存路径
                # '-'表示stdout
      --audit-log-truncate-enabled                                                                                                                     
                Whether event and batch truncating is enabled.
                # 是否打开event和batch的截断功能
      --audit-log-truncate-max-batch-size int                                                                                                          
                Maximum size of the batch sent to the underlying backend. Actual serialized size can be several hundreds of bytes greater. If a batch
                exceeds this limit, it is split into several batches of smaller size. (default 10485760)
                # 发送到底层后端的单个audit-log batch的最大值。默认值为10485760
                # 序列化后的大小可能会多几百字节。如果一个batch超过该限制，将会被分割成几个较小的batch
      --audit-log-truncate-max-event-size int                                                                                                          
                Maximum size of the audit event sent to the underlying backend. If the size of an event is greater than this number, first request and
                response are removed, and if this doesn't reduce the size enough, event is discarded. (default 102400)
                # 发送到底层后端的单个audit event的最大值，默认值为102400
                # 如果event大于该值，首个请求和响应将被移除，如果仍超过最大值，该event将被丢弃。
      --audit-log-version string                                                                                                                       
                API group and version used for serializing audit events written to log. (default "audit.k8s.io/v1")
                # 指定写入log的序列化audit event的API group和version
                # 默认值为"audit.k8s.io/v1"
      --audit-policy-file string                                                                                                                       
                Path to the file that defines the audit policy configuration.
                # audit policy的配置文件路径
      --audit-webhook-batch-buffer-size int                                                                                                            
                The size of the buffer to store events before batching and writing. Only used in batch mode. (default 10000)
                # 在batching和writing之前保存audit-webhook event的最大缓存值，默认值为10000
                # 仅batch模式可用
      --audit-webhook-batch-max-size int                                                                                                               
                The maximum size of a batch. Only used in batch mode. (default 400)
                # 单个audit-webhook batch的最大值，默认值为400
                # 仅batch模式可用
      --audit-webhook-batch-max-wait duration                                                                                                          
                The amount of time to wait before force writing the batch that hadn't reached the max size. Only used in batch mode. (default 30s)
                # 强制写入未达到最大size的batch的等待时间周期，默认值为30s
                # 仅batch模式可用
      --audit-webhook-batch-throttle-burst int                                                                                                         
                Maximum number of requests sent at the same moment if ThrottleQPS was not utilized before. Only used in batch mode. (default 15)
                # ThrottleQPS未被使用时，同时发送请求的最大数量，默认值为15
                # 仅batch模式可用
      --audit-webhook-batch-throttle-enable                                                                                                            
                Whether batching throttling is enabled. Only used in batch mode. (default true)
                # 是否开启batching throttling，默认值为true
                # 仅batch模式可用
      --audit-webhook-batch-throttle-qps float32                                                                                                       
                Maximum average number of batches per second. Only used in batch mode. (default 10)
                # 每秒batch的最大平均数量，默认值为10
                # 仅batch模式可用
      --audit-webhook-config-file string                                                                                                               
                Path to a kubeconfig formatted file that defines the audit webhook configuration.
                # audit webhook的配置文件路径（kubeconfig格式）
      --audit-webhook-initial-backoff duration                                                                                                         
                The amount of time to wait before retrying the first failed request. (default 10s)
                # 首次请求失败后，重试的等待时间，默认值为10s
      --audit-webhook-mode string                                                                                                                      
                Strategy for sending audit events. Blocking indicates sending events should block server responses. Batch causes the backend to buffer and
                write events asynchronously. Known modes are batch,blocking,blocking-strict. (default "batch")
                # audit-webhook的策略模式
                # blocking为发送event将阻塞服务器响应
                # batch为后端异步缓冲和写event
                # 已有模式为batch, blocking, blocking-strict
      --audit-webhook-truncate-enabled                                                                                                                 
                Whether event and batch truncating is enabled.
                # 是否打开audit-webhook event和batch的截断模式
      --audit-webhook-truncate-max-batch-size int                                                                                                      
                Maximum size of the batch sent to the underlying backend. Actual serialized size can be several hundreds of bytes greater. If a batch
                exceeds this limit, it is split into several batches of smaller size. (default 10485760)
                # 发送到底层后端的audit-webhook batch的最大值，默认值为10485760
                # 序列化后的大小可能会超过数百字节，如果一个batch超过该限制，则会被分割成几个较小的batch
      --audit-webhook-truncate-max-event-size int                                                                                                      
                Maximum size of the audit event sent to the underlying backend. If the size of an event is greater than this number, first request and
                response are removed, and if this doesn't reduce the size enough, event is discarded. (default 102400)
                # 发送到底层后端的单个audit-webhook event的最大值，默认值为102400
                # 若某个event大于该数值，首个请求和响应将被移除，若仍大于该数值，则该event将被丢弃
      --audit-webhook-version string                                                                                                                   
                API group and version used for serializing audit events written to webhook. (default "audit.k8s.io/v1")
                --audit-webhook-version-string
                # 写入webhook的序列化audit event的API group和version
                # 默认值为"audit.k8s.io/v1"

Features flags:

      --contention-profiling                                                                                                                           
                Enable lock contention profiling, if profiling is enabled
                # 若分析已启用，则启用锁定竞争分析
                # 不太明白，需研究
      --profiling                                                                                                                                      
                Enable profiling via web interface host:port/debug/pprof/ (default true)
                # 开启web界面的分析功能，默认值为true
                # 访问地址host:port/debug/pprof/

Authentication flags:

      --anonymous-auth                                                                                                                                 
                Enables anonymous requests to the secure port of the API server. Requests that are not rejected by another authentication method are
                treated as anonymous requests. Anonymous requests have a username of system:anonymous, and a group name of system:unauthenticated.
                (default true)
                # 是否允许对API Server安全端口的匿名请求，未被其他身份验证方法拒绝的请求将被视为匿名请求
                # 匿名请求具有system username：anonymous，system group name：unauthenticated
                # 默认值：true
      --api-audiences strings                                                                                                                          
                Identifiers of the API. The service account token authenticator will validate that tokens used against the API are bound to at least one
                of these audiences. If the --service-account-issuer flag is configured and this flag is not, this field defaults to a single element list
                containing the issuer URL .
                # API的标识符列表。service account token验证器将验证token使用的API绑定了至少一个标识符列表中的值。
                # 如果启动了service-account-issuer参数，但api-audiences未设置，则该字段默认值为包含service-account-issuer的单元素列表
                
      --authentication-token-webhook-cache-ttl duration                                                                                                
                The duration to cache responses from the webhook token authenticator. (default 2m0s)
                # webhook token验证器的缓存响应时间，默认值为2m0s
      --authentication-token-webhook-config-file string                                                                                                
                File with webhook configuration for token authentication in kubeconfig format. The API server will query the remote service to determine
                authentication for bearer tokens.
                # token认证的webhook配置文件（kubeconfig格式）
                # API server将查询远程服务以确定不记名（bearer）token的认证结果
      --basic-auth-file string                                                                                                                         
                If set, the file that will be used to admit requests to the secure port of the API server via http basic authentication.
      --client-ca-file string                                                                                                                          
                If set, any request presenting a client certificate signed by one of the authorities in the client-ca-file is authenticated with an
                identity corresponding to the CommonName of the client certificate.
      --enable-bootstrap-token-auth                                                                                                                    
                Enable to allow secrets of type 'bootstrap.kubernetes.io/token' in the 'kube-system' namespace to be used for TLS bootstrapping authentication.
                # 是否启用TLS bootstrap认证模式
      --oidc-ca-file string                                                                                                                            
                If set, the OpenID server's certificate will be verified by one of the authorities in the oidc-ca-file, otherwise the host's root CA set
                will be used.
                # OpenID server的ca文件路径
                # 若不设置，将使用本机的root ca设置
      --oidc-client-id string                                                                                                                          
                The client ID for the OpenID Connect client, must be set if oidc-issuer-url is set.
                # OpenID Connect客户端ID
                # 当已设置--oidc-issuer-url时，必须设置该参数
      --oidc-groups-claim string                                                                                                                       
                If provided, the name of a custom OpenID Connect claim for specifying user groups. The claim value is expected to be a string or array of
                strings. This flag is experimental, please see the authentication documentation for further details.
                # 指定OpenID的user groups
                # 该值需为字符串或字符串数组
                # 该参数为试验性质，请查阅authentication文档获取更多详情
      --oidc-groups-prefix string                                                                                                                      
                If provided, all groups will be prefixed with this value to prevent conflicts with other authentication strategies.
                # 设定OpenID组的前缀，以便与其他认证策略区分
      --oidc-issuer-url string                                                                                                                         
                The URL of the OpenID issuer, only HTTPS scheme will be accepted. If set, it will be used to verify the OIDC JSON Web Token (JWT).
                # OpenID issuer的URL，仅接受https
                # 若设置，将被用来确认OIDC JWT（Json Web Token）
      --oidc-required-claim mapStringString                                                                                                            
                A key=value pair that describes a required claim in the ID Token. If set, the claim is verified to be present in the ID Token with a
                matching value. Repeat this flag to specify multiple claims.
                # 以键值对描述的ID Token所需的断言
                # 该断言将被用来确认ID Token是否匹配
                # 可多次设置该参数来指定多个断言
      --oidc-signing-algs strings                                                                                                                      
                Comma-separated list of allowed JOSE asymmetric signing algorithms. JWTs with a 'alg' header value not in this list will be rejected.
                Values are defined by RFC 7518 https://tools.ietf.org/html/rfc7518#section-3.1. (default [RS256])
                # 可接受的JOSE非对称签名算法列表，以逗号分隔
                # 默认值为RS256
                # 若JWTs head中的alg字段值不在该列表中，将拒绝该JWT
                # 可使用的值请参考RFC 7518 https://tools.ietf.org/html/rfc7518#section-3.1
      --oidc-username-claim string                                                                                                                     
                The OpenID claim to use as the user name. Note that claims other than the default ('sub') is not guaranteed to be unique and immutable.
                This flag is experimental, please see the authentication documentation for further details. (default "sub")
                # OpenID的用户名，默认值为sub
                # 请注意，不保证除sub以外的断言值的唯一性和不可变性
                # 该参数为试验性，请查阅authentication文档获取更多详情
      --oidc-username-prefix string                                                                                                                    
                If provided, all usernames will be prefixed with this value. If not provided, username claims other than 'email' are prefixed by the
                issuer URL to avoid clashes. To skip any prefixing, provide the value '-'.
                # OpenID的默认用户名前缀
                # 若不设置，除email外的所有用户名将默认以issuer URL开头以避免冲突
                # 若设置为'-'，将取消所有默认前缀
      --requestheader-allowed-names strings                                                                                                            
                List of client certificate common names to allow to provide usernames in headers specified by --requestheader-username-headers. If empty,
                any client certificate validated by the authorities in --requestheader-client-ca-file is allowed.
                # 客户端证书的common names列表，--requestheader-username-headers参数中指定可用的用户名
                # 若为空，将允许所有可被--requestheader-client-ca-file中ca验证的客户端证书
      --requestheader-client-ca-file string                                                                                                            
                Root certificate bundle to use to verify client certificates on incoming requests before trusting usernames in headers specified by
                --requestheader-username-headers. WARNING: generally do not depend on authorization being already done for incoming requests.
                # 在信任--requestheader-username-headers参数中指定的username之前，用来验证客户端证书的传入请求的ca文件。
                # 一般不依赖于已验证过的传入请求
      --requestheader-extra-headers-prefix strings                                                                                                     
                List of request header prefixes to inspect. X-Remote-Extra- is suggested.
                # 需注入到请求头的前缀
                # 建议设为X-Remote-Extra-
      --requestheader-group-headers strings                                                                                                            
                List of request headers to inspect for groups. X-Remote-Group is suggested.
                # 需注入到请求头中的Group前缀
                # 建议设为X-Remote-Group
      --requestheader-username-headers strings                                                                                                         
                List of request headers to inspect for usernames. X-Remote-User is common.
                # 需注入到请求头中的username前缀
                # 一般为X-Remote-User
      --service-account-issuer string                                                                                                                  
                Identifier of the service account token issuer. The issuer will assert this identifier in "iss" claim of issued tokens. This value is a
                string or URI.
                # 指定service account token issuer的标识符
                # 该issuer将在iss声明中分发Token以使标识符生效
                # 该参数的值为字符串或URL
      --service-account-key-file stringArray                                                                                                           
                File containing PEM-encoded x509 RSA or ECDSA private or public keys, used to verify ServiceAccount tokens. The specified file can contain
                multiple keys, and the flag can be specified multiple times with different files. If unspecified, --tls-private-key-file is used. Must be
                specified when --service-account-signing-key is provided
                # 验证ServiceAccount Token的私钥或公钥文件，以x509 RSA或ECDSA PEM编码
                # 指定的文件可以包含多个key
                # 可以多次设置该参数以指定不同的文件
                # 若未设置，将使用--tls-private-key-file
                # 当设置了--service-account-signing-key参数时，必须设置该参数
      --service-account-lookup                                                                                                                         
                If true, validate ServiceAccount tokens exist in etcd as part of authentication. (default true)
                # 若true，将验证etcd中是否存在对应的ServiceAccount Token作为认证的一部分
                # 默认值为true
      --service-account-max-token-expiration duration                                                                                                  
                The maximum validity duration of a token created by the service account token issuer. If an otherwise valid TokenRequest with a validity
                duration larger than this value is requested, a token will be issued with a validity duration of this value.
                # service account token issuer创建的token的最大有效逾期时间
                # 当有以其他形式创建的TokenRequest，逾期时间超过该值，此token的有效逾期时间将被设为该值
      --token-auth-file string                                                                                                                         
                If set, the file that will be used to secure the secure port of the API server via token authentication.
                # 若设置，token authentication将使用指定的文件加密API server的加密端口
Authorization flags:

      --authorization-mode strings                                                                                                                     
                Ordered list of plug-ins to do authorization on secure port. Comma-delimited list of: AlwaysAllow,AlwaysDeny,ABAC,Webhook,RBAC,Node.
                (default [AlwaysAllow])
                # 通过安全端口认证模式的插件列表
                # 默认值AlwaysAllow
                # 现有列表（以逗号分隔）：AlwaysAllow,AlwaysDeny,ABAC,Webhook,RBAC,Node
      --authorization-policy-file string                                                                                                               
                File with authorization policy in json line by line format, used with --authorization-mode=ABAC, on the secure port.
                # authorization-policy配置文件（json line by line格式）
                # --authorization-mode=ABAC且在安全端口上时需设置
      --authorization-webhook-cache-authorized-ttl duration                                                                                            
                The duration to cache 'authorized' responses from the webhook authorizer. (default 5m0s)
                # 缓存来自webhook认证器'authorized'响应的持续时间，默认值为5m0s
      --authorization-webhook-cache-unauthorized-ttl duration                                                                                          
                The duration to cache 'unauthorized' responses from the webhook authorizer. (default 30s)
                # 缓存来自webhook认证器'unauthorized'响应的持续时间，默认值为30s
      --authorization-webhook-config-file string                                                                                                       
                File with webhook configuration in kubeconfig format, used with --authorization-mode=Webhook. The API server will query the remote service
                to determine access on the API server's secure port.
                # webhook认证的配置文件路径（kubeconfig格式）
                # --authorization-mode=Webhook时需设置
                # API server将查询远程服务以确认API server安全端口的使用权限

Cloud provider flags:

      --cloud-config string                                                                                                                            
                The path to the cloud provider configuration file. Empty string for no configuration file.
                # 云服务商配置文件
      --cloud-provider string                                                                                                                          
                The provider for cloud services. Empty string for no provider.
                # 云服务商

Api enablement flags:

      --runtime-config mapStringString                                                                                                                 
                A set of key=value pairs that describe runtime configuration that may be passed to apiserver. <group>/<version> (or <version> for the core
                group) key can be used to turn on/off specific api versions. api/all is special key to control all api versions, be careful setting it
                false, unless you know what you do. api/legacy is deprecated, we will remove it in the future, so stop using it.
                # 以键值对形式开启或关闭内建的APIs
                # 支持的选项如下：
                v1=true|false for the core API group
                <group>/<version>=true|false for a specific API group and version (e.g. apps/v1=true)
                api/all=true|false controls all API versions
                api/ga=true|false controls all API versions of the form v[0-9]+
                api/beta=true|false controls all API versions of the form v[0-9]+beta[0-9]+
                api/alpha=true|false controls all API versions of the form v[0-9]+alpha[0-9]+
                api/legacy 已废弃，将在未来版本中移除

Admission flags:

      --admission-control strings                                                                                                                      
                Admission is divided into two phases. In the first phase, only mutating admission plugins run. In the second phase, only validating
                admission plugins run. The names in the below list may represent a validating plugin, a mutating plugin, or both. The order of plugins in
                which they are passed to this flag does not matter. Comma-delimited list of: AlwaysAdmit, AlwaysDeny, AlwaysPullImages,
                DefaultStorageClass, DefaultTolerationSeconds, DenyEscalatingExec, DenyExecOnPrivileged, EventRateLimit, ExtendedResourceToleration,
                ImagePolicyWebhook, LimitPodHardAntiAffinityTopology, LimitRanger, MutatingAdmissionWebhook, NamespaceAutoProvision, NamespaceExists,
                NamespaceLifecycle, NodeRestriction, OwnerReferencesPermissionEnforcement, PersistentVolumeClaimResize, PersistentVolumeLabel,
                PodNodeSelector, PodPreset, PodSecurityPolicy, PodTolerationRestriction, Priority, ResourceQuota, SecurityContextDeny, ServiceAccount,
                StorageObjectInUseProtection, TaintNodesByCondition, ValidatingAdmissionWebhook. (DEPRECATED: Use --enable-admission-plugins or
                --disable-admission-plugins instead. Will be removed in a future version.)
                # 必须关闭的admission插件列表（即使已默认开启）
                # 默认开启的插件列表：NamespaceLifecycle, LimitRanger, ServiceAccount, TaintNodesByCondition, Priority, DefaultTolerationSeconds, DefaultStorageClass, StorageObjectInUseProtection, PersistentVolumeClaimResize, MutatingAdmissionWebhook, ValidatingAdmissionWebhook, RuntimeClass, ResourceQuota
                # 可关闭的插件列表（以逗号隔开，排名不分先后）：AlwaysAdmit, AlwaysDeny, AlwaysPullImages, DefaultStorageClass, DefaultTolerationSeconds,.....
                # 指定admission control configuration文件的路径
      --disable-admission-plugins strings                                                                                                              
                admission plugins that should be disabled although they are in the default enabled plugins list (NamespaceLifecycle, LimitRanger,
                ServiceAccount, TaintNodesByCondition, Priority, DefaultTolerationSeconds, DefaultStorageClass, StorageObjectInUseProtection,
                PersistentVolumeClaimResize, MutatingAdmissionWebhook, ValidatingAdmissionWebhook, ResourceQuota). Comma-delimited list of admission
                plugins: AlwaysAdmit, AlwaysDeny, AlwaysPullImages, DefaultStorageClass, DefaultTolerationSeconds, DenyEscalatingExec,
                DenyExecOnPrivileged, EventRateLimit, ExtendedResourceToleration, ImagePolicyWebhook, LimitPodHardAntiAffinityTopology, LimitRanger,
                MutatingAdmissionWebhook, NamespaceAutoProvision, NamespaceExists, NamespaceLifecycle, NodeRestriction,
                OwnerReferencesPermissionEnforcement, PersistentVolumeClaimResize, PersistentVolumeLabel, PodNodeSelector, PodPreset, PodSecurityPolicy,
                PodTolerationRestriction, Priority, ResourceQuota, SecurityContextDeny, ServiceAccount, StorageObjectInUseProtection,
                TaintNodesByCondition, ValidatingAdmissionWebhook. The order of plugins in this flag does not matter.
                # 去激活插件
      --enable-admission-plugins strings                                                                                                               
                admission plugins that should be enabled in addition to default enabled ones (NamespaceLifecycle, LimitRanger, ServiceAccount,
                TaintNodesByCondition, Priority, DefaultTolerationSeconds, DefaultStorageClass, StorageObjectInUseProtection, PersistentVolumeClaimResize,
                MutatingAdmissionWebhook, ValidatingAdmissionWebhook, ResourceQuota). Comma-delimited list of admission plugins: AlwaysAdmit, AlwaysDeny,
                AlwaysPullImages, DefaultStorageClass, DefaultTolerationSeconds, DenyEscalatingExec, DenyExecOnPrivileged, EventRateLimit,
                ExtendedResourceToleration, ImagePolicyWebhook, LimitPodHardAntiAffinityTopology, LimitRanger, MutatingAdmissionWebhook,
                NamespaceAutoProvision, NamespaceExists, NamespaceLifecycle, NodeRestriction, OwnerReferencesPermissionEnforcement,
                PersistentVolumeClaimResize, PersistentVolumeLabel, PodNodeSelector, PodPreset, PodSecurityPolicy, PodTolerationRestriction, Priority,
                ResourceQuota, SecurityContextDeny, ServiceAccount, StorageObjectInUseProtection, TaintNodesByCondition, ValidatingAdmissionWebhook. The
                order of plugins in this flag does not matter.
                # 激活插件

Misc flags:

      --allow-privileged                                                                                                                               
                If true, allow privileged containers. [default=false]
                # 是否允许特权容器（privileged container），默认false
      --apiserver-count int                                                                                                                            
                The number of apiservers running in the cluster, must be a positive number. (In use when --endpoint-reconciler-type=master-count is
                enabled.) (default 1)
                # endpoint reconciler模式，默认值为lease
                # 可用模式：master-count, lease, none
      --enable-aggregator-routing                                                                                                                      
                Turns on aggregator routing requests to endpoints IP rather than cluster IP.
                # 是否启用aggregator routing请求到endpoints IP而非集群IP
      --endpoint-reconciler-type string                                                                                                                
                Use an endpoint reconciler (master-count, lease, none) (default "lease")
      --event-ttl duration                                                                                                                             
                Amount of time to retain events. (default 1h0m0s)
                # events的保留时间，默认值为1h0m0s
      --kubelet-certificate-authority string                                                                                                           
                Path to a cert file for the certificate authority.
                # kubelet certificate authority的cert文件路径
      --kubelet-client-certificate string                                                                                                              
                Path to a client cert file for TLS.
                # 客户端（kubelet）TLS通讯的cert文件路径
      --kubelet-client-key string                                                                                                                      
                Path to a client key file for TLS.
                # 客户端（kubelet）TLS通讯的key文件路径
      --kubelet-https                                                                                                                                  
                Use https for kubelet connections. (default true)
                # 是否启用kubelet的https链接，默认值为true
      --kubelet-preferred-address-types strings                                                                                                        
                List of the preferred NodeAddressTypes to use for kubelet connections. (default [Hostname,InternalDNS,InternalIP,ExternalDNS,ExternalIP])
                # kubelet连接的NodeAddressType优先级列表（优先访问哪个地址）
                # 默认值为Hostname,InternalDNS,InternalIP,ExternalDNS,ExternalI
      --kubelet-read-only-port uint                                                                                                                    
                DEPRECATED: kubelet port. (default 10255)
      --kubelet-timeout duration                                                                                                                       
                Timeout for kubelet operations. (default 5s)
                # kubelet操作的超时时间，默认值为5s
      --kubernetes-service-node-port int                                                                                                               
                If non-zero, the Kubernetes master service (which apiserver creates/maintains) will be of type NodePort, using this as the value of the
                port. If zero, the Kubernetes master service will be of type ClusterIP.
                # 若不为0，kubernetes master service(apiserver所在主机)将以NodePort形式暴露（使用该值为端口号）
                # 若为0，kubernetes master service将以ClusterIP形式暴露
      --max-connection-bytes-per-sec int                                                                                                               
                If non-zero, throttle each user connection to this number of bytes/sec. Currently only applies to long-running requests.
      --proxy-client-cert-file string                                                                                                                  
                Client certificate used to prove the identity of the aggregator or kube-apiserver when it must call out during a request. This includes
                proxying requests to a user api-server and calling out to webhook admission plugins. It is expected that this cert includes a signature
                from the CA in the --requestheader-client-ca-file flag. That CA is published in the 'extension-apiserver-authentication' configmap in the
                kube-system namespace. Components receiving calls from kube-aggregator should use that CA to perform their half of the mutual TLS verification.
                # 客户端代理的cert文件路径
                # 当需要在请求中调用aggregator或kube-apiserver时使用
                # 包括代理请求到api-server用户和调用webhook admission插件
                # 该cert文件必须包含--requestheader-client-ca-file参数中指定的CA签名，该CA签名保存在kube-system namespace下的‘extension-apiserver-authentication’ configmap中
                # 当kube-aggregator调用其他组件时，此CA签名提供一半的TLS相互身份验证信息（half of the mutual TLS verfication）
      --proxy-client-key-file string                                                                                                                   
                Private key for the client certificate used to prove the identity of the aggregator or kube-apiserver when it must call out during a
                request. This includes proxying requests to a user api-server and calling out to webhook admission plugins.
                # 客户端代理的私钥文件
                # 当需要在请求中调用aggregator或kube-apiserver时使用
                # 包括代理请求到api-server用户和调用webhook admission插件
      --service-account-signing-key-file string                                                                                                        
                Path to the file that contains the current private key of the service account token issuer. The issuer will sign issued ID tokens with
                this private key. (Requires the 'TokenRequest' feature gate.)
                # 含有当前service account token issuer私钥的文件路径
                # 该issuer将以此私钥签名发布的ID token（需开启TokenRequest特性）
      --service-cluster-ip-range ipNet                                                                                                                 
                A CIDR notation IP range from which to assign service cluster IPs. This must not overlap with any IP ranges assigned to nodes for pods.
                (default 10.0.0.0/24)
                # 以CIDR格式声明可分配的集群服务IP范围，不可与分配Pods的nodes IP地址范围重叠
      --service-node-port-range portRange                                                                                                              
                A port range to reserve for services with NodePort visibility. Example: '30000-32767'. Inclusive at both ends of the range. (default
                30000-32767)
                # 保留的以NodePort类型暴露的服务的端口范围，默认值为30000-32767，左闭右闭
