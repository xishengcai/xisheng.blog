<!-- toc -->

# Ginkgo 实践

一个 Golang 的BDD(行为驱动开发)测试框架

Ginkgo是一个BDD风格的Go测试框架，旨在帮助你有效地编写富有表现力的全方位测试。它最好与Gomega匹配器库配对使用，但它的设计是与匹配器无关的。



## install
```
go get github.com/onsi/ginkgo/ginkgo
go get github.com/onsi/gomega/...
```



## 运行测试

### 不同场景下的测试命令

- 在当前目录下运行该套件，只需：

  ```
  ginkgo #or go test
  ```



- 输出覆盖率

  ```
  # 运行 e2e文件夹下的测试文件， 只统计 remote 和 service 目录下的代码覆盖率
  go test ./e2e -coverpkg=./remote/... -coverpkg=./service/... -covermode=count -coverprofile=coverprofile.cov 
  
  # 对覆盖率文件转换成txt 报告
  go tool cover -func=coverprofile.cov -o coverprofile.txt
  ```



- 在其它目录下运行该套件，只需：

  ```
  ginkgo /path/to/package /path/to/other/package ...
  ```



- 通过正则匹配测试用例的名称，进行专注测试

  ```
  ginkgo --focus=项目 --v
  ```

  <img src="https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/090937.png" alt="image-20210421170936287" style="zoom: 50%;" />
  
- 通过idea 统计覆盖率测试

  <img src="https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/091152.png" alt="image-20210421171150345" style="zoom: 80%;" />
  
  

  效果1: 定位包级覆盖率

  <img src="https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/114345.png" alt="image-20210421194344286" style="zoom:50%;" />

	​	 

  效果2: 定位代码行级覆盖率

<img src="https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/114507.png" alt="image-20210421194505683" style="zoom:50%;" />


### ginkgo 常用命令参数详解

**指定运行哪些测试套件：**

- `-r`

  使用`-r`递归运行目标文件夹下的所有测试套件。适用于在所有包中运行所有测试。

- `-skipPackage=PACKAGES,TO,SKIP`

  当运行带有 `-r` 的测试，你可以传递一个逗号分隔的条目列表给 `-skipPackage` 。任何包的路径如果含有逗号分隔的条目列表之一就会被跳过。

**并行测试：**

- `-p`

  设置 `-p` 可以并行运行测试套件并自动经检测节点数。


**修改输出：**

- `--v`

  如果设置该参数， Ginkgo 默认报告会在每个 spec 运行前打印文本和位置。同时，GinkgoWriter 会实时刷新输出到标准输出。

- `--trace`

  如果设置该参数，Ginkgo 默认报告会为每个失败打印全栈跟踪日志，不仅仅打印失败发现的行号。


**控制随机性：**

- `--seed=SEED`

  变换 spec 顺序时使用的随机种子。

- `--randomizeAllSpecs`

  如果设置该参数，所有 spec 都会被重新排序。默认 Ginkgo 只会改变顶层容器的顺序。

- `--randomizeSuites`

  如果设置该参数并运行多个 spec 套件，specs 运行的顺序会被随机化。

**聚焦 spec 和跳过 spec：**

- `--skipMeasurements`

  如果设置该参数，Ginkgo 会跳过任何你定义的 `Measure` spec 。

- `--focus=REGEXP`

  如果设置该参数，Ginkgo 只会运行带有符合正则表达式 REGEXP 的描述的 spec。

- `--skip=REGEXP`

  如果设置该参数，Ginkgo 只会运行不有符合正则表达式 REGEXP 的描述的 spec。

**运行竞态检测和测试覆盖率工具：**

- `-race`

  设置`-race` 来让 `ginkgo` CLI 使用竞态检测来运行测试。

- `-cover`

  设置`-race` 来让 `ginkgo` CLI 使用代码覆盖率分析工具来运行测试（Go 1.2+ 的功能）。Ginkgo 会在在个测试包的目录下生成名为`PACKAGE.coverprofile` 的代码覆盖文件。

- `-coverpkg=<PKG1>,<PKG2>`

  `-cover`, `-coverpkg` 运行你的测试并开启代码覆盖率分析。然而， `-coverpkg` 允许你知道需要分析的包。它允许你获得当前包之外的包的代码覆盖率，这对集成测试很有用。注意，它默认不在当前包运行覆盖率分析，你需要制定所有你想分析的包。包名应该是全写，例如`github.com/onsi/ginkgo/reporters/stenographer`。

