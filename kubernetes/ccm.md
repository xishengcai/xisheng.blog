# cloud controller manage



Kubernetes 是一个云原生平台，但为了让 Kubernetes 能够更好地运行在公有云平台上，能够灵活地使用、管理云上其他的基础资源和基础服务，
云厂商需要实现自己的适配器。 1.6版本之前各云服务商的基础资源管理代码都集成在kubernetes源码的CloudProvider中, 后面为了不影响kubernetes
版本的发布进度，将其从中解耦出来。由各云服务商独自实现其抽象出来的接口即可。
于是在 Kubernetes v1.6，引入了cloud-controller-manager(CCM)项目。



### 开发CCM 云服务商需要实现哪些接口

[cloudprovider.Interface](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/cloud-provider/cloud.go)

Interface

```go
type Interface interface {
    //　可以通过client　和　kube-apiserver通信,　启动自定义控制器，任何从这里启动的goroutine都
    //  必须可以安全退出
    // k8s.io/kubernetes/cmd/cloud-controller-manager/app/controllermanager.go  Line 225 被调用
    // openstack: return nil
    // alibaba: 启动了route 和　node 控制器
	Initialize(clientBuilder ControllerClientBuilder, stop <-chan struct{})
    
    // 操作云服务商LoadBalancer接口
	LoadBalancer() (LoadBalancer, bool)

    // 获取节点信息的接口
	Instances() (Instances, bool)

    // 获取节点和可用区的相关接口
	Zones() (Zones, bool)

    //　与集群相关接口，　可以不实现，　直接return nil, false
	Clusters() (Clusters, bool)

    // 与路由相关接口
	Routes() (Routes, bool)

    // 云服务商名称, 如aws, openstack, ali, huawei
	ProviderName() string

    // 集群ID,　暂时可以不用，　以后必须有
	HasClusterID() bool
}
```

```go
type InformerUser interface {
	SetInformers(informerFactory informers.SharedInformerFactory)
}
```

```go
type LoadBalancer interface {
    // 通过传入service对象，获取云服务商的LB exists and its status
	GetLoadBalancer(ctx context.Context, clusterName string, service *v1.Service) (status *v1.LoadBalancerStatus, exists bool, err error)
    
    // 通过传入的service 对象，获取LoadBalancerName, 创建lb的时候默认会根据service uid 前32位来命名
	GetLoadBalancerName(ctx context.Context, clusterName string, service *v1.Service) string

    // service controller 监听到 type 修改为LoadBalancher　的时候会触发该接口, 调用ccm 去创建　LB and EIP(floatIP)
	EnsureLoadBalancer(ctx context.Context, clusterName string, service *v1.Service, nodes []*v1.Node) (*v1.LoadBalancerStatus, error)

    // service controller 监听到 port or node change, 调用ccm modify lb.Listener or Backend
	UpdateLoadBalancer(ctx context.Context, clusterName string, service *v1.Service, nodes []*v1.Node) error
	
    //　service controller 监听到service　被删除或者type由于LoadBalancer改变为其他类型的时候触发,调用ccm delete LB and EIP
    EnsureLoadBalancerDeleted(ctx context.Context, clusterName string, service *v1.Service) error
}

type Instances interface {
	NodeAddresses(ctx context.Context, name types.NodeName) ([]v1.NodeAddress, error)
	NodeAddressesByProviderID(ctx context.Context, providerID string) ([]v1.NodeAddress, error)
	InstanceID(ctx context.Context, nodeName types.NodeName) (string, error)
	InstanceType(ctx context.Context, name types.NodeName) (string, error)
	InstanceTypeByProviderID(ctx context.Context, providerID string) (string, error)
	AddSSHKeyToAllInstances(ctx context.Context, user string, keyData []byte) error
	CurrentNodeName(ctx context.Context, hostname string) (types.NodeName, error)
	InstanceExistsByProviderID(ctx context.Context, providerID string) (bool, error)
	InstanceShutdownByProviderID(ctx context.Context, providerID string) (bool, error)
}

type Clusters interface {
	ListClusters(ctx context.Context) ([]string, error)
	Master(ctx context.Context, clusterName string) (string, error)
}

type Routes interface {
    //　列出当前集群的路由规则
	ListRoutes(ctx context.Context, clusterName string) ([]*Route, error)

    // 当前集群新建路由规则
	CreateRoute(ctx context.Context, clusterName string, nameHint string, route *Route) error

    // 删除路由规则
	DeleteRoute(ctx context.Context, clusterName string, route *Route) error
}

type Zones interface {
	GetZone(ctx context.Context) (Zone, error)
	GetZoneByProviderID(ctx context.Context, providerID string) (Zone, error)
	GetZoneByNodeName(ctx context.Context, nodeName types.NodeName) (Zone, error)
}

type PVLabeler interface {
	GetLabelsForVolume(ctx context.Context, pv *v1.PersistentVolume) (map[string]string, error)
}
```




