### 使用telepresence在k8s中调试

 作者： 吴江法

 公司：杭州朗澈科技

## 前言

关于golang程序在k8s中的远程调试，可以参考使用[dlv](https://app.yinxiang.com/fx/6f0c2a27-35d1-4dad-8115-1d3d863776ad)进行，但是这种方式缺陷也很明显，已部署的工作负载，需要重新制作镜像，重新部署，对业务也有一定侵入性，也不够灵活。
本文介绍一种更契合远程调试部署在k8s中的业务的方式，这种方式也是k8s在官方文档中推荐使用的：[telepresence](https://github.com/telepresenceio/telepresence)

------

### 1.准备

- [telepresence下载](https://www.telepresence.io/docs/latest/install/)
- [kubectl下载](https://kubernetes.io/docs/tasks/tools/)

------

### 2.版本检测

下载完毕后，执行以下命令查看telepresence版本

```
$telepresence version
Client: v2.5.3 (api v3)
Root Daemon: not running
User Daemon: not running
```

注意：如果版本小于v2.0.3,则需要[升级telepresence](https://www.telepresence.io/docs/latest/install/upgrade)

### 3.连接k8s集群

执行以下命令连接k8s集群：

```
$telepresence connect
Launching Telepresence Root Daemon
Need root privileges to run: /usr/local/bin/telepresence daemon-foreground /Users/xxx/Library/Logs/telepresence '/Users/xxx/Library/Application Support/telepresence'
Password:
Launching Telepresence User Daemon
Connected to context kubernetes-admin@kubernetes (https://8.16.0.211:6443)
```

注意：连接的集群为kubeconfig中指定的集群，需要能真实可访问。
同时，telepresence会自动打开浏览器，要求登录：
![img](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/8c66ec0e1620f485805dea7ef7416023-356289.png)
该步骤不能省略，否则后续的步骤执行时，都会要求先登录才能继续执行。
完成上述步骤后，查看k8s集群，能发现在该集群中会创建了名为traffic-manager的控制器：

```
$kubectl get po -n ambassador
NAME                               READY   STATUS    RESTARTS   AGE
traffic-manager-5bcfc9766f-lbrsz   1/1     Running   0          15m
```

------

### 4.拦截器

![img](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/e142783601322eda22426ed54a899a5c-160383.png)
如上图所示，在k8s中部署了两个service，分别是Users和Orders。
这里以service Orders为例，正常情况下，一个访问Orders的请求，会被正常的收发。而telepresence的功能，就是拦截发送到Orders的请求，并将其转发到用户指定的地址（一般为本地)。
因此在开始配置前，需要了解telepresence中拦截器的概念：

- 全局拦截（Global intercept）：将访问k8s中某个service的流量全部拦截，并转发到本地。
  ![img](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/72d1bdc332b7ebd97f0320b4a79cbca3-208865.png)
  如图所示，使用全局拦截，能将访问Orders服务的全部流量拦截，全部转发到本地。当然，我们需要将本地代码运行起来，用于接收转发过来的请求，同时，可以使用任意的debug的工具在本地进行调试。
- 个人拦截（Personal intercept）：有选择性地仅拦截某个service的部分流量，而不会干扰其余流量。
  可以通过以下参数设置是否拦截请求的标识：

```
--http-match=key=value 基于请求头识别请求是否需要拦截转发
--http-path-equal <path> 基于请求路径
--http-path-prefix <prefix>	基于请求路径前缀
--http-path-regex <regex> 基于请求路径是否匹配给定的正则表达式
```

------

### 5.实践

在开始前，需要把用来远程调试的服务部署到k8s集群：

```
$kubectl get po,svc  -lk8s-app=lsh-mcp-idp-cd-test
NAME                                  READY   STATUS    RESTARTS   AGE
pod/lsh-mcp-idp-cd-6c68876d48-v6c88   1/1     Running   0          30s

NAME                     TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                         AGE
service/lsh-mcp-idp-cd   NodePort   20.102.1.158   <none>        9090:30323/TCP,2345:30886/TCP   30s
```

并在本地debug运行lsh-mcp-idp-cd代码:
![img](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/b0fcd08f413cd8c0b75a0d90c5d1119e-166363.png)
接着使用以下命令找到要拦截转发的service，即lsh-mcp-idp-cd：

```
$telepresence list 
lsh-mcp-idp-cd: ready to intercept (traffic-agent not yet installed)
```

注意，要指定命名空间时，可以添加--namespace参数，如下所示：

```
$telepresence list --namespace=kube-system
```

添加全局拦截器：

```
telepresence intercept <service-name> --port <local-port>[:<remote-port>] --http-match=all --env-file <path-to-env-file> [--namespace 可选]
```

对应到实践场景：

```
$telepresence intercept lsh-mcp-idp-cd --port 9090:9090 --http-match=all --env-file ~/lsh-mcp-idp-cd-intercept.env  

Flag --http-match has been deprecated, use --http-header
Using Deployment lsh-mcp-idp-cd
intercepted
    Intercept name         : lsh-mcp-idp-cd
    State                  : ACTIVE
    Workload kind          : Deployment
    Destination            : 127.0.0.1:9090
    Service Port Identifier: 9090
    Volume Mount Error     : sshfs is not installed on your local machine
    Intercepting           : matching all HTTP requests
    Preview URL            : https://sad-thompson-7927.preview.edgestack.me
    Layer 5 Hostname       : lsh-mcp-idp-cd.default.svc.cluster.local
```

执行完成后，会发现工作负载被注入了一个sidecar:

```
$kubectl get po -lk8s-app=lsh-mcp-idp-cd-test -oyaml | grep -A 5  containerID
    - containerID: docker://6aea792f32af00b2e71f643ea41630de9bb6b0ebbe91251877fd79f67630efa1
      image: registry.cn-beijing.aliyuncs.com/launcher-agent-only-dev/idp:v1
      imageID: docker-pullable://registry.cn-beijing.aliyuncs.com/launcher-agent-only-dev/idp@sha256:c3be2545c30eb75fb652d383e9ec5545df9142e40d3b6f7f78633316b0db8103
      lastState: {}
      name: idp-cd
      ready: true
--
    - containerID: docker://5acc04048950fdd38be3a8012c4cc0edbfd83079883717e34992f6f31036176f
      image: datawire/ambassador-telepresence-agent:1.11.10
      imageID: docker-pullable://datawire/ambassador-telepresence-agent@sha256:9008fc1a6a91dd27baf3da9ebd0aee024f0d6d6a3f9c24611476474f6583e7f8
      lastState: {}
      name: traffic-agent
      ready: true
```

增加了一个名为traffic-agent的容器，正是该容器，负责拦截发送到该pod的流量，并负责转发。
在k8s集群内执行以下命令,请求lsh-mcp-idp-cd服务：

```
$curl 20.102.1.158:9090/version
```

再看本地代码，发现已经收到了请求:
![img](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/e078c8e231efcacaf77369476830b8bf-477834.png)
以上就是全局拦截的实践部分，个人拦截gan兴趣的同学自己实践吧，另外关于个人拦截，似乎每个账号存在使用次数限制，超过次数后创建个人拦截器时会报错：

```
telepresence: error: Failed to establish intercept: intercept in error state AGENT_ERROR: You’ve reached your limit of personal intercepts available for your subscription. See usage and available plans at https://app.getambassador.io/cloud/subscriptions

See logs for details (1 error found): "/Users/xxx/Library/Logs/telepresence/daemon.log"

See logs for details (13609 errors found): "/Users/xxx/Library/Logs/telepresence/connector.log"
If you think you have encountered a bug, please run `telepresence gather-logs` and attach the telepresence_logs.zip to your github issue or create a new one: https://github.com/telepresenceio/telepresence/issues/new?template=Bug_report.md .
```

------

### 6.卸载

删除拦截器：执行后，会删除注入工作负载的sidecar

```
$telepresence leave lsh-mcp-idp-cd
```

删除telepresence agents and manager，执行后清除所有sidecar，以及traffic-manager控制器，并关闭本地telepresence的后台进程

```gra
$telepresence uninstall --everything
Telepresence Network quitting...done
Telepresence Traffic Manager quitting...done
```