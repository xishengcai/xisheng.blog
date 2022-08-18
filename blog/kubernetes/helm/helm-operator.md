# helm-operator quick start

<!--toc-->

## Prerequisites

- Kubernetes cluster **>=1.13.0**
- Up-to-date **Helm 2 or 3** [`helm` binary](https://github.com/helm/helm/releases)
- `kubectl`

## Install the Helm Operator

First, install the `HelmRelease` Custom Resource Definition. By adding this CRD it will be possible to define `HelmRelease` resources on the cluster:

```
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/1.2.0/deploy/crds.yaml
```

Create a new namespace:

```
kubectl create ns flux
```

Using `helm`, first add the Flux CD Helm repository:

```
helm repo add fluxcd https://charts.fluxcd.io
```

Next, install the Helm Operator using the available Helm chart:

```
helm upgrade -i helm-operator fluxcd/helm-operator \
    --namespace flux \
    --set helm.versions=v3
```

This installs the Helm Operator with default settings and support for Helm 3 enabled.

Hint

See the [operator reference](https://docs.fluxcd.io/projects/helm-operator/en/stable/references/operator/) and [chart documentation](https://docs.fluxcd.io/projects/helm-operator/en/stable/references/chart/#configuration) for detailed configuration options.

## Create your first `HelmRelease`

To install a Helm chart using the Helm Operator, create a `HelmRelease` resource on the cluster:

```
cat <<EOF | kubectl apply -f -
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: podinfo
  namespace: default
spec:
  chart:
    repository: https://stefanprodan.github.io/podinfo
    name: podinfo
    version: 3.2.0
EOF
```



Example2:

```go
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: podinfo
  namespace: default
spec:
  chart:
    repository: "https://charts.bitnami.com/bitnami"
    name: "redis"
    version: "14.2.1"
```



The applied resource will install the [`podinfo` chart](https://github.com/stefanprodan/podinfo) with a tiny Go web application from a Helm repository chart source. *Chart sources* are references to places where the operator can find Helm charts. The release name the Helm Operator will use is composed out of the namespace and name of the `HelmRelease` resource (but can be configured): `default-podinfo`.

Hint

Read more about different chart sources in the [chart sources](https://docs.fluxcd.io/projects/helm-operator/en/stable/helmrelease-guide/chart-sources/) section of the `HelmRelease` guide.

## Confirm the chart has been installed

When a Helm chart has been successfully released the Helm Operator will push a condition of type `Released` with status `True`. You can check this condition is set using `kubectl`:

```
$ kubectl wait --for=condition=released helmrelease/podinfo
helmrelease.helm.fluxcd.io/podinfo condition met
```

Or, by describing the `HelmRelease` itself:

```
$ kubectl describe helmrelease podinfo
Name:         podinfo
Namespace:    default
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"helm.fluxcd.io/v1","kind":"HelmRelease","metadata":{"annotations":{},"name":"podinfo","namespace":"default"},"spec":{"chart...
API Version:  helm.fluxcd.io/v1
Kind:         HelmRelease
Metadata:
  Creation Timestamp:  2020-01-01T12:00:00Z
  Generation:          1
  Resource Version:    9017
  Self Link:           /apis/helm.fluxcd.io/v1/namespaces/default/helmreleases/podinfo
  UID:                 e9c11dc8-5ba6-4ee7-9226-cb0f9cab04ff
Spec:
  Chart:
    Name:        podinfo
    Repository:  https://stefanprodan.github.io/podinfo
    Version:     3.2.0
Status:
  Conditions:
    Last Transition Time:  2020-01-01T12:00:00Z
    Last Update Time:      2020-01-01T12:00:00Z
    Message:               chart fetched: podinfo-3.2.0.tgz
    Reason:                RepoChartInCache
    Status:                True
    Type:                  ChartFetched
    Last Transition Time:  2020-01-01T12:00:01Z
    Last Update Time:      2020-01-01T12:00:01Z
    Message:               Helm release sync succeeded
    Reason:                HelmSuccess
    Status:                True
    Type:                  Released
  Observed Generation:     1
  Release Name:            default-podinfo
  Release Status:          deployed
  Revision:                3.2.0
Events:
  Type    Reason       Age   From           Message
  ----    ------       ----  ----           -------
  Normal  ChartSynced  35s   helm-operator  Chart managed by HelmRelease processed
```

Confirm the `default-podinfo` pod has been deployed:

```
$ kubectl get pods
NAME                               READY   STATUS    RESTARTS   AGE
default-podinfo-7f9759cc66-bslsl   1/1     Running   0          59s
```

Tip

The available shorthand for `kubectl` operations on `helmrelease` resources is `hr`, i.e:

```
console $ kubectl get hr NAME RELEASE STATUS MESSAGE AGE podinfo default-podinfo deployed Helm release sync succeeded 59s
```

## Make a modification

The Helm Operator ensures that the Helm release in the cluster matches the defined state in the `HelmRelease` resource. This means that an upgrade will be performed when the resource is modified. To demonstrate this, we are going to increase the number of `podinfo` replicas:

```
kubectl edit helmrelease/podinfo
```

[Helm values](https://helm.sh/docs/chart_best_practices/values/#helm) can be defined on the `HelmRelease` resources under the `spec.values` key:

```
...
spec:
  chart:
    name: podinfo
    repository: https://stefanprodan.github.io/podinfo
    version: 3.2.0
  values:
    replicaCount: 2
```

Save the modification and watch the new pod enroll:

```
$ kubectl get pods -w
NAME                               READY   STATUS              RESTARTS   AGE
default-podinfo-7f9759cc66-lk45t   1/1     Running             0          59s
default-podinfo-7f9759cc66-w7fj7   0/1     ContainerCreating   0          1s
default-podinfo-7f9759cc66-w7fj7   0/1     Running             0          1s
default-podinfo-7f9759cc66-w7fj7   1/1     Running             0          1s
```

Hint

See the [values](https://docs.fluxcd.io/projects/helm-operator/en/stable/helmrelease-guide/values/) and [release configuration](https://docs.fluxcd.io/projects/helm-operator/en/stable/helmrelease-guide/release-configuration/) sections in the `HelmRelease` guide for more details.

## Reconciliation

All `HelmRelease` resources in the cluster watched by a Helm Operator instance are rescheduled to synchronize every 3 minutes (or configured `--charts-sync-interval`); this is also known as the reconciliation loop.

During reconciliation the result of a dry-run upgrade made with the `HelmRelease` resource is compared to the current deployed Helm release, and if they differ an upgrade is performed to ensure the defined and in-cluster state match again.

You can experience this with your own eyes by rolling back the modification we just made using `helm`, the Helm Operator created the release with a name composed of the namespace and name of the `HelmRelease`:

```
$ helm rollback podinfo
Rollback was a success! Happy Helming!
$ kubectl get pods
NAME                               READY   STATUS        RESTARTS   AGE
default-podinfo-7f9759cc66-w7fj7   1/1     Terminating   0          1m1s
default-podinfo-7f9759cc66-lk45t   1/1     Running       0          2m1s
```

Watch the Helm Operator reverting the unauthorized modification (this can take a while, but no longer than 3 minutes):

```
$ kubectl get pods -w
NAME                               READY   STATUS              RESTARTS   AGE
default-podinfo-7f9759cc66-lk45t   1/1     Running             0          2m19s
default-podinfo-7f9759cc66-kd5rk   0/1     Pending             0          0s
default-podinfo-7f9759cc66-kd5rk   0/1     Pending             0          0s
default-podinfo-7f9759cc66-kd5rk   0/1     ContainerCreating   0          0s
default-podinfo-7f9759cc66-kd5rk   0/1     Running             0          1s
default-podinfo-7f9759cc66-kd5rk   1/1     Running             0          7s
```

Hint

Read more about [reconciliation and upgrades](https://docs.fluxcd.io/projects/helm-operator/en/stable/helmrelease-guide/reconciliation-and-upgrades/) in the `HelmRelease` guide.

## Uninstalling the chart

To uninstall the chart and clean up the release, simply run `kubectl delete` for the resource:

```
kubectl delete helmrelease podinfo
$ kubectl get pods -w
NAME                               READY   STATUS        RESTARTS   AGE
default-podinfo-7f9759cc66-fr4vb   1/1     Terminating   0          3m30s
default-podinfo-7f9759cc66-kd5rk   1/1     Terminating   0          1m6s
default-podinfo-7f9759cc66-kd5rk   0/1     Terminating   0          1m8s
default-podinfo-7f9759cc66-fr4vb   0/1     Terminating   0          3m32s
```

Delete the Helm Operator by removing the `fluxcd` namespace:

```
kubectl delete namespace flux
```

## Next steps

Want to continue testing the Helm Operator or install it in a cluster environment? Take a look at the available get started guides for more sophisticated setup options:

- [Get started using Helm](https://docs.fluxcd.io/projects/helm-operator/en/stable/get-started/using-helm/)
- [Get started using Kustomize](https://docs.fluxcd.io/projects/helm-operator/en/stable/get-started/using-kustomize/)
- [Get started using YAMLs](https://docs.fluxcd.io/projects/helm-operator/en/stable/get-started/using-yamls/)

Want to take a deeper dive in the available features and the `HelmRelease` resource? **Continue with the [`HelmRelease` guide](https://docs.fluxcd.io/projects/helm-operator/en/stable/helmrelease-guide/introduction/).**



## issue

- can't build docker

- current helmRelease CRD  not support helm password
- use kubectl is layer low





```
#!/bin/bash
go run cmd/helm-operator/main.go \
--kubeconfig=/Users/xishengcai/.kube/config \
--enabled-helm-versions=v3 \
--git-timeout=20s \
--git-poll-interval=5m \
--charts-sync-interval=3m \
--status-update-interval=30s \
--update-chart-deps=true \
--log-release-diffs=false \
--workers=4 \
--tiller-namespace=kube-system
```





{"auths":{"registry.cn-hangzhou.aliyuncs.com":{"username":"xlauncher","password":"811@Launcher#1806","auth":"eGxhdW5jaGVyOjgxMUBMYXVuY2hlciMxODA2"}}}





{"auths":{"registry.cn-beijing.aliyuncs.com":{"username":"lstack1","password":"Launcher@1302","auth":"eGxhdW5jaGVyOjgxMUBMYXVuY2hlciMxODA2"}}}

