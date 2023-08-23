# k8s: garbage collector
GC is short of Garbage Collector. 清理kubernetes中 符合特定条件的 Resource Object



## What are dependent mechanisms to clear needless resource objects?

Kubernetes 在不同的 Resource Objects 中维护一定的「从属关系」。内置的 Resource Objects 
一般会默认在一个 Resource Object 和它的创建者之间建立一个「从属关系」。当然，
你也可以利用ObjectMeta.OwnerReferences自由的去给两个 Resource Object 建立关系，
前提是被建立关系的两个对象必须在一个 Namespace 下

```go
// OwnerReference contains enough information to let you identify an owning
// object. Currently, an owning object must be in the same namespace, so there
// is no namespace field.
type OwnerReference struct {
    // API version of the referent.
    APIVersion string `json:"apiVersion" protobuf:"bytes,5,opt,name=apiVersion"`
    // Kind of the referent.
    // More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#types-kinds
    Kind string `json:"kind" protobuf:"bytes,1,opt,name=kind"`
    // Name of the referent.
    // More info: http://kubernetes.io/docs/user-guide/identifiers#names
    Name string `json:"name" protobuf:"bytes,3,opt,name=name"`
    // UID of the referent.
    // More info: http://kubernetes.io/docs/user-guide/identifiers#uids
    UID types.UID `json:"uid" protobuf:"bytes,4,opt,name=uid,casttype=k8s.io/apimachinery/pkg/types.UID"`
    // If true, this reference points to the managing controller.
    // +optional
    Controller *bool `json:"controller,omitempty" protobuf:"varint,6,opt,name=controller"`
    // If true, AND if the owner has the "foregroundDeletion" finalizer, then
    // the owner cannot be deleted from the key-value store until this
    // reference is removed.
    // Defaults to false.
    // To set this field, a user needs "delete" permission of the owner,
    // otherwise 422 (Unprocessable Entity) will be returned.
    // +optional
    BlockOwnerDeletion *bool `json:"blockOwnerDeletion,omitempty" protobuf:"varint,7,opt,name=blockOwnerDeletion"`
}
```

OwnerReference 一般存在于某一个 Resource Object 信息中的metadata 部分。

OwnerReference中的字段可以唯一的确定 k8s 中的一个 Resource Object。两个 Object 可以通过这种方式建立一个 owner-dependent的关系。

K8s 实现了一种「Cascading deletion」（级联删除）的机制，它利用已经建立的「从属关系」进行资源对
象的清理工作。例如，当一个 dependent 资源的 owner 已经被删除或者不存在的时候，从某种角度就可以判定，
这个 dependent 的对象已经是异常（无人管辖）的了，需要进行清理。而 「cascading deletion」则是被 k8s 中的一个 controller 
组件实现的：Garbage Collector。所以，k8s 是通过 Garbage Collector 和 ownerReference 一起配合实现了「垃圾回收」的功能。



[K8s GC Design Principle](https://zhuanlan.zhihu.com/p/50101300)
