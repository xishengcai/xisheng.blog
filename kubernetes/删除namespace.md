namespace Terminating

一般性的删除

```
kubectl delete  <resource>  <resourename> --grace-period=0 --force --wait=false
```

强制删除

```
kubectl patch <resource>  <resourename> -p '{"metadata":{"finalizers":null}}'
```



在k8s集群中进行测试删除namespace是经常的事件，而为了方便操作，一般都是直接对整个名称空间进行删除操作。
相信道友们在进行此步操作的时候，会遇到要删除的namespace一直处于Terminating。下面我将给出一个完美的解决方案，



## 测试demo

```
创建demo namespace
# kubectl create ns test
namespace/test created

删除demo namespace
# kubectl delete ns test
namespace "test" deleted

一直处于deleted不见exit
查看状态 可见test namespace 处于Terminating  
# kubectl get ns -w
NAME                STATUS        AGE
test                Terminating   18s
```



### 下面给出一种完美的解决方案：调用接口删除

1. 开启一个代理终端

```
kubectl proxy
```



2. 将test namespace的配置文件输出保存,

```
kubectl get ns test -o json > test.json
```

**删除spec及status部分的内容还有metadata字段后的","号，切记**



3.调接口删除

```
  curl -k -H "Content-Type: application/json" -X PUT --data-binary @test.json \
http://127.0.0.1:8001/api/v1/namespaces/test/finalize
```



### 查看结果

```
1、delete 状态终止
kubectl delete ns test
namespace "test" deleted

2、Terminating状态终止
kubectl get ns -w
test                Terminating   18s
test                Terminating   17m
```

名称空间被删除掉