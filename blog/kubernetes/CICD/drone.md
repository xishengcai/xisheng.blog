# drone



## what

Drone is a continuous delivery system built on container technology. Drone uses a simple YAML build file, to define and execute build pipelines inside Docker containers.



![image-20211104145120115](/Users/xishengcai/Library/Application Support/typora-user-images/image-20211104145120115.png)



- - **DRONE_RPC_HOST**

    provides the hostname (and optional port) of your Drone server. The runner connects to the server at the host address to receive pipelines for execution.

- - **DRONE_RPC_PROTO**

    provides the protocol used to connect to your Drone server. The value must be either http or https.

- - **DRONE_RPC_SECRET**

    provides the shared secret used to authenticate with your Drone server. This must match the secret defined in your Drone server configuration.





## 部署



        helm install drone ./stable/drone
    
        kubectl create secret generic drone-server-secrets \
          --namespace=default \
          --from-literal=clientSecret="github-oauth2-client-secret"
    
        helm upgrade drone \
          --reuse-values \
          --set 'sourceControl.provider=github' \
          --set 'sourceControl.github.clientID=5f2f26363e1a11e43f11' \
          --set 'sourceControl.secret=drone-server-secrets' \
          --set 'service.type=LoadBalancer' \
          --set 'server.host=drone.xisheng.vip ' \
          stable/drone
    





## 代码结构







