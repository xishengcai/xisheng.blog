# kubectl 源码阅读1



1. 资源对象创建过程

   ![image-20210426150234604](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/070236.png)



Question:

1. 创建流程

   构建Cmd， 构建 资源对象， request api， handle result Info

2. 用到了哪些设计模式

   工厂模式

   建造者模式： The Builder object simplifies converting standard command line arguments and parameters into a Visitor that can iterate over all of the identified resources, whether on the server or on the local filesystem.

   访问者模式:  将多个方法用于作用于同一个对象，该设计模式使 操作和对象分离

3. 用到了哪些接口

   Factory

   **Visitor**：The Visitor interface makes it easy to deal with multiple resources in bulk for retrieval and operation.

   **Helper**：The Helper object provides simple CRUD operations on resources. 

   **Builde**r： The Builder object simplifies converting standard command line arguments and parameters into a Visitor that can iterate over all of the identified resources, whether on the server or on the local filesystem.

   



```
NewCommand ---> add commands   

​										add sub Commands

create example
	
// NewCmdCreate returns new initialized instance of create sub command
func NewCmdCreate(f cmdutil.Factory, ioStreams genericclioptions.IOStreams) *cobra.Command {
	o := NewCreateOptions(ioStreams)

	cmd := &cobra.Command{
...
		Run: func(cmd *cobra.Command, args []string) {
			..
			cmdutil.CheckErr(o.RunCreate(f, cmd))
		},
	}
	...


	// create subcommands
	cmd.AddCommand(NewCmdCreateNamespace(f, ioStreams))
	...
	return cmd
}
```




```go
type Result struct{
	Operation Opearation  // ERROR, SET, DROP
	MergedResult interface{}
}
```



strategic visitor

```go
createReplaceStrategy
createMergeStrategy
createRetainKeysStrategy
```



openapi.Resource 是干啥的

```go
// Factory creates an Element by combining object values from recorded, local and remote sources with
// the metadata from an openapi schema.
type Factory struct {
	// Resources contains the openapi field metadata for the object models
	Resources openapi.Resources
}
```



```go
	dryRunVerifier := &DryRunVerifier{
		Finder:        cmdutil.NewCRDFinder(cmdutil.CRDFromDynamic(o.DynamicClient)),
		OpenAPIGetter: o.DiscoveryClient,
	}
```



```go
	r := o.Builder.
		// unstructuredscheme.NewUnstructuredObjectTyper()
    // unstructuredObjectTyper    runtime.ObjectTyper
		// imple get kind and version
		// target : set objectType and mapper
		Unstructured().    

		//
		Schema(o.Validator).
		ContinueOnError().
		NamespaceParam(o.Namespace).DefaultNamespace().
		FilenameParam(o.EnforceNamespace, &o.DeleteOptions.FilenameOptions).
		LabelSelectorParam(o.Selector).
		Flatten().
// Do returns a Result object with a Visitor for the resources identified by the Builder.
// The visitor will respect the error behavior specified by ContinueOnError. Note that stream
// inputs are consumed by the first execution - use Infos() or Object() on the Result to capture a list
// for further iteration.
		Do()
```



```go
err = r.Visit(func(info *resource.Info, err error) error {
      if o.ServerSideApply {
        data, err := runtime.Encode(unstructured.UnstructuredJSONScheme, info.Object)
        if err != nil {
          return cmdutil.AddSourceToErr("serverside-apply", info.Source, err)
        }
        ...
				obj, err := resource.NewHelper(info.Client, info.Mapping).Patch(
          info.Namespace,
          info.Name,
          types.ApplyPatchType,
          data,
          &options,
			)
        
        info.Refresh(obj, true)
        
        
      }
}
```





![image-20210427153254258](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/073256.png)





![image-20210427162216602](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/082218.png)





NewDecoratedVisitor --> ContinueOnErrorVisitor ---> NewFlattenListVisitor --->EagerVisitorList-->



DecoratedVisitor→ContinueOnErrorVisitor → FlattenListVisitor →FlattenListVisitor → StreamVisitor →FileVisitor→EagerVisitorList



构建restClient

factoryImpl

Complete 方法中可获取

​	

```
o.DynamicClient, err = f.DynamicClient()
discoveryClient, err := f.ToDiscoveryClient()

o.OpenAPISchema, _ = f.OpenAPISchema()
o.Builder = f.NewBuilder()
o.Mapper, err = f.ToRESTMapper()
```



getObjects

```go
func (o *ApplyOptions) GetObjects() ([]*resource.Info, error) {
   var err error = nil
      r := o.Builder.
         Unstructured().
         Schema(o.Validator).
         ContinueOnError().
         NamespaceParam(o.Namespace).DefaultNamespace().
         Flatten().
         Do()
      o.objects, err = r.Infos()
      o.objectsCached = true  
   return o.objects, err
}
```



apply

