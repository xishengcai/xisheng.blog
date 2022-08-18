# k8s: pod 信息注入



|描述|Docker 字段名称|Kubernetes 字段名称|
|---|---|---|
|容器执行的命令|Entrypoint|command|
|传给命令的参数|Cmd|args|

如果要覆盖默认的 Entrypoint 与 Cmd，需要遵循如下规则：

- 如果在容器配置中没有设置 command 或者 args，那么将使用 Docker 镜像自带的命令及其入参。
- 如果在容器配置中只设置了 command 但是没有设置 args，那么容器启动时只会执行该命令，Docker 镜像中自带的命令及其入参会被忽略。
- 如果在容器配置中只设置了 args，那么 Docker 镜像中自带的命令会使用该新入参作为其执行时的入参。
- 如果在容器配置中同时设置了 command 与 args，那么 Docker 镜像中自带的命令及其入参会被忽略。容器启动时只会执行配置中设置的命令，并使用配置中设置的入参作为命令的入参。

### 在配置中使用环境变量

您在 Pod 的配置中定义的环境变量可以在配置的其他地方使用，例如可用在为 Pod 的容器设置的命令和参数中。在下面的示例配置中，环境变量 GREETING ，HONORIFIC 和 NAME 分别设置为 Warm greetings to ，The Most Honorable 和 Kubernetes。然后这些环境变量在传递给容器 env-print-demo 的 CLI 参数中使用。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: print-greeting
spec:
  containers:
  - name: env-print-demo
    image: bash
    env:
    - name: GREETING
      value: "Warm greetings to"
    - name: HONORIFIC
      value: "The Most Honorable"
    - name: NAME
      value: "Kubernetes"
    command: ["echo"]
    args: ["$(GREETING) $(HONORIFIC) $(NAME)"]
```

### 使用 PodPreset 将信息注入 Pods

在 pod 创建时，用户可以使用 `podpreset` 对象将 secrets、卷挂载和环境变量等信息注入其中。
本文展示了一些 `PodPreset` 资源使用的示例。
用户可以从[理解 Pod Presets](/docs/concepts/workloads/pods/podpreset/) 中了解 PodPresets 的整体情况。
用户提交的 pod spec：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: website
  labels:
    app: website
    role: frontend
spec:
  containers:
    - name: website
      image: nginx
      ports:
        - containerPort: 80
```

用户提交的 ConfigMap：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: etcd-env-config
data:
  number_of_members: "1"
  initial_cluster_state: new
  initial_cluster_token: DUMMY_ETCD_INITIAL_CLUSTER_TOKEN
  discovery_token: DUMMY_ETCD_DISCOVERY_TOKEN
  discovery_url: http://etcd_discovery:2379
  etcdctl_peers: http://etcd:2379
  duplicate_key: FROM_CONFIG_MAP
  REPLACE_ME: "a value"
```

PodPreset 示例：

```yaml
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-database
spec:
  selector:
    matchLabels:
      role: frontend
  env:
    - name: DB_PORT
      value: "6379"
    - name: duplicate_key
      value: FROM_ENV
    - name: expansion
      value: $(REPLACE_ME)
  envFrom:
    - configMapRef:
        name: etcd-env-config
  volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
    - name: cache-volume
      emptyDir: {}

```

### 使用 Secret 安全地分发凭证

#### 将 secret 数据转换为 base-64 形式

假设用户想要有两条 secret 数据：用户名 my-app 和密码 39528$vdg7Jb。 首先使用 Base64 编码 将用户名和密码转化为 base-64 形式。 这里是一个 Linux 示例：

```bash
echo -n 'my-app' | base64
echo -n '39528$vdg7Jb' | base64
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
data:
  username: bXktYXBw
  password: Mzk1MjgkdmRnN0pi
```

> 注意： 如果想要跳过 Base64 编码的步骤，可以使用 kubectl create secret 命令来创建 Secret：

```bash
kubectl create secret generic test-secret --from-literal=username='my-app' --from-literal=password='39528$vdg7Jb'
```

#### 创建可以通过卷访问 secret 数据的 Pod

这里是一个可以用来创建 pod 的配置文件：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-test-pod
spec:
  containers:
    - name: test-container
      image: nginx
      volumeMounts:
        # name must match the volume name below
        - name: secret-volume
          mountPath: /etc/secret-volume
  # The secret data is exposed to Containers in the Pod through a Volume.
  volumes:
    - name: secret-volume
      secret:
        secretName: test-secret
```