- `-coverprofile=<FILENAME>`

  使用 `FILENAME` 重命名代码覆盖率文件的名字。


**失败行为：**

- `--failOnPending`

  如果设置该参数，Ginkgo 会在有暂停 spec 的情况下使套件失败。

- `--failFast`

  如果设置该参数，Ginkgo 会在第一个 sepc 时候后立即停止套件。



## 不执行部分用例

您可以将单个Spec或容器标记为待定。这将阻止Spec（或者容器中的Specs）运行。您可以在您的Describe, Context, It 和 Measure前面添加一个P或者一个X来实现这一点：PDescribe("some behavior", func() { ... })
```
PContext("some scenario", func() { ... })
PIt("some assertion")
PMeasure("some measurement")

XDescribe("some behavior", func() { ... })
XContext("some scenario", func() { ... })
XIt("some assertion")
XMeasure("some measurement")
```



默认，Ginkgo将会打出每一个处于Pending态的Spec的说明。您可以通过设置--noisyPendings=false标签来关闭它。

在编译时，使用P和X将规格标记为Pending态。如果您需要在运行时（可能是由于只能在运行时才知道约束）跳过一个规格。您可以在您的测试中调用Skip：
```
It("should do something, if it can", func() {
    if !someCondition {
        Skip("special condition wasn't met")
    }

    // assertions go here
})
```



## 只执行部分用例

当开发的时候，运行规格的子集将会非常方便。Ginkgo有两种机制可以让您专注于特定规格：

1，您可以在`Descirbe`, `Context` 和 `It`前面添加F以编程方式专注于单个规格或者整个容器的规格：

```go
 FDescribe("some behavior", func() { ... })
 FContext("some scenario", func() { ... })
 FIt("some assertion", func() { ... })
```

这样做是为了指示Ginkgo只运行这些规格。要运行所有规格，您需要退回去并删除所有的F。



2，您可以使用`--focus = REGEXP`和/或`--skip = REGEXP`标签来传递正则表达式。Ginkgo只运行 `focus` 正则表达式匹配的规格，不运行`skip`正则表达式匹配的规格。



3，为了防止规格不能在测试组之间提供足够的等级区分，可以通过`--regexScansFilePath`选项，将目录加载到`focus`和`skip`的匹配中。也就是说，如果测试的初始代码位置是`test/a/b/c/my_test.go`，可以将`--focus=/b/`和`--regexScansFilePath=true`结合起来，专注于包含路径`/b/`的测试。此功能对于在创建这些测试的原始目录的行中过滤二进制工件中的测试是十分有用的。但理想情况下，您应该遵循最大限度地减少使用此功能的需求来组织您的规格。

当Ginkgo检测到以编程式为测试中心的测试组件时，它将以非零状态码退出。这有助于检测CI系统上错误提交的重点测试。当传入命令行`focus`/`skip`标志时，Ginkgo以`0`状态码退出。如果要将测试集中在CI系统上，则应该显示地传入`-focus`或`-skip`标志。

嵌套的以编程方式为重点的规格遵循一个简单的规则：如果叶子节点被标记为重点，那么它的被标记为重点的任何根结点将变为非重点。根据这个规则，标记为重点的兄弟叶子节点（无论相对深度如何），将会运行无论共享的根结点是否是重点；非重点的兄弟节点将不会运行无论共享的根结点或者相对深度的兄弟姐妹是否是重点。更简单地：

```go
FDescribe("outer describe", func() {
    It("A", func() { ... })
    It("B", func() { ... })
})
```

将会运行所有的`It`，但是：

```go
FDescribe("outer describe", func() {
    It("A", func() { ... })
    FIt("B", func() { ... })
})
```

只会运行`B`，这种行为倾向于更紧密地反应开发人员在测试套件上进行迭代时的实际意图。

程序化方法和`--focus=REGEXP`/`--skip=REGEXP`方法是互斥的。使用命令行标志将覆盖程序化的重点。

专注于没有`It`或者`Measure`的叶子节点的容器是没有意义的。由于容器中没有任何东西可以运行，因此实际上，Ginkgo忽略了它。

使用命令行标志时，您可以指定`--focus`和`--skip`中的一个或两个。如果都指定了，则他们的限制将都会生效。