```go
func (o *ApplyOptions) applyOneObject(info *resource.Info) error {
  // ?????
   o.MarkNamespaceVisited(info)

  // ?????
   if err := o.Recorder.Record(info.Object); err != nil {
      klog.V(4).Infof("error recording current command: %v", err)
   }

   if len(info.Name) == 0 {
     // ?????
      metadata, _ := meta.Accessor(info.Object)
      generatedName := metadata.GetGenerateName()
      if len(generatedName) > 0 {
         return fmt.Errorf("from %s: cannot use generate name with apply", generatedName)
      }
   }

   helper := resource.NewHelper(info.Client, info.Mapping).
      // ?????
      WithFieldManager(o.FieldManager)

   if o.ServerSideApply {
      // Send the full object to be applied on the server side.
      data, err := runtime.Encode(unstructured.UnstructuredJSONScheme, info.Object)
      if err != nil {
         return cmdutil.AddSourceToErr("serverside-apply", info.Source, err)
      }

      options := metav1.PatchOptions{
         Force: &o.ForceConflicts,
      }
      obj, err := helper.Patch(
         info.Namespace,
         info.Name,
         types.ApplyPatchType,
         data,
         &options,
      )
      if err != nil {
         if isIncompatibleServerError(err) {
            err = fmt.Errorf("Server-side apply not available on the server: (%v)", err)
         }
         if errors.IsConflict(err) {
            err = fmt.Errorf(`%v
Please review the fields above--they currently have other managers. Here
are the ways you can resolve this warning:
* If you intend to manage all of these fields, please re-run the apply
  command with the `+"`--force-conflicts`"+` flag.
* If you do not intend to manage all of the fields, please edit your
  manifest to remove references to the fields that should keep their
  current managers.
* You may co-own fields by updating your manifest to match the existing
  value; in this case, you'll become the manager if the other manager(s)
  stop managing the field (remove it from their configuration).
See http://k8s.io/docs/reference/using-api/api-concepts/#conflicts`, err)
         }
         return err
      }

      info.Refresh(obj, true)

      if err := o.MarkObjectVisited(info); err != nil {
         return err
      }

      if o.shouldPrintObject() {
         return nil
      }

      printer, err := o.ToPrinter("serverside-applied")
      if err != nil {
         return err
      }

      if err = printer.PrintObj(info.Object, o.Out); err != nil {
         return err
      }
      return nil
   }

   // Get the modified configuration of the object. Embed the result
   // as an annotation in the modified configuration, so that it will appear
   // in the patch sent to the server.
   modified, err := util.GetModifiedConfiguration(info.Object, true, unstructured.UnstructuredJSONScheme)
   if err != nil {
      return cmdutil.AddSourceToErr(fmt.Sprintf("retrieving modified configuration from:\n%s\nfor:", info.String()), info.Source, err)
   }

   if err := info.Get(); err != nil {
      if !errors.IsNotFound(err) {
         return cmdutil.AddSourceToErr(fmt.Sprintf("retrieving current configuration of:\n%s\nfrom server for:", info.String()), info.Source, err)
      }

      // Create the resource if it doesn't exist
      // First, update the annotation used by kubectl apply
      if err := util.CreateApplyAnnotation(info.Object, unstructured.UnstructuredJSONScheme); err != nil {
         return cmdutil.AddSourceToErr("creating", info.Source, err)
      }

      if o.DryRunStrategy != cmdutil.DryRunClient {
         // Then create the resource and skip the three-way merge
         obj, err := helper.Create(info.Namespace, true, info.Object)
         if err != nil {
            return cmdutil.AddSourceToErr("creating", info.Source, err)
         }
         info.Refresh(obj, true)
      }

      if err := o.MarkObjectVisited(info); err != nil {
         return err
      }

      if o.shouldPrintObject() {
         return nil
      }

      printer, err := o.ToPrinter("created")
      if err != nil {
         return err
      }
      if err = printer.PrintObj(info.Object, o.Out); err != nil {
         return err
      }
      return nil
   }

   if err := o.MarkObjectVisited(info); err != nil {
      return err
   }

   if o.DryRunStrategy != cmdutil.DryRunClient {
      metadata, _ := meta.Accessor(info.Object)
      annotationMap := metadata.GetAnnotations()
      if _, ok := annotationMap[corev1.LastAppliedConfigAnnotation]; !ok {
         fmt.Fprintf(o.ErrOut, warningNoLastAppliedConfigAnnotation, o.cmdBaseName)
      }

      patcher, err := newPatcher(o, info, helper)
      if err != nil {
         return err
      }
      patchBytes, patchedObject, err := patcher.Patch(info.Object, modified, info.Source, info.Namespace, info.Name, o.ErrOut)
      if err != nil {
         return cmdutil.AddSourceToErr(fmt.Sprintf("applying patch:\n%s\nto:\n%v\nfor:", patchBytes, info), info.Source, err)
      }

      info.Refresh(patchedObject, true)

      if string(patchBytes) == "{}" && !o.shouldPrintObject() {
         printer, err := o.ToPrinter("unchanged")
         if err != nil {
            return err
         }
         if err = printer.PrintObj(info.Object, o.Out); err != nil {
            return err
         }
         return nil
      }
   }

   if o.shouldPrintObject() {
      return nil
   }

   printer, err := o.ToPrinter("configured")
   if err != nil {
      return err
   }
   if err = printer.PrintObj(info.Object, o.Out); err != nil {
      return err
   }

   return nil
}
```