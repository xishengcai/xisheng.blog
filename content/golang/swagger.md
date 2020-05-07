---
title: "Swagger"
date: 2020-01-17T17:49:57+08:00
draft: true
---

#### start edit ui web
```shell script
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



#### auto generate doc
api method

doc.go

```go


```
```shell script
swagger generate spec -o ./swagger.json
``` 