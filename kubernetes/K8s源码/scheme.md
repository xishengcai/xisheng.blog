# k8s client and scheme

<!-- toc -->

## 1. 什么是scheme

### 1.1 在了解scheme之前， 我们先了解下kubernetes 中的资源分类

运维人员在创建资源的时候，可能只关注kind（如deployment，本能的忽略分组和版本信息）， 但是在k8s的资源定位中只说deployment是不准确的。因为Kubernetes系统支持多个Group，每个Group支持多个Version，每个Version支持多个Resource，其中部分资源同时会拥有自己的子资源（即SubResource）。例如，Deployment资源拥有Status子资源。



资源组、资源版本、资源、子资源的完整表现形式为<group>/<version>/<resource>/<subresource>。以常用的Deployment资源为例，其完整表现形式为apps/v1/deployments/status。



为了方便资源管理和有序迭代，资源有Group（组）和Version（版本）的概念。

​	● Group：被称为资源组，在Kubernetes API Server中也可称其为APIGroup。

​	● Version：被称为资源版本，在Kubernetes API Server中也可称其为APIVersions。

​	● Resource：被称为资源，在Kubernetes API Server中也可称其为APIResource。

​	● Kind：资源种类，描述Resource的种类，与Resource为同一级别。

![image-20210518112228962](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/032231.png)



### 1.2 scheme 是什么

Kubernetes系统拥有众多资源，每一种资源就是一个资源类型，这些资源类型需要有统一的注册、存储、查询、管理等机制。目前Kubernetes系统中的所有资源类型都已注册到Scheme资源注册表中，其是一个内存型的资源注册表，拥有如下特点。

​	● 支持注册多种资源类型，包括内部版本和外部版本。

​	● 支持多种版本转换机制。

​	● 支持不同资源的序列化/反序列化机制。



Scheme资源注册表支持两种资源类型（Type）的注册，分别是**UnversionedType**和**KnownType**资源类型，分别介绍如下。

​	● **UnversionedType**：无版本资源类型，这是一个早期Kubernetes系统中的概念，它主要应用于某些没有版本的资源类型，该类型的资源对象并不需要进行转换。在目前的Kubernetes发行版本中，无版本类型已被弱化，几乎所有的资源对象都拥有版本，但在metav1元数据中还有部分类型，它们既属于meta.k8s.io/v1又属于UnversionedType无版本资源类型，例如metav1.Status、metav1.APIVersions、metav1.APIGroupList、metav1.APIGroup、metav1.APIResourceList。

​	● **KnownType**：是目前Kubernetes最常用的资源类型，也可称其为“拥有版本的资源类型”。在Scheme资源注册表中，UnversionedType资源类型的对象通过scheme.AddUnversionedTypes方法进行注册，KnownType资源类型的对象通过scheme.AddKnownTypes方法进行注册。



### 1.3 由表及里,scheme结构体定义

staging/src/k8s.io/apimachinery/pkg/runtime/scheme.go

```go
type Scheme struct {
	gvkToType map[schema.GroupVersionKind]reflect.Type
	typeToGVK map[reflect.Type][]schema.GroupVersionKind
	unversionedTypes map[reflect.Type]schema.GroupVersionKind
	unversionedKinds map[string]reflect.Type
	...
}
```

Scheme资源注册表结构字段说明如下。

​	● gvkToType：存储GVK与Type的映射关系。

​	● typeToGVK：存储Type与GVK的映射关系，一个Type会对应一个或多个GVK。

​	● unversionedTypes：存储UnversionedType与GVK的映射关系。

​	● unversionedKinds：存储Kind（资源种类）名称与UnversionedType的映射关系。



Scheme资源注册表通过Go语言的map结构实现映射关系，这些映射关系可以实现高效的正向和反向检索，从Scheme资源注册表中检索某个GVK的Type，它的时间复杂度为O（1）。资源注册表映射关系如下图：

