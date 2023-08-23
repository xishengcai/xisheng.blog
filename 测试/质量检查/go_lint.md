# golangci-lint



在需要进行静态代码扫描的目录下执行 `golangci-lint run`，此命令和 `golangci-lint run ./…` 命令等效，表示扫描整个项目文件代码，并进行监测，也可以通过指定 go 文件或者文件目录名来对特定的代码文件或者目录进行代码扫描，例如 `golangci-lint run dir1 dir2/... dir3/file1.go`。

> ps：扫描指定目录的时候是不支持递归扫描的，如果要进行递归扫描需要在目录路径后面追加`/…`

默认情况下 golangci-lint 只启用以下的 linters：

**Enabled by default linters:**

- **deadcode**: 发现没有使用的代码
- **errcheck**: 用于检查 go 程序中有 error 返回的函数，却没有做判断检查
- **gosimple**: 检测代码是否可以简化
- **govet (vet, vetshadow)**: 检查 go 源代码并报告可疑结构，例如 Printf 调用，其参数与格式字符串不一致
- **ineffassign**: 检测是否有未使用的代码、变量、常量、类型、结构体、函数、函数参数等
- **staticcheck**: 提供了巨多的静态检查，检查 bug，分析性能等
- **structcheck**:发现未使用的结构体字段
- **typecheck**: 对 go 代码进行解析和类型检查
- **unused**: 检查未使用的常量，变量，函数和类型
- **varcheck**: 查找未使用的全局变量和常量

**Disabled by default linters:**

- **bodyclose**: 对 HTTP 响应是否 close 成功检测
- **dupl**: 代码克隆监测工具
- **gochecknoglobals**: 检查 go 代码中是否存在全局变量
- **goimports**: 做所有 gofmt 做的事. 此外还检查未使用的导入
- **golint**: 打印出 go 代码的格式错误
- **gofmt**: 检测代码是否都已经格式化, 默认情况下使用 `-s` 来检查代码是否简化
- **…………………………..**

未启用的还有很多工具，可以通过使用 `golangci-lint help linters` 命令查看还有哪些工具可以使用，如果想要启用没有默认开启的工具，可以在执行命令时使用 `-E` 参数来启用，比如要启用 golint 的话，只需要执行一下命令 `golangci-lint run -E=golint`。除了用 `-E` 来启动参数外，还可以指定最长执行时间 `—deadline`、跳过要扫描的目录 `--skip-dirs` 等等。如果要了解更多，请使用 `golangci-lint run -h` 来查看。

特别注意 `—-exclude-use-default` 参数，golangci-lint 对于上面默认的启用 linters 中做了一些过滤措施，比如对于 `errcheck` ，它不会扫描 `((os\.)?std(out|err)\..*|.*Close|.*Flush|os\.Remove(All)?|.*printf?|os\.(Un)?Setenv)` 这些函数返回的 error 是否被 checked，所以如果代码中使用到这些函数，并且没有接收 error 的话是不会被扫描到的。类似的还有`golint`、`govet`、`staticcheck`、`gosec` 需要注意。如果想要不过滤这些就需要使用 `--exclude-use-default=false` 来启用。