secret 数据通过挂载在 /etc/secret-volume 目录下的卷暴露在容器中。 在 shell 中，进入 secret 数据被暴露的目录：

```bash
root@secret-test-pod:/etc/secret-volume# ls
password username
```

## 通过文件将Pod信息呈现给容器

```yaml
pods/inject/dapi-volume.yaml 

apiVersion: v1
kind: Pod
metadata:
  name: kubernetes-downwardapi-volume-example
  labels:
    zone: us-est-coast
    cluster: test-cluster1
    rack: rack-22
  annotations:
    build: two
    builder: john-doe
spec:
  containers:
    - name: client-container
      image: k8s.gcr.io/busybox
      command: ["sh", "-c"]
      args:
      - while true; do
          if [[ -e /etc/podinfo/labels ]]; then
            echo -en '\n\n'; cat /etc/podinfo/labels; fi;
          if [[ -e /etc/podinfo/annotations ]]; then
            echo -en '\n\n'; cat /etc/podinfo/annotations; fi;
          sleep 5;
        done;
      volumeMounts:
        - name: podinfo
          mountPath: /etc/podinfo
  volumes:
    - name: podinfo
      downwardAPI:
        items:
          - path: "labels"
            fieldRef:
              fieldPath: metadata.labels
          - path: "annotations"
            fieldRef:
              fieldPath: metadata.annotations
```

### Downward　API

####　存储POD字段

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubernetes-downwardapi-volume-example
  labels:
    zone: us-est-coast
    cluster: test-cluster1
    rack: rack-22
  annotations:
    build: two
    builder: john-doe
spec:
  containers:
    - name: client-container
      image: k8s.gcr.io/busybox
      command: ["sh", "-c"]
      args:
      - while true; do
          if [[ -e /etc/podinfo/labels ]]; then
            echo -en '\n\n'; cat /etc/podinfo/labels; fi;
          if [[ -e /etc/podinfo/annotations ]]; then
            echo -en '\n\n'; cat /etc/podinfo/annotations; fi;
          sleep 5;
        done;
      volumeMounts:
        - name: podinfo
          mountPath: /etc/podinfo
  volumes:
    - name: podinfo
      downwardAPI:
        items:
          - path: "labels"
            fieldRef:
              fieldPath: metadata.labels
          - path: "annotations"
            fieldRef:
              fieldPath: metadata.annotations
```

在配置文件中，你可以看到Pod有一个downwardAPI类型的Volume，并且挂载到容器中的/etc。

查看downwardAPI下面的items数组。每个数组元素都是一个DownwardAPIVolumeFile。 第一个元素指示Pod的metadata.labels字段的值保存在名为labels的文件中。 第二个元素指示Pod的annotations字段的值保存在名为annotations的文件中。

#### 存储容器字段

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubernetes-downwardapi-volume-example-2
spec:
  containers:
    - name: client-container
      image: k8s.gcr.io/busybox:1.24
      command: ["sh", "-c"]
      args:
      - while true; do
          echo -en '\n';
          if [[ -e /etc/podinfo/cpu_limit ]]; then
            echo -en '\n'; cat /etc/podinfo/cpu_limit; fi;
          if [[ -e /etc/podinfo/cpu_request ]]; then
            echo -en '\n'; cat /etc/podinfo/cpu_request; fi;
          if [[ -e /etc/podinfo/mem_limit ]]; then
            echo -en '\n'; cat /etc/podinfo/mem_limit; fi;
          if [[ -e /etc/podinfo/mem_request ]]; then
            echo -en '\n'; cat /etc/podinfo/mem_request; fi;
          sleep 5;
        done;
      resources:
        requests:
          memory: "32Mi"
          cpu: "125m"
        limits:
          memory: "64Mi"
          cpu: "250m"
      volumeMounts:
        - name: podinfo
          mountPath: /etc/podinfo
  volumes:
    - name: podinfo
      downwardAPI:
        items:
          - path: "cpu_limit"
            resourceFieldRef:
              containerName: client-container
              resource: limits.cpu
              divisor: 1m
          - path: "cpu_request"
            resourceFieldRef:
              containerName: client-container
              resource: requests.cpu
              divisor: 1m
          - path: "mem_limit"
            resourceFieldRef:
              containerName: client-container
              resource: limits.memory
              divisor: 1Mi
          - path: "mem_request"
            resourceFieldRef:
              containerName: client-container
              resource: requests.memory
              divisor: 1Mi
```

