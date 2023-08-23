https://cloud.tencent.com/developer/article/1661285

1. 概述

   Beehive是基于go-channel的消息传递框架，用于kubeedge模块之间的通信。如果已注册其他beehive模块的名称或该模块的名称已知，则在峰箱中注册的模块可以与其他峰箱模块进行通信。

   - 添加模块
   - 将模块添加到组
   - 清理

   Beehive 支持如下操作

   - 发送到模块/组
   - 通过模块接收
   - 发送同步到模块/组
   - 发送对同步消息的响应

   

   # 消息格式

   消息分为三部分

   1.header：

   - ID：消息ID（字符串）
   - ParentID：如果是对同步消息的响应，则说明parentID存在（字符串）
   - TimeStamp：生成消息的时间（整数）
   - sync：标志，指示消息是否为同步类型（布尔型）

   2.Route：

   - Source：消息的来源（字符串）
   - Group：必须将消息广播到的组（字符串）
   - Operation：对资源的操作（字符串）
   - Resource：要操作的资源（字符串）

   3.content：消息的内容（interface{}）

   实现两种通信机制，一种是unixsocket;另一种是golang 的channel

   

   # 注册模块

   1. 在启动edgecore时，每个模块都会尝试将其自身注册到beehive内核。
   2. Beehive核心维护一个名为modules的映射，该映射以模块名称为键，模块接口的实现为值。
   3. 当模块尝试向蜂巢核心注册自己时，beehive 内核会从已加载的modules.yaml配置文件中进行检查， 以检查该模块是否已启用。如果启用，则将其添加到模块映射中，否则将其添加到禁用的模块映射中。

   # channel上下文结构字段

   - channels - channels是字符串（键）的映射，它是模块的名称和消息的通道（值），用于将消息发送到相应的模块。
   - chsLock - channels map的锁
   - typeChannels - typeChannels是一个字符串（key）的映射，它是组(将字符串(key)映射到message的chan(value)， 是该组中每个模块的名称到对应通道的映射。
   - typeChsLock - typeChannels map的锁
   - anonChannels - anonChannels是消息的字符串（父id）到chan（值）的映射，将用于发送同步消息的响应。
   - anonChsLock - anonChannels map的锁







1. 代码架构

​	2.1 目录结构

```
├── pkg
│   ├── common
│   │   ├── config
│   │   │   ├── config.go
│   │   │   └── config_test.go
│   │   └── util
│   │       ├── conn.go
│   │       ├── conn_test.go
│   │       ├── file_util.go
│   │       └── parse_resource.go
│   └── core
│       ├── context
│       │   ├── context.go
│       │   ├── context_channel.go
│       │   ├── context_channel_test.go
│       │   ├── context_factory.go
│       │   └── context_unixsocket.go
│       ├── core.go
│       ├── model
│       │   └── message.go
│       └── module.go
```





3. 使用方法

   beehive并不是单独能运行的模块，而是直接被其他模块引用的。

   ```
       core.Register(MODULE)
       // start all modules
       core.Run()
   ```

   

1. 注意事项