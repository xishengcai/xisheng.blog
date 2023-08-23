# 观察者模式

观察者模式用于触发联动。

一个对象的改变会触发其它观察者的相关动作，而此对象无需关心连动对象的具体实现。

#### obserser.go

```go
package observer

import "fmt"

type Subject struct {
    observers []Observer
    context   string
}

func NewSubject() *Subject {
    return &Subject{
        observers: make([]Observer, 0),
    }
}

func (s *Subject) Attach(o Observer) {
    s.observers = append(s.observers, o)
}

func (s *Subject) notify() {
    for _, o := range s.observers {
        o.Update(s)
    }
}

func (s *Subject) UpdateContext(context string) {
    s.context = context
    s.notify()
}

type Observer interface {
    Update(*Subject)
}

type Reader struct {
    name string
}

func NewReader(name string) *Reader {
    return &Reader{
        name: name,
    }
}

func (r *Reader) Update(s *Subject) {
    fmt.Printf("%s receive %s\n", r.name, s.context)
}
```

#### obserser_test.go

```go
package observer

func ExampleObserver() {
    subject := NewSubject()
    reader1 := NewReader("reader1")
    reader2 := NewReader("reader2")
    reader3 := NewReader("reader3")
    subject.Attach(reader1)
    subject.Attach(reader2)
    subject.Attach(reader3)

    subject.UpdateContext("observer mode")
    // Output:
    // reader1 receive observer mode
    // reader2 receive observer mode
    // reader3 receive observer mode
}
```