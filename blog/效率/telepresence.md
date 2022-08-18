# telepresence



# Debug a Kubernetes service locally

<details style="box-sizing: border-box; margin: 0px; padding: 0px; border: 0px; font-size: 16px; font-family: Inter, arial, helvetica, sans-serif; vertical-align: baseline; display: block; color: rgb(34, 34, 34); font-style: normal; font-variant-ligatures: normal; font-variant-caps: normal; font-weight: 400; letter-spacing: normal; orphans: 2; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: 2; word-spacing: 0px; -webkit-text-stroke-width: 0px; text-decoration-thickness: initial; text-decoration-style: initial; text-decoration-color: initial;"><summary style="box-sizing: border-box; margin: 0px; padding: 0px; border: 0px; font-size: 16px; font-family: inherit; vertical-align: baseline;">Install Telepresence with Homebrew/apt/dnf</summary></details>

### Debugging a service locally with Telepresence

Imagine you have a service running in a staging cluster, and someone reports a bug against it. In order to figure out the problem you want to run the service locally... but the service depends on other services in the cluster, and perhaps on cloud resources like a database.

In this tutorial you'll see how Telepresence allows you to debug your service locally. We'll use the `telepresence` command line tool to swap out the version running in the staging cluster for a debug version under your control running on your local machine. Telepresence will then forward traffic from Kubernetes to the local process.

You should start a `Deployment` and publicly exposed `Service` like this:

Terminal

```bash
kubectl create deployment hello-world --image=datawire/hello-world
kubectl expose deployment hello-world --type=LoadBalancer --port=8000
```

> **If your cluster is in the cloud** you can find the address of the resulting `Service` like this:

 ```bash
 $ kubectl get service hello-world
 
 NAME          CLUSTER-IP     EXTERNAL-IP       PORT(S)          AGE
 
 hello-world   10.3.242.226   104.197.103.123   8000:30022/TCP   5d
 ```

> If you see `<pending>` under EXTERNAL-IP wait a few seconds and try again. In this case the `Service` is exposed at `http://104.197.103.123:8000/`.

 **On `minikube` you should instead** do this to find the URL:

 ```bash
 $ minikube service --url hello-world
 
 http://192.168.99.100:12345/
 ```

Once you know the address you can store its value (don't forget to replace this with the real address!):

Terminal

```bash
$ export HELLOWORLD=http://104.197.103.13:8000
```

And you send it a query and it will be served by the code running in your cluster:

Terminal

```bash
$ curl $HELLOWORLD/

Hello, world!
```

#### Swapping your deployment with Telepresence

**Important:** Starting `telepresence` the first time may take a little while, since Kubernetes needs to download the server-side image.

At this point you want to switch to developing the service locally, replace the version running on your cluster with a custom version running on your laptop. To simplify the example we'll just use a simple HTTP server that will run locally on your laptop:

Terminal

```bash
$ mkdir /tmp/telepresence-test
$ cd /tmp/telepresence-test
$ echo "hello from your laptop" > file.txt
```
```bash
$ python3 -m http.server 8001 &
[1] 2324

$ curl http://localhost:8001/file.txt
hello from your laptop

$ kill %1
```

We want to expose this local process so that it gets traffic from Kubernetes, replacing the existing `hello-world` deployment.

**Important:** you're about to expose a web server on your laptop to the Internet. This is pretty cool, but also pretty dangerous! Make sure there are no files in the current directory that you don't want shared with the whole world.

Here's how you should run `telepresence` (you should make sure you're still in the `/tmp/telepresence-test` directory you created above):

Terminal

```bash
$ cd /tmp/telepresence-test
$ telepresence --swap-deployment hello-world --expose 8000 --run python3 -m http.server 8000 &
```

This does three things:

- Starts a VPN-like process that sends queries to the appropriate DNS and IP ranges to the cluster.
- `--swap-deployment` tells Telepresence to replace the existing `hello-world` pod with one running the Telepresence proxy. On exit, the old pod will be restored.
- `--run` tells Telepresence to run the local web server and hook it up to the networking proxy.

