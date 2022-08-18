# 适配器模式

适配器模式用于转换一种接口适配另一种接口。

实际使用中Adaptee一般为接口，并且使用工厂函数生成实例。

在Adapter中匿名组合Adaptee接口，所以Adapter类也拥有SpecificRequest实例方法，又因为Go语言中非入侵式接口特征，其实Adapter也适配Adaptee接口。

#### adapter.go

```go
package adapter

//Target 是适配的目标接口
type Target interface {
    Request() string
}

//Adaptee 是被适配的目标接口
type Adaptee interface {
    SpecificRequest() string
}

//NewAdaptee 是被适配接口的工厂函数
func NewAdaptee() Adaptee {
    return &adapteeImpl{}
}

//AdapteeImpl 是被适配的目标类
type adapteeImpl struct{}

//SpecificRequest 是目标类的一个方法
func (*adapteeImpl) SpecificRequest() string {
    return "adaptee method"
}

//NewAdapter 是Adapter的工厂函数
func NewAdapter(adaptee Adaptee) Target {
    return &adapter{
        Adaptee: adaptee,
    }
}

//Adapter 是转换Adaptee为Target接口的适配器
type adapter struct {
    Adaptee
}

//Request 实现Target接口
func (a *adapter) Request() string {
    return a.SpecificRequest()
}
```

#### adapter_test.go

```go
package adapter

import "testing"

var expect = "adaptee method"

func TestAdapter(t *testing.T) {
    adaptee := NewAdaptee()
    target := NewAdapter(adaptee)
    res := target.Request()
    if res != expect {
        t.Fatalf("expect: %s, actual: %s", expect, res)
    }
}
```