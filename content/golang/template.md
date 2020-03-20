---
title: "Template"
date: 2020-01-14T17:24:33+08:00
draft: true
---

[原文](https://github.com/astaxie/build-web-application-with-golang/blob/master/zh/07.4.md)
#### what
Web应用反馈给客户端的信息中的大部分内容是静态的，不变的，而另外少部分是根据用户的请求来动态生成的，
例如要显示用户的访问记录列表。用户之间只有记录数据是不同的，而列表的样式则是固定的，此时采用模板可以复用很多静态代码。