![image-20210518113028732](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/033030.png)





## 2. 如何使用scheme

### 2.1 定义注册方法 AddToScheme

通过runtime.NewScheme实例化一个新的Scheme资源注册表。注册资源类型到Scheme资源注册表有两种方式，

- 第一种通过scheme.AddKnownTypes方法注册KnownType类型的对象

- 第二种通过scheme.AddUnversionedTypes方法注册UnversionedType类型的对象



在我们创建crd 资源的时候，通过代码生成工具，都会在register.go文件里帮我们自动生成 AddToScheme方法

```go
package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"lsh-mcp-lcs-timer/constant"
)

var (
	SchemeBuilder = runtime.NewSchemeBuilder(addKnownTypes)
  
  // 外部的scheme 直接调用该方法进行scheme注册
	AddToScheme = SchemeBuilder.AddToScheme
	SchemeGroupVersion = schema.GroupVersion{Group: constant.ResourceOverviewGroupName, Version: "v1"}
)

func Kind(kind string) schema.GroupKind {
	return SchemeGroupVersion.WithKind(kind).GroupKind()
}

func Resource(resource string) schema.GroupResource {
	return SchemeGroupVersion.WithResource(resource).GroupResource()
}

func addKnownTypes(scheme *runtime.Scheme) error {
	scheme.AddKnownTypes(SchemeGroupVersion,
		&RsOverView{},
		&RsOverViewList{},
	)
	metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
	return nil
}

```



### 2.2 调用AddToScheme进行GVK注册

场景： 将其他项目的GVK 注册到自己项目的scheme中。

example，下面代码摘自kubevela： 

```go
import(
	kruise "github.com/openkruise/kruise-api/apps/v1alpha1"
	certmanager "github.com/wonderflow/cert-manager-api/pkg/apis/certmanager/v1"
	istioclientv1beta1 "istio.io/client-go/pkg/apis/networking/v1beta1"
	crdv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	k8sruntime "k8s.io/apimachinery/pkg/runtime"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"


	oamcore "github.com/oam-dev/kubevela/apis/core.oam.dev"
	oamstandard "github.com/oam-dev/kubevela/apis/standard.oam.dev/v1alpha1"

)

var (
	// Scheme defines the default KubeVela schema
	Scheme = k8sruntime.NewScheme()
)

func init() {
	_ = clientgoscheme.AddToScheme(Scheme)
	_ = crdv1.AddToScheme(Scheme)
	_ = oamcore.AddToScheme(Scheme)
	_ = oamstandard.AddToScheme(Scheme)
	_ = istioclientv1beta1.AddToScheme(Scheme)
	_ = certmanager.AddToScheme(Scheme)
	_ = kruise.AddToScheme(Scheme)
	// +kubebuilder:scaffold:scheme
}
```



### 2.3 docode 

这里以 k8s.io/client-go 为例， 代码位置： kubernetes/scheme/register.go    

注册scheme

```go
var Scheme = runtime.NewScheme()
var Codecs = serializer.NewCodecFactory(Scheme) 
var ParameterCodec = runtime.NewParameterCodec(Scheme)

// 生成一个Decode
var decode = Codecs.UniversalDeserializer().Decode 
```



UniversalDeserializer 返回 CodeFactory 的属性universal

```
// UniversalDeserializer can convert any stored data recognized by this factory into a Go object that satisfies
// runtime.Object. It does not perform conversion. It does not perform defaulting.
func (f CodecFactory) UniversalDeserializer() runtime.Decoder {
	return f.universal
}
```



查看CodecFactory生成过程，发现universal 的值是recognizer.NewDecoder(decoders...)

