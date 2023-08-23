# install harbor with helm



chart source：



use nodePort

```
helm repo add harbor https://helm.goharbor.io
helm fetch harbor/harbor
helm pull harbor/harbor --version 1.8.2
安装
tar zxf harbor-1.8.2.tgz
# 创建命名空间
kubectl create ns harbor
# 安装harbor到harbor命名空间
# externalURL: 访问地址，非常重要
# persistence.enabled: 测试使用，关闭持久化
# registry.relativeurls: 前面再放一层代理需要的配置

helm install harbor ./harbor -n harbor  --set externalURL=http://192.168.10.11:30002 --set expose.type=nodePort --set expose.tls.enabled=false --set persistence.enabled=false --set trivy.enabled=false --set notary.enabled=false --set registry.relativeurls=true
(这个过程需要下载公网镜像，并非离线安装)

externalURL=https不修改成http会报错：{"errors":[{"code":"FORBIDDEN","message":"CSRF token invalid"}]}
```





use domain visit





## question

### support http





需求： 通过charts 在任意kubernetes 部署 harbor， 用户点击 部署后，即可使用



前提条件

Domain:

1. 申请 域名
2. 域名解析到IP地址
3. 粘贴证书

![image-20230505175640236](/Users/xishengcai/soft/xisheng.blog/blog/kubernetes/harbor/image-20230505175640236.png)





![image-20230505175700553](/Users/xishengcai/soft/xisheng.blog/blog/kubernetes/harbor/image-20230505175700553.png)



harbor-core

