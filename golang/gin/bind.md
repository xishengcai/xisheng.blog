# gin bind 源码阅读



## gin 支持哪些参数bind

- query
- uri
- form
- body



## background knowledge



### relect.Value

```go
// Kind returns v's Kind. If v is the zero Value (IsValid returns false), Kind returns Invalid.
// A Kind represents the specific kind of type that a Type represents. The zero Kind is not a valid kind.
func (v Value) Kind() Kind

// Type is the representation of a Go type.
// Not all methods apply to all kinds of types. Restrictions, if any, are noted in the documentation for each  method. Use the Kind method to find out the kind of type before calling kind-specific methods. Calling a method inappropriate to the kind of type causes a run-time panic.
func (v Value) Type() Type

// Elem returns a type's element type.
// It panics if the type's Kind is not Array, Chan, Map, Pointer, or Slice.
Elem() Type


```

## associate interface







## bind detail





```go

// setter get from gin.Params
// tag "uri","form","body","header"
// value  any( receive frontend params, struct of user defined)
// field one struct field
// 1. validate tag
// 2. 期望 value.Kind == Struct
// 3. 遍历 field， get value.Field(i), structField
// 4. 只有在非struct 的情况下，属于基本类型，才尝试设置value，tryToSetValue
// 5. setter.TrySet(value, field, tagValue, setOpt)
func mapping(value reflect.Value, field reflect.StructField, setter setter, tag string) (bool, error)

// A StructField describes a single field in a struct.
type StructField struct {
	// Name is the field name.
	Name string

	// PkgPath is the package path that qualifies a lower case (unexported)
	// field name. It is empty for upper case (exported) field names.
	// See https://golang.org/ref/spec#Uniqueness_of_identifiers
	PkgPath string

	Type      Type      // field type
	Tag       StructTag // field tag string
	Offset    uintptr   // offset within struct, in bytes
	Index     []int     // index sequence for Type.FieldByIndex
	Anonymous bool      // is an embedded field
}
```