```go
func NewCodecFactory(scheme *runtime.Scheme, mutators ...CodecFactoryOptionsMutator) CodecFactory {
	options := CodecFactoryOptions{Pretty: true}
	for _, fn := range mutators {
		fn(&options)
	}

	serializers := newSerializersForScheme(scheme, json.DefaultMetaFactory, options)
	return newCodecFactory(scheme, serializers)
}

// newCodecFactory is a helper for testing that allows a different metafactory to be specified.
func newCodecFactory(scheme *runtime.Scheme, serializers []serializerType) CodecFactory {
	decoders := make([]runtime.Decoder, 0, len(serializers))
	var accepts []runtime.SerializerInfo
	alreadyAccepted := make(map[string]struct{})

	var legacySerializer runtime.Serializer
	for _, d := range serializers {
		// 组装decoder
		decoders = append(decoders, d.Serializer)
		....
	}
	if legacySerializer == nil {
		legacySerializer = serializers[0].Serializer
	}

	return CodecFactory{
		scheme:      scheme,
		serializers: serializers,
		
		// set universal
		universal:   recognizer.NewDecoder(decoders...),

		accepts: accepts,

		legacySerializer: legacySerializer,
	}
}
```



结论：universal 是一个数组， 里面的元素都实现了接口 Decoder

```go
// NewDecoder creates a decoder that will attempt multiple decoders in an order defined
// by:
//
// 1. The decoder implements RecognizingDecoder and identifies the data
// 2. All other decoders, and any decoder that returned true for unknown.
//
// The order passed to the constructor is preserved within those priorities.
func NewDecoder(decoders ...runtime.Decoder) runtime.Decoder {
   return &decoder{
      decoders: decoders,
   }
}
```



**调用Decoder 的 decode 方法**

```go
obj, _, err := decode([]byte(objStr),nil, nil)
```



decoders 关于Decode 的具体实现， 代码：k8s.io/apimachinery@v0.20.1/pkg/runtime/serializer/recognizer/recognizer.go

```go
func (d *decoder) Decode(data []byte, gvk *schema.GroupVersionKind, into runtime.Object) (runtime.Object, *schema.GroupVersionKind, error) {
	var (
		lastErr error
		skipped []runtime.Decoder
	)

	// try recognizers, record any decoders we need to give a chance later
	for _, r := range d.decoders {
		switch t := r.(type) {
		case RecognizingDecoder:
			buf := bytes.NewBuffer(data)
			ok, unknown, err := t.RecognizesData(buf)
			if err != nil {
				lastErr = err
				continue
			}
			if unknown {
				skipped = append(skipped, t)
				continue
			}
			if !ok {
				continue
			}
			return r.Decode(data, gvk, into)
		default:
			skipped = append(skipped, t)
		}
	}

	// try recognizers that returned unknown or didn't recognize their data
	for _, r := range skipped {
		out, actual, err := r.Decode(data, gvk, into)
		if err != nil {
			lastErr = err
			continue
		}
		return out, actual, nil
	}

	if lastErr == nil {
		lastErr = fmt.Errorf("no serialization format matched the provided data")
	}
	return nil, nil, lastErr
}

```





挖掘Decoder的具体实现类：

查看CodeFactory 相关代码，发现这里Decoder的实现类是Serializer

```go
// form. If typer is not nil, the object has the group, version, and kind fields set. Options are copied into the Serializer
// and are immutable.
func NewSerializerWithOptions(meta MetaFactory, creater runtime.ObjectCreater, typer runtime.ObjectTyper, options SerializerOptions) *Serializer {
	return &Serializer{
		meta:       meta,
		creater:    creater,
		typer:      typer,
		options:    options,
		identifier: identifier(options),
	}
}

```



Serializer 类的Docder 接口实现

