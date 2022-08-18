<!-- toc -->

# 有赞 GO 项目单测、集成、增量覆盖率统计与分析



## 一、引言

我是一名中间件 QA，我对应的研发团队是有赞 PaaS，目前我们团队有很多产品是使用 go 语言开发，因此我对 go 语言项目的单测覆盖率、集成以及增量测试覆盖率统计与分析做了探索。



## 二、单测覆盖率以及静态代码分析

### 2.1､单测覆盖率分析

测试覆盖率是指，作为被测试对象的代码包中的代码有多少在刚刚执行的测试中被使用到。如果执行的该测试致使当前代码包中的90%的语句都被执行了，那么该测试的测试覆盖率就是90%。

**go test** 命令可接受的与测试覆盖率有关的标记

| 标记名称      | 使用示例                | 说明                                                         |
| :------------ | ----------------------- | ------------------------------------------------------------ |
| -cover        | -cover                  | 启用测试覆盖率分析                                           |
| -covermode    | -covermode=set          | 自动添加**-cover**标记并设置不同的测试覆盖率统计模式，支持的模式共有以下3个。<br />**set**：只记录语句是否被执行过   <br />**count**: 记录语句被执行的次数   <br />**atomic**: 记录语句被执行的次数，并保证在并发执行时也能正确计数，但性能会受到一定的影响   这几个模式不可以被同时使用在,默认情况下，测试覆盖率的统计模式是**set** |
| -coverpkg     | -coverpkg bufio,net     | 自动添加**-cover**标记并对该标记后罗列的代码包中的程序进行测试覆盖率统计。  在默认情况下，测试运行程序会只对被直接测试的代码包中的程序进行统计。  该标记意味着在测试中被间接使用到的其他代码包中的程序也可以被统计。  另外，代码包需要由它的导入路径指定，且多个导入路径之间以逗号“，”分隔。 |
| -coverprofile | -coverprofile cover.out | 自动添加**-cover**标记并把所有通过的测试的覆盖率的概要写入指定的文件中 |



