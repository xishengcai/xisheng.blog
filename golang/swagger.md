## Swagger



#### start edit ui web
```bash
docker run -d -p 8081:8080 swaggerapi/swagger-editor
```



#### sample yaml

```
swagger: "2.0"

info:
  version: 1.0.0
  title: Simple API
  description: A simple API to learn how to write OpenAPI Specification

schemes:
  - https
host: simple.api
basePath: /openapi101

paths: {}
```



#### 懒人必备

[Generate a spec from source](https://github.com/go-swagger/go-swagger#generate-a-spec-from-source),即通过源码生成文档，很符合我的需求。

Swagger 是一个规范和完整的框架，用于生成、描述、调用和可视化 RESTful 风格的 Web 服务的接口文档。

目前的项目基本都是前后端分离，后端为前端提供接口的同时，还需同时提供接口的说明文档。但我们的代码总是会根据实际情况来实时更新，这个时候有可能会忘记更新接口的说明文档，造成一些不必要的问题。

用人话说，swagger就是帮你写接口说明文档的。更具体地，可以看下面的图片，swagger官方建议使用下面的红字部分，这篇博客主要是记录如何，使用swagger自动生成Api文档的，所以只介绍swagger-ui，其他的…以后我用到会再整理。







curl --location --request POST 'http://10.247.116.62:9090/api/lsh/idp/base/rbac/v1/res_group/trim'

#### auto generate doc

```bash
swagger generate spec -o ./swagger.json
```
