<!-- toc -->
# Golang　代码规范



### 注释语句

  参考 [https://golang.org/doc/effective_go.html#commentary] 

  所有导出的名称、函数声明、结构声明等都应该有注释  

  Go语言提供C风格的`/* */`块注释和C++风格的`//`行注释。

  包应该有一个包注释，对于多文件包，注释只需要出现在任意一个文件中。包注释应当提供整个包相关的信息。

  注释的句子应当具有完整性，这使得它们在提取到文档时能保持良好的格式。使用godoc时包注释将与声明一起提取，作为项目的解释性文本。这些注释的风格和内容决定了文档的质量。

  注释应当以描述的事物名称开头，以句点（或者 ! ? ）结束。

  参考以下格式：

```go
// Request represents a request to run a command.
type Request struct { ...

// Encode writes the JSON encoding of req to w.
func Encode(w io.Writer, req *Request) { ...
```
```go
/*
Package regexp implements a simple library for regular expressions.

The syntax of the regular expressions accepted is:

    regexp:
        concatenation { '|' concatenation }
    concatenation:
        { closure }
    closure:
        term [ '*' | '+' | '?' ]
    term:
        '^'
        '$'
        '.'
        character
        '[' [ '^' ] character-ranges ']'
        '(' regexp ')'
*/
package regexp
```
### 包的注释

与godoc呈现的所有注释一样，包的注释必须出现在package子句的旁边，且不带空行：

```go
// Package math provides basic constants and mathematical functions.
package math
```

```go
/*
Package template implements data-driven templates for generating textual
output such as HTML.
....
*/
package template
```

对于main包的注释，很多种注释格式都是可以接受的，比如在目录`seedgen`中的 `package main`包，注释可以这下写:

``` go
// Binary seedgen ...
package main
```
或
```go
// Command seedgen ...
package main
```
or
```go
// Program seedgen ...
package main
```
或
```go
// The seedgen command ...
package main
```
或
```go
// The seedgen program ...
package main
```
或
```go
// Seedgen ..
package main
```
请注意，以小写字母开头的句子不在包注释的可接受选项中，因为包是公开可见的，应当用合适的英语格式写成，包括将第一个词首字母大写。

[获取更多有关包注释的规范](https://golang.org/doc/effective_go.html#commentary)

### 命名规范
原则：　见名知意，短小精悍，不允许在命名时中使用@、$和%等标点符号

**函数命名：**
- 驼峰规则

**结构体：**
- 采用驼峰命名法，首字母根据访问控制大写或者小写

**包名:**
- 保持package的名字和目录保持一致，尽量采取有意义的包名，简短，有意义，尽量和标准库不要冲突。
- 包名应该为小写单词，不要使用下划线或者混合大小写。

**文件命名:**
- 尽量采取有意义的文件名，简短，有意义，应该为小写单词
- 使用下划线分隔各个单词。

**接口命名:**
- 命名规则基本和上面的结构体类型相同
- 单个函数的结构名以 “er” 作为后缀，例如 Reader , Writer 

**常量:**
- 常量均需使用全部大写字母组成，并使用下划线分词

**变量:**

和结构体类似，变量名称一般遵循驼峰法，首字母根据访问控制原则大写或者小写，但遇到特有名词时，需要遵循以下规则：

- 如果变量为私有，且特有名词为首个单词，则使用小写，如 apiClient
- 其它情况都应当使用该名词原有的写法，如 APIClient、repoID、UserID
- 若变量类型为 bool 类型，则名称应以 Has, Is, Can 或 Allow 开头

**组合名**
- Go语言决定使用MixedCaps或mixedCaps来命名由多个单词组合的名称，而不是使用下划线来连接多个单词。即使它打破了其他语言的惯例。
例如，未导出的常量名为`maxLength` 而不是`MaxLength` 或 `MAX_LENGTH`。

### 错误处理
- 错误处理的原则就是不能丢弃任何有返回err的调用，不要使用 _ 丢弃，必须全部处理。接收到错误，要么返回err，或者使用log记录下来
- 尽早return：一旦有错误发生，马上返回
- 尽量不要使用panic，除非你知道你在做什么
- 错误描述如果是英文必须为小写，不需要标点结尾
- 采用独立的错误流进行处理

### Gofmt
  你可以在你的代码中运行 [Gofmt](https://golang.org/cmd/gofmt/) 以解决大多数代码格式问题。几乎所有的代码都使用 `gofmt`。如果使用[liteide](https://github.com/visualfc/liteide)编写Go代码时，使用ctrl+s即可调用gofmt。

  另一种方法是使用 [goimports](https://godoc.org/golang.org/x/tools/cmd/goimports)，它是 `gofmt`的超集，可根据需要添加（删除）行。

### 方法规范
- 单一职责
- 注释方功能
- 注释变量和返回值
- 对于一些关键位置的代码逻辑，或者局部较为复杂的逻辑，需要有相应的逻辑说明，方便其他开发者阅读该段代码

### 包管理
尽量避免导入包时的重命名，以避免名称冲突。如果发生名称冲突，尽量重命名本地或项目特定的包。

导入包按名称分组，用空行隔开。

标准库包应始终位于第一组。

```go
package main

import (
	"fmt"
	"hash/adler32"
	"os"

	"appengine/foo"
	"appengine/user"

        "github.com/foo/bar"
	"rsc.io/goversion/version"
)
```
可以使用 [goimports](https://godoc.org/golang.org/x/tools/cmd/goimports) 来规范包的排序。

### 单元测试
单元测试文件命名规范　example_test.go

测试用例的函数名称必须以Test开头

使用数组存放多个测试条件结构体，然后遍历数组，断言result vs except

测试失败时应当返回有效的错误信息，说明错误在哪，输入是什么，输出时什么，期望输出是什么。

一个典型的测试条件形如：

```go
if got != tt.want {
	t.Errorf("Foo(%q) = %d; want %d", tt.in, got, tt.want) // or Fatalf, if test can't test anything more past this point
}
```

请注意此处的命令是 `实际结果 != 预期结果`.一些测试框架鼓励程序员编写： 0 != x, "expected 0, got x"，go并不推荐。

在任何情况下，您有责任提供有用的错误信息，以便将来调试您的代码。

### 项目完整性
- 架构设计文档
- 项目功能
- 编译和打包镜像的脚本
- 必须使用go mod 进行版本控制

### Goroutine 生命周期

当你需要使用goruntines时，请确保它们什么时候/什么条件下退出。

Goroutines可能会因阻塞channel的send或者receives而泄露,即使被阻塞的通道无法访问，垃圾收集器也不会终止goroutine。

即使gorountine没有泄露，当不再需要它们时仍在继续运行会导致难以诊断的问题。即使在不需要结果后，修改正在使用的数据也会导致数据竞争。

尽量保证并发代码足够简单，使gorountine的生命周期更明显。如果难以做到，请记录gorountines退出的时间和原因。

### 空切片

当声明一个空切片时， 使用

```go
var t []string
```

而不是

```go
t := []string{}
```

### 传值

不要仅仅为了节省几个字节而传指针给函数。如果函数仅仅将其参数"x"作为`*x`使用，那么参数就不应该是指针。

常见的传指针的情况有：传递一个string的指针、指向接口值(`*io.Reader`)的指针;这两种情况下，值本身都是固定的，可以直接传递。

对于大型数据结构，或者是小型的可能增长的结构，请考虑传指针。

[goLang slice 和 array区别](https://segmentfault.com/a/1190000013148775)

更多情况请见 [Receiver Type](#receiver-type)

### Contexts

Go提供了`context`包来管理gorountine的生命周期。

`context.Context`类型的值包括了跨API和进程边界的安全凭证，跟踪信息，结束时间和取消信号。

使用context包时请遵循以下规则：

* 不要将 Contexts 放入结构体，context应该作为第一个参数传入。 不过也有例外，函数签名(method signature)必须与标准库或者第三方库中的接口相匹配
```go
func F(ctx context.Context, /* other arguments */) {}
```
* 即使函数允许，也不要传入nil的 Context。如果不知道用哪种 Context，可以使用context.TODO()

* 使用context的Value相关方法只应该用于在程序和接口中传递的和请求相关的元数据，不要用它来传递一些可选的参数

* 相同的 Context 可以传递给共享结束时间、取消信号、安全凭证和父进程追踪等信息的多个goroutine，Context 是并发安全的

* 从不做特定请求的函数可以使用 context.Background()，但即使您认为不需要，也可以在传递Context时使用错误(error)。如果您有充分的理由认为替代方案是错误的，那么只能直接使用context.Background()

* 不要在函数签名中创建Context类型或者使用Context以外的接口。

官方使用context的例子：
```go
package main

import (
    "context"
    "fmt"
    "time"
)

func main() {
    d := time.Now().Add(50 * time.Millisecond)
    ctx, cancel := context.WithDeadline(context.Background(), d)

    // Even though ctx will be expired, it is good practice to call its
    // cancelation function in any case. Failure to do so may keep the
    // context and its parent alive longer than necessary.
    defer cancel()

    select {
    case <-time.After(1 * time.Second):
        fmt.Println("overslept")
    case <-ctx.Done():
        fmt.Println(ctx.Err())
    }
}
```
### Receiver 

#### 名称
方法receiver的名称应该反映其身份；通常，其类型的一个或两个字母缩写就足够了(例如"client"的"c"或"cl")。请不要使用通用名称如"me", "this" 或 "self"。请始终保持名称不变，如果你在一个地方命名receiver为 "c"，那么请不要在另一处叫其"cl"
#### 指针还是值
如果您不知道怎么决定，请使用指针。但有时候receiver为值也挺有用，这种通常是出于效率的原因，且值为小的不变结构或基本类型的值。

一些建议：
* 请不要使用指针，如果满足receiver为map，func或者chan，或receiver为切片并且该方法不会重新分配切片
* 请不要使用指针，如果receiver是较小数组或结构体，没有可变的字段和指针，或者是一个简单的基本类型，int或者string
* 请使用指针，如果方法需要改变receiver
* 请使用指针，以避免被拷贝，如果receiver包含了sync.Mutex 或类似同步字段的结构
* 请使用指针，以提升效率，如果receiver是较大的数组或结构体
* 请使用指针，如果需要在方法中改变receiver的值
* 请使用指针，如果receiver是结构体，数组或切片这种成员是一个指向可变内容的指针
* 请使用指针，如果不清楚该如何选择


### 使用crypto rand生成随机值

请不要使用包 `math/rand` 来生成密钥，即使是一次性的。如果不提供种子，则密钥完全可以被预测到。就算用`time.Nanoseconds()`作为种子，也仅仅只有几个位上的差别。

使用`crypto/rand`'s Reader作为代替。并且如果你需要生成文本，打印成16进制或者base64类型即可。

``` go
import (
    "crypto/rand"
    // "encoding/base64"
    // "encoding/hex"
    "fmt"
)

func Key() string {
    buf := make([]byte, 16)
    _, err := rand.Read(buf)
    if err != nil {
        panic(err)  // out of randomness, should never happen
    }
    return fmt.Sprintf("%x", buf)
    // or hex.EncodeToString(buf)
    // or base64.StdEncoding.EncodeToString(buf)
}
```

## 代码走读检查点

### 检查业务逻辑
    - 操作顺序， 如：删除操作，先处理业务，再删除库

### 异常场景是否考虑完全
    - 网络中断异常
    - 多使用场景的，是否列举全面
    - 依赖的第三方服务暂停或升级

### goroutine 是否存在内存泄漏
    - 发送到一个没有接受者的channel
    - 从没有发送者的channel中接受数据
    - 传递尚未初始化的channel
    - goroutine 泄露不仅仅是因为 channel 的错误使用造成的。泄露的原因也可能是 I/O 操作上的堵塞，例如发送请求到 API 服务器，而没有使用超时。另一种原因是，程序可以单纯地陷入死循环中

### 是否存在过多的重复代码，可以抽象
    - log 打印尽量放到最外层

### 并发操作是否安全
    - map 并发写要加锁
    - 数据库记录修改需要使用带判断的原子操作修改, update ... set ... where condition
    - 使用锁的要记得解锁, defer unlock

### 数据库操作
    - 最大连接数设置
    - 失败重连接
    - 失败后是否需要回滚操作
    - 插入前数据库重复条目检查
    - 删除前关联应用是否已经删除