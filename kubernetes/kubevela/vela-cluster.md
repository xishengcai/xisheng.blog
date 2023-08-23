# vela-cluster

## **Task:**

	1. Rollout deployment
	2. Traffic-shift (with istio)
	3. Multi-cluster



## step by step

- create application, but not deploy workload

  ```yaml
  cat <<EOF | kubectl apply -f -
  apiVersion: core.oam.dev/v1beta1
  kind: Application
  metadata:
    name: example-app
    annotations:
      app.oam.dev/revision-only: "true"
  spec:
    components:
      - name: testsvc
        type: webservice
        properties:
          addRevisionLabel: true
          image: crccheck/hello-world
          port: 8000
  EOF
  
  ```

  

- **发布版本v1** **AppDeployment**, deploy workload

  ```yaml
  cat <<EOF | kubectl apply -f -
  apiVersion: core.oam.dev/v1beta1
  kind: AppDeployment
  metadata:
    name: example-appdeploy
  spec:
    appRevisions:
      - revisionName: example-app-v1
  
        placement:
          - distribution:
              replicas: 2
  EOF
  ```

  

- Update Application properties:

  ```yaml
  cat <<EOF | kubectl apply -f -
  apiVersion: core.oam.dev/v1beta1
  kind: Application
  metadata:
    name: example-app
    annotations:
      app.oam.dev/revision-only: "true"
  spec:
    components:
      - name: testsvc
        type: webservice
        properties:
          addRevisionLabel: true
          image: nginx
          port: 80
  EOF
  ```

  This will create a new `example-app-v2` AppRevision. Check it:

  ```
  $ kubectl get applicationrevisions.core.oam.dev
  NAME
  example-app-v1
  example-app-v2
  
  ```

  

- Then use the two AppRevisions to update the AppDeployment:

  ```yaml
  cat <<EOF | kubectl apply -f -
  apiVersion: core.oam.dev/v1beta1
  kind: AppDeployment
  metadata:
    name: example-appdeploy
  spec:
    appRevisions:
      - revisionName: example-app-v1
  
        placement:
          - distribution:
              replicas: 1
  
      - revisionName: example-app-v2
  
        placement:
          - distribution:
              replicas: 1
  EOF
  ```

  

- create gateay

  ```yaml
  apiVersion: networking.istio.io/v1alpha3
  kind: Gateway
  metadata:
    name: example-app-gateway
  spec:
    selector:
      istio: ingressgateway # use istio default controller
    servers:
      - port:
          number: 80
          name: http
          protocol: HTTP
        hosts:
          - "*"
  
  ```

- Apply traffic shift

  ```yaml
  apiVersion: core.oam.dev/v1beta1
  kind: AppDeployment
  metadata:
    name: example-appdeploy
  spec:
    traffic:
      hosts:
        - example-app.example.com
      gateways:
        - example-app-gateway
      http:
        - weightedTargets:
            - revisionName: example-app-v1
              componentName: testsvc
              port: 8000
              weight: 50
            - revisionName: example-app-v2
              componentName: testsvc
              port: 80
              weight: 50
  
    appRevisions:
      - revisionName: example-app-v1
        placement:
          - distribution:
              replicas: 1
  
      - revisionName: example-app-v2
        placement:
          - distribution:
              replicas: 1
  ```
  
- check

  ```bash
  # run this in another terminal
  $ kubectl -n istio-system port-forward service/istio-ingressgateway 8080:80
  Forwarding from 127.0.0.1:8080 -> 8080
  Forwarding from [::1]:8080 -> 8080
  
  # The command should return pages of either docker whale or nginx in 50/50
  $ curl -H "Host: example-app.example.com" http://localhost:8080/
  
  ```

- clean

  ```bash
  kubectl delete appdeployments.core.oam.dev  --all
  kubectl delete applications.core.oam.dev --all\
  ```

  

1. 
2. Controller
3. 流程
   1. 获取 Application  with annotation “app.oam.dev/revision-only: "true"
   2. 获取 appdeployment
   3. 



question

Q：vela 创建应用的方式是不是有点多， 方式1: 原oam ApplicationConfiguration， 方式2: create vela  Application，     方式3: 创建 vela Application +  vela AppDeployment

vela 创建应用的方式是不是有点多， 方式1: 原oam ApplicationConfiguration， 方式2: create vela Application without annotation of revision， 方式3: 创建 vela Application with revision + vela AppDeployment