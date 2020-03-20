---
title: "Build_image"
date: 2019-12-27T13:55:54+08:00
draft: true
---

## base image
构建一个安装时区的基础镜像

golang: alpine
```
FROM alpine:latest

MAINTAINER xishengcai <cc710917049@163.com>

ENV TZ=Asia/Shanghai
ENV ALPINE_VERSION=3.11.2

RUN apk add tzdata zeromq

```

## start cmd

