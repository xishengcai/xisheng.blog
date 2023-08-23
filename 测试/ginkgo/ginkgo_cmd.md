## Ginkgo cmd

可以通过如下命令来安装Ginkgo命令：

```
$ go install github.com/onsi/ginkgo/ginkgo
```

Ginkgo 比 `go test` 提供了更多方便的指令。推荐使用 Ginkgo 命令虽然这不是必需的。

### 运行测试

在当前目录下运行该套件，只需：

```
$ ginkgo #or go test
```

在其它目录下运行该套件，只需：

```
$ ginkgo /path/to/package /path/to/other/package ...
```

传递参数和特定的标签到该测试套件：

```
$ ginkgo -- <PASS-THROUGHS>
```

注意：这个”–“是重要的。只有该双横线后面的参数才会被传递到测试套件。要在你的测试套件中解析参数和特定标签，需要声明一个变量并在包级别初始化它：

```
var myFlag string
func init() {
    flag.StringVar(&myFlag, "myFlag", "defaultvalue", "myFlag is used to control my behavior")
}
```

当然，Ginkgo使用一些标签。在运行指定的包之前必须指定这些标签。以下是调用语法的摘要：

```
$ ginkgo <FLAGS> <PACKAGES> -- <PASS-THROUGHS>
```

下面是Ginkgo可以接受的一些参数：

**指定运行哪些测试套件：**

- `-r`

  使用`-r`递归运行目标文件夹下的所有测试套件。适用于在所有包中运行所有测试。

- `-skipPackage=PACKAGES,TO,SKIP`

  当运行带有 `-r` 的测试，你可以传递一个逗号分隔的条目列表给 `-skipPackage` 。任何包的路径如果含有逗号分隔的条目列表之一就会被跳过。

**并行测试：**

- `-p`

  设置 `-p` 可以并行运行测试套件并自动经检测节点数。

- `--nodes=NODE_TOTAL`

  使用这个可以并行运行测试套件并使用 NODE_TOTAL 个数的进程。你不需要指定`-p` （尽管你可以！）。

- `-stream`

  默认地，当你并行运行测试套件，测试执行器从每个并行节点聚合数据，在运行测试的时候产生连贯的输出。设置 `stream`为 `true`，则会实时以流形式输出所有并行节点日志，每行头都会带有相应节点 id 。

**修改输出：**

- `--noColor`

  如果提供该参数，Ginkgo 默认不使用多种颜色打印报告。

- `--succinct`

  Succinct （简洁）会静默 Ginkgo 的详情输出。成功执行的测试套件基本上只会打印一行！当在一个包中运行测试的时候，Succinct 默认关闭。它在 Ginkgo 运行多个测试包的时候默认打开。

- `--v`

  如果设置该参数， Ginkgo 默认报告会在每个 spec 运行前打印文本和位置。同时，GinkgoWriter 会实时刷新输出到标准输出。

- `--noisyPendings=false`

  默认情况下，Ginkgo 默认报告会提供暂停 spec 的详情输出。你可以设置` --noisyPendings=false` 来禁止该行为。

- `--noisySkippings=false`

  默认情况下，Ginkgo 默认报告会提供跳过 spec 的详情输出。你可以设置` --noisySkippings=false` 来禁止该行为。

- `--reportPassed`

  如果设置该参数，Ginkgo 默认报告会提供通过 spec 的详情输出。

- `--reportFile=<file path>`

  在指定路径(相对路径或绝对路径)创建报告输出文件。它会同时覆盖预设的`ginkgo.Reporter` 路径，并且父目录不存在的话会被创建。

- `--trace`

  如果设置该参数，Ginkgo 默认报告会为每个失败打印全栈跟踪日志，不仅仅打印失败发现的行号。

- `--progress`

  如果设置该参数，当 Ginkgo 进入并运行每个 `BeforeEach`, `AfterEach`, `It` 节点的时候，Ginkgo 会输出过程到 `GinkgoWriter`。这在调试被卡主的测试时（例如测试卡在哪里？），或使用测试输出更多易读的日志到`GinkgoWriter` （例如什么日志在`BeforeEach`中输出？什么日志在`It`中输出？）。结合 `--v` 输出 `--progress` 日志到标准输出。

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

- `-outputdir=<DIRECTORY>`

  将覆盖率输出文件移到到指定目录。
  结合`-coverprofile` 参数也能使用。

**构建参数：**

- `-tags`

  设置`-tags`来传递 标识到编译步骤。

- `-compilers`

  当编译多个测试套件（如 `ginkgo -r`），Ginkgo 会使用 `runtime.NumCPU()` 绝对启动的编译进程数。在一些环境中这不是个好主意。你可以通过这个参数手动指定编译器进程数。

**失败行为：**

- `--failOnPending`

  如果设置该参数，Ginkgo 会在有暂停 spec 的情况下使套件失败。

- `--failFast`

  如果设置该参数，Ginkgo 会在第一个 sepc 时候后立即停止套件。

