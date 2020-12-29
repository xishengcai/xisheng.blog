---
title: "field-selector"
date: 2020-12-29T16:08:36+08:00
draft: false
---

The --field-selector only works with some limited fields.
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

```shell script
kubectl get nodes -o json | jq -r '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True")) | .metadata.name '
```