```go
// Decode attempts to convert the provided data into YAML or JSON, extract the stored schema kind, apply the provided default gvk, and then
// load that data into an object matching the desired schema kind or the provided into.
// If into is *runtime.Unknown, the raw data will be extracted and no decoding will be performed.
// If into is not registered with the typer, then the object will be straight decoded using normal JSON/YAML unmarshalling.
// If into is provided and the original data is not fully qualified with kind/version/group, the type of the into will be used to alter the returned gvk.
// If into is nil or data's gvk different from into's gvk, it will generate a new Object with ObjectCreater.New(gvk)
// On success or most errors, the method will return the calculated schema kind.
// The gvk calculate priority will be originalData > default gvk > into
func (s *Serializer) Decode(originalData []byte, gvk *schema.GroupVersionKind, into runtime.Object) (runtime.Object, *schema.GroupVersionKind, error) {
	data := originalData
	if s.options.Yaml {
		altered, err := yaml.YAMLToJSON(data)
		if err != nil {
			return nil, nil, err
		}
		data = altered
	}

	actual, err := s.meta.Interpret(data)
	if err != nil {
		return nil, nil, err
	}

	if gvk != nil {
		*actual = gvkWithDefaults(*actual, *gvk)
	}

	if unk, ok := into.(*runtime.Unknown); ok && unk != nil {
		unk.Raw = originalData
		unk.ContentType = runtime.ContentTypeJSON
		unk.GetObjectKind().SetGroupVersionKind(*actual)
		return unk, actual, nil
	}

	if into != nil {
		_, isUnstructured := into.(runtime.Unstructured)
		types, _, err := s.typer.ObjectKinds(into)
		switch {
		case runtime.IsNotRegisteredError(err), isUnstructured:
			if err := caseSensitiveJsonIterator.Unmarshal(data, into); err != nil {
				return nil, actual, err
			}
			return into, actual, nil
		case err != nil:
			return nil, actual, err
		default:
			*actual = gvkWithDefaults(*actual, types[0])
		}
	}

	if len(actual.Kind) == 0 {
		return nil, actual, runtime.NewMissingKindErr(string(originalData))
	}
	if len(actual.Version) == 0 {
		return nil, actual, runtime.NewMissingVersionErr(string(originalData))
	}

  
	// use the target if necessary, 重点： 生成一个空数据的对象
	obj, err := runtime.UseOrCreateObject(s.typer, s.creater, *actual, into)
	if err != nil {
		return nil, actual, err
	}

   // 通过 json 解析，给上面生成的空数据对象，赋值
	if err := caseSensitiveJsonIterator.Unmarshal(data, obj); err != nil {
		return nil, actual, err
	}

	// If the deserializer is non-strict, return successfully here.
	if !s.options.Strict {
		return obj, actual, nil
	}

	// In strict mode pass the data trough the YAMLToJSONStrict converter.
	// This is done to catch duplicate fields regardless of encoding (JSON or YAML). For JSON data,
	// the output would equal the input, unless there is a parsing error such as duplicate fields.
	// As we know this was successful in the non-strict case, the only error that may be returned here
	// is because of the newly-added strictness. hence we know we can return the typed strictDecoderError
	// the actual error is that the object contains duplicate fields.
	altered, err := yaml.YAMLToJSONStrict(originalData)
	if err != nil {
		return nil, actual, runtime.NewStrictDecodingError(err.Error(), string(originalData))
	}
	// As performance is not an issue for now for the strict deserializer (one has regardless to do
	// the unmarshal twice), we take the sanitized, altered data that is guaranteed to have no duplicated
	// fields, and unmarshal this into a copy of the already-populated obj. Any error that occurs here is
	// due to that a matching field doesn't exist in the object. hence we can return a typed strictDecoderError,
	// the actual error is that the object contains unknown field.
	strictObj := obj.DeepCopyObject()
	if err := strictCaseSensitiveJsonIterator.Unmarshal(altered, strictObj); err != nil {
		return nil, actual, runtime.NewStrictDecodingError(err.Error(), string(originalData))
	}
	// Always return the same object as the non-strict serializer to avoid any deviations.
	return obj, actual, nil
}

```



## 3. kubectl 是如何将输入字节转换成k8s对象的

