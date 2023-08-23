# vela-helm



项目 helm operator 通过crd：HelmRelease 声明期望的chart 发行版本，完成helm 的CRUD。

KubeVela 集成helm 模版，负载创建helm crd对象

![](https://github.com/fluxcd/helm-operator/raw/master/docs/_files/fluxcd-helm-operator-diagram.png)



## 1.New chart-component

**Workload**

```yaml
apiVersion: core.oam.dev/v1beta1
kind: WorkloadDefinition
metadata:
  name: webapp-chart
  annotations:
    definition.oam.dev/description: helm chart for webapp
spec:
  definitionRef:
    name: deployments.apps
    version: v1
```



**Component**

```yaml
apiVersion: core.oam.dev/v1beta1
kind: ComponentDefinition
metadata:
  name: webapp-chart
  namespace: vela-system
  annotations:
    definition.oam.dev/description: helm chart for webapp
spec:
  workload:
    definition:
      apiVersion: apps/v1
      kind: Deployment
  schematic:
    helm:
      release:
        chart:
          spec:
            chart: "podinfo"
            version: "5.1.4"
      repository:
        url: "http://oam.dev/catalog/"
```



​	by cue define,

​		template is helmRelease

​		argument is helm value

## 2.application controller

**业务逻辑**：

- 获取application

- Generate AppFile

- 将application 渲染为 ApplicationConfiguration 和 Component

- appHandler apply ac && component

  - ac   get component
  - ac render component to wrokload， trait
  - Workloads  apply  
  - traits apply
  
- appHandler apply helm repo && release

  

**关键代码**

​	application Controller

​			convert app Application to Appfile

​						？ why use appFile

​						？ why wd in appFile,  old oam use component convert to wd

​						call Appfile function： GenerateApplicationConfiguration

​							   generate cueModule by wd

​									call function **baseGenerateComponent(pCtx, wl, appName, ns)**

​											comp, acComp, err = evalWorkloadWithContext(pCtx, wl, ns, appName, wl.Name)



​    需要修改的关键逻辑：

1. **compoent 抽象结构修改**

   通过组合抽象来拓宽抽象能力
   
   ```
   // A ComponentSpec defines the desired state of a Component.
   type ComponentSpec struct {
   	// A Workload that will be created for each ApplicationConfiguration that
   	// includes this Component. Workload is an instance of a workloadDefinition.
   	// We either use the GVK info or a special "type" field in the workload to associate
   	// the content of the workload with its workloadDefinition
   	// +kubebuilder:validation:EmbeddedResource
   	// +kubebuilder:pruning:PreserveUnknownFields
   	Workload runtime.RawExtension `json:"workload"`
   
   	// HelmRelease records a Helm release used by a Helm module workload.
   	// +optional
   	Helm *common.Helm `json:"helm,omitempty"`
   
   	// Parameters exposed by this component. ApplicationConfigurations that
   	// reference this component may specify values for these parameters, which
   	// will in turn be injected into the embedded workload.
   	// +optional
   	Parameters []ComponentParameter `json:"parameters,omitempty"`
   }
   ```
   
   



2. **helm 结构体定义**

   ```
   // A Helm represents resources used by a Helm module
   type Helm struct {
   	// Release records a Helm release used by a Helm module workload.
   	// +kubebuilder:pruning:PreserveUnknownFields
   	Release runtime.RawExtension `json:"release"`
   
   	// HelmRelease records a Helm repository used by a Helm module workload.
   	// +kubebuilder:pruning:PreserveUnknownFields
   	Repository runtime.RawExtension `json:"repository"`
   }
   ```

    

3. **协调器： application， 主要完成以下任务**

   1. get appconfig
   2. appConfig ----->  appFile
   3. appFile  ----> applicationConfiguration and components
   4. apply applicationConfiguration and components

   改协调器在

   ```go
   // Reconcile process app event
   func (r *Reconciler) Reconcile(req ctrl.Request) (ctrl.Result, error) {
    ...
     // line 76，获取application
    	app := new(v1beta1.Application)
   	if err := r.Get(ctx, client.ObjectKey{
   		Name:      req.Name,
   		Namespace: req.Namespace,
   	}, app); err != nil {
   		if kerrors.IsNotFound(err) {
   			err = nil
   		}
   		return ctrl.Result{}, err
   	}
    ....
    // line 122, 通过Application 生成Appfile
    	ctx = oamutil.SetNamespaceInCtx(ctx, app.Namespace)
   	generatedAppfile, err := appParser.GenerateAppFile(ctx, app)
   	if err != nil {
   		applog.Error(err, "[Handle Parse]")
   		app.Status.SetConditions(errorCondition("Parsed", err))
   		r.Recorder.Event(app, event.Warning(velatypes.ReasonFailedParse, err))
   		return handler.handleErr(err)
   	}
   	
   	
   	// line 146, 通过Appfile 生成 ac， comps
   	// build template to applicationconfig & component
   	ac, comps, err := generatedAppfile.GenerateApplicationConfiguration()
     ...
     
     
     // line 168， 创建ac， comps
   	if err := handler.apply(ctx, appRev, ac, comps); err != nil {
   		applog.Error(err, "[Handle apply]")
   		app.Status.SetConditions(errorCondition("Applied", err))
   		r.Recorder.Event(app, event.Warning(velatypes.ReasonFailedApply, err))
   		return handler.handleErr(err)
   	}
   }
   ```

   

4. **函数 GenerateApplicationConfiguration 实现**

   根据不同的category 转换成不同的组件对象

   ```go
   // GenerateApplicationConfiguration converts an appFile to applicationConfig & Components
   func (af *Appfile) GenerateApplicationConfiguration() (*v1alpha2.ApplicationConfiguration,
   	....
   
   	var components []*v1alpha2.Component
   	for _, wl := range af.Workloads {
   		....
   		switch wl.CapabilityCategory {
   		case types.HelmCategory:
         // line 196
   			comp, acComp, err = generateComponentFromHelmModule(wl, af.Name, af.RevisionName, af.Namespace)
   			...
   		case types.KubeCategory:
   		...
   		case types.TerraformCategory:
   		...
   		default:
   		....
   		}
   		components = append(components, comp)
   		appconfig.Spec.Components = append(appconfig.Spec.Components, *acComp)
   	}
   	return appconfig, components, nil
   }
   ```

   

5. **函数 generateComponentFromHelmModule 实现**

   ```go
   func generateComponentFromHelmModule(wl *Workload, appName, revision, ns string) (*v1alpha2.Component, *v1alpha2.ApplicationConfigurationComponent, error) {
   	...
   	// re-use the way CUE module generates comp & acComp
   	comp, acComp, err := generateComponentFromCUEModule(wl, appName, revision, ns)
   	if err != nil {
   		return nil, nil, err
   	}
   
   	release, repo, err := helm.RenderHelmReleaseAndHelmRepo(wl.FullTemplate.Helm, wl.Name, appName, ns, wl.Params)
   	...
   	rlsBytes, err := json.Marshal(release.Object)
   	...
   	repoBytes, err := json.Marshal(repo.Object)
   	...
   	comp.Spec.Helm = &common.Helm{
   		Release:    runtime.RawExtension{Raw: rlsBytes},
   		Repository: runtime.RawExtension{Raw: repoBytes},
   	}
   	return comp, acComp, nil
   }
   ```

6. **函数generateComponentFromCUEModule 实现**

   ```go
   func generateComponentFromCUEModule(wl *Workload, appName, revision, ns string) (*v1alpha2.Component, *v1alpha2.ApplicationConfigurationComponent, error) {
   	pCtx, err := PrepareProcessContext(wl, appName, revision, ns)
   	if err != nil {
   		return nil, nil, err
   	}
   	return baseGenerateComponent(pCtx, wl, appName, ns)
   }
   ```

7. **baseGenerateComponent**

   ```go
   func baseGenerateComponent(pCtx process.Context, wl *Workload, appName, ns string) (*v1alpha2.Component, *v1alpha2.ApplicationConfigurationComponent, error) {
   	var (
   		outputSecretName string
   		err              error
   	)
   	if wl.IsCloudResourceProducer() {
   		outputSecretName, err = GetOutputSecretNames(wl)
   		if err != nil {
   			return nil, nil, err
   		}
   		wl.OutputSecretName = outputSecretName
   	}
   
   	for _, tr := range wl.Traits {
   		if err := tr.EvalContext(pCtx); err != nil {
   			return nil, nil, errors.Wrapf(err, "evaluate template trait=%s app=%s", tr.Name, wl.Name)
   		}
   	}
   	var comp *v1alpha2.Component
   	var acComp *v1alpha2.ApplicationConfigurationComponent
   	comp, acComp, err = evalWorkloadWithContext(pCtx, wl, ns, appName, wl.Name)
   	if err != nil {
   		return nil, nil, err
   	}
   	comp.Name = wl.Name
   	acComp.ComponentName = comp.Name
   
   	for _, sc := range wl.Scopes {
   		acComp.Scopes = append(acComp.Scopes, v1alpha2.ComponentScope{ScopeReference: v1alpha1.TypedReference{
   			APIVersion: sc.GVK.GroupVersion().String(),
   			Kind:       sc.GVK.Kind,
   			Name:       sc.Name,
   		}})
   	}
   	if len(comp.Namespace) == 0 {
   		comp.Namespace = ns
   	}
   	if comp.Labels == nil {
   		comp.Labels = map[string]string{}
   	}
   	comp.Labels[oam.LabelAppName] = appName
   	comp.SetGroupVersionKind(v1alpha2.ComponentGroupVersionKind)
   
   	return comp, acComp, nil
   }
   ```

8. **App handler:** apply

   ```go
   // apply will
   // 1. set ownerReference for ApplicationConfiguration and Components
   // 2. update AC's components using the component revision name
   // 3. update or create the AC with new revisionsand remember it in the application status
   // 4. garbage collect unused components
   func (h *appHandler) apply(ctx context.Context, appRev *v1beta1.ApplicationRevision, ac *v1alpha2.ApplicationConfiguration, comps []*v1alpha2.Component) error {
   	...
   	for _, comp := range comps {
   		...
   		newComp := comp.DeepCopy()
   		// newComp will be updated and return the revision name instead of the component name
   		revisionName, err := h.createOrUpdateComponent(ctx, newComp)
   		if err != nil {
   			return err
   		}
   		...
   		// find the ACC that contains this component
   		for i := 0; i < len(ac.Spec.Components); i++ {
   			....
   		// isNewRevision indicates app's newly created or spec has changed
   		// skip applying helm resources if no spec change
   		if h.isNewRevision && comp.Spec.Helm != nil {
   			if err = h.applyHelmModuleResources(ctx, comp, owners); err != nil {
   				return errors.Wrap(err, "cannot apply Helm module resources")
   			}
   		}
   	}
   	...
   
   	return nil
   }
   ```
   
   

9. **App handler:** createOrUpdateComponent

   ```go
   // createOrUpdateComponent creates a component if not exist and update if exists.
   // it returns the corresponding component revisionName and if a new component revision is created
   func (h *appHandler) createOrUpdateComponent(ctx context.Context, comp *v1alpha2.Component) (string, error) {
    ....
   	err := h.r.Get(ctx, compKey, &curComp)
   	if err != nil {
   		if !apierrors.IsNotFound(err) {
   			return "", err
   		}
   		if err = h.r.Create(ctx, comp); err != nil {
   			return "", err
   		}
   		h.logger.Info("Created a new component", "component name", comp.GetName())
   	} else {
   		// remember the revision if there is a previous component
   		if curComp.Status.LatestRevision != nil {
   			preRevisionName = curComp.Status.LatestRevision.Name
   		}
   		comp.ResourceVersion = curComp.ResourceVersion
   		if err := h.r.Update(ctx, comp); err != nil {
   			return "", err
   		}
   		h.logger.Info("Updated a component", "component name", comp.GetName())
   	}
   
   	return curRevisionName, nil
   }
   
   ```

10. **App handler:**   applyHelmModuleResources

    ```
    func (h *appHandler) applyHelmModuleResources(ctx context.Context, comp *v1alpha2.Component, owners []metav1.OwnerReference) error {
    	klog.Info("Process a Helm module component")
    	repo, err := oamutil.RawExtension2Unstructured(&comp.Spec.Helm.Repository)
    	if err != nil {
    		return err
    	}
    	release, err := oamutil.RawExtension2Unstructured(&comp.Spec.Helm.Release)
    	if err != nil {
    		return err
    	}
    
    	release.SetOwnerReferences(owners)
    	repo.SetOwnerReferences(owners)
    
    	if err := h.r.applicator.Apply(ctx, repo); err != nil {
    		return err
    	}
    	klog.InfoS("Apply a HelmRepository", "namespace", repo.GetNamespace(), "name", repo.GetName())
    	if err := h.r.applicator.Apply(ctx, release); err != nil {
    		return err
    	}
    	klog.InfoS("Apply a HelmRelease", "namespace", release.GetNamespace(), "name", release.GetName())
    	return nil
    }
    
    ```

    