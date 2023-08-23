```yaml
  cloudcore.yaml: |
    apiVersion: cloudcore.config.kubeedge.io/v1alpha2
    kind: CloudCore
    kubeAPIConfig:
      kubeConfig: ""
      master: ""
    modules:
      dynamicController:
        enable: true
      cloudHub:
        advertiseAddress:
          - 121.41.64.133
        nodeLimit: 100
        unixsocket:
          address: unix:///var/lib/kubeedge/kubeedge.sock
          enable: true
        websocket:
          address: 0.0.0.0
          enable: true
          port: 10000
      cloudStream:
        enable: true
        streamPort: 10003
        tlsStreamCAFile: /etc/kubeedge/ca/streamCA.crt
        tlsStreamCertFile: /etc/kubeedge/certs/stream.crt
        tlsStreamPrivateKeyFile: /etc/kubeedge/certs/stream.key
        tunnelPort: 10004
```



```
curl -k \
     --include \
     --no-buffer \
     --header "Connection: Upgrade" \
     --header "Upgrade: websocket" \
     --header "Sec-WebSocket-Version: 13" \
     https://172.16.2.249:10003/stats/summary
```

