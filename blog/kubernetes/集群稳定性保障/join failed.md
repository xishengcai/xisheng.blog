# k8s nodes is forbidden user cannot list resource nodes in api group at the cluster scope

May 7, 2020· 4 min read ·[DOCKER](https://111qqz.com/tags/docker)[K8S](https://111qqz.com/tags/k8s)



继续将k8s用于模型转换和部署的自动化流程...然后发现之前安装k8s的文档不work了．． 时间是2020年5月7日，当前最新的k8s版本是　v1.18.2

报错如下:

```bash
  1
  2
  3<2kzzqw6rsjid0   --discovery-token-ca-cert-hash sha256:c6c72bdc96c0ff4d59559ff915eee61ba7ac5e8b93c0b2f9e11e813412387ec2  --v=5                                                                
  4W0507 15:45:12.608784    4768 join.go:346] [preflight] WARNING: JoinControlPane.controlPlane settings will be ignored when control-plane flag is not set.                                     
  5I0507 15:45:12.608822    4768 join.go:371] [preflight] found NodeName empty; using OS hostname as NodeName                                                                                    
  6I0507 15:45:12.608853    4768 initconfiguration.go:103] detected and using CRI socket: /var/run/dockershim.sock                                                                               
  7[preflight] Running pre-flight checks                                                                                                                                                         
  8I0507 15:45:12.608902    4768 preflight.go:90] [preflight] Running general checks                                                                                                             
  9I0507 15:45:12.608933    4768 checks.go:249] validating the existence and emptiness of directory /etc/kubernetes/manifests                                                                    
 10I0507 15:45:12.608966    4768 checks.go:286] validating the existence of file /etc/kubernetes/kubelet.conf                                                                                    
 11I0507 15:45:12.608975    4768 checks.go:286] validating the existence of file /etc/kubernetes/bootstrap-kubelet.conf                                                                          
 12I0507 15:45:12.608985    4768 checks.go:102] validating the container runtime                                                                                                                 
 13I0507 15:45:12.685381    4768 checks.go:128] validating if the service is enabled and active                                                                                                  
 14        [WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
 15I0507 15:45:12.765669    4768 checks.go:335] validating the contents of file /proc/sys/net/bridge/bridge-nf-call-iptables                                                                     
 16I0507 15:45:12.765720    4768 checks.go:335] validating the contents of file /proc/sys/net/ipv4/ip_forward                                                                                    
 17I0507 15:45:12.765752    4768 checks.go:649] validating whether swap is enabled or not                                                                                                        
 18I0507 15:45:12.765780    4768 checks.go:376] validating the presence of executable conntrack                                                                                                  
 19I0507 15:45:12.765804    4768 checks.go:376] validating the presence of executable ip                                                                                                         
 20I0507 15:45:12.765826    4768 checks.go:376] validating the presence of executable iptables                                                                                                   
 21I0507 15:45:12.765844    4768 checks.go:376] validating the presence of executable mount                                                                                                      
 22I0507 15:45:12.765864    4768 checks.go:376] validating the presence of executable nsenter                                                                                                    
 23I0507 15:45:12.765882    4768 checks.go:376] validating the presence of executable ebtables                                                                                                   
 24I0507 15:45:12.765902    4768 checks.go:376] validating the presence of executable ethtool                                                                                                    
 25I0507 15:45:12.765920    4768 checks.go:376] validating the presence of executable socat                                                                                                      
 26I0507 15:45:12.765935    4768 checks.go:376] validating the presence of executable tc                                                                                                         
 27I0507 15:45:12.765953    4768 checks.go:376] validating the presence of executable touch                                                                                                      
 28I0507 15:45:12.765973    4768 checks.go:520] running all checks                                                                                                                               
 29I0507 15:45:12.844881    4768 checks.go:406] checking whether the given node name is reachable using net.LookupHost                                                                           
 30I0507 15:45:12.845030    4768 checks.go:618] validating kubelet version
 31I0507 15:45:12.888056    4768 checks.go:128] validating if the service is enabled and active
 32I0507 15:45:12.893254    4768 checks.go:201] validating availability of port 10250
 33I0507 15:45:12.893373    4768 checks.go:286] validating the existence of file /etc/kubernetes/pki/ca.crt
 34I0507 15:45:12.893388    4768 checks.go:432] validating if the connectivity type is via proxy or direct
 35I0507 15:45:12.893414    4768 join.go:441] [preflight] Discovering cluster-info
 36I0507 15:45:12.893440    4768 token.go:78] [discovery] Created cluster-info discovery client, requesting info from "172.20.52.117:6443"
 37I0507 15:45:13.033539    4768 token.go:116] [discovery] Requesting info from "172.20.52.117:6443" again to validate TLS against the pinned public key
 38I0507 15:45:13.172634    4768 token.go:133] [discovery] Cluster info signature and contents are valid and TLS certificate validates against pinned roots, will use API Server "172.20.52.117:6443"
 39I0507 15:45:13.172653    4768 discovery.go:51] [discovery] Using provided TLSBootstrapToken as authentication credentials for the join process
 40I0507 15:45:13.172660    4768 join.go:455] [preflight] Fetching init configuration
 41I0507 15:45:13.172669    4768 join.go:493] [preflight] Retrieving KubeConfig objects
 42[preflight] Reading configuration from the cluster...
 43[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
 44I0507 15:45:13.541858    4768 interface.go:400] Looking for default routes with IPv4 addresses
 45I0507 15:45:13.541871    4768 interface.go:405] Default route transits interface "eth0"
 46I0507 15:45:13.541941    4768 interface.go:208] Interface eth0 is up
 47I0507 15:45:13.541978    4768 interface.go:256] Interface "eth0" has 2 addresses :[10.198.21.97/22 fe80::f816:3eff:fe5e:88f1/64].
 48I0507 15:45:13.541998    4768 interface.go:223] Checking addr  10.198.21.97/22.
 49I0507 15:45:13.542008    4768 interface.go:230] IP found 10.198.21.97
 50I0507 15:45:13.542016    4768 interface.go:262] Found valid IPv4 address 10.198.21.97 for interface "eth0".
 51I0507 15:45:13.542023    4768 interface.go:411] Found active IP 10.198.21.97 
 52I0507 15:45:13.542057    4768 preflight.go:101] [preflight] Running configuration dependant checks
 53I0507 15:45:13.542072    4768 controlplaneprepare.go:211] [download-certs] Skipping certs download
 54I0507 15:45:13.542080    4768 kubelet.go:111] [kubelet-start] writing bootstrap kubelet config file at /etc/kubernetes/bootstrap-kubelet.conf
 55I0507 15:45:13.542775    4768 kubelet.go:119] [kubelet-start] writing CA certificate at /etc/kubernetes/pki/ca.crt
 56I0507 15:45:13.543283    4768 kubelet.go:145] [kubelet-start] Checking for an existing Node in the cluster with name "host-10-198-21-97" and status "Ready"
 57nodes "host-10-198-21-97" is forbidden: User "system:bootstrap:0752yx" cannot get resource "nodes" in API group "" at the cluster scope
 58cannot get Node "host-10-198-21-97"
 59k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/join.runKubeletStartJoinPhase
 60        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/join/kubelet.go:148
 61k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow.(*Runner).Run.func1
 62        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow/runner.go:234
 63k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow.(*Runner).visitAll
 64        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow/runner.go:422
 65k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow.(*Runner).Run
 66        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow/runner.go:207
 67k8s.io/kubernetes/cmd/kubeadm/app/cmd.NewCmdJoin.func1
 68        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/cmd/join.go:170
 69k8s.io/kubernetes/vendor/github.com/spf13/cobra.(*Command).execute
 70        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/vendor/github.com/spf13/cobra/command.go:826
 71k8s.io/kubernetes/vendor/github.com/spf13/cobra.(*Command).ExecuteC
 72        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/vendor/github.com/spf13/cobra/command.go:914
 73k8s.io/kubernetes/vendor/github.com/spf13/cobra.(*Command).Execute
 74        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/vendor/github.com/spf13/cobra/command.go:864
 75k8s.io/kubernetes/cmd/kubeadm/app.Run
 76        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/kubeadm.go:50
 77main.main
 78        _output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/kubeadm.go:25
 79runtime.main
 80        /usr/local/go/src/runtime/proc.go:203
 81runtime.goexit
 82        /usr/local/go/src/runtime/asm_amd64.s:1357
 83error execution phase kubelet-start
 84k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow.(*Runner).Run.func1
 85        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow/runner.go:235
 86k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow.(*Runner).visitAll
 87        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow/runner.go:422
 88k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow.(*Runner).Run
 89        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/cmd/phases/workflow/runner.go:207
 90k8s.io/kubernetes/cmd/kubeadm/app/cmd.NewCmdJoin.func1
 91        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/cmd/join.go:170
 92k8s.io/kubernetes/vendor/github.com/spf13/cobra.(*Command).execute
 93        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/vendor/github.com/spf13/cobra/command.go:826
 94k8s.io/kubernetes/vendor/github.com/spf13/cobra.(*Command).ExecuteC
 95        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/vendor/github.com/spf13/cobra/command.go:914
 96k8s.io/kubernetes/vendor/github.com/spf13/cobra.(*Command).Execute
 97        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/vendor/github.com/spf13/cobra/command.go:864
 98k8s.io/kubernetes/cmd/kubeadm/app.Run
 99        /workspace/anago-v1.18.2-beta.0.14+a78cd082e8c913/src/k8s.io/kubernetes/_output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/app/kubeadm.go:50
100main.main
101        _output/dockerized/go/src/k8s.io/kubernetes/cmd/kubeadm/kubeadm.go:25
102runtime.main
103        /usr/local/go/src/runtime/proc.go:203
104runtime.goexit
105        /usr/local/go/src/runtime/asm_amd64.s:1357
106
```

...



SHELL

看起来重点的报错在这一句

```bash
1
2nodes "host-10-198-21-97" is forbidden: User "system:bootstrap:0752yx" cannot get resource "nodes" in API group "" at the cluster scope
3cannot get Node "host-10-198-21-97"
4
```



SHELL

然后google发现大概是权限相关的原因...Role-Based Access Contro　相关的．　但是似乎都不是在搭建集群的时候遇到的．

然后打算重新看一遍最新的搭建手册，发现troubleshooting里面

[Not possible to join a v1.18 Node to a v1.17 cluster due to missing RBAC](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/#not-possible-to-join-a-v1-18-node-to-a-v1-17-cluster-due-to-missing-rbac)

原来是v1.18增加了权限控制，1.18的slave机器没办法加入到1.17的master节点上...看来就是这个问题．

然后在控制节点上apply了如下内容:

```yaml
 1
 2apiVersion: rbac.authorization.k8s.io/v1
 3kind: ClusterRole
 4metadata:
 5  name: kubeadm:get-nodes
 6rules:
 7- apiGroups:
 8  - ""
 9  resources:
10  - nodes
11  verbs:
12  - get
13---
14apiVersion: rbac.authorization.k8s.io/v1
15kind: ClusterRoleBinding
16metadata:
17  name: kubeadm:get-nodes
18roleRef:
19  apiGroup: rbac.authorization.k8s.io
20  kind: ClusterRole
21  name: kubeadm:get-nodes
22subjects:
23- apiGroup: rbac.authorization.k8s.io
24  kind: Group
25  name: system:bootstrappers:kubeadm:default-node-token
26
```

...



YAML

重新尝试加入，已经可以了．