###  3.1 visitor 接口

Visitor接口包含Visit方法，实现了Visit（VisitorFunc） error的结构体都可以成为Visitor。其中，VisitorFunc是一个匿名函数，它接收Info与error信息，Info结构用于存储RESTClient请求的返回结果，而VisitorFunc匿名函数则生成或处理Info结构。Visitor的设计较为复杂，并非单纯实现了访问者模式，它相当于一个匿名函数集。在Kubernetes源码中，Visitor被设计为可以多层嵌套（即多层匿名函数嵌套，使用一个Visitor嵌套另一个Visitor）

```go
// Visitor lets clients walk a list of resources.
type Visitor interface {
	Visit(VisitorFunc) error
}
```



### 3.2 StreamVisitor

kubectl 将输入的字节码通过如下visitor进行处理

DecoratedVisitor→ContinueOnErrorVisitor → FlattenListVisitor →FlattenListVisitor → **StreamVisitor** →FileVisitor→EagerVisitorList



这里我们重点关注StreamVisitor的操作

```go
// Visit implements Visitor over a stream. StreamVisitor is able to distinct multiple resources in one stream.
func (v *StreamVisitor) Visit(fn VisitorFunc) error {
	d := yaml.NewYAMLOrJSONDecoder(v.Reader, 4096)
	for {
		ext := runtime.RawExtension{}
    // 使用unstructured.UnstructuredJSONScheme 解析
    // d 循环解析，自动通过---分割对象，每次只解析一个对象
		if err := d.Decode(&ext); err != nil {
			if err == io.EOF {
				return nil
			}
			return fmt.Errorf("error parsing %s: %v", v.Source, err)
		}
		// TODO: This needs to be able to handle object in other encodings and schemas.
		ext.Raw = bytes.TrimSpace(ext.Raw)
		if len(ext.Raw) == 0 || bytes.Equal(ext.Raw, []byte("null")) {
			continue
		}
		if err := ValidateSchema(ext.Raw, v.Schema); err != nil {
			return fmt.Errorf("error validating %q: %v", v.Source, err)
		}
    
    // StreamVisitor 对NewYAMLOrJSONDecoder 解析出的数据进一步 解码出k8s对象
    // info 就是一个k8s runtime.Object
		info, err := v.infoForData(ext.Raw, v.Source)
		if err != nil {
			if fnErr := fn(info, err); fnErr != nil {
				return fnErr
			}
			continue
		}
		if err := fn(info, nil); err != nil {
			return err
		}
	}
}

```



### 3.3 方法infoForData的具体实现

infoForData 属于StreamVisitor 内嵌结构体 mapper的方法， 所以上面可以直接通过StreamVisitor调用infoForData方法

```go
// Mapper is a convenience struct for holding references to the interfaces
// needed to create Info for arbitrary objects.
type mapper struct {
	// localFn indicates the call can't make server requests
	localFn func() bool

	restMapperFn RESTMapperFunc
	clientFn     func(version schema.GroupVersion) (RESTClient, error)
	decoder      runtime.Decoder
}

```



```go

func (m *mapper) infoForData(data []byte, source string) (*Info, error) {
  
  // 对字节数组进行解码
	obj, gvk, err := m.decoder.Decode(data, nil, nil)
	if err != nil {
		return nil, fmt.Errorf("unable to decode %q: %v", source, err)
	}

	name, _ := metadataAccessor.Name(obj)
	namespace, _ := metadataAccessor.Namespace(obj)
	resourceVersion, _ := metadataAccessor.ResourceVersion(obj)

	ret := &Info{
		Source:          source,
		Namespace:       namespace,
		Name:            name,
		ResourceVersion: resourceVersion,

		Object: obj,
	}
  ... 

	return ret, nil
}
```



## 4. 代码实践

目标：

1. 实现类似kubectl 一样的client ，可以apply 任意yaml文件



