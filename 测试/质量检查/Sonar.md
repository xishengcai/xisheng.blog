# Sonar

为了保证项目代码质量，需要控制每个Pull Request的代码单元测试覆盖率。翻看了Sonar文档，发现Sonar是一款保证代码质量的工具，可以满足此类需求

SonarQube社区版是开源的代码质量管理平台，涵盖了架构设计、注释、编码规范、潜在缺陷、代码复杂度、单元测试、重复代码7个维度。通过强大的插件扩展机制，支持对主流编程语言的指标分析，目前可以支持超过20种以上主流编程语言。

SonarQube 在进行代码质量管理时，会从下图所示的七个纬度来分析项目的质量。
[![image](https://user-images.githubusercontent.com/1940588/53157101-c7ffbc00-35fb-11e9-8044-a7d756287e44.png)](https://user-images.githubusercontent.com/1940588/53157101-c7ffbc00-35fb-11e9-8044-a7d756287e44.png)
SonarQube 在进行代码质量管理时，会从七个纬度来分析项目的质量。

- 糟糕的复杂度分析：文件、类、方法等，如果复杂度过高将难以改变，这会使得开发人员难以理解它们，且如果没有自动化的单元测试，对于程序中的任何组件的改变都将可能导致需要全面的回归测试。

- 重复:显然程序中包含大量复制粘贴的代码是质量低下的，sonar可以展示源码中重复严重的地方。

- 缺乏单元测试：可以很方便的统计并展示单元测试覆盖率。

- 没有代码标准:sonar可以通过PMD,CheckStyle,Findbugs等等代码规则检测工具规范代码编写.

- 没有足够的或者过多的注释：没有注释将使代码可读性变差，特别是当不可避免地出现人员变动时，程序的可读性将大幅下降，而过多的注释又会使得开发人员将精力过多地花费在阅读注释上，亦违背初衷。

- 潜在的bug：可以通过PMD,CheckStyle,Findbugs等等代码规则检测工具检测出潜在的缺陷。

  issue的类型分为五个：

  - [Blocker]阻断:错误，高概率影响程序运行，例如：内存泄漏，未关闭的JDBC连接等等，代码必须修复。
  - [Critical]严重:低概率影响程序运行活着一个安全漏洞的错误，例如：空catch块，SQL注入等，这样的代码需要立即审查。
  - [Major]主要:代码缺陷，影响开发人员的生产力，例如：裸露一段代码，复制代码块，未使用的参数，这样的代码需要关注或忽略。
  - [Minor]次要:可能较少的影响开发人员生产力，这样的代码需要关注或忽略。。
  - [info]信息:不是错误，也不是质量缺陷，只是发现而已，这样的代码可以忽略。

- 糟糕的设计：可以找出循环，展示包与包，类与类之间的相互依赖关系，可以检测自定义的架构规则。可以管理第三方的jar包，可以利用LCOM4检测单个任务规则的应用情况，检测耦合。

SonarQube 可以测量的关键指标，包括代码错误、 代码异味(code smells)、安全漏洞和重复的代码。

- 代码错误 是代码中的一部分不正确或无法正常运行、可能会导致错误的结果，是指那些在代码发布到生产环境之前应该被修复的明显的错误。
- 代码异味 不同于代码错误，被检测到的代码是可能能正确执行并符合预期。然而，它不容易被修复，也不能被单元测试覆盖，却可能会导致一些未知的错误，或是一些其它的问题。从长期的可维护性来讲，立即修复代码异味是明智之举。通常在编写代码的时候，代码异味并不容易被发现，而 SonarQube 的静态分析是一种发现它们的很好的方式。
- 安全漏洞 正如听起来的一样：指的是现在的代码中可能存在的安全问题的缺陷。这些缺陷应该立即修复来防止黑客利用它们。
- 重复的代码 也和听起来的一样：指的是源代码中重复的部分。代码重复在软件设计中是一种很不好的做法。总的来说，如果对一部分代码进行更改而另一部分没有，则会导致一些维护性的问题。例如，识别重复的代码可以很容易的将重复的代码打包成一个库来重复的使用。
- 为什么它那么重要

SonarQube 为组织提供了一个集中的位置来管理和跟踪多个项目代码中的问题。它还可以把持续的检查与质量门限相结合。一旦项目分析过一次以后，更进一步的分析会参考软件最新的修改来更新原始的统计信息，以反映最新的变化。这些跟踪可以让用户看到问题解决的程度和速度。这与 “尽早发布并经常发布”不谋而合。

另外，SonarQube 可使用 可持续集成流程，比如像 Hudson 和 Jenkins 这样的工具。这个质量门限可以很好的反映代码的整体运行状况，并且通过 Jenkins 等集成工具，在发布代码到生产环境时担任一个重要的角色。

本着 DevOps 的精神， SonarQube 可以量化代码质量，来达到组织内部的要求。为了加快代码生产和发布的周期，组织必须意识到它们自己的技术债务和软件问题。通过发现这些信息， SonarQube 可以帮助组织更快的生成高质量的软件。

### 组件组成

- sonarqube server ： 他有三个程序分别是 webserver（配置和管理sonar） searchserver（搜索结果返回给sonarUI） ComplateEngineserver（计算服务 将分析结果入库）。
- sonarqube db : 数据库 存放配置。
- sonarqube plugins： 插件增加功能。
- sonar-scanner ： 代码扫描工具 可以有多个。

[![image](https://user-images.githubusercontent.com/1940588/53156946-75260480-35fb-11e9-8787-da891670283f.png)](https://user-images.githubusercontent.com/1940588/53156946-75260480-35fb-11e9-8787-da891670283f.png)

### SonarQube各组件的工作流程

1. 开发者在IDE中编码，并使用SonarLint执行本地代码分析；
2. 开发者向软件配置管理平台（Git，SVN，TFVC等）提交代码；
3. 代码提交触发持续集成平台自动构建、使用SonarQube Scanner执行分析；
4. 分析报告被发送到SonarQube Server进行处理；
5. 处理好的报告生成对应可视化的视图，并将数据保持到数据库；
6. 开发者可以在页面通过查看，评论，解决问题来管理和减少技术债；

[![image](https://user-images.githubusercontent.com/1940588/53156995-896a0180-35fb-11e9-8564-42f03ac81d1c.png)](https://user-images.githubusercontent.com/1940588/53156995-896a0180-35fb-11e9-8564-42f03ac81d1c.png)

### SonarQube中的一些重要概念

指标：SonarQube中的主要指标有可靠性，安全性，可维护性，测试覆盖率，复杂度，重复代码，规模（大小），问题等。

- 代码规则：在SonarQube中，通过插件提供的规则，在执行代码分析时对代码进行分析并生成问题。由于规则中定义了修复问题话费的成本（时间），解决问题的代价以及技术债可以通过这些问题进行计算。规则一般有三种类型：可靠性（Bug），可维护性（坏味道），安全性（漏洞）。
- 质量配置：质量配置提供了根据需求配置一组代码规则的能力，这组代码规则将被用于分析某些指定的组件（项目）。例如，项目A对应什么编程语言，适用于那些代码规则等等。
- 质量阈：质量阈是一系列对项目指标进行度量的条件。项目必须达到所有条件才能算整体上通过了质量阈。例如，配置质量阈为新增Bugs大于10，新代码可靠率低于评级A，新代码可维护率低于评级B，那分析完成后若指标符合这些标准，则代码质量将被认为是不合格的。

SonarQube Server处理分析报告时，根据质量配置中的代码规则进行匹配，从而生成具体的指标数据，然后根据质量阈中的阈值判断出项目的代码是否合格。



### 安装Sonar server

```
docker run -d --name sonarqube -p 9000:9000 sonarqube
```



### [本地安装 cli](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/)

![image-20210410135011204](/Users/xishengcai/Library/Application Support/typora-user-images/image-20210410135011204.png)

### 添加PATH

```
sudo vim ~/.bashrc
```

   

### 修改配置文件

![image.png](https://imgconvert.csdnimg.cn/aHR0cHM6Ly91cGxvYWQtaW1hZ2VzLmppYW5zaHUuaW8vdXBsb2FkX2ltYWdlcy80MjY5MDYwLTc4MzI2YjY5ZjBhMzgzMWUucG5n?x-oss-process=image/format,png)



### 测试

```
sonar-scanner -h
```



### Sonar create project

   ![image-20210410170630557](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/090633.png)



### test your program

Copy 上一步中的测试命令

   ```bash
   sonar-scanner \
     -Dsonar.projectKey=stream \
     -Dsonar.sources=. \
     -Dsonar.host.url=http://localhost:9000 \
     -Dsonar.login=97bbbbe51ea897682bf8e7fc175aae3e16589385
   ```



命令行终端进入到你的程序更目录执行

![image-20210410171059800](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/091103.png)



登陆serve 查看测试结果

![image-20210410171201841](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/091209.png)



link

-[参考](https://github.com/bingoohuang/blog/issues/67)

