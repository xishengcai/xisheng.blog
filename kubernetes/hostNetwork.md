# kubernetes hostNetwork: true 网络


kubernetes hostNetwork: true 网络
这是一种直接定义Pod网络的方式。
如果在POD中使用hostNetwork:true配置网络，pod中运行的应用程序可以直接看到宿主主机的网络接口，宿主主机所在的局域网上所有网络接口都可以访问到该应用程序。
POD定义样例：
$ cat nginx.yaml 

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx
spec:
  template:
    metadata:
      labels:
        app: nginx
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
```




网络情况：
$ kubectl get po -o wide |grep nginx
nginx-3035625259-vrj13  1/1   Running  0  9m 192.168.0.206 192.168.0.200

$ sudo netstat -anp |grep LISTEN |grep 0.0.0.0:80
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      32107/nginx.conf
可以看到pod IP和节点IP是相同的。

注意：
dnsPolicy: ClusterFirstWithHostNet 设置，该设置是使POD使用的k8s的dns
$ kubectl exec -it nginx-3035625259-vrj13 -- cat /etc/resolv.conf
nameserver 10.254.0.2
search default.svc.cluster.local. svc.cluster.local. cluster.local. mycrop
options ndots:5

如果不加上dnsPolicy: ClusterFirstWithHostNet ，pod默认使用所在宿主主机使用的DNS，这样也会导致容器内不能通过service name 访问k8s集群中其他POD：
$ kubectl exec -it nginx-3035625259-vrj13 -- cat /etc/resolv.conf
nameserver 202.96.134.133

$ kubectl exec -it nginx-3035625259-vrj13 -- nslookup busybox
nslookup: can't resolve '(null)': Name does not resolve
nslookup: can't resolve 'busybox': Name does not resolve

参考：

https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
————————————————
版权声明：本文为CSDN博主「大飞哥2」的原创文章，遵循CC 4.0 BY-SA版权协议，转载请附上原文出处链接及本声明。
原文链接：https://blog.csdn.net/kozazyh/article/details/79468508