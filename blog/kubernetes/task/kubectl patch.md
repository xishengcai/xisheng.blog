# Update API Objects in Place Using kubectl patch

This task shows how to use `kubectl patch` to update an API object in place. The exercises in this task demonstrate a strategic merge patch and a JSON merge patch.



## Before you begin



You need to have a Kubernetes cluster, and the kubectl command-line tool must be configured to communicate with your cluster. If you do not already have a cluster, you can create one by using [minikube](https://kubernetes.io/docs/tasks/tools/#minikube) or you can use one of these Kubernetes playgrounds:

- [Katacoda](https://www.katacoda.com/courses/kubernetes/playground)
- [Play with Kubernetes](http://labs.play-with-k8s.com/)

To check the version, enter `kubectl version`.



## kubectl Patch usage

**Command**

```bash
 kubectl patch (-f FILENAME | TYPE NAME) -p PATCH [options]
```



**Examples:**

下面是三种类型的Patch 例子

1.  Partially update a node using a **strategic merge patch**. Specify the patch as JSON.

```bash
 kubectl patch node k8s-node-1 -p '{"spec":{"unschedulable":true}}'
```



2. Update a container's image using a **json patch** with positional arrays.

```bash
kubectl patch pod valid-pod --type='json' -p='[{"op": "replace", "path": "/spec/containers/0/image", "value":"newimage"}]'
```

  

3. Update a container's image using a **merge patch** with positional arrays.

```bash
kubectl patch deployment patch-demo --patch '{"spec": {"template": {"spec": {"containers": [{"name": "patch-demo-ctr-4","image": "redis"}]}}}}' --type merge
```



**Options:**

```bash
   --allow-missing-template-keys=true: If true, ignore any errors in templates when a field or map key is missing in

the template. Only applies to golang and jsonpath output formats.

   --dry-run=false: If true, only print the object that would be sent, without sending it.

 -f, --filename=[]: Filename, directory, or URL to files identifying the resource to update

 -k, --kustomize='': Process the kustomization directory. This flag can't be used together with -f or -R.

   --local=false: If true, patch will operate on the content of the file, not the server-side resource.

 -o, --output='': Output format. One of:

json|yaml|name|go-template|go-template-file|template|templatefile|jsonpath|jsonpath-file.

 -p, --patch='': The patch to be applied to the resource JSON file.

   --record=false: Record current kubectl command in the resource annotation. If set to false, do not record the

command. If set to true, record the command. If not set, default to updating the existing annotation value only if one

already exists.

 -R, --recursive=false: Process the directory used in -f, --filename recursively. Useful when you want to manage

related manifests organized within the same directory.

   --template='': Template string or path to template file to use when -o=go-template, -o=go-template-file. The

template format is golang templates [http://golang.org/pkg/text/template/#pkg-overview].

   --type='strategic': The type of patch being provided; one of [json merge strategic]
```



## Use a strategic merge patch to update a Deployment

Here's the configuration file for a Deployment that has two replicas. Each replica is a Pod that has one container:

`application/deployment-patch.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: patch-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: patch-demo-ctr
        image: nginx
      tolerations:
      - effect: NoSchedule
        key: dedicated
        value: test-team
```

Create the Deployment:

```
kubectl apply -f https://k8s.io/examples/application/deployment-patch.yaml
```

View the Pods associated with your Deployment:

```bash
kubectl get pods
```

The output shows that the Deployment has two Pods. The `1/1` indicates that each Pod has one container:

```
NAME                        READY     STATUS    RESTARTS   AGE
patch-demo-28633765-670qr   1/1       Running   0          23s
patch-demo-28633765-j5qs3   1/1       Running   0          23s
```

Make a note of the names of the running Pods. Later, you will see that these Pods get terminated and replaced by new ones.

At this point, each Pod has one Container that runs the nginx image. Now suppose you want each Pod to have two containers: one that runs nginx and one that runs redis.

Create a file named `patch-file.yaml` that has this content:

```yaml
spec:
  template:
    spec:
      containers:
      - name: patch-demo-ctr-2
        image: redis
```

Patch your Deployment:

- [Bash](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/#kubectl-patch-example-0)
- [PowerShell](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/#kubectl-patch-example-1)



```bash
kubectl patch deployment patch-demo --patch "$(cat patch-file.yaml)"
```

View the patched Deployment:

```bash
kubectl get deployment patch-demo --output yaml
```

The output shows that the PodSpec in the Deployment has two Containers:

```bash
containers:
- image: redis
  imagePullPolicy: Always
  name: patch-demo-ctr-2
  ...
- image: nginx
  imagePullPolicy: Always
  name: patch-demo-ctr
  ...
```

View the Pods associated with your patched Deployment:

```bash
kubectl get pods
```

The output shows that the running Pods have different names from the Pods that were running previously. The Deployment terminated the old Pods and created two new Pods that comply with the updated Deployment spec. The `2/2` indicates that each Pod has two Containers:

```
NAME                          READY     STATUS    RESTARTS   AGE
patch-demo-1081991389-2wrn5   2/2       Running   0          1m
patch-demo-1081991389-jmg7b   2/2       Running   0          1m
```

Take a closer look at one of the patch-demo Pods:

```bash
kubectl get pod <your-pod-name> --output yaml
```

The output shows that the Pod has two Containers: one running nginx and one running redis:

```
containers:
- image: redis
  ...
- image: nginx
  ...
```

### Notes on the strategic merge patch

The patch you did in the preceding exercise is called a *strategic merge patch*. Notice that the patch did not replace the `containers` list. Instead it added a new Container to the list. In other words, the list in the patch was merged with the existing list. This is not always what happens when you use a strategic merge patch on a list. In some cases, the list is replaced, not merged.

With a strategic merge patch, a list is either replaced or merged depending on its patch strategy. The patch strategy is specified by the value of the `patchStrategy` key in a field tag in the Kubernetes source code. For example, the `Containers` field of `PodSpec` struct has a `patchStrategy` of `merge`:

```go
type PodSpec struct {
  ...
  Containers []Container `json:"containers" patchStrategy:"merge" patchMergeKey:"name" ...`
```

You can also see the patch strategy in the [OpenApi spec](https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json):

```json
"io.k8s.api.core.v1.PodSpec": {
    ...
     "containers": {
      "description": "List of containers belonging to the pod. ...
      },
      "x-kubernetes-patch-merge-key": "name",
      "x-kubernetes-patch-strategy": "merge"
     },
```

And you can see the patch strategy in the [Kubernetes API documentation](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#podspec-v1-core).

Create a file named `patch-file-tolerations.yaml` that has this content:

```yaml
spec:
  template:
    spec:
      tolerations:
      - effect: NoSchedule
        key: disktype
        value: ssd
```

Patch your Deployment:

```bash
kubectl patch deployment patch-demo --patch "$(cat patch-file-tolerations.yaml)"
```

View the patched Deployment:

```bash
kubectl get deployment patch-demo --output yaml
```

The output shows that the PodSpec in the Deployment has only one Toleration:

```bash
tolerations:
      - effect: NoSchedule
        key: disktype
        value: ssd
```

Notice that the `tolerations` list in the PodSpec was replaced, not merged. This is because the Tolerations field of PodSpec does not have a `patchStrategy` key in its field tag. So the strategic merge patch uses the default patch strategy, which is `replace`.

```go
type PodSpec struct {
  ...
  Tolerations []Toleration `json:"tolerations,omitempty" protobuf:"bytes,22,opt,name=tolerations"`
```

## Use a JSON merge patch to update a Deployment

A strategic merge patch is different from a [JSON merge patch](https://tools.ietf.org/html/rfc7386). With a JSON merge patch, if you want to update a list, you have to specify the entire new list. And the new list completely replaces the existing list.

The `kubectl patch` command has a `type` parameter that you can set to one of these values:

| Parameter value | Merge type                                                   | 备注                                                         |
| --------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| json            | [JSON Patch, RFC 6902](https://tools.ietf.org/html/rfc6902)  | The JSON Patch format is similar to a database transaction: <br>it is an array of mutating operations on a JSON document, <br>which is executed atomically by a proper implementation. <br>It is basically a series of `"add"`, `"remove"`, `"replace"`, `"move"` and `"copy"` operations. |
| merge           | [JSON Merge Patch, RFC 7386](https://tools.ietf.org/html/rfc7386) | 对json 进行了简化，但是仍然有缺陷。1. delete must set null； 2. add new element must report entire array。3. 缺少JSON Schema验证。 |
| strategic       | Strategic merge patch                                        | 不必提供完整的字段，新字段会添加，出现的已有字段会更新，没有出现的已有字段不变<br>不支持 custom resource， custom resource 需要用"application/merge-patch+json" |

For a comparison of JSON patch and JSON merge patch, see [JSON Patch and JSON Merge Patch](https://erosb.github.io/post/json-patch-vs-merge-patch/).

The default value for the `type` parameter is `strategic`. So in the preceding exercise, you did a strategic merge patch.

Next, do a JSON merge patch on your same Deployment. Create a file named `patch-file-2.yaml` that has this content:

```yaml
spec:
  template:
    spec:
      containers:
      - name: patch-demo-ctr-3
        image: gcr.io/google-samples/node-hello:1.0
```

In your patch command, set `type` to `merge`:

```bash
kubectl patch deployment patch-demo --type  "$(cat patch-file-2.yaml)"
```

View the patched Deployment:

```bash
kubectl get deployment patch-demo --output yaml
```

The `containers` list that you specified in the patch has only one Container. The output shows that your list of one Container replaced the existing `containers` list.

```bash
spec:
  containers:
  - image: gcr.io/google-samples/node-hello:1.0
    ...
    name: patch-demo-ctr-3
```

List the running Pods:

```bash
kubectl get pods
```

In the output, you can see that the existing Pods were terminated, and new Pods were created. The `1/1` indicates that each new Pod is running only one Container.

```bash
NAME                          READY     STATUS    RESTARTS   AGE
patch-demo-1307768864-69308   1/1       Running   0          1m
patch-demo-1307768864-c86dc   1/1       Running   0          1m
```

## Use strategic merge patch to update a Deployment using the retainKeys strategy

Here's the configuration file for a Deployment that uses the `RollingUpdate` strategy:

[`application/deployment-retainkeys.yaml`](https://raw.githubusercontent.com/kubernetes/website/master/content/en/examples/application/deployment-retainkeys.yaml) ![Copy application/deployment-retainkeys.yaml to clipboard](https://d33wubrfki0l68.cloudfront.net/0901162ab78eb4ff2e9e5dc8b17c3824befc91a6/44ccd/images/copycode.svg)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: retainkeys-demo
spec:
  selector:
    matchLabels:
      app: nginx
  strategy:
    rollingUpdate:
      maxSurge: 30%
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: retainkeys-demo-ctr
        image: nginx
```

Create the deployment:

```bash
kubectl apply -f https://k8s.io/examples/application/deployment-retainkeys.yaml
```

At this point, the deployment is created and is using the `RollingUpdate` strategy.

Create a file named `patch-file-no-retainkeys.yaml` that has this content:

```yaml
spec:
  strategy:
    type: Recreate
```

Patch your Deployment:

- [Bash](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/#kubectl-retainkeys-example-0)
- [PowerShell](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/#kubectl-retainkeys-example-1)



```bash
kubectl patch deployment retainkeys-demo --patch "$(cat patch-file-no-retainkeys.yaml)"
```

In the output, you can see that it is not possible to set `type` as `Recreate` when a value is defined for `spec.strategy.rollingUpdate`:

```bash
The Deployment "retainkeys-demo" is invalid: spec.strategy.rollingUpdate: Forbidden: may not be specified when strategy `type` is 'Recreate'
```

The way to remove the value for `spec.strategy.rollingUpdate` when updating the value for `type` is to use the `retainKeys` strategy for the strategic merge.

Create another file named `patch-file-retainkeys.yaml` that has this content:

```yaml
spec:
  strategy:
    $retainKeys:
    - type
    type: Recreate
```

With this patch, we indicate that we want to retain only the `type` key of the `strategy` object. Thus, the `rollingUpdate` will be removed during the patch operation.

Patch your Deployment again with this new patch:

- [Bash](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/#kubectl-retainkeys2-example-0)
- [PowerShell](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/#kubectl-retainkeys2-example-1)



```bash
kubectl patch deployment retainkeys-demo --patch "$(cat patch-file-retainkeys.yaml)"
```

Examine the content of the Deployment:

```bash
kubectl get deployment retainkeys-demo --output yaml
```

The output shows that the strategy object in the Deployment does not contain the `rollingUpdate` key anymore:

```bash
spec:
  strategy:
    type: Recreate
  template:
```

### Notes on the strategic merge patch using the retainKeys strategy

The patch you did in the preceding exercise is called a *strategic merge patch with retainKeys strategy*. This method introduces a new directive `$retainKeys` that has the following strategies:

- It contains a list of strings.
- All fields needing to be preserved must be present in the `$retainKeys` list.
- The fields that are present will be merged with live object.
- All of the missing fields will be cleared when patching.
- All fields in the `$retainKeys` list must be a superset or the same as the fields present in the patch.

The `retainKeys` strategy does not work for all objects. It only works when the value of the `patchStrategy` key in a field tag in the Kubernetes source code contains `retainKeys`. For example, the `Strategy` field of the `DeploymentSpec` struct has a `patchStrategy` of `retainKeys`:

```go
type DeploymentSpec struct {
  ...
  // +patchStrategy=retainKeys
  Strategy DeploymentStrategy `json:"strategy,omitempty" patchStrategy:"retainKeys" ...`
```

You can also see the `retainKeys` strategy in the [OpenApi spec](https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json):

```json
"io.k8s.api.apps.v1.DeploymentSpec": {
   ...
  "strategy": {
    "$ref": "#/definitions/io.k8s.api.apps.v1.DeploymentStrategy",
    "description": "The deployment strategy to use to replace existing pods with new ones.",
    "x-kubernetes-patch-strategy": "retainKeys"
  },
```

And you can see the `retainKeys` strategy in the [Kubernetes API documentation](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#deploymentspec-v1-apps).

## Alternate forms of the kubectl patch command

The `kubectl patch` command takes YAML or JSON. It can take the patch as a file or directly on the command line.

Create a file named `patch-file.json` that has this content:

```json
{
   "spec": {
      "template": {
         "spec": {
            "containers": [
               {
                  "name": "patch-demo-ctr-2",
                  "image": "redis"
               }
            ]
         }
      }
   }
}
```

The following commands are equivalent:

```bash
kubectl patch deployment patch-demo --patch "$(cat patch-file.yaml)"
kubectl patch deployment patch-demo --patch 'spec:\n template:\n  spec:\n   containers:\n   - name: patch-demo-ctr-2\n     image: redis'

kubectl patch deployment patch-demo --patch "$(cat patch-file.json)"
kubectl patch deployment patch-demo --patch '{"spec": {"template": {"spec": {"containers": [{"name": "patch-demo-ctr-2","image": "redis"}]}}}}'
```

## Summary

In this exercise, you used `kubectl patch` to change the live configuration of a Deployment object. You did not change the configuration file that you originally used to create the Deployment object. Other commands for updating API objects include [kubectl annotate](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands/#annotate), [kubectl edit](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands/#edit), [kubectl replace](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands/#replace), [kubectl scale](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands/#scale), and [kubectl apply](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands/#apply).

> **Note:** Strategic merge patch is not supported for custom resources.



Link:

[Update API Objects in Place Using kubectl patch](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/)

[Json and merge Patch pk]([https://erosb.github.io/post/json-patch-vs-merge-patch/)