# volumeTrait design

[toc]

## target

1. oam ContainerizedWorkload child resource 支持 动态工作负载，原先只支持deployment，现在 是在第一次初始化的工作负载的时候，发现如果添加了 volume
   trait，则更改工作负载为statefulSet，否则默认是deployment。

2. 用户填写信息

- 存储类名称

- 存储大小

- 容器内挂载路径

  

主机目录生成规则： 

- 方式一： 用户自己填写主机全目录

- 方式二： 用户指定主机目录前缀+自动生成后缀目录



后缀目录自动生成规则： {namespace}{component-name}/{containerName-mountDirectoryIndex}





## storageClass

用户填写storageClass名称和容器挂载路径即可，oam负责创建pvc， 回收pvc。



## hostPath

卷能将主机节点文件系统上的文件或目录挂载到你的 Pod 中。 虽然这不是大多数 Pod 需要的，但是它为一些应用程序提供了强大的逃生舱。

具有相同配置（例如基于同一 PodTemplate 创建）的多个 Pod 会由于节点上文件的不同 而在不同节点上有不同的行为。

下层主机上创建的文件或目录只能由 root 用户写入。你需要在 特权容器 中以 root 身份运行进程，或者修改主机上的文件权限以便容器能够写入 hostPath 卷。

hostPath 有两个参数， 主机路径和文件类型

|type |有如下类型|
|--------|--------|
|DirectoryOrCreate|    如果在给定路径上什么都不存在，那么将根据需要创建空目录，权限设置为 0755，具有与 kubelet 相同的组和属主信息。|
|Directory|    在给定路径上必须存在的目录。|
|FileOrCreate|    如果在给定路径上什么都不存在，那么将在那里根据需要创建空文件，权限设置为 0644，具有与 kubelet 相同的组和所有权。|
|File    |在给定路径上必须存在的文件。|
|Socket|    在给定路径上必须存在的 UNIX 套接字。|
|CharDevice    |在给定路径上必须存在的字符设备。|
|BlockDevice    |在给定路径上必须存在的块设备。|

Example:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pd
spec:
  containers:
  - image: k8s.gcr.io/test-webserver
    name: test-container
    volumeMounts:
    - mountPath: /test-pd
      name: test-volume
  volumes:
  - name: test-volume
    hostPath:
      # 宿主上目录位置
      path: /data
      # 此字段为可选
      type: Directory
# 注意： FileOrCreate 模式不会负责创建文件的父目录。 如果欲挂载的文件的父目录不存在，Pod 启动会失败。 为了确保这种模式能够工作，可以尝试把文件和它对应的目录分开挂载，如 FileOrCreate 配置 所示。
```



## struct define

```go
type VolumeTrait struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   VolumeTraitSpec   `json:"spec,omitempty"`
	Status VolumeTraitStatus `json:"status,omitempty"`
}

// A VolumeTraitSpec defines the desired state of a VolumeTrait.
type VolumeTraitSpec struct {
	VolumeList []VolumeMountItem `json:"volumeList"`
	// WorkloadReference to the workload this trait applies to.
	WorkloadReference runtimev1alpha1.TypedReference `json:"workloadRef"`
}

type VolumeMountItem struct {
	ContainerIndex int        `json:"containerIndex"`
	Paths          []PathItem `json:"paths"`
}

type PathItem struct {
	StorageClassName string             `json:"storageClassName"`
	HostPath         string             `json:"hostPath"`
	Size             string             `json:"size"`
	Path             string             `json:"path"`
}
```



## 3. 实现逻辑

1. appConfig 

​		apply workload

2. container workload

   根据 type 创建deployment or statefulset
2. volumeTrait
- fetchWorkloadChildResources by traits 
- create pvc by storageClassName and size 
- patch Volumes and VolumeMount



### 4.volume 挂载场景

**创建场景：**

4.1 单容器挂载

4.2 多容器挂载

4.3 Deployment 单容器挂载storageClass

4.3 Statefulset 单容器挂载StorageClass

4.4 Deployment 单容器挂载 hostPath

4.5 Statefulset 单容器挂载hostPath

4.6 Deployment 单容器挂载storageClass and ConfigMap

4.7 Statefulset 单容器挂载storageClass and ConfigMap



无状态的 存储挂载是通过pvc

有状态的 所有的挂载都只能是volumeTemplate



Deployment 目录挂载逻辑 

volumeMount

	1. 遍历目录，生成 Volumes
	1. 合并comfigMap

volumes

1. 遍历目录，生产volumes
2. 合并ConfigMap



StatefulSet 目录挂载逻辑

volumeMount

 	1. 遍历目录，生成 Volumes
 	2. 合并comfigMap
 	3. 合并statefulset





## 5. 注意事项

1. nfs,nas 大小无法限制
2. pvc 创建后不能修改大小
3. VolumeTrait 只支持重建，不支持修改
   



## pvc create

### 支持 storage class updat
1. get pvc

   

2. 比较pvc. storage class
   no delete old
   create new pvc
   
   new pvc uid list
   
   
   
3. gc
   compare pvcUid && volumeTrait status resource  pvc
   if pvc.uid not in pvcUid
        delete