### cloudProvider 到　CCM　的重构演进

因为原先的 Cloud Provider 与 Mater 中的组件 kube-controller-manager、kube-apiserver 以及 Node 中的组件
 kubelet 耦合很紧密，所以这三个组件也需要进行重构。

- kube-controller-manager 的重构策略
    - Route Controller 移入 CCM
    - Service Controller 移入 CCM
    - PersistentVolumeLabel Controller 移入 CCM
    - Node Controller 移入 CCM, 并且新增功能
        - CIDR 的管理
        - 监控节点的状态
        - 节点Pod的驱逐策略
    
- kube-apiserver 的重构策略
    - 分发SSH Keys 由CCM实现
    - PV的Adminssion Controller　由 kubelet实现

- kubelet的重构策略
  - kubelet 需要增加一个新功能：在 CCM 还未初始化 kubelet 所在节点时，需标记此节点类似“ NotReady ”的状态，防止
  scheduler 调度 Pod 到此节点时产生一系列错误。此功能通过给节点加上如下 Taints 并在 CCM 初始化后删去此 Taints 来实现
  
### CCM　架构介绍
![client-go](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/155236.png)



#### node controller

使用 Cloud Provider 来检查 Node 是否已经在云上被删除了。如果 Cloud Provider 返回有 Node 被删除，那么 
Node Controller 立马就会把此 Node 从 Kubernetes 中删除。



#### service controller

负责为type: LoadBalancer的service 创建，删除，更新LB and EIP.



#### route controller

配置node路由.kubernetes 网络的基本原则是每个pod都要有一个独立ip地址,而且假定所有的pod都在直接连通的扁平网络中.
而云上node的基础设施是云服务商提供的,所以 Route Controller 需要调用 Cloud Provider 来配置云上的 Node 的底层路由.



#### pvLabel controller

使用 Cloud Provider 来创建、删除、挂载、卸载 Node 上的卷，这是因为卷也是云厂商额外提供的云存储服务。



### CCM 源码分析

本文的源码分析是以openstack为基础:https://github.com/kubernetes/cloud-provider-openstack:origin/release-1.17
kuberentes 1.17

启动流程

- 1.项目启动后，先执行所有init方法，注册 getCloudProvider方法（map[云服务商名称]创建cloudProvider方法）

/root/go/src/k8s.io/cloud-provider-openstack/pkg/cloudprovider/providers/openstack/openstack.go
    
    line: 251, 完成cloudProvider　获取方法的注册
    func init() {
        RegisterMetrics()
    
        cloudprovider.RegisterCloudProvider(ProviderName, func(config io.Reader) (cloudprovider.Interface, error) {
            cfg, err := ReadConfig(config)
            logcfg(cfg)
            if err != nil {
                return nil, err
            }
            // 这里可以new　一个自己的CloudProvider对象(前提是实现接口cloudprovider.Interface),
            cloud, err := NewOpenStack(cfg)
            if err != nil {
                klog.V(1).Infof("New openstack client created failed with config")
            }
            return cloud, err
        })
    }