#### Capabilities of the Downward API

下面这些信息可以通过环境变量和DownwardAPIVolumeFiles提供给容器：

能通过fieldRef获得的： * metadata.name - Pod名称 * metadata.namespace - Pod名字空间 * metadata.uid - Pod的UID, 版本要求 v1.8.0-alpha.2 * metadata.labels['<KEY>'] - 单个 pod 标签值 <KEY> (例如, metadata.labels['mylabel']); 版本要求 Kubernetes 1.9+ * metadata.annotations['<KEY>'] - 单个 pod 的标注值 <KEY> (例如, metadata.annotations['myannotation']); 版本要求 Kubernetes 1.9+

能通过resourceFieldRef获得的： * 容器的CPU约束值 * 容器的CPU请求值 * 容器的内存约束值 * 容器的内存请求值 * 容器的临时存储约束值, 版本要求 v1.8.0-beta.0 * 容器的临时存储请求值, 版本要求 v1.8.0-beta.0

此外，以下信息可通过DownwardAPIVolumeFiles从fieldRef获得：

- metadata.labels - all of the pod’s labels, formatted as label-key="escaped-label-value" with one label per line
- metadata.annotations - all of the pod’s annotations, formatted as annotation-key="escaped-annotation-value" with one annotation per line
- metadata.labels - 所有Pod的标签，以label-key="escaped-label-value"格式显示，每行显示一个label
- metadata.annotations - Pod的注释，以annotation-key="escaped-annotation-value"格式显示，每行显示一个标签

以下信息可通过环境变量从fieldRef获得：

- status.podIP - 节点IP
- spec.serviceAccountName - Pod服务帐号名称, 版本要求 v1.4.0-alpha.3
- spec.nodeName - 节点名称, 版本要求 v1.4.0-alpha.3
- status.hostIP - 节点IP, 版本要求 v1.7.0-alpha.1

### 通过环境变量将Pod信息呈现给容器

用Pod字段作为环境变量的值

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-envars-fieldref
spec:
  containers:
    - name: test-container
      image: k8s.gcr.io/busybox
      command: [ "sh", "-c"]
      args:
      - while true; do
          echo -en '\n';
          printenv MY_NODE_NAME MY_POD_NAME MY_POD_NAMESPACE;
          printenv MY_POD_IP MY_POD_SERVICE_ACCOUNT;
          sleep 10;
        done;
      env:
        - name: MY_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: MY_POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: MY_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: MY_POD_SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
  restartPolicy: Never
```

这个配置文件中，你可以看到五个环境变量。env字段是一个EnvVars类型的数组。 数组中第一个元素指定MY_NODE_NAME这个环境变量从Pod的spec.nodeName字段获取变量值。同样，其它环境变量也是从Pod的字段获取它们的变量值。

用容器字段作为环境变量的值

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dapi-envars-resourcefieldref
spec:
  containers:
    - name: test-container
      image: k8s.gcr.io/busybox:1.24
      command: [ "sh", "-c"]
      args:
      - while true; do
          echo -en '\n';
          printenv MY_CPU_REQUEST MY_CPU_LIMIT;
          printenv MY_MEM_REQUEST MY_MEM_LIMIT;
          sleep 10;
        done;
      resources:
        requests:
          memory: "32Mi"
          cpu: "125m"
        limits:
          memory: "64Mi"
          cpu: "250m"
      env:
        - name: MY_CPU_REQUEST
          valueFrom:
            resourceFieldRef:
              containerName: test-container
              resource: requests.cpu
        - name: MY_CPU_LIMIT
          valueFrom:
            resourceFieldRef:
              containerName: test-container
              resource: limits.cpu
        - name: MY_MEM_REQUEST
          valueFrom:
            resourceFieldRef:
              containerName: test-container
              resource: requests.memory
        - name: MY_MEM_LIMIT
          valueFrom:
            resourceFieldRef:
              containerName: test-container
              resource: limits.memory
  restartPolicy: Never
```

这个配置文件中，你可以看到四个环境变量。env字段是一个EnvVars 类型的数组。数组中第一个元素指定MY_CPU_REQUEST这个环境变量从容器的requests.cpu字段获取变量值。同样，其它环境变量也是从容器的字段获取它们的变量值。
