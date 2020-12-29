---
title: "rainbond build"
date: 2020-9-12T13:55:54+08:00
draft: false
---

## 代码目录介绍
|目录名称|描述 |
|-----|--------|
|api|路由|
|build| 构建镜像|
|clean| 定时清理垃圾镜像｜
|cloudos| ali oss， s3 云存储｜
|discover| 管理构建任务的发送和停止｜
|exector|
|model| 存放结构体｜
|monitor|
|parser|
|sources|
｜job| 源码构建job｜


## build
- build.go
 定义Build接口
 创建缓存： HostPathDirectoryOrCreate， PersistentVolumeClaimVolumeSource
 镜像名称： strings.ToLower(fmt.Sprintf("%s/%s:%s", builder.REGISTRYDOMAIN, serviceID, deployversion))
 
- code_build.go

- dockerfile_build.go

- netcore_build.go

## clean
1. 每24小时清理一次iamge or slug， 版本数少于5的不处理
2. 通过 context 控制任务停止

## cloudos
1. oss
2. s3

## discover
1. 管理构建任务的发送，停止
2. 通过mq client 发送， ctx 停止

## job
1. 代码编译，通过runBuildJob 启动job
2. stopPreBuildJob  有新的构建任务时，停止前面的构建，只保留一份构建任务
3. 主要是构建 Job， 启动job， 删除job， 获取job container 的日志等


## model
1.BuildPluginTaskBody
2.BuildPluginVersion
3.CodeCheckResult
4.ImageName


## source
### registry
1. 查询仓库中的镜像列表：
2. 
## 定时任务
```go
//Exec 上下文执行
func Exec(ctx context.Context, f func() error, wait time.Duration) error {
	timer := time.NewTimer(wait)
	defer timer.Stop()
	for {
		re := f()
		if re != nil {
			return re
		}
		timer.Reset(wait)
		select {
		case <-ctx.Done():
			return nil
		case <-timer.C:
		}
	}
}
```
