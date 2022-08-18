# kubesphere helm repo 源码分析

<!--toc-->

## 背景介绍

### kubesphere 中的helm 仓库功能

- kubesphere helm 仓库添加
  ![image-20210623134118349](https://tva1.sinaimg.cn/large/008i3skNly1grs5bcmzv6j31lf0u0k0h.jpg)
  
- helm repo list
  ![image-20210623134053555](https://tva1.sinaimg.cn/large/008i3skNly1grs5b08mdoj31s00u0ajs.jpg)

- kubesphere helm 仓库中的应用模版查询

  ![image-20210623134213510](https://tva1.sinaimg.cn/large/008i3skNly1grs5cav76dj61hj0u0h3702.jpg)



### helm 仓库简介

helm charts是存放k8s 应用模版的仓库，该仓库由index.yaml 文件和 .tgz模版包组成

```bash
[root@ningbo stable]# ls -al 
总用量 400
drwxr-xr-x. 26 root root   4096 6月  22 17:01 .
drwxr-xr-x.  4 root root     86 6月  22 16:37 ..
-rw-r--r--.  1 root root  10114 6月  22 17:12 index.yaml
-rw-r--r--.  1 root root   3803 6月   8 2020 lsh-cluster-csm-om-agent-0.1.0.tgz
-rw-r--r--.  1 root root   4022 6月   8 2020 lsh-mcp-cc-alert-service-0.1.0.tgz
-rw-r--r--.  1 root root   4340 6月   8 2020 lsh-mcp-cc-sms-service-0.1.0.tgz
-rw-r--r--.  1 root root   4103 6月   8 2020 lsh-mcp-cpm-metrics-exchange-0.1.0.tgz
-rw-r--r--.  1 root root   4263 6月   8 2020 lsh-mcp-cpm-om-service-0.1.0.tgz
-rw-r--r--.  1 root root   4155 6月   8 2020 lsh-mcp-csm-om-service-0.1.0.tgz
-rw-r--r--.  1 root root   3541 6月   8 2020 lsh-mcp-deploy-service-0.1.0.tgz
-rw-r--r--.  1 root root   5549 6月   8 2020 lsh-mcp-iam-apigateway-service-0.1.0.tgz
```



- **index.yaml 文件**

```
apiVersion: v1
entries:
  aliyun-ccm:
  - apiVersion: v2
    appVersion: addon
    created: "2021-06-21T08:59:58Z"
    description: A Helm chart for Kubernetes
    digest: 6bda563c86333475255e5edfedc200ae282544e2c6e22b519a59b3c7bdef9a32
    name: aliyun-ccm
    type: application
    urls:
    - charts/aliyun-ccm-0.1.0.tgz
    version: 0.1.0
  aliyun-csi-driver:
  - apiVersion: v2
    appVersion: addon
    created: "2021-06-21T08:59:58Z"
    description: A Helm chart for Kubernetes
    digest: b49f128d7a49401d52173e6f58caedd3fabbe8e2827dc00e6a824ee38860fa51
    name: aliyun-csi-driver
    type: application
    urls:
    - charts/aliyun-csi-driver-0.1.0.tgz
    version: 0.1.0
  application-controller:
  - apiVersion: v1
    appVersion: addon
    created: "2021-06-21T08:59:58Z"
    description: A Helm chart for application Controller
    digest: 546e72ce77f865683ce0ea75f6e0203537a40744f2eb34e36a5bd378f9452bc5
    name: application-controller
    urls:
    - charts/application-controller-0.1.0.tgz
    version: 0.1.0
```



- **tgz 解压缩后的文件目录**

```bash
[root@ningbo stable]# cd mysql/
[root@ningbo mysql]# ls -al
总用量 20
drwxr-xr-x.  3 root root   97 5月  25 2020 .
drwxr-xr-x. 26 root root 4096 6月  22 17:01 ..
-rwxr-xr-x.  1 root root  106 5月  25 2020 Chart.yaml
-rwxr-xr-x.  1 root root  364 5月  25 2020 .helmignore
-rwxr-xr-x.  1 root root   76 5月  25 2020 index.yaml
drwxr-xr-x.  3 root root  146 5月  25 2020 templates
-rwxr-xr-x.  1 root root 1735 5月  25 2020 values.yaml
```


- **Chart.yaml**

```
[root@ningbo mysql]# cat Chart.yaml 
apiVersion: v1
appVersion: "1.0"
description: A Helm chart for Kubernetes
name: mysql
version: 0.1.0
```



## 添加helm 仓库代码介绍

### 接口实现分析

1. 路由注册
2. handler：校验参数， 构建 models
3. models ： 调用createRepo方法
4. crd client： 调用k8s api, 创建 crd HelmRepo

- [路由注册](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/kapis/openpitrix/v1/register.go#L47)

```go
	webservice.Route(webservice.POST("/repos").
		To(handler.CreateRepo). // 跟进
		Doc("Create a global repository, which is used to store package of app").
		Metadata(restfulspec.KeyOpenAPITags, []string{constants.OpenpitrixTag}).
		Param(webservice.QueryParameter("validate", "Validate repository")).
		Returns(http.StatusOK, api.StatusOK, openpitrix.CreateRepoResponse{}).
		Reads(openpitrix.CreateRepoRequest{}))
```



- [校验参数， 构建 models](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/kapis/openpitrix/v1/handler.go#L66:29)

```go
func (h *openpitrixHandler) CreateRepo(req *restful.Request, resp *restful.Response) {

	createRepoRequest := &openpitrix.CreateRepoRequest{}
	err := req.ReadEntity(createRepoRequest)
	if err != nil {
		klog.V(4).Infoln(err)
		api.HandleBadRequest(resp, nil, err)
		return
	}

	createRepoRequest.Workspace = new(string)
	*createRepoRequest.Workspace = req.PathParameter("workspace")

	user, _ := request.UserFrom(req.Request.Context())
	creator := ""
	if user != nil {
		creator = user.GetName()
	}
	parsedUrl, err := url.Parse(createRepoRequest.URL)
	if err != nil {
		api.HandleBadRequest(resp, nil, err)
		return
	}
	userInfo := parsedUrl.User
	// trim credential from url
	parsedUrl.User = nil

	repo := v1alpha1.HelmRepo{
		ObjectMeta: metav1.ObjectMeta{
			Name: idutils.GetUuid36(v1alpha1.HelmRepoIdPrefix),
			Annotations: map[string]string{
				constants.CreatorAnnotationKey: creator,
			},
			Labels: map[string]string{
				constants.WorkspaceLabelKey: *createRepoRequest.Workspace,
			},
		},
		Spec: v1alpha1.HelmRepoSpec{
			Name:        createRepoRequest.Name,
			Url:         parsedUrl.String(),
			SyncPeriod:  0,
			Description: stringutils.ShortenString(createRepoRequest.Description, 512),
		},
	}

	if strings.HasPrefix(createRepoRequest.URL, "https://") || strings.HasPrefix(createRepoRequest.URL, "http://") {
		if userInfo != nil {
			repo.Spec.Credential.Username = userInfo.Username()
			repo.Spec.Credential.Password, _ = userInfo.Password()
		}
	} else if strings.HasPrefix(createRepoRequest.URL, "s3://") {
		cfg := v1alpha1.S3Config{}
		err := json.Unmarshal([]byte(createRepoRequest.Credential), &cfg)
		if err != nil {
			api.HandleBadRequest(resp, nil, err)
			return
		}
		repo.Spec.Credential.S3Config = cfg
	}

	var result interface{}
	// 1. validate repo
	result, err = h.openpitrix.ValidateRepo(createRepoRequest.URL, &repo.Spec.Credential)
	if err != nil {
		klog.Errorf("validate repo failed, err: %s", err)
		api.HandleBadRequest(resp, nil, err)
		return
	}

	// 2. create repo
	validate, _ := strconv.ParseBool(req.QueryParameter("validate"))
	if !validate {
		if repo.GetTrueName() == "" {
			api.HandleBadRequest(resp, nil, fmt.Errorf("repo name is empty"))
			return
		}
		result, err = h.openpitrix.CreateRepo(&repo) // 👇
	}

	if err != nil {
		klog.Errorln(err)
		handleOpenpitrixError(resp, err)
		return
	}

	resp.WriteEntity(result)
}
```



- [调用createRepo方法](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/models/openpitrix/repos.go#L113)

```go
func (c *repoOperator) CreateRepo(repo *v1alpha1.HelmRepo) (*CreateRepoResponse, error) {
	name := repo.GetTrueName()

	items, err := c.repoLister.List(labels.SelectorFromSet(map[string]string{constants.WorkspaceLabelKey: repo.GetWorkspace()}))
	if err != nil && !apierrors.IsNotFound(err) {
		klog.Errorf("list helm repo failed: %s", err)
		return nil, err
	}

	for _, exists := range items {
		if exists.GetTrueName() == name {
			klog.Error(repoItemExists, "name: ", name)
			return nil, repoItemExists
		}
	}

	repo.Spec.Description = stringutils.ShortenString(repo.Spec.Description, DescriptionLen)
	_, err = c.repoClient.HelmRepos().Create(context.TODO(), repo, metav1.CreateOptions{}) //  👇
	if err != nil {
		klog.Errorf("create helm repo failed, repo_id: %s, error: %s", repo.GetHelmRepoId(), err)
		return nil, err
	} else {
		klog.V(4).Infof("create helm repo success, repo_id: %s", repo.GetHelmRepoId())
	}

	return &CreateRepoResponse{repo.GetHelmRepoId()}, nil
}
```



- [调用k8s api, 创建 crd HelmRepo](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/client/clientset/versioned/typed/application/v1alpha1/helmrepo.go#L108)

```
// Create takes the representation of a helmRepo and creates it.  Returns the server's representation of the helmRepo, and an error, if there is any.
func (c *helmRepos) Create(ctx context.Context, helmRepo *v1alpha1.HelmRepo, opts v1.CreateOptions) (result *v1alpha1.HelmRepo, err error) {
	result = &v1alpha1.HelmRepo{}
	err = c.client.Post().
		Resource("helmrepos").
		VersionedParams(&opts, scheme.ParameterCodec).
		Body(helmRepo).
		Do(ctx).
		Into(result)
	return
}

```



## 查询helm 仓库应用模版代码介绍

### 接口实现

1. 路由注册
2. handler，参数解析，调用models 方面
3. models ， 调用models 方法
4. crd client， 调用k8s api 存储



- [路由注册](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/kapis/openpitrix/v1/register.go#L211)

```go
	webservice.Route(webservice.GET("/apps").LiHui, 6 months ago: • openpitrix crd
		Deprecate().
		To(handler.ListApps).  // 跟进
		Doc("List app templates").
		Param(webservice.QueryParameter(params.ConditionsParam, "query conditions,connect multiple conditions with commas, equal symbol for exact query, wave symbol for fuzzy query e.g. name~a").
			Required(false).
			DataFormat("key=%s,key~%s")).
		Param(webservice.QueryParameter(params.PagingParam, "paging query, e.g. limit=100,page=1").
			Required(false).
			DataFormat("limit=%d,page=%d").
			DefaultValue("limit=10,page=1")).
		Param(webservice.QueryParameter(params.ReverseParam, "sort parameters, e.g. reverse=true")).
		Param(webservice.QueryParameter(params.OrderByParam, "sort parameters, e.g. orderBy=createTime")).
		Metadata(restfulspec.KeyOpenAPITags, []string{constants.OpenpitrixTag}).
		Returns(http.StatusOK, api.StatusOK, models.PageableResponse{}))
```



- [参数解析，调用models 方面](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/kapis/openpitrix/v1/handler.go#L398:29)

```go
func (h *openpitrixHandler) ListApps(req *restful.Request, resp *restful.Response)
	limit, offset := params.ParsePaging(req)
	orderBy := params.GetStringValueWithDefault(req, params.OrderByParam, openpitrix.CreateTime)
	reverse := params.GetBoolValueWithDefault(req, params.ReverseParam, false)
	conditions, err := params.ParseConditions(req)

	if err != nil {
		klog.V(4).Infoln(err)
		api.HandleBadRequest(resp, nil, err)
		return
	}

	if req.PathParameter("workspace") != "" {
		conditions.Match[openpitrix.WorkspaceLabel] = req.PathParameter("workspace")
	}

	result, err := h.openpitrix.ListApps(conditions, orderBy, reverse, limit, offset)  //  👇

	if err != nil {
		klog.Errorln(err)
		handleOpenpitrixError(resp, err)
		return
	}

	resp.WriteEntity(result)
}
```



- [从缓存中获取applist](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/models/openpitrix/applications.go#L299)

```go
func (c *applicationOperator) ListApps(conditions *params.Conditions, orderBy string, reverse bool, limit, offset int) (*models.PageableResponse, error) {

	apps, err := c.listApps(conditions)  //  👇
	if err != nil {
		klog.Error(err)
		return nil, err
	}
	apps = filterApps(apps, conditions)

	if reverse {
		sort.Sort(sort.Reverse(HelmApplicationList(apps)))
	} else {
		sort.Sort(HelmApplicationList(apps))
	}

	totalCount := len(apps)
	start, end := (&query.Pagination{Limit: limit, Offset: offset}).GetValidPagination(totalCount)
	apps = apps[start:end]
	items := make([]interface{}, 0, len(apps))

	for i := range apps {
		versions, err := c.getAppVersionsByAppId(apps[i].GetHelmApplicationId())
		if err != nil && !apierrors.IsNotFound(err) {
			return nil, err
		}
		ctg, _ := c.ctgLister.Get(apps[i].GetHelmCategoryId())
		items = append(items, convertApp(apps[i], versions, ctg, 0))
	}
	return &models.PageableResponse{Items: items, TotalCount: totalCount}, nil
}

// line 601
func (c *applicationOperator) listApps(conditions *params.Conditions) (ret []*v1alpha1.HelmApplication, err error) {
	repoId := conditions.Match[RepoId]
	if repoId != "" && repoId != v1alpha1.AppStoreRepoId {
		// get helm application from helm repo
		if ret, exists := c.cachedRepos.ListApplicationsByRepoId(repoId); !exists {
			klog.Warningf("load repo failed, repo id: %s", repoId)
			return nil, loadRepoInfoFailed
		} else {
			return ret, nil
		}
	} else {
		if c.backingStoreClient == nil {
			return []*v1alpha1.HelmApplication{}, nil
		}
		ret, err = c.appLister.List(labels.SelectorFromSet(buildLabelSelector(conditions)))
	}

	return
}
```



- [缓存具体获取应用逻辑](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/utils/reposcache/repo_cahes.go#L265)

```go
func (c *cachedRepos) ListApplicationsByRepoId(repoId string) (ret []*v1alpha1.HelmApplication, exists bool) {
	c.RLock()
	defer c.RUnlock()

	if repo, exists := c.repos[repoId]; !exists {
		return nil, false
	} else {
		ret = make([]*v1alpha1.HelmApplication, 0, 10)
		for _, app := range c.apps {
			if app.GetHelmRepoId() == repo.Name { // 应用的仓库ID相同则追加
				ret = append(ret, app)
			}
		}
	}
	return ret, true
}
```



> 既然app template 是从缓存中获取的，那么缓存中的数据又是什么时候录入的呢？

1. 创建全局缓存变量
2. 添加新helm仓库，k8s中已安装crd控制器helmRepoController 发现有新的helmRepo 创建，更新.Status.Data内容
3. informer 发现有更新，同时更新缓存



## 缓存更新的实现

1. 创建全局变量，通过init函数初始化

2. 通过helmRepo的informer实现缓存同步更新

3. 在每次调用接口的时候，hanlder 类中包换了缓存变量

   

- [创建接口类openpitrix.Interface](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/kapis/openpitrix/v1/handler.go#L51)

```go
type openpitrixHandler struct {
	openpitrix openpitrix.Interface
}

func newOpenpitrixHandler(ksInformers informers.InformerFactory, ksClient versioned.Interface, option *openpitrixoptions.Options) *openpitrixHandler {
	var s3Client s3.Interface
	if option != nil && option.S3Options != nil && len(option.S3Options.Endpoint) != 0 {
		var err error
		s3Client, err = s3.NewS3Client(option.S3Options)
		if err != nil {
			klog.Errorf("failed to connect to storage, please check storage service status, error: %v", err)
		}
	}

	return &openpitrixHandler{
		openpitrix.NewOpenpitrixOperator(ksInformers, ksClient, s3Client),
	}
}
```



[NewOpenpitrixOperator](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/models/openpitrix/interface.go#L58:6)

- 通过在informer中添加通知函数，执行缓存更新
- once.Do 只执行一次

```go
var cachedReposData reposcache.ReposCache
var helmReposInformer cache.SharedIndexInformer
var once sync.Once


func init() {
	cachedReposData = reposcache.NewReposCache() // 全局缓存
}

func NewOpenpitrixOperator(ksInformers ks_informers.InformerFactory, ksClient versioned.Interface, s3Client s3.Interface) Interface {

	once.Do(func() {
		klog.Infof("start helm repo informer")
		helmReposInformer = ksInformers.KubeSphereSharedInformerFactory().Application().V1alpha1().HelmRepos().Informer()
		helmReposInformer.AddEventHandler(cache.ResourceEventHandlerFuncs{
			AddFunc: func(obj interface{}) {
				r := obj.(*v1alpha1.HelmRepo)
				cachedReposData.AddRepo(r) // 缓存更新，  👇
			},
			UpdateFunc: func(oldObj, newObj interface{}) {
				oldR := oldObj.(*v1alpha1.HelmRepo)
				cachedReposData.DeleteRepo(oldR)
				r := newObj.(*v1alpha1.HelmRepo)
				cachedReposData.AddRepo(r)
			},
			DeleteFunc: func(obj interface{}) {
				r := obj.(*v1alpha1.HelmRepo)
				cachedReposData.DeleteRepo(r)
			},
		})
		go helmReposInformer.Run(wait.NeverStop)
	})

	return &openpitrixOperator{
		AttachmentInterface:  newAttachmentOperator(s3Client),
    // cachedReposData used
		ApplicationInterface: newApplicationOperator(cachedReposData, ksInformers.KubeSphereSharedInformerFactory(), ksClient, s3Client),
    // cachedReposData used
		RepoInterface:        newRepoOperator(cachedReposData, ksInformers.KubeSphereSharedInformerFactory(), ksClient),
    // cachedReposData used
		ReleaseInterface:     newReleaseOperator(cachedReposData, ksInformers.KubernetesSharedInformerFactory(), ksInformers.KubeSphereSharedInformerFactory(), ksClient),
		CategoryInterface:    newCategoryOperator(ksInformers.KubeSphereSharedInformerFactory(), ksClient),
	}
}
```



[缓存更新逻辑](https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/utils/reposcache/repo_cahes.go#L120)

```go
// 缓存结构体
type cachedRepos struct {
	sync.RWMutex

	chartsInRepo  map[workspace]map[string]int
	repoCtgCounts map[string]map[string]int

	repos    map[string]*v1alpha1.HelmRepo
	apps     map[string]*v1alpha1.HelmApplication
	versions map[string]*v1alpha1.HelmApplicationVersion
}
```



- ByteArrayToSavedIndex： 将repo.Status.Data 转换为SavedIndex数组对象
- 遍历 SavedIndex.Applications
- 保存（app.ApplicationId：HelmApplication）到 cachedRepos.apps

```go

func (c *cachedRepos) AddRepo(repo *v1alpha1.HelmRepo) error {
	return c.addRepo(repo, false)
}

//Add new Repo to cachedRepos
func (c *cachedRepos) addRepo(repo *v1alpha1.HelmRepo, builtin bool) error {
	if len(repo.Status.Data) == 0 {
		return nil
	}
	index, err := helmrepoindex.ByteArrayToSavedIndex([]byte(repo.Status.Data))
	if err != nil {
		klog.Errorf("json unmarshal repo %s failed, error: %s", repo.Name, err)
		return err
	}
	...

	chartsCount := 0
	for key, app := range index.Applications {
		if builtin {
			appName = v1alpha1.HelmApplicationIdPrefix + app.Name
		} else {
			appName = app.ApplicationId
		}

		HelmApp := v1alpha1.HelmApplication{
		....
		}
		c.apps[app.ApplicationId] = &HelmApp

		var ctg, appVerName string
		var chartData []byte
		for _, ver := range app.Charts {
			chartsCount += 1
			if ver.Annotations != nil && ver.Annotations["category"] != "" {
				ctg = ver.Annotations["category"]
			}
			if builtin {
				appVerName = base64.StdEncoding.EncodeToString([]byte(ver.Name + ver.Version))
				chartData, err = loadBuiltinChartData(ver.Name, ver.Version)
				if err != nil {
					return err
				}
			} else {
				appVerName = ver.ApplicationVersionId
			}

			version := &v1alpha1.HelmApplicationVersion{
			....
			}
			c.versions[ver.ApplicationVersionId] = version
		}
		....
	}
	return nil
}
```



## helmRepo 协调器

### HelmRepo.Status.Data 加载流程

1. LoadRepoIndex:  convert index.yaml to IndexFile

2. MergeRepoIndex: merge new and old IndexFile

3. savedIndex.Bytes():  compress data with zlib.NewWriter

4. 将savedIndex 数据存入 CRD（helmRepo.Status.Data) 

   

   关键结构体

   ```go
   // helmRepo.Status.Data == SavedIndex 压缩后的数据
   type SavedIndex struct {
   	APIVersion   string                  `json:"apiVersion"`
   	Generated    time.Time               `json:"generated"`
   	Applications map[string]*Application `json:"apps"`
   	PublicKeys   []string                `json:"publicKeys,omitempty"`
   
   	// Annotations are additional mappings uninterpreted by Helm. They are made available for
   	// other applications to add information to the index file.
   	Annotations map[string]string `json:"annotations,omitempty"`
   }
   
   // IndexFile represents the index file in a chart repository
   type IndexFile struct {
   	APIVersion string                   `json:"apiVersion"`
   	Generated  time.Time                `json:"generated"`
   	Entries    map[string]ChartVersions `json:"entries"`
   	PublicKeys []string                 `json:"publicKeys,omitempty"`
   }
   ```
   
   [代码位置]( https://github.com/kubesphere/kubesphere/blob/d4be6d704ab1356d79d0fd677aa13915ad3a73e4/pkg/controller/openpitrix/helmrepo/helm_repo_controller.go#L291)
   
   ```go
   func (r *ReconcileHelmRepo) syncRepo(instance *v1alpha1.HelmRepo) error {
   	// 1. load index from helm repo
   	index, err := helmrepoindex.LoadRepoIndex(context.TODO(), instance.Spec.Url, &instance.Spec.Credential)
   
   	if err != nil {
   		klog.Errorf("load index failed, repo: %s, url: %s, err: %s", instance.GetTrueName(), instance.Spec.Url, err)
   		return err
   	}
   
   	existsSavedIndex := &helmrepoindex.SavedIndex{}
   	if len(instance.Status.Data) != 0 {
   		existsSavedIndex, err = helmrepoindex.ByteArrayToSavedIndex([]byte(instance.Status.Data))
   		if err != nil {
   			klog.Errorf("json unmarshal failed, repo: %s,  error: %s", instance.GetTrueName(), err)
   			return err
   		}
   	}
   
   	// 2. merge new index with old index which is stored in crd
   	savedIndex := helmrepoindex.MergeRepoIndex(index, existsSavedIndex)
   
   	// 3. save index in crd
   	data, err := savedIndex.Bytes()
   	if err != nil {
   		klog.Errorf("json marshal failed, error: %s", err)
   		return err
   	}
   
   	instance.Status.Data = string(data)
   	return nil
   }
   
   ```



## Question:

**Q1**：helm 仓库发包时如何进行helm release 版本控制

A：修改Charts.yaml 中的字段 version，然后helm package， 等于新增一个tgz包，老版本的不要删除，这时候执行index 的时候会吧所有的tgz包包含在内。

```bash
  $ helm repo index stable --url=xxx.xx.xx.xxx:8081/
  $ cat index.yaml
  ....
  redis:
  - apiVersion: v1
    appVersion: "1.0"
    created: "2021-06-22T16:34:58.286583012+08:00"
    description: A Helm chart for Kubernetes
    digest: fd7c0d962155330527c0a512a74bea33302fca940b810c43ee5f461b1013dbf5
    name: redis
    urls:
    - xxx.xx.xx.xxx:8081/redis-0.1.1.tgz
    version: 0.1.1
  - apiVersion: v1
    appVersion: "1.0"
    created: "2021-06-22T16:34:58.286109049+08:00"
    description: A Helm chart for Kubernetes
    digest: 1a23bd6d5e45f9d323500bbe170011fb23bfccf2c1bd25814827eb8dc643d7f0
    name: redis
    urls:
    - xxx.xx.xx.xxx:8081/redis-0.1.0.tgz
    version: 0.1.0
```



**Q2**：kubersphere版本同步功能有缺失？用户添加完helm 仓库后，如果有新的应用发布，查询不到

A：解决方案：使用3种同步策略

- 定时同步helm仓库（helmRepo 设置一个定时协调的事件）
- 企业仓库，用户可以设置hook，发布新版本的时候主动触发更新
- 用户主动更新charts；



**Q3**：index.yaml 缓存位置

A：某些仓库的index.yaml 比较大，如果1000个用户，1000个charts 会太吃内存。建议常用index.yaml的放在内存中，不常用的index.yaml存储在本地磁盘。