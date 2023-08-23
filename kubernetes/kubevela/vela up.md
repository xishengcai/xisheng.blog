# 如何将一个 appfile 转为 Kubernetes 中的 Application

- 起点：appfile
- 终点：applicatioin
- 路径：appfile -> application (services -> component)
  - comp[workload, traits]

### 1. 起点：AppFile

```
// references/appfile/api/appfile.go
// AppFile defines the spec of KubeVela Appfile
type AppFile struct {
  Name       string             `json:"name"`
  CreateTime time.Time          `json:"createTime,omitempty"`
  UpdateTime time.Time          `json:"updateTime,omitempty"`
  Services   map[string]Service `json:"services"`
  Secrets    map[string]string  `json:"secrets,omitempty"`

  configGetter config.Store
  initialized  bool
}

// NewAppFile init an empty AppFile struct
func NewAppFile() *AppFile {
  return &AppFile{
    Services:     make(map[string]Service),
    Secrets:      make(map[string]string),
    configGetter: &config.Local{},
  }
}
// references/appfile/api/service.go
// Service defines the service spec for AppFile, it will contain all related information including OAM component, traits, source to image, etc...
type Service map[string]interface{}
```

上面两段代码是 AppFile 在客户端的声明，vela 会将指定路径的 yaml 文件读取后，赋值给一个 AppFile。

```
// references/appfile/api/appfile.go
// LoadFromFile will read the file and load the AppFile struct
func LoadFromFile(filename string) (*AppFile, error) {
  b, err := ioutil.ReadFile(filepath.Clean(filename))
  if err != nil {
    return nil, err
  }
  af := NewAppFile()
  // Add JSON format appfile support
  ext := filepath.Ext(filename)
  switch ext {
  case ".yaml", ".yml":
    err = yaml.Unmarshal(b, af)
  case ".json":
    af, err = JSONToYaml(b, af)
  default:
    if json.Valid(b) {
      af, err = JSONToYaml(b, af)
    } else {
      err = yaml.Unmarshal(b, af)
    }
  }
  if err != nil {
    return nil, err
  }
  return af, nil
}
```

下面为读取 vela.yaml 文件后，加载到 AppFile 中的数据：

```
# vela.yaml
name: test
services:
  nginx:
    type: webservice
    image: nginx
    env:
    - name: NAME
      value: kubevela

    # svc trait
    svc:
      type: NodePort
      ports:
      - port: 80
        nodePort: 32017
Name: test
CreateTime: 0001-01-01 00:00:00 +0000 UTC
UpdateTime: 0001-01-01 00:00:00 +0000 UTC
Services： map[
             nginx: map[
               env: [map[name: NAME value: kubevela]] 
               image: nginx 
               svc: map[ports: [map[nodePort: 32017 port: 80]] type: NodePort] 
               type: webservice
            ]
          ]
Secrets    map[]
configGetter: 0x447abd0 
initialized: false
```

### 2. 终点：application

```
// apis/core.oam.dev/application_types.go
type Application struct {
  metav1.TypeMeta   `json:",inline"`
  metav1.ObjectMeta `json:"metadata,omitempty"`

  Spec   ApplicationSpec `json:"spec,omitempty"`
  Status AppStatus       `json:"status,omitempty"`
}

// ApplicationSpec is the spec of Application
type ApplicationSpec struct {
  Components []ApplicationComponent `json:"components"`

  // TODO(wonderflow): we should have application level scopes supported here

  // RolloutPlan is the details on how to rollout the resources
  // The controller simply replace the old resources with the new one if there is no rollout plan involved
  // +optional
  RolloutPlan *v1alpha1.RolloutPlan `json:"rolloutPlan,omitempty"`
}
```

上面代码，为 Application 的声明，结合 .vela/deploy.yaml（见下面代码），可以看出，要将一个 AppFile 渲染为 Application 主要就是将 AppFile 的 Services 转化为 Application 的 Components。

