
# kubernetes config
当kubectl必须向Kubernetes API发出请求时，它会读取系统上所谓的kubeconfig文件，以获取它需要访问的所有连接参数并向API服务器发出请求。

config
    clusters
    users
    contexts
    current-context

# 查看上下文
```
kubectl config get-contexts：列出所有上下文
kubectl config current-context：获取当前上下文
kubectl config use-context：更改当前上下文
kubectl config set-context：更改上下文的元素
```

# meger

# persistent
# ~/.bashrc
export KUBECONFIG=${HOME}/.kube/config:/tmp/admin.conf


[tonybai-link](https://tonybai.com/2019/08/31/kubectl-productivity-part3/)