您可以通过运行`ginkgo unfocus`来取消以编程为中心的测试的关注。这将从您当前目录中可能具有任何`FDescribe`，`FContext`和`FIt`的测试中删除`F`。

如果你想跳过整个包（当使用`-r`标志递归运行`ginkgo`时），你可以将逗号分隔的列表传递给`--skipPackage = PACKAGES, TO, SKIP`。包含列表中目录的任何包都将会被忽略。



## 基准测试

Ginkgo 允许你使用Measure块来测量你的代码的性能。Measure块可以运行在任何It块可以运行的地方--每一个Meature生成一个规格。传递给Measure的闭包函数必须使用Benchmarker参数。Benchmarker用于测量运行时间并记录任意数值。你也必须在该闭包函数之后传递一个整型参数给Measure，它表示Measure将执行的你的代码的样本数。例如：
```
Measure("it should do something hard efficiently", func(b Benchmarker) {
    runtime := b.Time("runtime", func() {
        output := SomethingHard()
        Expect(output).To(Equal(17))
    })

    Ω(runtime.Seconds()).Should(BeNumerically("<", 0.2), "SomethingHard() shouldn't take too long.")

    b.RecordValue("disk usage (in MB)", HowMuchDiskSpaceDidYouUse())
}, 10)
```



##  Ginkgo与持续集成

```
ginkgo -r --randomizeAllSpecs --randomizeSuites --failOnPending --cover --trace --race --progress
```



## 编写自定义报告器

