```json
https://50.96.207.97:443/apis/custom.metrics.k8s.io/v1beta1: Get https://50.96.207.97:443/apis/custom.metrics.k8s.io/v1beta1: read tcp 50.96.207.97:34496->50.96.207.97:443: read: connection reset by peer
I0323 05:58:29.083182       1 controller.go:107] OpenAPI AggregationController: Processing item v1beta1.metrics.k8s.io
```



现象：

1. node curl svc 通
2. pods内 curl svc 通
3. api-server request svc 不通