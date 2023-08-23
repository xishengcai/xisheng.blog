## Go mod



Go modules是官方推出推荐的GOPATH的一个替代方案，同时集成了对版本控制和包分发的支持。
随着go1.11推出后，还是有很多的问题。官网不断在社区收集开发者反馈的问题，继续进行优化修bug。
到go1.12 gomod还是未默认将gomod设置为包管理工具取代GOPATH。在go1.11和go1.12版本中，
因为没有将gomod设置为默认包管理方式，增加了一个临时环境变量GO111MODULE来控制使用方式。
这个环境变量有三种设置方式：off、on、auto

off，则go命令从不使用go modules的功能，在执行go命令时将继续在GOPATH中查找依赖包，继续使用老的GOPATH模式；

auto，当go源码不在GOPATH路径下且当前目录或者上层目录存在go.mod文件时，启用gomod模式，否则将使用GOPATH模式。

on，则go命令使用go mod模式，命令执行过程中将忽略GOPATH的设置，按照gomod的方式管理go程序；

在gomod模式下，开发的项目下载的依赖包还是会存储到GOPATH/pkg/mod目录下，编译生成的二进制文件也将会存放到GOPATH/bin/ 目录下。

go.mod：依赖列表和版本约束。

go.sum：记录module文件hash值，用于安全校验。



## use go mod build project

- set env

```
export GO111MODULE=on
export GOPROXY=https://goproxy.io
```

- create init file: go.mod

```
go mod init
```

- go build auto write require package

```bash
go build main.go
```

- go mod replace

将 go.mod 中的所有依赖下载到vendor包下, old是要被替换的package，new就是用于替换的package。
```
go mod edit -replace=old[@v]=new[@v]
```
> **这里有几点要注意：**
>
>  - replace应该在引入新的依赖后立即执行，以免go tools自动更新mod文件时使用了old package导致可能的失败
>
>  - package后面的version不可省略。（edit所有操作都需要版本tag）
>
>  - version不能是master或者latest，这两者go get可用，但是go mod edit不可识别，会报错。（不知道是不是bug，虽然文档里表示可以这么用，希望go1.12能做点完善措施）



- download package to vendor

```bash
go mod vendor
```

> go get 下载/升级依赖
>
> go mod不再下载源码进$GOPATH/src
>
> go mod的下载目录在$GOPATH/pkg/mod，并且是文件权限是只读的-r--r--r--

- vendor 模式

go mod是不推荐使用vendor目录的，而是直接使用source或cache中的包。

module mode下默认忽略vendor目录。通过flag-mod=vendor设置vendor模式，依赖只从顶层的vendor中查找。可以通过环境变量GOFLAGS=-mod=vendor来设置flag



- 清除缓存

```
go clean -modcache
```

  

#### 最佳实践

go mod不推荐使用vendor，不要将vendor提交到版本控制。

提交go.mod，可以忽略go.sum，因为会根据校验sum跨平台可能报错