**监视参数：**

- `--depth=DEPTH`

  当监视包的时候，Ginkgo 同时监视包依赖的变化。默认的 `--depth` 为 1 ，意味着只有直接依赖的包被监控。你能调整它到 依赖的依赖（dependencies-of-dependencies），或者设置为零就只监控它自己，不监控依赖。

- `--watchRegExp=WATCH_REG_EXP`

  当监视包的时候，Ginkgo只监控符合该正则表达式的文件。默认值是`\.go$` ，意味着只有 go 文件的变化会被监视。

**减少随机失败的测试(flaky test):**

- `--flakeAttempts=ATTEMPTS`

  如果一个测试失败了，Ginkgo 能马上返回。设置这个参数大于 1 的话会重试。只要一个重试成功，Ginkgo 就不会认为测试套件失败。单独失败的运行仍会被报告在输出中；举个例子，JUnit 输出中，会声称 0 失败（因为套件通过了），但是仍会包含一个同时失败和成功的测试的所有失败的运行。

  这个参数很危险！不要试图使用它来掩盖失败的测试！

**杂项：**

- `-dryRun`

  如果设置该参数，Ginkgo 会遍历你的测试套件并报告输出，但是不会真正运行你的测试。这最好搭配`-v`来预览你将运行的测试。测试的顺序遵循了 `--seed` 和 `--randomizeAllSpecs` 指定的随机策略。

- `-keepGoing`

  默认地，当多个测试运行的时候（使用 `-r`或一列表的包），Ginkgo 在一个测试失败的时候会中断。要让 Ginkgo 时候后继续接下来的测试套件，你可以设置 `-keepGoing`。

- `-untilItFails`

  如果设置为 `true`，Ginkgo 会持续运行测试直到发送失败。这会有助于弄明白竞态条件或者古怪测试。最好搭配 `--randomizeAllSpecs` 和 `--randomizeSuites` 来变换迭代的测试顺序。

- `-notify`

  设置 `-notify` 来接受桌面测试套件完成的通知。结合子命令 `watch` 特别有用。当前 `-notify` 只有 OS X 和 Linux 支持。在 OS X 上，你需要运行 `brew install terminal-notifier` 来接受通知，在 Linux 你需要下载安装 `notify-send`。

- `--slowSpecThreshold=TIME_IN_SECONDS`

  默认地，Ginkgo报告器会表示运行超过 5 秒的测试，这不会使测试失败，它只是通知你该 sepc 运行慢。你可以使用这个参数修改该门槛。

- `-timeout=DURATION`

  如果时间超过 `DURATION` ，Ginkgo 会使测试套件失败。默认值是 24 小时。

- `--afterSuiteHook=HOOK_COMMAND`

  Ginko 有能力在套件测试结束后运行一个命令（a command hook）。你只需给它需要运行的命令，它就会替换字符串来传给命令数据。举例：` –afterSuiteHook=”echo (ginkgo-suite-name) suite tests have [(ginkgo-suite-passed)]” `，这个测试沟子会替换 (ginkgo-suite-name) 和 (ginkgo-suite-passed) 为套件名和各自的通过/失败状态，然后输出到终端。

- `-requireSuite`

  如果你使用 Ginkgo 测试文件创建包，但是你忘了运行 `ginkgo bootstrap` 初始化，你的测试不会运行而且该套件会一致通过。Ginkgo 会通知你 `Found no test suites, did you forget to run "ginkgo bootstrap"?` ，但是不会失败。如果有测试文件但没有引用`RunSpecs.`，这个参数使得 Ginkgo 标识套件为失败。

### 监视修改

Ginkgo CLI 提供子命令 `watch` ，监视（几乎）所有的 `ginkgo` 命令参数。使用`ginkgo watch` ，Ginkgo 会监控当前目录的包，当有修改的时候就触发测试。

你也可以使用 `ginkgo watch -r` 递归监控所有包。

对每个被监控的包，Ginkgo 也会监控包的依赖并在依赖产生修改的时候触发测试套件。默认地，`ginkgo watch` 监控包的直接依赖。你可以使用 `-depth` 来调整。设置 `-depth` 为0则不监控依赖，设置 `-depth` 大于 1 则监控更深依赖路径。

在 Linux 或 OS X 传递 `-notify` 参数，会在 `ginkgo watch` 触发和完成测试的时候产生桌面通知。

### 预编译测试

Ginkgo 对写集成风格的验收测试（integration-style acceptance tests）有强力的支持。比如，这些测试有助于验证一个复杂分布式系统的函数是否正确。它常便于分布这些作为单独二进制文件的验收测试。 Ginkgo 允许你这样构建这些二进制文件：

```
ginkgo build path/to/package
```

这会产生一个名为 `package.test `的预编译二进制文件。然后，你能直接调用 `package.test` 来运行测试套件。原理很简单， `ginkgo` 只是调用 `go test -c -o` 来编译 `package.test` 二进制文件。 直接调用 `package.test` 会*连续*运行测试。要并行测试的话，你需要 `ginkgo` cli 编排并行节点。你可以运行：