As long as you leave the HTTP server running inside `telepresence` it will be accessible from inside the Kubernetes cluster. You've gone from this...

graph RL subgraph Kubernetes in Cloud server["datawire/hello-world server on port 8000"] end

...to this:

graph RL subgraph Laptop code["python HTTP server on port 8000"]---client[Telepresence client] end subgraph Kubernetes in Cloud client-.-proxy["Telepresence proxy, listening on port 8000"] end

We can now send queries via the public address of the `Service` we created, and they'll hit the web server running on your laptop instead of the original code that was running there before. Wait a few seconds for the Telepresence proxy to startup; you can check its status by doing:

Terminal

```bash
$ kubectl get pod | grep hello-world

hello-world-2169952455-874dd   1/1       Running       0          1m

hello-world-3842688117-0bzzv   1/1       Terminating   0          4m
```

Once you see that the new pod is in `Running` state you can use the new proxy to connect to the web server on your laptop:

Terminal

```bash
$ curl $HELLOWORLD/file.txt

hello from your laptop
```

Finally, let's kill Telepresence locally so you don't have to worry about other people accessing your local web server by bringing it to the foreground and hitting Ctrl-C:

Terminal

```bash
$ fg

telepresence --swap-deployment hello-world --expose 8000 --run python3 -m http.server 8000

Keyboard interrupt received, exiting.
```

Now if we wait a few seconds the old code will be swapped back in. Again, you can check status of swap back by running:

Terminal

```bash
$ kubectl get pod | grep hello-world
```

When the new pod is back to `Running` state you can see that everything is back to normal:

Terminal

```bash
$ curl $HELLOWORLD/file.txt

Hello, world!
```

------

> **What you've learned:** Telepresence lets you replace an existing deployment with a proxy that reroutes traffic to a local process on your machine. This allows you to easily debug issues by running your code locally, while still giving your local process full access to your staging or testing cluster.

------

Now it's time to clean up the service:

Terminal

```bash
$ kubectl delete deployment,service hello-world
```

Telepresence can do much more than this: see the reference section of the documentation, on the top-left, for details.

<details style="box-sizing: border-box; margin: 0px; padding: 0px; border: 0px; font-size: 16px; font-family: Inter, arial, helvetica, sans-serif; vertical-align: baseline; display: block; color: rgb(34, 34, 34); font-style: normal; font-variant-ligatures: normal; font-variant-caps: normal; font-weight: 400; letter-spacing: normal; orphans: 2; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: 2; word-spacing: 0px; -webkit-text-stroke-width: 0px; text-decoration-thickness: initial; text-decoration-style: initial; text-decoration-color: initial;"><summary style="box-sizing: border-box; margin: 0px; padding: 0px; border: 0px; font-size: 16px; font-family: inherit; vertical-align: baseline;">Install Telepresence with Homebrew/apt/dnf</summary></details>