/root/go/src/k8s.io/cloud-provider-.../vendor/k8s.io/cloud-provider/plugins.go

    // RegisterCloudProvider registers a cloudprovider.Factory by name.  This
    // is expected to happen during app startup.
    func RegisterCloudProvider(name string, cloud Factory) {
    	providersMutex.Lock()
    	defer providersMutex.Unlock()
    	if _, found := providers[name]; found {
    		klog.Fatalf("Cloud provider %q was registered twice", name)
    	}
    	klog.V(1).Infof("Registered cloud provider %q", name)
    	providers[name] = cloud
    }
    
    // provider是一个map, 
    // key: 云服务商名称
    // value: 工厂方法，即创建CloudProvider的方法
    providers                = make(map[string]Factory)
    
    // Factory is a function that returns a cloudprovider.Interface.
    // The config parameter provides an io.Reader handler to the factory in
    // order to load specific configurations. If no configuration is provided
    // the parameter is nil.
    type Factory func(config io.Reader) (Interface, error)

- 2.main 函数入口启动程序
    - 生成ccm　默认配置文件对象
    - 解析启动命令行参数
        verflag.PrintAndExitIfRequested()
        utilflag
        pflag.CommandLine.SetNormalizeFunc
        pflag.CommandLine.AddGoFlagSet
        logs.InitLogs()
    - 调用 k8s中的cloud-controller-manager.Run()
    - InitCloudProvider, err, nil, and clusterID　校验
    - configz.New　不懂
    - create HealthChecker
    - create (安全和不安全)httpServer
    - 定义controller启动函数
    - 选择参数校验　--leader-elect　
        false:
            按顺序启动controller
            select{}　程序阻塞
        true:
            append(healthCheck,NewLeaderHealthzAdaptor)
            create lock(锁资源类型，namespace, name,corev1Client,coorinationv1Client,rlconfig)
            try become the leader and start cloud controller manager loops
    
```go
package main

import (
	goflag "flag"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/apiserver/pkg/server/healthz"
	"k8s.io/cloud-provider-huawei/huawei"
	"k8s.io/cloud-provider-huawei/pkg/version"
	"k8s.io/component-base/cli/flag"
	"k8s.io/component-base/logs"
	_ "k8s.io/component-base/metrics/prometheus/restclient" // for client metric registration
	_ "k8s.io/component-base/metrics/prometheus/version"    // for version metric registration
	"k8s.io/component-base/version/verflag"
	"k8s.io/klog"
	"k8s.io/kubernetes/cmd/cloud-controller-manager/app"
	"k8s.io/kubernetes/cmd/cloud-controller-manager/app/options"
	_ "k8s.io/kubernetes/pkg/features" // add the kubernetes feature gates
	utilflag "k8s.io/kubernetes/pkg/util/flag"
	"net/http"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
)

func init() {
	mux := http.NewServeMux()
	healthz.InstallHandler(mux)
	version.Version = "1.17"
}

func main() {
	// 获取ccm默认配置文件
	s, err := options.NewCloudControllerManagerOptions()
	if err != nil {
		klog.Fatalf("unable to initialize command options: %v", err)
	}

	//　使用lease会报错, 需要继续探究
	s.Generic.LeaderElection.ResourceLock = "endpoints"

	// CLI命令行的golang库，也是一个生成程序应用和命令行文件的程序
	// 在command.Run中完成config生成和ccm启动
	command := &cobra.Command{
		Use: "huawei cloud controller manager",
		Long: `The Cloud controller manager is a daemon that embeds