因为 Ginkgo 的默认报告器提供了全面的功能， Ginkgo 很容易同时写和运行多个自定义报告器。这有很多使用案例。你能实现一个自定义报告器使你的持续集成方案支持一个特殊的输出格式，或者你能实现一个自定义报告器从Ginkgo `Measure` 节点[聚合数据](https://ke-chain.github.io/ginkgodoc/#measuring-time) 和制造 HTML 或 CSV 报告（或者甚至图表！）。

在 Ginkgo 中，一个报告器必须满足 `Reporter` 接口：

```
type Reporter interface {
    SpecSuiteWillBegin(config config.GinkgoConfigType, summary *types.SuiteSummary)
    BeforeSuiteDidRun(setupSummary *types.SetupSummary)
    SpecWillRun(specSummary *types.SpecSummary)
    SpecDidComplete(specSummary *types.SpecSummary)
    AfterSuiteDidRun(setupSummary *types.SetupSummary)
    SpecSuiteDidEnd(summary *types.SuiteSummary)
}
```

方法的名字应该能是自解释的。为了使你获得合理可用的数据，确保深入理解 `SuiteSummary` 和 `SpecSummary` 。如果你写了一个自定义报告器，用于获取 `Measure` 节点产生的基准测试数据，你会想看看 `ExampleSummary.Measurements` 提供的结构体 `ExampleMeasurement` 。

一旦你创建了自定义报告器，你可能要替换你测试套件中的`RunSpecs`命令，来传入该实例到 Ginkgo，要么这样：

```
RunSpecsWithDefaultAndCustomReporters(t *testing.T, description string, reporters []Reporter)
```

要么这样

```
RunSpecsWithCustomReporters(t *testing.T, description string, reporters []Reporter)
```

`RunSpecsWithDefaultAndCustomReporters` 会运行你的自定义报告器和 Ginkgo 默认报告器。`RunSpecsWithCustomReporters` 只会运行你的自定义报告器。

如果你希望运行并行测试，你不应该使用 `RunSpecsWithCustomReporters`，因为默认报告器是 ginkgo CLI 测试输出流的重要角色。



### 生成 JUnit XML 的输出。

​	Ginkgo 提供了一个 [自定义报告器](https://onsi.github.io/ginkgo/#writing-custom-reporters) 来生成 JUnit 兼容的 XML 输出。这是一个示例引导文件，该文件实例化了JUnit报告程序并将其传递给测试运行器：

```
package foo_test

import (
    . "github.com/onsi/ginkgo"
    . "github.com/onsi/gomega"

    "github.com/onsi/ginkgo/reporters"
    "testing"
)

func TestFoo(t *testing.T) {
    RegisterFailHandler(Fail)
    junitReporter := reporters.NewJUnitReporter("junit.xml")
    RunSpecsWithDefaultAndCustomReporters(t, "Foo Suite", []Reporter{junitReporter})
}
```

​	这会在包含你测试的目录中生成一个名为 “junit.xml” 的文件。这个 xml 文件兼容最新版本的 Jenkins JUnit 插件。

如果你想要并行运行你的测试，你需要让你的 JUnit xml 文件带有并行节点号。你可以这样做：

```
junitReporter := reporters.NewJUnitReporter(fmt.Sprintf("junit_%d.xml", config.GinkgoConfig.ParallelNode))
```

​	注意，你需要导入 `fmt` 和 `github.com/onsi/ginkgo/config` ，以使其正常工作。这会为每个并行节点生成一个 xml 文件。 Jenkins JUnit 插件（举例） 会自动聚合所有这些文件的数据。



## 项目实践

1. 在model 文件夹下构建moke 变量， model 包原则上只能被其他包导入，不可以导入其他包。所以把moke数据放在这里，不管你的单元测试文件放在哪里都不会出现循环导包的问题。

   ![image-20210421180930190](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/100931.png)

2. 单元测试仍然使用 ***testing.T**测试（方便Idea 上单个方法测试）， 集成测试使用ginkgo（方便多个用例串行测试）。 

3. 注册

   ![image-20210421174816367](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/094818.png)

   ```go
   package e2e
   
   import (
     ....
   )
   
   func TestCluster(t *testing.T) {
   
   	defer GinkgoRecover()
   	RegisterFailHandler(Fail)
   	//RunSpecs(t, "Cluster Suite")
   	junitReporter := reporters.NewJUnitReporter("./junit.xml")
   	RunSpecsWithDefaultAndCustomReporters(t, "APIServer test", []Reporter{junitReporter})
   }
   
   ```

4. 添加所有测试用例的一次性执行的前置条件

   ```go
   package e2e
   
   import (
   	....
   )
   
   var _ = Describe("Cluster", func() {
   	// 在所有测试用例执行前执行
   	BeforeSuite(func() {
   		SetupOamStatusCheck()
   		gateway.SetUpGatewaysStatusCheck()
   		setClient(moke.TestClusterIdStr)
   	})
   	
   	// 此Describe 用例测试前 准备环境
   	It("cluster test prepare env", func() {
   		deleteApp("", "")
   		deleteGateway("", moke.TestClusterName)
   		unImportCluster()
   	})
   	
   	// 此Describe 下每个It 之前执行
   	BeforeEach(func() {
   		
   	})
   	
   	// 此Describe 下每个It 之后执行
   	AfterEach(func() {
   	
   	})
   
     // 一个接口用一个Context测试
   	Context("sync cluster", func() {
   		It("sync cluster", func() {
   				....
   		})
   
   		It("sync cluster: subUser", func() {
   			....
   		})
   
   		// 鉴权的行为由IAM服务控制，所以这里仍然可以查询到
   		It("sync cluster: subUser no any auth", func() {
   				....
   		})
   	})
   
   	Context("集群导入, 取消导入", func() {
   		It("未授权的用户导入集群失败", func() {
   			....
   		})
   
   		It("异常1: 正在导入中的集群，取消导入失败", func() {
   			....
   		})
   
   		It("异常2: 集群重复导入", func() {
   			....
   		})
   	})
   
   	Context("unImport", func() {
       // 不要在It外，Contex内有代码，否则会在程序初始化的时候执行，产生意想不到的异常。
   		It("", func() {
   			....
   		})
   	})
   
   })
   
   ```
   
5. 不要在It外，Contex内有代码，否则会在程序初始化的时候执行，产生意想不到的异常。



## FQA

**Q:** 如何对单个文件测试？单个文件测试会出现自定义函数 undefined。

![image-20210412172929724](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/092931.png)

**A:** 在`Descirbe`, `Context` 和 `It`前面添加F以编程方式专注于单个规格或者整个容器的规格。



**Q** :如何将文件按顺序测试？

**A**: 文件默认是随机测试，不建议顺序测试。可以发现不同的测试文件之间是否有污染。



**Q:** Context，IT 测试顺序是怎样的？

**A:** Context ，IT 都是按顺序执行。



**Q:**有任务发生失败或只执行了部分测试用例，都无法获取覆盖率？

**A**: ...




## link
- [gomega](https://github.com/onsi/gomega)
- [ginkgo](https://github.com/onsi/ginkgo)
- [中文文档](https://ke-chain.github.io/ginkgodoc/)
- [ginkgo EN doc](http://onsi.github.io/ginkgo/#avoiding-dot-imports)