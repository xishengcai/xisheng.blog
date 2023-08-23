# k8s client 和schema



## 1.  k8s.io/client-go
client-go 项目有4种类型的客户端

- RestClient      rest.RESTClient
RESTClient是最基础的客户端RESTClient对HTTP Request进行了封装，实现了RESTful风格的API。
ClientSet，DynamicClient，DiscoveryClient客户端都是基于RESTClient实现的。
```go
package main
import (
	"flag"
	"fmt"
	"k8s.io/client-go/pkg/runtime"
	"k8s.io/client-go/pkg/runtime/serializer"
	"k8s.io/client-go/pkg/api"
	v1 "k8s.io/client-go/pkg/api/v1"
	"k8s.io/client-go/pkg/api/unversioned"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)
func main() {
	kubeconfig := flag.String("kubeconfig", "/root/.kube/config", "Path to a kube config. Only required if out-of-cluster.")
	flag.Parse()
	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		fmt.Println("BuildConfigFromFlags error")
	}
	groupversion := &unversioned.GroupVersion{"", "v1"}
	config.GroupVersion = groupversion
	config.APIPath = "/api"
	config.ContentType = runtime.ContentTypeJSON
	config.NegotiatedSerializer = serializer.DirectCodecFactory{CodecFactory: api.Codecs}
	restClient, err := rest.RESTClientFor(config)
	if err != nil {
		fmt.Println("RESTClientFor error")
	}
	pod := v1.Pod{}
	err = restClient.Get().Resource("pods").Namespace("default").Name("nginx-1487191267-b4w5j").Do().Into(&pod)
	if err != nil {
		fmt.Println("error")
	}
	fmt.Println(pod)
}
```

- ClientSet      *kubernetes.Clientset
ClientSet 是在RESTClient基础上封装了对Resource和Version的管理方法。每一个Resource可以理解为一个客户端，而ClientSet则是多个客户端的集合，每一个Resource和Version都以函数的方式暴露给开发者。ClientSet只能够处理Kubernetes内置资源，他是通过Client-go代码生成器生成的。
```go
package main

import (
	"context"
	"fmt"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	ctrl "sigs.k8s.io/controller-runtime"
)

func main() {
	config := ctrl.GetConfigOrDie()
	c, err := kubernetes.NewForConfig(config)
	if err != nil {
		fmt.Println("error")
	}
	deploys, err := c.AppsV1().Deployments("default").List(context.TODO(),v1.ListOptions{})
	if err != nil {
		fmt.Println("error")
	}
	for _, d := range deploys.Items {
		fmt.Println(d.Name)
	}
}

```

- DynamicClient   dynamic.Interface
DynamicClient与ClientSet最大的不同之处是，ClientSet仅能访问Kubernetes自带的资源（即client集合哪的资源）， 而不能直接访问CRD自带的资源。DynamicClient能过处理Kubernetes中的所有资源对象，包括Kubernetes内置资源与 CRD自定义资源。
```go
package main

import (
	"context"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/client-go/dynamic"
	"k8s.io/klog"
	ctrl "sigs.k8s.io/controller-runtime"
)


func main(){

	config := ctrl.GetConfigOrDie()

	// create the dynamic client from kubeconfig
	dynamicClient, err := dynamic.NewForConfig(config)
	if err != nil {
		klog.Fatal(err)
	}

	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: "test-1",
		},
	}
	// convert the runtime.Object to unstructured.Unstructured
	mapData, err := runtime.DefaultUnstructuredConverter.ToUnstructured(ns)
	if err != nil {
		klog.Fatal(err)
	}
	unstructuredObj := unstructured.Unstructured{
		Object: mapData,
	}

	// create the object using the dynamic client
	nameSpaceResource := schema.GroupVersionResource{Version: "v1", Resource: "namespaces"}
	nsList, err := dynamicClient.Resource(nameSpaceResource).List(context.Background(),metav1.ListOptions{})
	if err != nil {
		klog.Fatal(err)
	}
	klog.Infof("list :%d", len(nsList.Items))

	respData, err := dynamicClient.Resource(nameSpaceResource).Create(context.Background(),&unstructuredObj,metav1.CreateOptions{})
	if err != nil {
		klog.Fatal(err)
	}

	respNs := &corev1.Namespace{}
	// convert unstructured.Unstructured to a Node
	if err = runtime.DefaultUnstructuredConverter.FromUnstructured(respData.UnstructuredContent(), respNs); err != nil {
		klog.Fatal(err)
	}

	klog.Infof("namespace: %+v", respNs)
}
```

- DiscoveryClient *discovery.DiscoveryClient
发现客户端，用于发现kube-apiserver所支持的资源组、资源版本、资源信息（即Group, Versions,Resources)

## 2. sigs.k8s.io/controller-runtime 
该客户端是可以直接从kubernetes server 中读写的，它能够处理普通类型，自定义类型，内建类型以及未知类型。 使用该client的时候，它会使用scheme去寻找Group， version 和类型。



### 2.1 scheme 资源注册表

 kubernetes中有很多资源，只有被注册到scheme资源注册表中，比如oam中的crd资源，我们是无法通过直接创建的。

```
var scheme = runtime.NewScheme()

func init() {
	_ = clientgoscheme.AddToScheme(scheme)
	_ = oamcore.AddToScheme(scheme)
}
```



###  2.2 example about apply  oam component

在实际使用场景中， 我们可能非常需要类似kubectl apply的功能，即没有对象的时候新建，如果有就更新。
使用改client的patch方法即可实现。

```
package main

import (
	"context"
	"fmt"
	"k8s-demo/common"
	"k8s-demo/k8s_client/deployment"
	appsv1 "k8s.io/api/apps/v1"
	"k8s.io/klog"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"time"
)

/*
patch deployment
if not found, new one;
else, update.
*/

var (
	workloadName = "apply-test"
	namespace    = "default"
	imageName    = "nginx"
)

func main() {
	ctx := context.Background()
	config := ctrl.GetConfigOrDie()
	begin := time.Now()
	c, err := client.New(config, client.Options{})
	if err != nil {
		klog.Fatal(err)
	}
	klog.Info("build client cost time: ", time.Since(begin))
	dep := deployment.GenerateDeployment(workloadName, namespace, imageName)

	// 1.delete deployment
	if err := c.Delete(ctx, &dep, &client.DeleteOptions{}); err != nil {
		klog.Fatal(err)
	}

	// patch 选项
	applyOpts := []client.PatchOption{
		client.ForceOwnership,
		client.FieldOwner(dep.GetUID()),
		&client.PatchOptions{FieldManager: "apply"},
	}

	for i:=0;i<3; i++ {
		// 2. 原始数据重复apply
		time.Sleep(1 *time.Second)
		dep.SetAnnotations(map[string]string{fmt.Sprintf("time-%d",i): time.Now().String()})
		dep.ObjectMeta.ManagedFields = nil
		dep.ObjectMeta.ResourceVersion = ""
		err = c.Patch(ctx, &dep, client.Apply, applyOpts...)
		if err != nil {
			klog.Fatal(err)
		}
	}

	// 3.打印当前deployment
	depGet := appsv1.Deployment{}
	key := client.ObjectKey{Namespace: namespace, Name: workloadName}
	if err := c.Get(ctx, key, &depGet); err != nil {
		klog.Fatal(err)
	}
	common.PrintData(depGet, nil)

}

```