```
# .vela/deploy.yaml
apiVersion: core.oam.dev/v1alpha2
kind: Application
metadata:
  creationTimestamp: null
  name: test
  namespace: default
spec:
  components:
  - name: nginx
    scopes:
      healthscopes.core.oam.dev: test-default-health
    settings:
      env:
      - name: NAME
        value: kubevela
      image: nginx
    traits:
    - name: svc
      properties:
        ports:
        - nodePort: 32017
          port: 80
        type: NodePort
    type: webservice
status: {}
```

### 3. 路径：Services -> Components

结合以上内容可以看出，将 Appfile 转化为 Application 主要是将 Services 渲染为 Components。

```
// references/appfile/api/appfile.go
// BuildOAMApplication renders Appfile into Application, Scopes and other K8s Resources.
func (app *AppFile) BuildOAMApplication(env *types.EnvMeta, io cmdutil.IOStreams, tm template.Manager, silence bool) (*v1alpha2.Application, []oam.Object, error) {
  ...
  servApp := new(v1alpha2.Application)
  servApp.SetNamespace(env.Namespace)
  servApp.SetName(app.Name)
  servApp.Spec.Components = []v1alpha2.ApplicationComponent{}
  for serviceName, svc := range app.GetServices() {
    ...
    // 完成 Service 到 Component 的转化
    comp, err := svc.RenderServiceToApplicationComponent(tm, serviceName)
    if err != nil {
      return nil, nil, err
    }
    servApp.Spec.Components = append(servApp.Spec.Components, comp)
  }
  servApp.SetGroupVersionKind(v1alpha2.SchemeGroupVersion.WithKind("Application"))
  auxiliaryObjects = append(auxiliaryObjects, addDefaultHealthScopeToApplication(servApp))
  return servApp, auxiliaryObjects, nil
}
```

上面的代码是 vela 将 Appfile 转化为 Application 代码实现的位置。其中 comp, err := svc.RenderServiceToApplicationComponent(tm, serviceName) 完成 Service 到 Component 的转化。

```
// references/appfile/api/service.go
// RenderServiceToApplicationComponent render all capabilities of a service to CUE values to KubeVela Application.
func (s Service) RenderServiceToApplicationComponent(tm template.Manager, serviceName string) (v1alpha2.ApplicationComponent, error) {

  // sort out configs by workload/trait
  workloadKeys := map[string]interface{}{}
  var traits []v1alpha2.ApplicationTrait

  wtype := s.GetType()
  comp := v1alpha2.ApplicationComponent{
    Name:         serviceName,
    WorkloadType: wtype,
  }

  for k, v := range s.GetApplicationConfig() {
    // 判断是否为 trait
    if tm.IsTrait(k) {
      trait := v1alpha2.ApplicationTrait{
        Name: k,
      }
      ....
      // 如果是 triat 加入 traits 中
      traits = append(traits, trait)
      continue
    }
    workloadKeys[k] = v
  }

  // Handle workloadKeys to settings
  settings := &runtime.RawExte nsion{}
  pt, err := json.Marshal(workloadKeys)
  if err != nil {
    return comp, err
  }
  if err := settings.UnmarshalJSON(pt); err != nil {
    return comp, err
  }
  comp.Settings = *settings

  if len(traits) > 0 {
    comp.Traits = traits
  }

  return comp, nil
}
```

### 4. 总结

执行 vela up 命令，渲染 appfile 为 Application，将数据写入到 .vela/deploy.yaml 中，并在 K8s 中创建。

![2.png](https://ucc.alicdn.com/pic/developer-ecology/37e6e8d84bfb43c98d3cc235b89bb9d1.png)



### 作者简介

樊大勇，华胜天成研发工程师，GitHub ID：@just-do1。

### 加入 OAM

- OAM 官网：

*[https://oam.dev](https://oam.dev/)*

- KubeVela GitHub 项目地址：

*https://github.com/oam-dev/kubevela*

- 社区交流钉群：

![5.png](https://ucc.alicdn.com/pic/developer-ecology/4973c80cc941457eadd83d104d1754d5.png)

link：

- [源码解读：KubeVela 是如何将 appfile 转换为 K8s 特定资源对象的](https://developer.aliyun.com/article/783169)

