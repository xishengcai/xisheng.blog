---
title: "Extend Kubernetes via a Shared Informer"
date: 2019-12-11T22:50:21+08:00
draft: true
---

[origin article](Extend Kubernetes via a Shared Informer)

Kubernetes runs a set of controllers to keep matching the current state of a resource with its desired state. It can be a Pod, Service or whatever is possible to control via Kubernetes. 
K8S has as core value extendibility to empower operators and applications to expand its set of capabilities. An event-based architecture where everything that matters get converted to
 an event that can be trigger custom code.

When I think about a problem I have that requires to take action when 
Kubernetes does something my first target is one of the events that it 
triggers, example:
- New Pod Created
- New Node Joined
- Service Removed and many, many more.

To stay informed about when these events get triggered you can use a primitive exposed by Kubernetes and the client-go called SharedInformer, inside the cache package. Let’s see how it works in practice.

First of all as every application that interacts with Kubernetes you need to build a client:

```go
// import "os"
// import  corev1 "k8s.io/api/core/v1"
// import  "k8s.io/client-go/kubernetes"
// import  "k8s.io/client-go/tools/clientcmd"


// Set the kubernetes config file path as environment variable
kubeconfig := os.Getenv("KUBECONFIG")

// Create the client configuration
config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
if err != nil {
    logger.Panic(err.Error())
    os.Exit(1)
}

// Create the client
clientset, err := kubernetes.NewForConfig(config)
if err != nil {
    logger.Panic(err.Error())
    os.Exit(1)
}
```

As you can see I am commenting the code almost line by line to give you a good understanding about what is going. Now that you have the client we can create the SharedInformerFactory. A shared informer listens to a specific resource; the factory helps you to create the one you need. For this example it lookup the Pod SharedInformer:

```go
// import v1 "k8s.io/api/core/v1"
 // import "k8s.io/client-go/informers"
// import  "k8s.io/client-go/tools/cache"
// import "k8s.io/apimachinery/pkg/util/runtime"

// Create the shared informer factory and use the client to connect to
// Kubernetes
factory := informers.NewSharedInformerFactory(clientset, 0)

// Get the informer for the right resource, in this case a Pod
informer := factory.Core().V1().Pods().Informer()

// Create a channel to stops the shared informer gracefully
stopper := make(chan struct{})
defer close(stopper)

// Kubernetes serves an utility to handle API crashes
defer runtime.HandleCrash()

// This is the part where your custom code gets triggered based on the
// event that the shared informer catches
informer.AddEventHandler(cache.ResourceEventHandlerFuncs{
    // When a new pod gets created
    AddFunc:    func(obj interface{}) { panic("not implemented") },
    // When a pod gets updated
    UpdateFunc: func(interface{}, interface{}) { panic("not implemented") },
    // When a pod gets deleted
    DeleteFunc: func(interface{}) { panic("not implemented") },
})

// You need to start the informer, in my case, it runs in the background
go informer.Run(stopper)
```

Knowing about Shared Informers gives you the ability to extend Kubernetes quickly. As you can see it is not a significant amount of code, the interfaces are pretty clear.

Use cases
I used them a lot to write dirty hack but also to complete automation gab a system for example:

We used to have a very annoying error during the creation of a Pod with a persistent volume. It was not a high rate error a restart makes everything to work as expected. A dirty hack is pretty clear; I automated the manual process of restarting the pod with that error using a Shared Informer just like to one I showed you
I am using AWS, and I would like to push some EC2 tags down as kubelet labels. I use a shared informer but this time to watch when a new node joins the cluster. From the new node I can get its AWS instanceID (it is a label itself), and with the AWS API. I can retrieve its tags to identify how to edit the node itself via Kubernetes API. Everything is part of the AddFunc in the shared informer itself.

Complete Example
This example is a function go program that logs when a new node that contains a particular tag joins the cluster:
```go
package main

import (
    "fmt"
    "log"
    "os"

    corev1 "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/util/runtime"

    "k8s.io/client-go/informers"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/cache"
    "k8s.io/client-go/tools/clientcmd"
)

const (
    // K8S_LABEL_AWS_REGION is the key name to retrieve the region from a
    // Node that runs on AWS.
    K8S_LABEL_AWS_REGION = "failure-domain.beta.kubernetes.io/region"
)

func main() {
    log.Print("Shared Informer app started")
    kubeconfig := os.Getenv("KUBECONFIG")
    config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
    if err != nil {
        log.Panic(err.Error())
    }
    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        log.Panic(err.Error())
    }

    factory := informers.NewSharedInformerFactory(clientset, 0)
    informer := factory.Core().V1().Nodes().Informer()
    stopper := make(chan struct{})
    defer close(stopper)
    defer runtime.HandleCrash()
    informer.AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc: onAdd,
    })
    go informer.Run(stopper)
    if !cache.WaitForCacheSync(stopper, informer.HasSynced) {
        runtime.HandleError(fmt.Errorf("Timed out waiting for caches to sync"))
        return
    }
    <-stopper
}

// onAdd is the function executed when the kubernetes informer notified the
// presence of a new kubernetes node in the cluster
func onAdd(obj interface{}) {
    // Cast the obj as node
    node := obj.(*corev1.Node)
    _, ok := node.GetLabels()[K8S_LABEL_AWS_REGION]
    if ok {
        fmt.Printf("It has the label!")
    }
}
```