- 关键代码之：**对象反序列化**

```go

var (
  // 解码器
	decode = unstructured.UnstructuredJSONScheme
)

func GetKubernetesObjectByBytes(ioBytes []byte) ([]interface{}, error) {
	objList := make([]interface{}, 0)
	d := yaml.NewYAMLOrJSONDecoder(bytes.NewReader(ioBytes), 4096)

	for {
		ext := runtime.RawExtension{}
		if err := d.Decode(&ext); err != nil {
			if err == io.EOF {
				return objList, nil
			}
		}
		// TODO: This needs to be able to handle object in other encodings and schemas.
		ext.Raw = bytes.TrimSpace(ext.Raw)
		if len(ext.Raw) == 0 || bytes.Equal(ext.Raw, []byte("null")) {
			return objList, nil
		}
    
    // 参数data 必须先yaml to json，否则会报错
		obj, _, err := decode.Decode(ext.Raw, nil, nil)
		if err != nil {
			return nil, err
		}
		objList = append(objList, obj)
	}
}
```



为什么yaml 必须要转换为 json

```go
// YAMLToJSON converts YAML to JSON. Since JSON is a subset of YAML,
// passing JSON through this method should be a no-op.
//
// Things YAML can do that are not supported by JSON:
// * In YAML you can have binary and null keys in your maps. These are invalid
//   in JSON. (int and float keys are converted to strings.)
// * Binary data in YAML with the !!binary tag is not supported. If you want to
//   use binary data with this library, encode the data as base64 as usual but do
//   not use the !!binary tag in your YAML. This will ensure the original base64
//   encoded data makes it all the way through to the JSON.
//
// For strict decoding of YAML, use YAMLToJSONStrict.
func YAMLToJSON(y []byte) ([]byte, error) {
   return yamlToJSON(y, nil, yaml.Unmarshal)
}
```

- 关键代码之： **对象apply**

client 要实现apply 需要实现两个接口： creator 和 patcher。

creator 负责获取集群中以存在的对象，不存在则创建。

patcher 负责对将集群中的对象更新为要修改的对象。

```go
func NewClient() *KubernetesClient {
	return &KubernetesClient{
    // 不存在则创建，存在则获取服务端对象
		creator: creatorFn(createOrGetExisting),
    
    // apply 的关键方法，后面再具体介绍
		patcher: patcherFn(threeWayMergePatch),
	}
}


// Apply applies new state to an object or create it if not exist
func (k *KubernetesClient) Apply(ctx context.Context, desired client.Object, ao ...ApplyOption) error {
	existing, err := k.createOrGetExisting(ctx, k.Client, desired, ao...)
	if err != nil {
		return err
	}
  // existing 为nil，表明这是第一次创建，直接退出
	if existing == nil {
		return nil
	}

	// the object already exists, patch new state
	if err := executeApplyOptions(ctx, existing, desired, ao); err != nil {
		return err
	}
	loggingApply("patching object", desired)
  // 如果已经存在，这里执行threeWayMergePatch
	patch, err := k.patcher.patch(existing, desired)
	if err != nil {
		return errors.Wrap(err, "cannot calculate patch by computing a three way diff")
	}
	return errors.Wrapf(k.Client.Patch(ctx, desired, patch), "cannot patch object")
}

```



threeWayMergePatch： 通过将 集群中的对象（current），apply后的对象（modified）， 存在于注解中的对象（original）三者对比，根据在runtime中是否注册改对象，又分两种方式patch。

