# go-clone：极致优化深拷贝效率与拷贝私有字段



## 关于提升深拷贝效率的思考

前文所说的思路和方案，对于熟悉反射的开发者来说非常容易想到，属于常规解法了。不过我们都知道，反射的执行效率有限，对于字段较多的结构来说，深拷贝的效率会远低于浅拷贝。考虑到 Go 数据结构并不存在副作用，对于普通的数值类型可以直接浅拷贝，对于指针、接口、`map` 等类型也可以先浅拷贝再替换成新内容，这种拷贝方法会比通过反射来拷贝高效很多。

考虑以下数据结构。

```go
type T1 struct {
    A int
    B string
    C []float64
    d uint
}
```

如果我们手动进行深拷贝，最高效的方法如下所示：

```go
t := &T1{
    A: 123,
    B: "test",
    C: []float64{1.2, 3.4},
    d: 321,
}

var cloned T1
cloned = *t                          // 先做一次浅拷贝。
cloned.C = make([]float64, len(t.C)) // 申请新的内存空间。
copy(cloned.T, t.C)                  // 将 t.C 内容拷贝过来。
```

这里需要注意，`B string` 是可以直接浅拷贝的，在 Go 里面约定 `string` 是不可变（immutable）的，其中引用的字符串不会被轻易修改，甚至字面常量都放在了只读的内存空间中来确保真正的不可变。

## 深拷贝私有字段

在这个例子里面暗含了一个「彩蛋」：本来不可见的私有字段（unexported field）`d` 也被「顺便」深拷贝了。

如果按照反射的方法，所有私有字段都不可写（私有字段的 `reflect.Value` 中 `CanSet` 方法始终返回 `false`）， 从而也不能在深拷贝的时候写入数据，但现在使用这种先浅拷贝再深拷贝的方法会造成私有字段也被拷贝，假设其中包含指针之类类型，那么这个指针就会还指向老的数据结构，并没有真正达成深拷贝的目标，会造成潜在的问题。

想要提升拷贝效率，就得考虑怎么样才能完美的拷贝所有私有字段才行，要想做到这点就得了解 Go 数据结构的内存布局细节。

Go 为了能方便的与底层系统进行互操作，在数据结构的内存布局方面保持了非常严格的顺序性，使得我们可以有机会直接通过偏移量来得知每个字段，包括私有字段，在内存中的真实位置，借助 `unsafe` 库提供的不安全内存访问的能力就可以修改任意的私有字段。

下面这个例子展示了如何纯粹通过 `reflect` 和 `unsafe` 来深拷贝一个私有字段的指针。

```go
type T2 struct {
    A int
    p []int
}

t := &T2{
    A: 123,
    p: []int{1},
}

tt := reflect.TypeOf(t).Elem() // 拿到类型 T。
fieldP := tt.FieldByName("p")  // 拿到 p 的字段信息。

tv := reflect.ValueOf(t).Elem()    // 拿到 t 的反射值。
p := tv.FieldByIndex(fieldP.Index) // 拿到 t.p 的反射值，虽然不让写，但是可以读。

num := p.Len()
c := p.Cap()
clonedP := reflect.MakeSlice(fieldP.Type, num, c) // 构造一个新的 slice。
src := unsafe.Pointer(p.Pointer())       // 拿到 p 数据指针。
dst := unsafe.Pointer(clonedP.Pointer()) // 拿到 clonedP 数据指针。
sz := int(p.Type().Elem().Size())        // 计算出 []int 单个数组元素的长度，即 int 的长度。
l := num * sz                            // 得到 p 的数据真实内存字节数。
cc := c * sz                             // 得到 p 的 cap 真实内存字节数。

// 直接无视类型进行内存拷贝，相当于 C 语言里面的 memcpy。
copy((*[math.MaxInt32]byte)(dst)[:l:cc], (*[math.MaxInt32]byte)(src)[:l:cc])
 
var cloned T2
cloned = *t // 先做一次浅拷贝。
ptr := unsafe.Pointer(uintptr(unsafe.Pointer(&cloned)) + fieldP.Offset) // 拿到 p 的真实内存位置。

// 这里已知 p 是一个 slice，用 `SliceHeader` 进行强制拷贝，相当于做了 cloned.p = clonedP。
*(*reflect.SliceHeader)(p) = reflect.SliceHeader{
    Data: dst,
    Len:  num,
    Cap:  c,
}
```

