---
title: "golang 单元测试"
date: 2020-7-28T17:24:33+08:00
draft: true
---

Golang 单元测试方案
1. 什么是单元测试
1.1 定义
单元测试（又称为模块测试）是针对程序模块(软件设计的最小单位)来进行正确性检验的测试工作。程序单元是应用的最小可测试部件。在过程化编程中，一个单元就是单个程序、函数、过程等；对于面向对象编程，最小单元就是方法，包括基类（超类）、抽象类、或者派生类（子类）中的方法。

1.2 单元测试任务包括：
1 模块接口测试；
2 模块局部数据结构测试；
3 模块边界条件测试；
4 模块中所有独立执行通路测试；
5 模块的各条错误处理通路测试。

1.3 go中的单元测试
1.单元测试文件名必须以xxx_test.go命名
2.方法必须是TestXxx开头
3.方法参数必须 t *testing.T
4.测试文件和被测试文件必须在一个包中

2. 如何写一个健壮的单元测试
在任何时间，任何地点都可以运行，原则上测试结束，不应该对研发环境产生影响，数据库也不应该有任何修改，这是一个非常困扰程序员的难题，主要涉及如下几点：
1.数据库依赖
2.外部程序或环境依赖：
3.顺序依赖：

2.1 测试数据构造
单元测试的一个重点就是测试数据的构造，在测试数据构造时要考虑这样几个方面：
1.正常输入，整个必不可少，至少验证函数的正常逻辑是否通过
2.边界输入，这个主要验证在极端情况下的输入，函数是否在有相应的容错处理
3.非法输入，对于一些非正常输入，我们要看函数是否处理，会不引起函数的奔溃和数据泄露等问题
4.白盒覆盖，白盒覆盖就要设计了，要设计一些用力，能够覆盖到函数的所有代码，这里主要考虑：语句覆盖、条件覆盖、分支覆盖、分支/条件覆盖、条件组合覆盖。


2.2 编写原则
单元测试是要写额外的代码的，这对开发同学的也是一个不小的工作负担，在一些项目中，我们合理的评估单元测试的编写，我认为我们不能走极端，当然理论上来说全写肯定时好的，但是从成本，效率上来说我们必须做出权衡。所以这里给出一些衡量的原则
1.优先编写核心组件和逻辑模块的测试用例
2.发现Bug时一定先编写测试用例进行Debug
3.关键util工具类要编写测试用例，这些util工具适用的很频繁，所以这个原则也叫做热点原则，和第1点相呼应。
4.测试用户应该独立，一个文件对应一个，而且不同的测试用例之间不要互相依赖。
5.测试用例的保持更新。

2.3单元测试Demo
2.3.1普通方法测试

2.3.2 HTTP API测试


接口测试由于要使用router包，但是router包引用了service，如果在service包中写单元测试，会导致循环导包的问题，所以这里我的API测试是放在项目根目录 test下。这样会导致service的覆盖检测不足。
2.3.3 数据库依赖测试
本地安装数据库
2.3.4 依赖外部不可达的远程接口测试
使用mock, http://8.14.0.108/lstack-hybrid/lstack-container-registry/lsh-mcp-lcr-cops/-/blob/caixisheng/service/pipelinegroup_service/pipelinegroup_authority_test.go

先对不可达的方法，创建接口

依赖的对象引入接口，比如参数A依赖远程接口调用，在A对象里面加入接口属性


命令生成接口对: 
mockgen --source pipelinegroup_authority.go -destination pipelinegroup_authority_mock.go -package pipelinegroup_service


写测试用例




测试： go test -v

3. Mock
mock测试不但可以支持io类型的测试，比如：数据库，网络API请求，文件访问等。mock测试还可以做为未开发服务的模拟、服务压力测试支持、对未知复杂的服务进行模拟，比如开发阶段我们依赖的服务还没有开发好，那么就可以使用mock方法来模拟一个服务，模拟的这个服务接收的参数和返回的参数和规划设计的服务是一致的，那我们就可以直接使用这个模拟的服务来协助开发测试了；再比如要对服务进行压力测试，这个时候我们就要把服务依赖的网络，数据等服务进行模拟，不然得到的结果不纯粹。总结一下，有以下几种情况下使用mock会比较好：
1.IO类型的，本地文件，数据库，网络API，RPC等
2.依赖的服务还没有开发好，这时候我们自己可以模拟一个服务，加快开发进度提升开发效率
3.压力性能测试的时候屏蔽外部依赖，专注测试本模块
4.依赖的内部函数非常复杂，要构造数据非常不方便，这也是一种

mock测试，简单来说就是通过对服务或者函数发送设计好的参数，并且通过构造注入期望返回的数据来方便以上几种测试开发。

3.1 gomock 介绍
gomock主要包含两部分：gomock库和辅助代码生成工具mockgen
安装
go get github.com/golang/mock/gomock
go install github.com/golang/mock/mockgen


3.2 mock demo
spider.go

go_version.go

使用mockgen 自动生成接口的实现


go_version_test.go

最终的目录结构


官方例子： https://github.com/golang/mock/tree/master/sample
3.3 mockgen参数介绍
mockgen -destination spider/mock_spider.go -package spider -source spider/spider.go
就是将接口spider/spider.go中的接口做实现并存在 spider/mock_spider.go文件中，文件的包名为"spider"

-source: 指定接口文件
-destination：生成的文件名
-package：生成的文件包名
-imports：依赖的需要import包
-aux_files: 接口文件不止一个文件时附加文件
-build_flags: 传递给build工具的参数

在我们上面的demo中，并没有使用"-source",那是如何实现接口的呢？mockgen还支持通过反射的方式来找到对应的接口。只要在所有选项的最后增加一个包名和里面对应的类型就可以了。其他参数和上面的公用。

通过注释指定mockgen
如上所述，如果有多个文件，并且分散在不同的位置，那么我们要生成mock文件的时候，需要对每个文件执行多次mockgen命令（假设包名不相同）。这样在真正操作起来的时候非常繁琐，mockgen还提供了一种通过注释生成mock文件的方式，此时需要借助go的"go generate "工具。

注释：
//go:generate mockgen -destination mock_spider.go -package spider github.com/cz-it/blog/blog/Go/testing/gomock/example/spider Spider

在spider下执行命令
go generate

3.4 gomock接口使用
1.创建控制器
2.延时回收
3.调用mock生成的代码，实现接口对象
4.断言EXPECT（）
5.链式调用


4.golang测试命令
4.1 go test command
常用参数：
-bench regexp 执行相应的 benchmarks，例如 -bench=.；
-cover 开启测试覆盖率；
-run regexp 只运行 regexp 匹配的函数，例如 -run=Array 那么就执行包含有 Array 开头的函数；
-v 显示测试的详细命令。


4.2 测试覆盖率统计
这里在介绍一下另外一个简单的测试功能，测试覆盖率的测试cover，只要在go test后面加上-cover就可以了，如下面的例子，这里还加了一个参数-coverprofile=cover.out，这个参数是把覆盖率测试数据导出到cover.out这个文件，然后我们可以使用图形化的方式来看具体的测试覆盖情况。



以网页的形式打开统计结果
go  tool cover -html=cover.out

参考链接：
1.https://cloud.tencent.com/developer/article/1399249
2.https://juejin.im/post/6844903853532381198
3. https://gocn.vip/topics/9796







