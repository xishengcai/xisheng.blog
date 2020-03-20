---
title: "pull image from private registries"
date: 2020-2-20T16:08:36+08:00
draft: false
---

[source doc](https://kubernetes.io/docs/concepts/containers/images/)

Here are the recommended steps to configuring your nodes to use a private registry. 

In this example, run these on your desktop/laptop:

Run docker login [server] for each set of credentials you want to use.

This updates $HOME/.docker/config.json.
```shell
docker login {your private registry}
```
 
View $HOME/.docker/config.json in an editor to ensure it contains just the credentials you want to use.

Get a list of your nodes, for example:

if you want the names: 
```shell
nodes=$(kubectl get nodes -o jsonpath='{range.items[*].metadata}{.name} {end}')
```


if you want to get the IPs:
```shell
nodes=$(kubectl get nodes -o jsonpath='{range .items[*].status.addresses[?(@.type=="ExternalIP")]}{.address} {end}')
```

Copy your local .docker/config.json to one of the search paths list above.

for example: 
```shell
for n in $nodes; do scp ~/.docker/config.json root@$n:/var/lib/kubelet/config.json; done
```