很显然上面这段代码非常的折腾，涉及不少 Go runtime 层面上的概念和技巧，我们来逐段仔细看一下。为了方便叙述，上面的代码里直接假定我们已经知道 p 是个 []int，这样就不用写大量 switch...case 判断 Kind，让本来就挺难理解的代码变得更难读了。如果希望看到完整的类型判断逻辑，可以参考源码 [https://github.com/huandu/go-clone/blob/v1.1.2/clone.go#L291](https://link.zhihu.com/?target=https%3A//github.com/huandu/go-clone/blob/v1.1.2/clone.go%23L291)。

首先，能拷贝私有字段的前提是，我们可以通过 `reflect` 库读到私有字段的类型定义和数据，只读不能写，假如读都读不到，那就一点办法都没有了。

其次，在拿到字段 `p` 的类型信息 `fieldP` 之后，我们就可以轻松通过 `field.Type` 得知 `p` 的类型，从而可以通过 `Kind` 来区分不同类型的不同代码逻辑。在 `fieldP` 里面有个非常关键点字段 `fieldP.Offset`，它表示 `p` 相对结构指针的头部的偏移量。

下面这个等式是始终正确的。

```go
unsafe.Pointer(&t.p) == unsafe.Pointer(uintptr(unsafe.Pointer(t)) + fieldP.Offset)
```

知道 `p` 真实内存位置之后就能做很多事情了，比如直接进行内存拷贝。同理，由于 slice 数据的内存是连续的，一旦知道了真实的内存地址之后也可以直接进行数据拷贝，完成 slice 内容的复制。

具体内存拷贝的方法就是下面这段代码。

```go
copy((*[math.MaxInt32]byte)(dst)[:l:cc], (*[math.MaxInt32]byte)(src)[:l:cc])
```

它的原理是：先将 `dst` 和 `src` 这样的 `unsafe.Pointer` 强制转成 `[math.MaxInt32]byte` 类型，然后再对这个伪装的数组进行 slice 操作，将要拷贝的内容切出来生成合法的 `[]byte`，最后交给 `copy` 来拷贝数据。

最后，还需要注意 slice 结构本身并不是一个指针，而是包含了几个字段的结构，具体定义放在 `reflect.SliceHeader` 这里。

## 减少反射使用的次数

反射使用过多就影响效率，我们可以看到，业务中大多数 Go 数据结构的字段类型都是数值类型（比如各种 int、float 等），特别是那些只包含数值类型的 Go 数据结构，简单的做一次浅拷贝就能完成所有工作，这样处理肯定比每次都用 `reflect` 遍历所有字段进行逐一拷贝来得快很多。

可以想到，如果能预先缓存类型信息，仅仅标记出类型中必须进行深拷贝的字段就好了，这样每个类型至多只做一次反射，剩下的拷贝就可以完全交给各种 `unsafe` 内存操作就好了。

在当前实现中，我们定义了一个类型 `type structType`，用于记录结构里面需要进行深拷贝的字段信息，没有记录在内的字段信息就是可以浅拷贝的数值字段。

```go
type structType struct {
    PointerFields []structFieldType
}

type structFieldType struct {
    Offset uintptr // The offset from the beginning of the struct.
    Index  int     // The index of the field.
}
```

具体生成这个类型数据的代码放在 [https://github.com/huandu/go-clone/blob/v1.1.2/structtype.go#L51](https://link.zhihu.com/?target=https%3A//github.com/huandu/go-clone/blob/v1.1.2/structtype.go%23L51) 这里，思路比较简单直接：遍历结构的每个字段，判断是否是数值类型，如果不是，生成 `structFieldType` 并放入到 `structType` 的 `PointerFields` 里面。

由于 Go 数据结构的类型定义不会在运行时进行修改，为了避免经常重复的分析一个类型，实际中我们用了一个 `sync.Map` 类型的全局变量 `cachedStructTypes` 类记录历史分析结果。

## 定义特殊的数值类型结构体

有一些 Go 结构体，看起来像是包含了指针需要深拷贝，但实际上应该始终当做值类型来使用。

这里面有下面几个典型的类型，我们正常使用的时候在函数中都是传值，而不是传指针：

- `time.Time` 表示时间，这里面虽然有一个 `loc *time.Location` 字段，但实际上不需要拷贝，这个 `loc` 指向的是一段只读的内容。
- `reflect.Value` 表示反射值，这里面有比较复杂的指针信息，但由于这个值仅仅是一个实际类型的「代理」，深度拷贝这个数据并无实际意义。

相信在业务代码中也可能会有类似的数值类型结构体，为了能争取处理这些情况，代码里提供了一个 `MarkAsScalar` 的函数，将这些类型统统加入到一个全局白名单里面，凡是这些类型的字段都会被看做简单的数值进行浅拷贝。

此外，还有 `reflect.Type` 这个特殊的 `interface` 也需要单独处理，它实际是 `*reflect.rtype` 类型，这个类型指向程序的只读内存空间，也不应该深度拷贝。不过由于它的独特性，没有任何一个类型与之相似，代码中就直接进行了特殊处理。

## 拷贝函数指针

经过上面的探索，基本解决了大部分的深拷贝问题，但实际中发现还有一个非常难啃的硬骨头，即函数指针的拷贝。

如果我们有下面的数据结构：

```go
type T3 struct {
    fn func()
}
```

这个 `fn` 本质上是一个指针，考虑到函数本身在运行时是只读的，一般情况下简单当做 `uintptr` 拷贝值就好了。

但凡是都有万一，当遇到下面这种非常复杂的情况时，浅拷贝并不可行。

```go
type T4 struct {
    fn func() int
    m  map[int]interface{}
}

t := T4{
    m: map[int]interface{}{
        0: T4{
            fn: bytes.NewBuffer(nil).Len, // fn 指向一个绑定了 receiver 的方法。
        },
    },
}
```

很显然，在拷贝 `m` 的时候必须遍历这个 `map` 所有元素，拿到 `interface{}` 具体值再进行拷贝。由于 `reflect` 接口的限制，在这个场景中我们无法拿到 `T4` 的内存位置，只能用老方法去遍历每个字段进行逐一拷贝，正常情况下一切都没问题，但很不幸的是，唯独只有当 `fn` 指向一个绑定了 receiver 的方法的时候，`reflect.Value` 的 `Pointer` 方法返回的地址是个假地址，这导致我们无法正确拷贝 `fn` 的值。

Go runtime 里面相关代码如下：

```go
func (v Value) Pointer() uintptr {
    k := v.kind()
    switch k {
    // 省略...

    case Func:
        if v.flag&flagMethod != 0 {
            // As the doc comment says, the returned pointer is an
            // underlying code pointer but not necessarily enough to
            // identify a single function uniquely. All method expressions
            // created via reflect have the same underlying code pointer,
            // so their Pointers are equal. The function used here must
            // match the one used in makeMethodValue.
            f := methodValueCall
            return **(**uintptr)(unsafe.Pointer(&f))
        }

    // 省略...
}
```

可以看到，当 `flagMethod` 标记设上时，即上面所说的这种 `fn` 的值， `Pointer` 方法不会诚实的返回函数指针。 Go 这样设计很可能是为了掩盖 runtime 在函数指针上做的 trick：一般来说，`fn` 指向一个函数指针，即代码段的内存位置，但 Go 为了能让函数指针绑定 receiver， 在这种情况下 `fn` 会指向一个包含了上下文信息的结构，`reflect` 为了在这种状况下依然让调用者感觉 `fn` 是一个代码段地址就做了这个伪装。

关于 Go runtime 怎么实现函数指针，详见官方文档 [https://golang.org/s/go11func](https://link.zhihu.com/?target=https%3A//golang.org/s/go11func)。

为了解决这个问题，我们重新思考了这个细节的拷贝策略。如果拿不到真实的值同时又不想过度依赖 Go runtime 的具体实现，还有一个简单可行的方法是使用 `reflect.Value` 的 `Set` 方法直接设置值（回到最原始的方案），但这里面有个前提是字段必须 `CanSet`，且设置进去的值不能是私有字段。

以下是 Go `reflect` 库的相关代码：

```go
// Set assigns x to the value v.
// It panics if CanSet returns false.
// As in Go, x's value must be assignable to v's type.
func (v Value) Set(x Value) {
    v.mustBeAssignable() // v 必须 CanSet。
    x.mustBeExported()   // x 必须不能是私有字段。

    // 省略...
}

// mustBeExported panics if f records that the value was obtained using
// an unexported field.
func (f flag) mustBeExported() {
    if f == 0 || f&flagRO != 0 {
        // 调用 panic...
    }
}
```

因此，为了能够正常的调用 `Set` 方法，我们不得不拿出终极大招，直接篡改 `reflect.Value` 里面的标志位，关键就是去掉 `fn` 这个私有字段的 `flagRO` 标志位。

直接去 hack `reflect.Value` 的私有字段是不靠谱的，未来太难以维护，考虑到我们可以相对安全的浅拷贝 `interface{}` ，可以通过一个空接口进行中转而间接的去掉这个标记位且不破坏其他的标记。

```go
// typeOfInterface 是 interface{} 这种类型本身。
var typeOfInterface = reflect.TypeOf((*interface{})(nil)).Elem()

// forceClearROFlag clears all RO flags in v to make v accessible.
// It's a hack based on the fact that InterfaceData is always available on RO data.
// This hack can be broken in any Go version.
// Don't use it unless we have no choice, e.g. copying func in some edge cases.
func forceClearROFlag(v reflect.Value) reflect.Value {
    var i interface{}

    v = v.Convert(typeOfInterface) // 将任意的类型强制转成 interface{}，确保 v 内存布局可控。
    nv := reflect.ValueOf(&i)      // i 是局部变量，不会设置 flagRO。
    *(*[2]uintptr)(unsafe.Pointer(nv.Pointer())) = v.InterfaceData() // 浅拷贝 v 的内容到 i.
    return nv.Elem().Elem() // 返回原来 v 指向的真实内容。
}
```

至此，我们就可以正常的通过 `Set` 来设置这个反射值了，最后再将复制出来的值通过内存操作拷贝到结构里面去即可。

## 小结

通过利用 Go 数据结构内存布局的特点，先进行浅拷贝再对有需要的字段进行深拷贝，并且预先将结构字段的类型信息缓存起来方便处理，这样可以极大的提升拷贝性能。对于字段都是纯数值类型来说，可以提升超过一个数量级的性能；对于本身就很复杂的类型来说，也会因为减少了反射调用而提升几倍性能。具体的测试结果可以看项目的 README。

基于这种非常彻底和高效的深拷贝，使得我们甚至于可以用这种技术来实现一些原来不敢想的功能，比如 Go 的 immutable data，这也就是 [clone.Wrap](https://link.zhihu.com/?target=https%3A//pkg.go.dev/github.com/huandu/go-clone%3Ftab%3Ddoc%23Wrap)、[clone.Unwrap](https://link.zhihu.com/?target=https%3A//pkg.go.dev/github.com/huandu/go-clone%3Ftab%3Ddoc%23Unwrap) 和 [clone.Undo](https://link.zhihu.com/?target=https%3A//pkg.go.dev/github.com/huandu/go-clone%3Ftab%3Ddoc%23Undo) 实现的功能了，通过这些 API 我们可以做到数据透明的保存和重置，模拟其他语言的 immutable 特性。这方面的实现细节也挺多的，未来有机会再分享吧。