Go 语言自身提供了单元测试工具 `go test`，单元测试文件必须以 `*_test.go` 形式存在，`go test` 工具同时也提供了分析单测覆盖率的功能。因为需要将单测覆盖率上传到 sonar 平台展示，所以必须将覆盖率文件转换成能被 sonar 识别的格式，因此，还需要另外一个命令行工具 [gocov](https://github.com/axw/gocov)。

首先我们使用 `go test` 生成覆盖率输出文件 `cover.out`，并通过 gocov 工具来将生成的覆盖率文件 `cover.out` 转换成可以被 sonar 识别的 Cobertura 格式的 xml 文件。 如下所示：

```bash
go test -v ./... -coverprofile=cover.out #生成覆盖率输出  
gocov convert cover.out | gocov-xml > coverage.xml #将覆盖率输出转换成xml格式的报告  
```

将生成的单测覆盖率报告发送到 sonar 平台上来展示。

*cover工具可接受的标记*

| 标记名称 | 使用示例        | 说明                                                         |
| -------- | --------------- | ------------------------------------------------------------ |
| -func    | -func=cover.out | 根据概要文件（即cover.out）中的内容，输出每一个被测试函数的测试覆盖率概要信息 |
| -html    | -html=cover.out | 把概要文件中的内容转换成HTML格式的文件，并使用当前操作系统中的默认网络浏览器查看它 |
| -mode    | -mode=count     | 被用于设置测试概要文件的统计模式，详见go test命令的-covermode标记 |
| -o       | -o=cover.out    | 把重写后的源代码输出到指定文件中，如果不添加此标记，那么重写后的源代码会输出到标准输出上 |
| -var     | -var=GoCover    | 设置被添加到原先的源代码中的额外变量的名称                   |

### 2.2､静态代码分析

Go 静态代码分析工具有两个，分别是 [gometalinter](https://github.com/alecthomas/gometalinter) 和 [golangci-lint](https://github.com/golangci/golangci-lint)，我们现在使用的是 **golangci-lint**，因为 **gometalinter** 已经停止维护，而且作者也推荐去使用 **golangci-lint**。

#### 2.2.1 golangci-lint 的安装

以下是安装 golangci-lint 推荐的两种方法：

- 将二进制文件安装在 (go env GOPATH)/bin/golangci-lint 目录下 `curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s -- -b $(go env GOPATH)/bin vX.Y.Z`
- 或者将二进制文件安装在 ./bin/ 目录下 `curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s vX.Y.Z`

安装完成之后可以通过使用`golangci-lint --version`来查看它的版本。



## 三、集成测试覆盖率分析

对于 Go 项目没有类似 java jacoco 这样的第三方测试工具，就算是开源的第三方工具，一般单元测试执行以及单测覆盖率分析都是使用 Go 自带的测试工具 `go test` 来执行的。

阅读了[GO的官方博客](https://blog.golang.org/cover)之后发现其实针对二进制文件是有类似的工具 gcov。在文章中作者也说了，对于在 go 1.2 之前，其实也是使用类似 gcov 的方式对二进制程序在分支上设置断点，在每个分支执行时，将断点清除并将分支的目标语句标记为 “covered” 。

但是通过文章可以知道，在 go 1.2 之后是不支持使用此种方式，而且也不推荐使用 gcov 来统计覆盖率，因为执行二进制分析是很有挑战且很困难的，它还需要一种可靠的方式来执行跟踪绑定到源代码，这也很困难，这些问题包括不准确的调试信息和类似内联函数使分析复杂化，最重要的是，这种方法非常不便携。

### 3.1､解决方法

通过查找[资料](https://www.elastic.co/cn/blog/code-coverage-for-your-golang-system-tests)，发现了一个并不完美但是可以解决这个问题的方法。go test 中有一个 -c 的 flag，可以将单测的代码和被单测调用的代码编译成二进制包执行，但是这种方式并没有将整个项目的代码包含进去，不过可以通过增加一个测试文件 main_test.go，文件内容如下：

```go
func TestMainStart(t *testing.T) {  
    var args []string
    for _, arg := range os.Args {
        if !strings.HasPrefix(arg, "-test") {
            args = append(args, arg)
        }
    }
    os.Args = args
    main()
}

12345678910
```

将主函数放在此测试代码中，由于 Go 的入口函数是 main 函数，所以这样就会将整个 Go 项目都打包成一个已经插桩的二进制文件，如果项目启动的时候需要传入参数，则会将其中程序启动时传入的不是 -test标记的参数放入到os.Args 中传递给main 函数。以上代码也可以自己在测试文件中增加消息通知监听，来退出测试函数。

当集成测试跑完后就可以得到覆盖率代码，整个流程可参考下图：

![ci_test](https://tech.youzan.com/content/images/2020/02/ci_test.png)

```bash
#第一步：执行集成测试，并将此函数编译成二进制文件
go test -coverpkg="./..." -c -o cover.test  
#第二步：运行二进制文件，指定运行的测试方法是 TestMainStart，并将覆盖率报告输出
./cover.test -test.run "TestMainStart" -test.coverprofile=cover.out
#第三步：将输出的覆盖率报告转换成 html 文件（html 文件查看效果比较好）
go tool cover -html cover.out -o cover.html  
#第四步：生成 Cobertura 格式的 xml 文件
gocov convert cover.out | gocov-xml > cover.xml  

12345678
```

### 3.2､缺点

1. 必须所有 Go 语言项目中新增一个这样的测试代码文件，才可以使用

2. 必须退出进程才可以获得报告，但是如果测试程序是在 k8s 的 pod 中，一旦程序退出，pod 就会自动退出无法获取到文件

3. 想要得到测试覆盖率数据不能像 jacoco 那样直接调用接口可以 dump 到本地，程序必须增加一个接收信号量的参数，保证主函数的退出，不然集成测试代码跑完，覆盖率信息是不会写到磁盘的

4. 由于上面的原因，报告储存在远端，无法下载到当前 Jenkins 上，要去远端 dump 文件下来分析

5. 不能将分布式的应用的数据结合起来之后做全量统计(只能跑单个应用)

   **以上缺陷在有赞paas团队通过一些不是特别优雅的方式解决,以下是解决方案**

### 3.3､优化

> ps：由于当前有赞 PaaS 的 ci 环境是在 k8s 集群中实现的，所以这里就针对 k8s中 的优化方案

**3.3.1、针对编译前需要新增一个测试文件，包裹main函数**

测试函数也是要求所有项目中增加一个测试文件，或者 Jenkins 编译部署镜像之前在 pipline 中生成一个文件

**3.3.2、针对以上必须程序退出才可以或许到测试覆盖率报告的缺点：**

假设 k8s 基础镜像中已经装好 python，我在启动 pod 的时候默认启动两个服务，一个是被测试的服务，一个是 python 启动的 http 服务。

然后将项目服务的启动写入脚本中，并在 deployment 中通过 nohup 启动服务，并再启动一个 python 服务

```yaml
    spec:
      containers:
      - command:
        - /bin/bash
        - -c
        - (nohup /data/project/start.sh &);(cd python && -m SimpleHTTPServer 12345)
        image: $imageAddress

1234567
```

杀死项目服务后，因为还有 python 服务在，pod 不会退出，可以拿到覆盖率测试报告

**3.3.3、覆盖率报告在远端，如何在跑完Jenkins任务后来直接获取到报告：**

可以在跑集成测试后通过执行 http 请求来获取容器内的 cover.out，比如 `wget http://{ip}:{port}/{path}/cover.out`，并将此覆盖率报告编译成 Cobertura 格式的 xml，放入到 Jenkins 中统计。

如果是执行了多个服务端，需要合并覆盖率报告，可以使用 [gocovmerge](https://github.com/wadey/gocovmerge)

**3.3.4、如何在k8s中自动化kill程序让其退出：**

对于退出程序可以直接在集成测试代码中使用 kubectl 命令将 pod 中的程序 kill

```bash
pid=`kubectl exec $podname -c $container -n dts -- ps -ef | grep $process | grep -v grep | awk '{print $2}'`  
kubectl exec $podname -c $container -n $namespace -- kill $pid  
```

### 3.4､jenkins 报告

![xml_cover](https://tech.youzan.com/content/images/2020/02/xml_cover.png)



## 四、集成测试增量覆盖率分析

### 4.1､diff_cover

增量覆盖率分析我们选择了开源工具 [diff*over*](https://www.github.com/Bachmann1234/diff_cover)*，diff*cover 是用 python 开发，通过 git diff 来对比当前分支和需要比对的分支，主要针对新增代码做覆盖率分析。

### 4.2､安装

安装 diff_cover的机器需要有 python 的环境，有两种安装方式:

1、通过pip 来直接下载安装

```
pip install diff_cover
```

2、通过源代码安装

```
pip install diff_covers
```

### 4.3､使用方式

> ps：必须在需要对比的项目目录下运行！！！

#### 4.3.1 生成单元测试覆盖率报告

```
go test -v ./... -coverprofile=cover.out gocov convert cover.out | gocov-xml > coverage.xml
```

#### 4.3.2 增量覆盖率分析

```
diff-cover coverage.xml --compare-branch=xxxx --html-report report.html
```

> --compare-branch：是选择需要对比的分支号
>
> --html-report：是将增量测试报告生成 html 的报告模式
>
> 除了以上参数，此工具还有很多其他参数，比如
>
> --fail-under：覆盖率低于某个值，返回非零状态代码
>
> --diff-range-notation：设置 diff 的范围,就是 `git diff {compare-branch} {diff-range-notation}` 的作用等等。
>
> 具体可以通过 `diff_cover -h` 来获得更多详细的信息

### 4.4､报告

1. 命令行展示
   ![diff_cover1](https://tech.youzan.com/content/images/2020/02/diff_cover1.png)
2. HTML展示

![diff_cover2](https://tech.youzan.com/content/images/2020/02/diff_cover2.png)

表格中可以看到当前分支覆盖率与选定分支覆盖率的差异。



link

-[Go测试之性能监控与代码覆盖率](https://juejin.cn/post/6844903544860966925)
