# error 优雅处理



问题： golang  一个方法里面有多个方法要执行， 每个方法都要判断，当有一个内方法发生error 的时候停止往下执行，直接跳出外方法并返回错误。有什么简单的方法可以避免多个if。。。else 。。。。 判断？

```
func extranlMethod() error{
		interMethod_1()
		interMethod_2()
		interMethod_3()
		interMethod_4()
}
```

