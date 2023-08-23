# Go结构体标签



结构体的字段除了名字和类型外，还可以有一个可选的标签（tag）：它是一个附属于字段的字符串，可以是文档或其他的重要标记。比如在我们解析json或生成json文件时，常用到encoding/json包，它提供一些默认标签，例如：omitempty标签可以在序列化的时候忽略0值或者空值。而-标签的作用是不进行序列化，其效果和和直接将结构体中的字段写成小写的效果一样。



```go
type Info struct {
    Name string
    Age  int `json:"age,omitempty"`
    Sex  string
}
```



```go
type Info struct {
    Name string
    Age  int   `json:"age,string"`
    //这样生成的json对象中，age就为字符串
    Sex  string
}
```



现在来了解下如何设置自定义的标签，以及如何像官方包一样，可以通过标签，对字段进行自定义处理。要实现这些，我们要用到`reflect`包。

```go
package main

import (
    "fmt"
    "reflect"
)

const tagName = "Testing"

type Info struct {
    Name string `Testing:"-"`
    Age  int    `Testing:"age,min=17,max=60"`
    Sex  string `Testing:"sex,required"`
}

func main() {
    info := Info{
        Name: "benben",
        Age:  23,
        Sex:  "male",
    }

    //通过反射，我们获取变量的动态类型
    t := reflect.TypeOf(info)
    fmt.Println("Type:", t.Name())
    fmt.Println("Kind:", t.Kind())

    for i := 0; i < t.NumField(); i++ {
        field := t.Field(i) //获取结构体的每一个字段
        tag := field.Tag.Get(tagName)
        fmt.Printf("%d. %v (%v), tag: '%v'\n", i+1, field.Name, field.Type.Name(), tag)
    }
}   
```