the cloud specific control loops shipped with Kubernetes.`,
		Run: func(cmd *cobra.Command, args []string) {

			// 如果有请求参数 --version 则打印kuberents　版本
			verflag.PrintAndExitIfRequested()

			// 打印所有命令flag and value
			utilflag.PrintFlags(cmd.Flags())

			// 验证KnownControllers key 是否包含了GenericControllerManagerConfiguration.Controllers中的所有控制器
			//获取ccm　config object
			c, err := s.Config(app.KnownControllers(), app.ControllersDisabledByDefault.List())
			if err != nil {
				klog.Error(os.Stderr, err)
				os.Exit(1)
			}

			// 启动CCM, 会执行 node, route, service, pvLabel controller
			if err := app.Run(c.Complete(), wait.NeverStop); err != nil {
				klog.Error(os.Stderr, err)
				os.Exit(1)
			}
		},
	}

	//　生成CLI默认启动参数对
	fs := command.Flags()

	//　将ccm config　的参数对　移入　CLI的启动　参数与对中
	namedFlagSets := s.Flags(app.KnownControllers(), app.ControllersDisabledByDefault.List())
	for _, f := range namedFlagSets.FlagSets {
		fs.AddFlagSet(f)
	}

	pflag.CommandLine.SetNormalizeFunc(flag.WordSepNormalizeFunc)
	pflag.CommandLine.AddGoFlagSet(goflag.CommandLine)
	logs.InitLogs()
	defer logs.FlushLogs()

	klog.Infof("huawei cloud provider version: %s", version.Version)

	//　省去从启动命令赋值的步骤
	s.KubeCloudShared.CloudProvider.Name = huawei.ProviderName

	// 执行cli启动命令
	if err := command.Execute(); err != nil {
		klog.Error(os.Stderr, err)
		os.Exit(1)
	}
}
```

- 3.启动所有控制器, 开始监听资源变化
/root/go/pkg/mod/k8s.io/kubernetes@v1.17.4/cmd/cloud-controller-manager/app/core.go

- cloud-node
  - UpdateNodeStatus updates the node status, such as node addresses
- cloud-node-lifecycle
  - when you shutdown nodes, will delete node from cluster
- service
  - update loadbalancer
- route
  - update node cidr
- pvController
  - 已经从core中移除

```go
// Run runs the ExternalCMServer.  This should never exit.
func Run(c *cloudcontrollerconfig.CompletedConfig, stopCh <-chan struct{}) error {

    // 获取cloudProvider对象, 前面我们已经通过cloudprovider.RegisterCloudProvider　把get cloudProvider 的方法已经注册
	cloud, err := cloudprovider.InitCloudProvider(c.ComponentConfig.KubeCloudShared.CloudProvider.Name, c.ComponentConfig.KubeCloudShared.CloudProvider.CloudConfigFile)
    .....

    // 定义启动控制器方法
    // newControllerInitializers()　返回一个map, 里面已经存放了node, route, service, pvLabel　controller
	run := func(ctx context.Context) {
		if err := startControllers(c, ctx.Done(), cloud, newControllerInitializers()); err != nil {
			klog.Fatalf("error running controllers: %v", err)
		}
	}
	
	//　选主
	leaderelection.RunOrDie(context.TODO(), leaderelection.LeaderElectionConfig{
		Lock:          rl,
		LeaseDuration: c.ComponentConfig.Generic.LeaderElection.LeaseDuration.Duration,
		RenewDeadline: c.ComponentConfig.Generic.LeaderElection.RenewDeadline.Duration,
		RetryPeriod:   c.ComponentConfig.Generic.LeaderElection.RetryPeriod.Duration,
		Callbacks: leaderelection.LeaderCallbacks{
			OnStartedLeading: run, //启动控制器
			OnStoppedLeading: func() {
				klog.Fatalf("leaderelection lost")
			},
		},
		WatchDog: electionChecker,
		Name:     "cloud-controller-manager",
	})
	panic("unreachable")
}
```

