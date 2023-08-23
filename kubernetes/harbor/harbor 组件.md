# harbor 组件介绍

[![harbor](https://bxdc-static.oss-cn-beijing.aliyuncs.com/images/Q2xt5X.jpg)](https://www.qikqiak.com/post/harbor-code-analysis/)

[Harbor](https://github.com/goharbor/harbor) 是一个`CNCF`基金会托管的开源的可信的云原生`docker registry`项目，可以用于存储、签名、扫描镜像内容，Harbor 通过添加一些常用的功能如安全性、身份权限管理等来扩展 docker registry 项目，此外还支持在 registry 之间复制镜像，还提供更加高级的安全功能，如用户管理、访问控制和活动审计等，在新版本中还添加了`Helm`仓库托管的支持。

> 本文所有源码基于 Harbor release-1.7.0 版本进行分析。

`Harbor`最核心的功能就是给 docker registry 添加上一层权限保护的功能，要实现这个功能，就需要我们在使用 docker login、pull、push 等命令的时候进行拦截，先进行一些权限相关的校验，再进行操作，其实这一系列的操作 docker registry v2 就已经为我们提供了支持，v2 集成了一个安全认证的功能，将安全认证暴露给外部服务，让外部服务去实现。



### docker registry v2 认证

上面我们说了 docker registry v2 将安全认证暴露给了外部服务使用，那么是怎样暴露的呢？我们在命令行中输入`docker login https://registry.qikqiak.com`为例来为大家说明下认证流程：

- 1. docker client 接收到用户输入的 docker login 命令，将命令转化为调用 engine api 的 RegistryLogin 方法
- 2. 在 RegistryLogin 方法中通过 http 盗用 registry 服务中的 auth 方法
- 3. 因为我们这里使用的是 v2 版本的服务，所以会调用 loginV2 方法，在 loginV2 方法中会进行 /v2/ 接口调用，该接口会对请求进行认证
- 4. 此时的请求中并没有包含 token 信息，认证会失败，返回 401 错误，同时会在 header 中返回去哪里请求认证的服务器地址
- 5. registry client 端收到上面的返回结果后，便会去返回的认证服务器那里进行认证请求，向认证服务器发送的请求的 header 中包含有加密的用户名和密码
- 6. 认证服务器从 header 中获取到加密的用户名和密码，这个时候就可以结合实际的认证系统进行认证了，比如从数据库中查询用户认证信息或者对接 ldap 服务进行认证校验
- 7. 认证成功后，会返回一个 token 信息，client 端会拿着返回的 token 再次向 registry 服务发送请求，这次需要带上得到的 token，请求验证成功，返回状态码就是200了
- 8. docker client 端接收到返回的200状态码，说明操作成功，在控制台上打印`Login Succeeded`的信息

至此，整个登录过程完成，整个过程可以用下面的流程图来说明：

![docker login](https://bxdc-static.oss-cn-beijing.aliyuncs.com/images/cQZwq7.jpg)docker login

要完成上面的登录认证过程有两个关键点需要注意：怎样让 registry 服务知道服务认证地址？我们自己提供的认证服务生成的 token 为什么 registry 就能够识别？

对于第一个问题，比较好解决，registry 服务本身就提供了一个配置文件，可以在启动 registry 服务的配置文件中指定上认证服务地址即可，其中有如下这样的一段配置信息：

```yaml
......
auth:
  token:
    realm: token-realm
    service: token-service
    issuer: registry-token-issuer
    rootcertbundle: /root/certs/bundle
......
```

其中 realm 就可以用来指定一个认证服务的地址，下面我们可以看到 Harbor 中该配置的内容

> 关于 registry 的配置，可以参考官方文档：https://docs.docker.com/registry/configuration/

第二个问题，就是 registry 怎么能够识别我们返回的 token 文件？如果按照 registry 的要求生成一个 token，是不是 registry 就可以识别了？所以我们需要在我们的认证服务器中按照 registry 的要求生成 token，而不是随便乱生成。那么要怎么生成呢？我们可以在 docker registry 的源码中可以看到 token 是如何定义的，文件路径在`distribution/registry/token/token.go`，从源码中我们可以看到 token 是通过`JWT（JSON Web Token）`来实现的，所以我们按照要求生成一个 JWT 的 token 就可以了。