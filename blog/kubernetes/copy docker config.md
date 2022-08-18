# K8s：all nodes scp docker config



[source doc](https://kubernetes.io/docs/concepts/containers/images/)

Here are the recommended steps to configuring your nodes to use a private registry. 

In this example, run these on your desktop/laptop:

Run docker login [server] for each set of credentials you want to use.

This updates $HOME/.docker/config.json.
```bash
docker login {your private registry}
```

View $HOME/.docker/config.json in an editor to ensure it contains just the credentials you want to use.

Get a list of your nodes, for example:

if you want the names: 
```bash
nodes=$(kubectl get nodes -o jsonpath='{range.items[*].metadata}{.name} {end}')
```


if you want to get the IPs:
```bash
nodes=$(kubectl get nodes -o jsonpath='{range .items[*].status.addresses[?(@.type=="ExternalIP")]}{.address} {end}')
```

Copy your local .docker/config.json to one of the search paths list above.

for example: 
```bash
for n in $nodes; do scp ~/.docker/config.json root@$n:/var/lib/kubelet/config.json; done
```
