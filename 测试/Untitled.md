​	测试工具





- 

  gomoc

  



​       gomock 是官方提供的 mock 框架，同时还提供了 mockgen 工具用来辅助生成测试代码。





mockgen 用于生成实现接口对象





- 

  mock 作用的是接口，因此将依赖抽象为接口，而不是直接依赖具体的类。

  

- 

  不直接依赖的实例，而是使用依赖注入降低耦合性。

  









- 

  monkey

  

- 

  PatchInstanceMethod(target reflect.Type, methodName string, replacement interface{}) *PatchGuar

  

- 

  Patch(target, replacement interface{}) *PatchGuard

  

- 

  Unpatch(target interface{}) bool

  

- 

  UnpatchAll()

  









gomock example





```
ctrl := gomock.NewController(t)	defer ctrl.Finish() // 断言 DB.Get() 方法是否被调用	m := NewMockDB(ctrl)
    // mock 对象m 的Get 方法，对Get 方法的参数进行打桩，当参数 == Tom 时，返回错误	m.EXPECT().Get(gomock.Eq("Tom")).Return(100, errors.New("not exist"))
打桩的参数可以是 参数(Eq（value）, Any, Not（value), Nil)





Plain Text
```





monkey 典型测试用例分享





```
func TestInstall2(t *testing.T) {   tests := []struct {      Title string      Install2      ExceptError error      MockFunc    func(ins *Install2)	  UnPatchFunc     func(ins *Install2)   }{		{			Title: "Install success",			Install2： Install2{				依赖的接口： New接口对象			}，			ExceptError: nil,			MockFunc: func(ins *Install2){			  monkey.PatchInstanceMethod(reflect.TypeOf(ins.依赖对象), "被依赖对象的方法", func(){}			}		},	}	for _, item := range tests {		t.Log("title: ", item.Title)		// 现执行相关mock		item.MockFunc(&item.Install)		resp := item.Run()		if resp.HasError() {			assert.Assert(t, resp.Error() == item.ExceptError))		}		item.UnPatchFunc(&item.Install)	}
}



Plain Text
```











建议做法





1. 

   使用创建者方法，构建依赖对象，放入测试实例

   

2. 

   使用类似代理方法，对测试用例中的依赖对象进行Patch，UnPatch

   



特殊情况处理





1. 

   mockgen 生成的方法对err 进行了却省处理，安全检测无法通过，需要放入test 文件

   

2. 

   如果使用 gomock 的打桩对期望参数构造比较难的，可以使用Any

   

3. 

   monkey 没有gomoc 类似 修改打桩参数的方法，需要自己实现

   



```go
monkey.PatchInstanceMethod(reflect.TypeOf(l.MongoHelp), "ListAll",					func(_ *test.MockHelper, ctx context.Context, option mongo.ListOption, coll string, obj interface{}) (int64, error) {						x, ok := obj.(*[]models.Instance)						if !ok {							panic("obj is not Instance")						}						ins := getInstance()						*x = append(*x, ins...)						return 10, nil					})




Plain Text
```