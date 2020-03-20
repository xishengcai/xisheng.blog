---
title: "Network Policy"
date: 2019-12-11T22:50:21+08:00
draft: false
---

### NetworkPolicy

network policies that govern how pods communicate with each other.

###  Require
- kubernetes cluster
- network policy in [calico, Cilium, Kube-router, Romana, Weave New]

### Practice
#### 1. Create an nginx deployment and expose it via a service
```
kubectl create deployment nginx --image=nginx
```

And expose it via a service.
```
kubectl expose deployment nginx --port=80
```

#### 2. Test the service by accessing it from another pod
```
kubectl run --generator=run-pod/v1 busybox --rm -ti --image=busybox -- /bin/sh
```

```
/ # wget --spider --timeout=1 nginx
Connecting to nginx (10.111.193.237:80)
remote file exists
```

#### 3. Limit access to the nginx service
```
cat <<EOF> nginx-policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: access-nginx
spec:
  podSelector:
    matchLabels:
      app: nginx
  ingress:
  - from:
    - podSelector:
        matchLabels:
          access: "true"
EOF
```
```
kubectl apply -f nginx-policy.yaml
```

#### 4. Test access to the service when access label is not defined
```
kubectl run --generator=run-pod/v1 busybox --rm -ti --image=busybox -- /bin/sh
```
```
/ # wget --spider --timeout=1 nginx
Connecting to nginx (10.100.0.16:80)
wget: download timed out
/ #
```

#### 5. Define access label and test again
---
Create a pod with the correct labels, and you’ll see that the request is allowed:
```
kubectl run --generator=run-pod/v1 busybox --rm -ti --labels="access=true" --image=busybox -- /bin/sh
```
```
/ # wget --spider --timeout=1 nginx
Connecting to nginx (10.100.0.16:80)
/ #
```






[offical-doc](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/#assign-the-policy-to-the-service)