**Still have questions? Ask in our [Slack chatroom](https://a8r.io/slack) or [file an issue on GitHub](https://github.com/telepresenceio/telepresence/issues/new).**



### 调试服务 B - 集群内服务与本地联调

服务 B 与刚才的不同之处在于，它是被别人访问的，要调试它，首先得要有真实的访问流量。我们如何才能做到将别人对它的访问路由到本地来，从而实现在本地捕捉到集群中的流量呢？

Telepresence 提供这样一个参数，`--swap-deployment <DEPLOYMENT_NAME[:CONTAINER]>`，用来将集群中的一个`Deployment`替换为本地的服务。对于上面的`service-b`，我们可以这样替换：

```bash
XishengdeMacBook-Pro:telepresence-test xishengcai$ telepresence --swap-deployment hello-world --expose 8000 --run python3 -m http.server 8000 
Legacy Telepresence command used
Command roughly translates to the following in Telepresence:
telepresence intercept hello-world --port 8000 -- python3 -m http.server 8000
running...
Launching Telepresence Daemon v2.3.1 (api v3)
Need root privileges to run "/usr/local/bin/telepresence daemon-foreground /Users/xishengcai/Library/Logs/telepresence '/Users/xishengcai/Library/Application Support/telepresence' ''"
Password:
Connecting to traffic manager...
Connected to context kubernetes-admin@kubernetes (https://115.238.145.60:6443)
Using Deployment hello-world
intercepted
    Intercept name    : hello-world
    State             : ACTIVE
    Workload kind     : Deployment
    Destination       : 127.0.0.1:8000
    Volume Mount Point: /var/folders/h7/dnzyb1d520v05x5m647khhnr0000gn/T/telfs-436589704
    Intercepting      : all TCP connections
Serving HTTP on :: port 8000 (http://[::]:8000/) ...
::ffff:127.0.0.1 - - [17/Jun/2021 20:26:28] "GET / HTTP/1.1" 200 -
::ffff:127.0.0.1 - - [17/Jun/2021 20:26:34] "GET /file.txt HTTP/1.1" 200 -
::ffff:127.0.0.1 - - [17/Jun/2021 20:26:36] "GET /file.txt HTTP/1.1" 200 -
```





```yaml
# XishengdeMacBook-Pro:~ xishengcai$ kubectl describe pods hello-world-6b8bbfd9c5-8kflp 
Name:         hello-world-6b8bbfd9c5-8kflp
Namespace:    default
Priority:     0
Node:         ningbo/115.238.145.60
Start Time:   Thu, 17 Jun 2021 20:25:29 +0800
Labels:       app=hello-world
              pod-template-hash=6b8bbfd9c5
Annotations:  cni.projectcalico.org/podIP: 10.244.210.19/32
Status:       Running
IP:           10.244.210.19
IPs:
  IP:           10.244.210.19
Controlled By:  ReplicaSet/hello-world-6b8bbfd9c5
Containers:
  hello-world:
    Container ID:   docker://acfe4a72ce5f98c50b59e5d886bd2dc4c9d13849b22c76a9107d3cc76701447d
    Image:          datawire/hello-world
    Image ID:       docker-pullable://datawire/hello-world@sha256:bf1110a41ec2e672d3beb56b382802255f1958bb28b97bdb9d62066e37bda83b
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Thu, 17 Jun 2021 20:26:19 +0800
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-cfh72 (ro)
  traffic-agent:
    Container ID:  docker://22c0cdeb9be8d9d674788911e288e5d76bebfa0cba11d369649aa87e773af42c
    Image:         docker.io/datawire/tel2:2.3.1
    Image ID:      docker-pullable://datawire/tel2@sha256:342f3ffb0c49b45e7f398a9eafa3558c1761504b7a9fbccdd04085ad85b2bba3
    Port:          9900/TCP
    Host Port:     0/TCP
    Args:
      agent
    State:          Running
      Started:      Thu, 17 Jun 2021 20:25:32 +0800
    Ready:          True
    Restart Count:  0
    Readiness:      exec [/bin/stat /tmp/agent/ready] delay=0s timeout=1s period=10s #success=1 #failure=3
    Environment:
      TELEPRESENCE_CONTAINER:  hello-world
      LOG_LEVEL:               debug
      AGENT_NAME:              hello-world
      AGENT_NAMESPACE:         default (v1:metadata.namespace)
      AGENT_POD_IP:             (v1:status.podIP)
      APP_PORT:                8000
      MANAGER_HOST:            traffic-manager.ambassador
    Mounts:
      /tel_pod_info from traffic-annotations (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-cfh72 (ro)
```











## link

- https://kubernetes.io/zh/docs/tasks/debug-application-cluster/local-debugging/
- https://www.telepresence.io/docs/v1/tutorials/kubernetes/
- https://cloud.tencent.com/developer/article/1548539