/root/go/pkg/mod/k8s.io/kubernetes@v1.17.4/cmd/cloud-controller-manager/app/controllermanager.go
ccm 4个控制器
```go
// line 139
// initFunc is used to launch a particular controller.  It may run additional "should I activate checks".
// Any error returned will cause the controller process to `Fatal`
// The bool indicates whether the controller was enabled.
type initFunc func(ctx *cloudcontrollerconfig.CompletedConfig, cloud cloudprovider.Interface, stop <-chan struct{}) (debuggingHandler http.Handler, enabled bool, err error)

// KnownControllers indicate the default controller we are known.
func KnownControllers() []string {
	ret := sets.StringKeySet(newControllerInitializers())
	return ret.List()
}

// ControllersDisabledByDefault is the controller disabled default when starting cloud-controller managers.
var ControllersDisabledByDefault = sets.NewString()

// newControllerInitializers is a private map of named controller groups (you can start more than one in an init func)
// paired to their initFunc.  This allows for structured downstream composition and subdivision.
func newControllerInitializers() map[string]initFunc {
	controllers := map[string]initFunc{}
	controllers["cloud-node"] = startCloudNodeController
	controllers["cloud-node-lifecycle"] = startCloudNodeLifecycleController
	controllers["service"] = startServiceController
	controllers["route"] = startRouteController
	return controllers
}

func startCloudNodeController(ctx *cloudcontrollerconfig.CompletedConfig, cloud cloudprovider.Interface, stopCh <-chan struct{}) (http.Handler, bool, error) {
	// Start the CloudNodeController
	nodeController, err := cloudcontrollers.NewCloudNodeController(
		ctx.SharedInformers.Core().V1().Nodes(),
		// cloud node controller uses existing cluster role from node-controller
		ctx.ClientBuilder.ClientOrDie("node-controller"),
		cloud,
		ctx.ComponentConfig.NodeStatusUpdateFrequency.Duration)
    ...
	go nodeController.Run(stopCh)
	return nil, true, nil
}

func startCloudNodeLifecycleController(ctx *cloudcontrollerconfig.CompletedConfig, cloud cloudprovider.Interface, stopCh <-chan struct{}) (http.Handler, bool, error) {
	// Start the cloudNodeLifecycleController
	cloudNodeLifecycleController, err := cloudcontrollers.NewCloudNodeLifecycleController(
		ctx.SharedInformers.Core().V1().Nodes(),
		// cloud node lifecycle controller uses existing cluster role from node-controller
		ctx.ClientBuilder.ClientOrDie("node-controller"),
		cloud,
		ctx.ComponentConfig.KubeCloudShared.NodeMonitorPeriod.Duration,
	)
	....
	go cloudNodeLifecycleController.Run(stopCh)
	return nil, true, nil
}

func startServiceController(ctx *cloudcontrollerconfig.CompletedConfig, cloud cloudprovider.Interface, stopCh <-chan struct{}) (http.Handler, bool, error) {
	// Start the service controller
	serviceController, err := servicecontroller.New(
		cloud,
		ctx.ClientBuilder.ClientOrDie("service-controller"),
		ctx.SharedInformers.Core().V1().Services(),
		ctx.SharedInformers.Core().V1().Nodes(),
		ctx.ComponentConfig.KubeCloudShared.ClusterName,
	)
    ....
	go serviceController.Run(stopCh, int(ctx.ComponentConfig.ServiceController.ConcurrentServiceSyncs))
	return nil, true, nil
}

func startRouteController(ctx *cloudcontrollerconfig.CompletedConfig, cloud cloudprovider.Interface, stopCh <-chan struct{}) (http.Handler, bool, error) {
	// If CIDRs should be allocated for pods and set on the CloudProvider, then start the route controller
    // 此处的routes就是通过云服务商sdk构建出来的route client
	routes, ok := cloud.Routes()
	if !ok {
		klog.Warning("configure-cloud-routes is set, but cloud provider does not support routes. Will not configure cloud provider routes.")
		return nil, false, nil
	}    

...
	routeController := routecontroller.New(
		routes,
		ctx.ClientBuilder.ClientOrDie("route-controller"),
		ctx.SharedInformers.Core().V1().Nodes(),
		ctx.ComponentConfig.KubeCloudShared.ClusterName,
		clusterCIDRs,
	)
	go routeController.Run(stopCh, ctx.ComponentConfig.KubeCloudShared.RouteReconciliationPeriod.Duration)
	return nil, true, nil
}
```
- 4.service type　变化后调用 cloudProvider LoadBalancer相关接口对LB 执行CRUD