```
ginkgo -p path/to/package.test
```

来这样做。因为 Ginkgo CLI 是一个单独二进制文件，你能直接分布两个二进制文件，来提供一个并行(所以快速)的集成风格验收测试集合。

> `build`子命令接受一系列 `ginkgo` 和 `ginkgo watch` 接收的参数。这些参数仅限关注于编译时，就像 `--cover` 和 `--race`。通过 `ginkgo help build`，你能获得更多信息。

> 使用标准 `GOOS` 和 `GOARCH` 环境变量，你能交叉编译并面向不同平台。因此，在 OS X 上运行 `GOOS=linux GOARCH=amd64 ginkgo build path/to/package` ，会产生一个能在 Linux 上运行的二进制文件。
>
> ### 生成器

- 在当前目录，为一个包引导 Ginkgo 测试套件，可以运行：

  ```
    $ ginkgo bootstrap
  ```

  这会生成一个名为 `PACKAGE_suite_test.go` 的文件，PACKAGE 是当前目录的名称。

- 如要添加一个测试文件，运行：

  ```
    $ ginkgo generate <SUBJECT>
  ```

  这会生成一个名为 `SUBJECT_test.go` 的文件。如果你不指定 SUBJECT ，它会生成一个名为 `PACKAGE_test.go` 的文件，PACKAGE 是当前目录的名称。

默认地，这些生成器会点引用（dot-import）Ginkgo 和 Gomega。想避免点导入，你可以传入 `--nodot` 到两个子命令。详情请看 [下一章](https://ke-chain.github.io/ginkgodoc/#避免点导入)

> 注意，你不是必须使用这两个生成器。他们是方便你快速初始化。

### 避免点导入

Ginkgo 和 Gomega 提供了一个 DSL ，而且，默认地 `ginkgo bootstrap` 和 `ginkgo generate` 命令使用点导入导入两个包到顶层命名空间。 有少许确定的情况，你需要避免点导入。例如，你的代码可能定义了与 Ginkgo 或 Gomega 方法冲突的方法名。这中情况下，你可以将你的代码导入到自己的命名空间（换言之，移除导入你的包签名的 `.`）。或者，你可以移除 Ginkgo 或 Gomega 签名的 `.`。后者会导致你一直要在 `Describe` 和 `It` 前面加 `ginkgo.` ，并且你的 `Expect` 和 `ContainSubstring `前面也都要加 `gomega.` 。 然而，这是第三个 ginkgo CLI 提供的选项。如果你需要（或想要）避免点导入你可以：

```
ginkgo bootstrap --nodot
```

和

```
ginkgo generate --nodot <filename>
```

这会创建一个引导文件，明确地在顶级命名空间，导入所有 Ginkgo 和 Gomega 的导出标识符。这出现在你引导文件的地步，生成的代码就像这样：

```
import (
    github.com/onsi/ginkgo
    ...
)

...

// Declarations for Ginkgo DSL
var Describe = ginkgo.Describe
var Context = ginkgo.Context
var It = ginkgo.It
// etc...
```

这允许你使用 `Describe`, `Context`, 和 `It`写测试，而不用添加 `ginkgo.`前缀。关键地，它同时允许你冲定义任何冲突的标识符（或组织你自己的语意）。例如：

```
var _ = ginkgo.Describe
var When = ginkgo.Context
var Then = ginkgo.It
```

这会避免导入`Describe`，并会将`Context` 和 `It` 重命名为 `When` 和 `Then`。 当新匹配库被添加到 Gomega ，你需要更新这些导入的标识符。你可以这样，进入包含引导文件的目录并运行：

```
ginkgo nodot
```

这会更新导入，保留你提供的重命名。

### 转换已存在的测试

如果你有一个 XUnit 测试套件，而且你想把它转化为 Ginkgo 套件，你可以使用 `ginkgo convert` 命令：

```
ginkgo convert github.com/your/package
```

这会生成一个 Ginkgo 引导文件，转化所有 XUnit 风格 `TestX...(t *testing.T)` 为简单（平坦）的 Ginkgo 测试。它同时将你代码中的 `GinkgoT()` 替换为 `*testing.T` 。 `ginkgo convert` 一般第一次就能正确转换，但事后你可能需要微调一下测试。 同时： `ginkgo convert` 会**覆盖 **你的测试文件，因此确保你尝试 `ginkgo convert` 之前，已经没有未提交的修改了。 `ginkgo convert` 是[Tim Jarratt](https://github.com/tjarratt) 的主意。

### 其它子命令

- 将当前目录(和子目录)写入代码的重点测试设为普通测试：

  ```
    $ ginkgo unfocus
  ```

- 查看帮助：

  ```
    $ ginkgo help
  ```

  查看特定子目录的帮助：

  ```
    $ ginkgo help <COMMAND>
  ```

- 获取当前 Ginkgo 的版本：

  ```
    $ ginkgo version
  ```