```
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: '1'
    meta.helm.sh/release-name: harbor
    meta.helm.sh/release-namespace: default
  creationTimestamp: '2023-05-05T09:49:43Z'
  generation: 1
  labels:
    app: harbor
    app.kubernetes.io/managed-by: Helm
    chart: harbor
    component: core
    heritage: Helm
    release: harbor
  managedFields:
    - apiVersion: apps/v1
      fieldsType: FieldsV1
      fieldsV1:
        'f:metadata':
          'f:annotations':
            .: {}
            'f:meta.helm.sh/release-name': {}
            'f:meta.helm.sh/release-namespace': {}
          'f:labels':
            .: {}
            'f:app': {}
            'f:app.kubernetes.io/managed-by': {}
            'f:chart': {}
            'f:component': {}
            'f:heritage': {}
            'f:release': {}
        'f:spec':
          'f:progressDeadlineSeconds': {}
          'f:replicas': {}
          'f:revisionHistoryLimit': {}
          'f:selector': {}
          'f:strategy':
            'f:rollingUpdate':
              .: {}
              'f:maxSurge': {}
              'f:maxUnavailable': {}
            'f:type': {}
          'f:template':
            'f:metadata':
              'f:annotations':
                .: {}
                'f:checksum/configmap': {}
                'f:checksum/secret': {}
                'f:checksum/secret-jobservice': {}
                'f:checksum/tls': {}
              'f:labels':
                .: {}
                'f:app': {}
                'f:component': {}
                'f:release': {}
            'f:spec':
              'f:automountServiceAccountToken': {}
              'f:containers':
                'k:{"name":"core"}':
                  .: {}
                  'f:env':
                    .: {}
                    'k:{"name":"CORE_SECRET"}':
                      .: {}
                      'f:name': {}
                      'f:valueFrom':
                        .: {}
                        'f:secretKeyRef':
                          .: {}
                          'f:key': {}
                          'f:name': {}
                    'k:{"name":"INTERNAL_TLS_CERT_PATH"}':
                      .: {}
                      'f:name': {}
                      'f:value': {}
                    'k:{"name":"INTERNAL_TLS_ENABLED"}':
                      .: {}
                      'f:name': {}
                      'f:value': {}
                    'k:{"name":"INTERNAL_TLS_KEY_PATH"}':
                      .: {}
                      'f:name': {}
                      'f:value': {}
                    'k:{"name":"INTERNAL_TLS_TRUST_CA_PATH"}':
                      .: {}
                      'f:name': {}
                      'f:value': {}
                    'k:{"name":"JOBSERVICE_SECRET"}':
                      .: {}
                      'f:name': {}
                      'f:valueFrom':
                        .: {}
                        'f:secretKeyRef':
                          .: {}
                          'f:key': {}
                          'f:name': {}
                  'f:envFrom': {}
                  'f:image': {}
                  'f:imagePullPolicy': {}
                  'f:livenessProbe':
                    .: {}
                    'f:failureThreshold': {}
                    'f:httpGet':
                      .: {}
                      'f:path': {}
                      'f:port': {}
                      'f:scheme': {}
                    'f:periodSeconds': {}
                    'f:successThreshold': {}
                    'f:timeoutSeconds': {}
                  'f:name': {}
                  'f:ports':
                    .: {}
                    'k:{"containerPort":8443,"protocol":"TCP"}':
                      .: {}
                      'f:containerPort': {}
                      'f:protocol': {}
                  'f:readinessProbe':
                    .: {}
                    'f:failureThreshold': {}
                    'f:httpGet':
                      .: {}
                      'f:path': {}
                      'f:port': {}
                      'f:scheme': {}
                    'f:periodSeconds': {}
                    'f:successThreshold': {}
                    'f:timeoutSeconds': {}
                  'f:resources': {}
                  'f:startupProbe':
                    .: {}
                    'f:failureThreshold': {}
                    'f:httpGet':
                      .: {}
                      'f:path': {}
                      'f:port': {}
                      'f:scheme': {}
                    'f:initialDelaySeconds': {}
                    'f:periodSeconds': {}
                    'f:successThreshold': {}
                    'f:timeoutSeconds': {}
                  'f:terminationMessagePath': {}
                  'f:terminationMessagePolicy': {}
                  'f:volumeMounts':
                    .: {}
                    'k:{"mountPath":"/etc/core/app.conf"}':
                      .: {}
                      'f:mountPath': {}
                      'f:name': {}
                      'f:subPath': {}
                    'k:{"mountPath":"/etc/core/ca"}':
                      .: {}
                      'f:mountPath': {}
                      'f:name': {}
                    'k:{"mountPath":"/etc/core/key"}':
                      .: {}
                      'f:mountPath': {}
                      'f:name': {}
                      'f:subPath': {}
                    'k:{"mountPath":"/etc/core/private_key.pem"}':
                      .: {}
                      'f:mountPath': {}
                      'f:name': {}
                      'f:subPath': {}
                    'k:{"mountPath":"/etc/core/token"}':
                      .: {}
                      'f:mountPath': {}
                      'f:name': {}
                    'k:{"mountPath":"/etc/harbor/ssl/core"}':
                      .: {}
                      'f:mountPath': {}
                      'f:name': {}
              'f:dnsPolicy': {}
              'f:restartPolicy': {}
              'f:schedulerName': {}
              'f:securityContext':
                .: {}
                'f:fsGroup': {}
                'f:runAsUser': {}
              'f:terminationGracePeriodSeconds': {}
              'f:volumes':
                .: {}
                'k:{"name":"ca-download"}':
                  .: {}
                  'f:name': {}
                  'f:secret':
                    .: {}
                    'f:defaultMode': {}
                    'f:secretName': {}
                'k:{"name":"config"}':
                  .: {}
                  'f:configMap':
                    .: {}
                    'f:defaultMode': {}
                    'f:items': {}
                    'f:name': {}
                  'f:name': {}
                'k:{"name":"core-internal-certs"}':
                  .: {}
                  'f:name': {}
                  'f:secret':
                    .: {}
                    'f:defaultMode': {}
                    'f:secretName': {}
                'k:{"name":"psc"}':
                  .: {}
                  'f:emptyDir': {}
                  'f:name': {}
                'k:{"name":"secret-key"}':
                  .: {}
                  'f:name': {}
                  'f:secret':
                    .: {}
                    'f:defaultMode': {}
                    'f:items': {}
                    'f:secretName': {}
                'k:{"name":"token-service-private-key"}':
                  .: {}
                  'f:name': {}
                  'f:secret':
                    .: {}
                    'f:defaultMode': {}
                    'f:secretName': {}
      manager: cluster-manage
      operation: Update
      time: '2023-05-05T09:49:43Z'
    - apiVersion: apps/v1
      fieldsType: FieldsV1
      fieldsV1:
        'f:metadata':
          'f:annotations':
            'f:deployment.kubernetes.io/revision': {}
        'f:status':
          'f:availableReplicas': {}
          'f:conditions':
            .: {}
            'k:{"type":"Available"}':
              .: {}
              'f:lastTransitionTime': {}
              'f:lastUpdateTime': {}
              'f:message': {}
              'f:reason': {}
              'f:status': {}
              'f:type': {}
            'k:{"type":"Progressing"}':
              .: {}
              'f:lastTransitionTime': {}
              'f:lastUpdateTime': {}
              'f:message': {}
              'f:reason': {}
              'f:status': {}
              'f:type': {}
          'f:observedGeneration': {}
          'f:readyReplicas': {}
          'f:replicas': {}
          'f:updatedReplicas': {}
      manager: kube-controller-manager
      operation: Update
      time: '2023-05-05T09:51:23Z'
  name: harbor-core
  namespace: default
  resourceVersion: '109823'
  uid: 9caba152-e12e-4fda-969d-bfaa31684d2b
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: harbor
      component: core
      release: harbor
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      annotations:
        checksum/configmap: 2d7fd6e43413482bf03db6417cf6468cc7eb2746360267e31aa9ab32c93d30e2
        checksum/secret: 57fa8e7690c38a8b5cbdbecc58eee1242f4051a3b8f2b24c96bfe75226fce889
        checksum/secret-jobservice: fed00572658df6c940150a9c27a70dec15ddb53bacb8bede62e94959497795ac
        checksum/tls: a3178f1a8286e596c338303a229c019f330a75da6f3936fef840b6bafb71a0a8
      labels:
        app: harbor
        component: core
        release: harbor
    spec:
      automountServiceAccountToken: false
      containers:
        - env:
            - name: CORE_SECRET
              valueFrom:
                secretKeyRef:
                  key: secret
                  name: harbor-core
            - name: JOBSERVICE_SECRET
              valueFrom:
                secretKeyRef:
                  key: JOBSERVICE_SECRET
                  name: harbor-jobservice
            - name: INTERNAL_TLS_ENABLED
              value: 'true'
            - name: INTERNAL_TLS_KEY_PATH
              value: /etc/harbor/ssl/core/tls.key
            - name: INTERNAL_TLS_CERT_PATH
              value: /etc/harbor/ssl/core/tls.crt
            - name: INTERNAL_TLS_TRUST_CA_PATH
              value: /etc/harbor/ssl/core/ca.crt
          envFrom:
            - configMapRef:
                name: harbor-core
            - secretRef:
                name: harbor-core
          image: 'goharbor/harbor-core:v2.8.0'
          imagePullPolicy: IfNotPresent
          livenessProbe:
            failureThreshold: 2
            httpGet:
              path: /api/v2.0/ping
              port: 8443
              scheme: HTTPS
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          name: core
          ports:
            - containerPort: 8443
              protocol: TCP
          readinessProbe:
            failureThreshold: 2
            httpGet:
              path: /api/v2.0/ping
              port: 8443
              scheme: HTTPS
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          resources: {}
          startupProbe:
            failureThreshold: 360
            httpGet:
              path: /api/v2.0/ping
              port: 8443
              scheme: HTTPS
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          volumeMounts:
            - mountPath: /etc/core/app.conf
              name: config
              subPath: app.conf
            - mountPath: /etc/core/key
              name: secret-key
              subPath: key
            - mountPath: /etc/core/private_key.pem
              name: token-service-private-key
              subPath: tls.key
            - mountPath: /etc/core/ca
              name: ca-download
            - mountPath: /etc/harbor/ssl/core
              name: core-internal-certs
            - mountPath: /etc/core/token
              name: psc
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext:
        fsGroup: 10000
        runAsUser: 10000
      terminationGracePeriodSeconds: 120
      volumes:
        - configMap:
            defaultMode: 420
            items:
              - key: app.conf
                path: app.conf
            name: harbor-core
          name: config
        - name: secret-key
          secret:
            defaultMode: 420
            items:
              - key: secretKey
                path: key
            secretName: harbor-core
        - name: token-service-private-key
          secret:
            defaultMode: 420
            secretName: harbor-core
        - name: ca-download
          secret:
            defaultMode: 420
            secretName: harbor-ingress
        - name: core-internal-certs
          secret:
            defaultMode: 420
            secretName: harbor-core-internal-tls
        - emptyDir: {}
          name: psc

```

```

sudo docker run --detach \
    --hostname localhost \
    --env GITLAB_OMNIBUS_CONFIG="external_url 'http://localhost/';\r\ngitlab_rails['lfs_enabled'] = true;" \
    --publish 443:443 --publish 80:80 --publish 221:22 \
    --restart always \
    --name gitlab \
    --volume /srv/gitlab/config:/etc/gitlab \
    --volume /srv/gitlab/logs:/var/log/gitlab \
    --volume /srv/gitlab/data:/var/opt/gitlab \
    gitlab/gitlab-ce:lates
```