// create or update LB
```go
// EnsureLoadBalancer creates a new load balancer 'name', or updates the existing one.
func (lbaas *LbaasV2) EnsureLoadBalancer(ctx context.Context, clusterName string, apiService *v1.Service, nodes []*v1.Node) (*v1.LoadBalancerStatus, error) {
    ...
    // 获取service port
	ports := apiService.Spec.Ports
	if len(ports) == 0 {
		return nil, fmt.Errorf("no ports provided to openstack load balancer")
	}
    
	affinity := apiService.Spec.SessionAffinity
    
	//若指定了elb_id，则不创建elb
	elbId := getStringFromServiceAnnotation(apiService, ServiceAnnotationLoadBalancerInstanceID, "")
	if elbId != "" {
		// 根据 loadbalancer id 获取 loadbalancer
		isCreateElb = false
		loadbalancer, err = getLoadbalancerByID(lbaas.lb, elbId)
		 ....
		// 根据service uuid 获取 loadbalancer 的标准命名格式
		name := lbaas.GetLoadBalancerName(ctx, clusterName, apiService)
		// 需要更新lb的name，否则无法删除lb
		err = lbaas.updateLoadBalancerName(apiService, name, elbId)
            ...
	} else {
		//创建elb
		lbaas.opts.SubnetID = getStringFromServiceAnnotation(apiService, ServiceAnnotationLoadBalancerSubnetID, lbaas.opts.SubnetID)
		if len(lbaas.opts.SubnetID) == 0 {
			subnetID, err := getSubnetIDForLB(lbaas.compute, *nodes[0])
			lbaas.opts.SubnetID = subnetID
		}
		name := lbaas.GetLoadBalancerName(ctx, clusterName, apiService)
        //　创建lb
		loadbalancer, err = lbaas.createLoadBalancer(apiService, name, internalAnnotation)
	}
    
    // 获取负载均衡算法
	lbMethod := getLBMethod(apiService)
    
    
    //　为lb　创建监听器，有几个端口，就创建几个
	for portIndex, port := range ports {
	
	}
    
    // 创建eip
	if floatIP == nil && floatingPool != "" && !internalAnnotation {
        ....
		}
	status := &v1.LoadBalancerStatus{}

	return status, nil
}
```



### 部署

以下部署方式适用于基于openstack改造后的华为ccm


#### 部署前必须先在kubelet配置文件中加入如下参数

--hostname-override=${INSTANCE_ID}
--provider-id=${INSTANCE_ID}



#### 集群外部署

```bash
export IDENTITY_ENDPOINT=https://iam.cn-east-3.myhuaweicloud.com/v3
export PROJECT_ID=...
export DOMAIN_ID=...
export ACCESS_KEY_ID= ...
export ACCESS_KEY_SECRET= ....
export ROUTER_ID= ...
export REGION= ...
go run ./cmd/cloud-controller-manager.go --kubeconfig=./kube.config -v 4
```



#### 集群内部署

RBAC, 这里为了方便好看直接用了超级权限
```
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloud-controller-manager
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cloud-controller-manager
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: cloud-controller-manager
    namespace: kube-system
```

DaemonSet
```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    k8s-app: cloud-controller-manager
  name: cloud-controller-manager
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: cloud-controller-manager
  template:
    metadata:
      labels:
        k8s-app: cloud-controller-manager
    spec:
      serviceAccountName: cloud-controller-manager
      containers:
        - name: cloud-controller-manager
          image: ...-huawei-ccm
          imagePullPolicy: Always
          command:
            - /cloud-controller-manager
          env:
            - name: IDENTITY_ENDPOINT
              value: "https://iam.cn-east-3.myhuaweicloud.com/v3"
            - name: PROJECT_ID
              value: ...
            - name: DOMAIN_ID
              value: ...
            - name: ACCESS_KEY_ID
              value: ...
            - name: ACCESS_KEY_SECRET
              value: ...
            - name: ROUTER_ID
              value: ...
            - name: REGION
              value: ...
            - name: SUBNET_ID
              value: ...
      tolerations:
        - effect: NoSchedule
          operator: Exists
          key: node-role.kubernetes.io/master
        - effect: NoSchedule
          operator: Exists
          key: node.cloudprovider.kubernetes.io/uninitialized
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
      nodeSelector:
        node-role.kubernetes.io/master: ""
      hostNetwork: true
```



参考文献:

1. https://mp.weixin.qq.com/s/a_540yJ1EGVroJ9TpvYtPw

作者简介:
蔡锡生，　杭州朗澈科技有限公司k8s工程师
