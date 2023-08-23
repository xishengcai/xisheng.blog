# golang apply AOP



## AOP 的核心概念
- 切面（Aspect） ：通常是一个类，在里面可以定义切入点和通知。
- 连接点（Joint Point） ：被拦截到的点，因为 Spring 只支持方法类型的连接点，所以在 Spring 中连接点指的就是被拦截的到的方法，实际上连接点还可以是字段或者构造器。
- 切入点（Pointcut） ：对连接点进行拦截的定义。
- 通知（Advice） ：拦截到连接点之后所要执行的代码，通知分为前置、后置、异常、最终、环绕通知五类。
- AOP 代理 ：AOP 框架创建的对象，代理就是目标对象的加强。Spring 中的 AOP 代理可以使 JDK 动态代理，也可以是 CGLIB 代理，前者基于接口，后者基于子类。



## golang code

```go
package main

import (
	"errors"
	"fmt"
)
// User
type User struct {
	Name string
	Pass string
}

// Auth 验证
func (u *User) Auth() {
	// 实际业务逻辑
	fmt.Printf("register user:%s, use pass:%s\n", u.Name, u.Pass)
}


// UserAdvice
type UserAdvice interface {
	// Before 前置通知
	Before(user *User) error

	// After 后置通知
	After(user *User)
}

// ValidatePasswordAdvice 用户名验证
type ValidateNameAdvice struct {
}

// ValidatePasswordAdvice 密码验证
type ValidatePasswordAdvice struct {
	MinLength int
	MaxLength int
}

func (ValidateNameAdvice) Before(user *User) error {
	fmt.Println("ValidateNameAdvice before")
	if user.Name == "admin" {
		return errors.New("admin can't be used")
	}

	return nil
}

func (ValidateNameAdvice) After(user *User) {
	fmt.Println("ValidateNameAdvice after")
	fmt.Printf("username:%s validate sucess\n", user.Name)
}

// Before 前置校验
func (advice ValidatePasswordAdvice) Before(user *User) error {
	fmt.Println("ValidatePasswordAdvice before")
	if user.Pass == "123456" {
		return errors.New("pass isn't strong")
	}

	if len(user.Pass) > advice.MaxLength {
		return fmt.Errorf("len of pass must less than:%d", advice.MaxLength)
	}

	if len(user.Pass) < advice.MinLength {
		return fmt.Errorf("len of pass must greater than:%d", advice.MinLength)
	}

	return nil
}

func (ValidatePasswordAdvice) After(user *User) {
	fmt.Println("ValidatePasswordAdvice after")
	fmt.Printf("password:%s validate sucess\n", user.Pass)
}

// UserAdviceGroup,通知管理组
type UserAdviceGroup struct {
	items []UserAdvice
}

// Add 注入可选通知
func (g *UserAdviceGroup) Add(advice UserAdvice) {
	g.items = append(g.items, advice)
}

func (g *UserAdviceGroup) Before(user *User) error {
	for _, item := range g.items {
		if err := item.Before(user); err != nil {
			return err
		}
	}

	return nil
}

// After
func (g *UserAdviceGroup) After(user *User) {
	for _, item := range g.items {
		item.After(user)
	}
}

// UserProxy 代理，也是切面
type UserProxy struct {
	user *User
}

// NewUser return UserProxy
func NewUser(name, pass string) UserProxy {
	return UserProxy{user:&User{Name:name, Pass:pass}}
}

// Auth 校验，切入点
func (p UserProxy) Auth() {
	group := UserAdviceGroup{}
	group.Add(&ValidatePasswordAdvice{MaxLength:10, MinLength:6})
	group.Add(&ValidateNameAdvice{})

	// 前置通知
	if err := group.Before(p.user); err != nil {
		panic(err)
	}

	// 实际逻辑
	p.user.Auth()

	// 后置通知
	group.After(p.user)

}


func main(){
	proxy := NewUser("xiaozhang","password")
	proxy.Auth()
}
```