**资源对象在runtime中没有注册**： 使用[JSON Merge Patch, RFC 7386](https://tools.ietf.org/html/rfc7386)，对[JSON Patch, RFC 6902](https://tools.ietf.org/html/rfc6902) 进行了简化。 但是仍然有如下缺陷：1. delete must set null； 2. add new element must report entire array。3. 缺少JSON Schema验证。

**资源对象在runtime中有注册**：使用StrategicMergePatch。不必提供完整的字段，新字段会添加，出现的已有字段会更新，没有出现的已有字段不变。缺点是不支持 custom resource。

```go
func threeWayMergePatch(currentObj, modifiedObj client.Object) (client.Patch, error) {
  // 集中的对象
	current, err := json.Marshal(currentObj)
	if err != nil {
		return nil, err
	}
  // 集中的对象的注解值 xxx/last-applied-configuration: {}
	original, err := getOriginalConfiguration(currentObj)
	if err != nil {
		return nil, err
	}
  // apply 后的对象
	modified, err := getModifiedConfiguration(modifiedObj, true)
	if err != nil {
		return nil, err
	}

	var patchType types.PatchType
	var patchData []byte
	var lookupPatchMeta strategicpatch.LookupPatchMeta

	versionedObject, err := k8sScheme.New(currentObj.GetObjectKind().GroupVersionKind())
	switch {
  // crd 对象，在默认的runtime中是没有注册的
	case runtime.IsNotRegisteredError(err):
		// use JSONMergePatch for custom resources
		// because StrategicMergePatch doesn't support custom resources
		patchType = types.MergePatchType
		preconditions := []mergepatch.PreconditionFunc{
			mergepatch.RequireKeyUnchanged("apiVersion"),
			mergepatch.RequireKeyUnchanged("kind"),
			mergepatch.RequireMetadataKeyUnchanged("name")}
		patchData, err = jsonmergepatch.CreateThreeWayJSONMergePatch(original, modified, current, preconditions...)
		if err != nil {
			return nil, err
		}
	case err != nil:
		return nil, err
	default:
		// use StrategicMergePatch for K8s built-in resources
		patchType = types.StrategicMergePatchType
		lookupPatchMeta, err = strategicpatch.NewPatchMetaFromStruct(versionedObject)
		if err != nil {
			return nil, err
		}
		patchData, err = strategicpatch.CreateThreeWayMergePatch(original, modified, current, lookupPatchMeta, true)
		if err != nil {
			return nil, err
		}
	}
	return client.RawPatch(patchType, patchData), nil
}
```

详细代码见： https://github.com/xishengcai/ganni-tool/blob/master/k8s/kubeapp.go



我们以下面的yaml 为例，执行apply，然后debug，观察threeWayMergePatch中的对象

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: launcher-test
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  # 名字必需与下面的 spec 字段匹配，并且格式为 '<名称的复数形式>.<组名>'
  name: crontabs.stable.example.com
spec:
  # 组名称，用于 REST API: /apis/<组>/<版本>
  group: stable.example.com
  # 列举此 CustomResourceDefinition 所支持的版本
  versions:
    - name: v1
      # 每个版本都可以通过 served 标志来独立启用或禁止
      served: true
      # 其中一个且只有一个版本必需被标记为存储版本
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                cronSpec:
                  type: string
                image:
                  type: string
                replicas:
                  type: integer
  # 可以是 Namespaced 或 Cluster
  scope: Namespaced
  names:
    # 名称的复数形式，用于 URL：/apis/<组>/<版本>/<名称的复数形式>
    plural: crontabs
    # 名称的单数形式，作为命令行使用时和显示时的别名
    singular: crontab
    # kind 通常是单数形式的驼峰编码（CamelCased）形式。你的资源清单会使用这一形式。
    kind: CronTab
    # shortNames 允许你在命令行使用较短的字符串来匹配资源
    shortNames:
      - ct
---
apiVersion: stable.example.com/v1
kind: CronTab
metadata:
  name: crontab
  namespace: launcher-test
spec:
  image: "xx"
  replicas: 1
---
apiVersion: stable.example.com/v1
kind: CronTab
metadata:
  name: crontab
  namespace: launcher-test
spec:
  image: "xxx"
  replicas: 2
```



结果如下

current：

```json
{
  "apiVersion": "stable.example.com/v1",
  "kind": "CronTab",
  "metadata": {
    "annotations": {
      "ganni-tool/last-applied-configuration": "{\"apiVersion\":\"stable.example.com/v1\",\"kind\":\"CronTab\",\"metadata\":{\"name\":\"crontab\",\"namespace\":\"launcher-test\"},\"spec\":{\"image\":\"xx\",\"replicas\":1}}"
    },
    "creationTimestamp": "2021-06-03T03:08:29Z",
    "generation": 1,
    "name": "crontab",
    "namespace": "launcher-test",
    "resourceVersion": "16154",
    "selfLink": "/apis/stable.example.com/v1/namespaces/launcher-test/crontabs/crontab",
    "uid": "7705fc1e-1a1c-457d-b9dd-9ff56658343d"
  },
  "spec": {
    "image": "xx",
    "replicas": 1
  }
}
```



Origin:

```json
{
  "apiVersion": "stable.example.com/v1",
  "kind": "CronTab",
  "metadata": {
    "name": "crontab",
    "namespace": "launcher-test"
  },
  "spec": {
    "image": "xx",
    "replicas": 1
  }
}
```



Modify:

```json
{
  "apiVersion": "stable.example.com/v1",
  "kind": "CronTab",
  "metadata": {
    "annotations": {
      "ganni-tool/last-applied-configuration": "{\"apiVersion\":\"stable.example.com/v1\",\"kind\":\"CronTab\",\"metadata\":{\"name\":\"crontab\",\"namespace\":\"launcher-test\"},\"spec\":{\"image\":\"xxx\",\"replicas\":2}}"
    },
    "name": "crontab",
    "namespace": "launcher-test"
  },
  "spec": {
    "image": "xxx",
    "replicas": 2
  }
}
```



**Question**:

**Q1**：为什么kubectl 在没有注册scheme 的情况下可以生成runtime.Object

**A**：因为kubectl 使用的是 UnstructuredJSONScheme， 可以不需要提注册scheme（without a predefined scheme）。

UnstructuredJSONScheme.Decode 方法将 yaml or json 的字节流转换成了 Unstructured.Object（ 而object 的类型是map[string]interface{}）。



下面代码是UnstructuredJSONScheme反序列化流程

代码位置： staging/src/k8s.io/apimachinery/pkg/apis/meta/v1/unstructured/helpers.go  

版本：v1.19.0

```go
		// UnstructuredJSONScheme is capable of converting JSON data into the Unstructured
		// type, which can be used for generic access to objects without a predefined scheme.
		// TODO: move into serializer/json.
329  var UnstructuredJSONScheme runtime.Codec = unstructuredJSONScheme{}


335 func (s unstructuredJSONScheme) Decode(data []byte, _ *schema.GroupVersionKind, obj runtime.Object) (runtime.Object, *schema.GroupVersionKind, error) {
	var err error
	if obj != nil {
		err = s.decodeInto(data, obj)
	} else {
    //注意 look down
		obj, err = s.decode(data)
	}
...
	gvk := obj.GetObjectKind().GroupVersionKind()
	if len(gvk.Kind) == 0 {
		return nil, &gvk, runtime.NewMissingKindErr(string(data))
	}

	return obj, &gvk, nil
}

391 func (s unstructuredJSONScheme) decode(data []byte) (runtime.Object, error) {
	...
	// No Items field, so it wasn't a list.
	unstruct := &Unstructured{}
	//注意 look down，
	err := s.decodeToUnstructured(data, unstruct)
	return unstruct, err
}

343 func (unstructuredJSONScheme) decodeToUnstructured(data []byte, unstruct *Unstructured) error {
	m := make(map[string]interface{})
  // 注意
	if err := json.Unmarshal(data, &m); err != nil {
		return err
	}

	unstruct.Object = m

	return nil
}

```

