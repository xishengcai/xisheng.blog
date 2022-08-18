# K8s: command tips

K8s 常用命令汇总



## query



获取所有pod

```
kubectl get pods -A
```



从最近的一条日志查询

```
kubectl logs -f {pod_name} --tail=1
```



获取svc 的终端

```
kubectl get ep
```



扩容

```

```



### --field-selector

```
"metadata.name",
"metadata.namespace",
"spec.nodeName",
"spec.restartPolicy",
"spec.schedulerName",
"spec.serviceAccountName",
"status.phase",
"status.podIP",
"status.podIPs",
"status.nominatedNodeName"
```

```bash
kubectl get nodes -o json | jq -r '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True")) | .metadata.name '
```





![image-20210908114425182](/Users/xishengcai/Library/Application Support/typora-user-images/image-20210908114425182.png)
