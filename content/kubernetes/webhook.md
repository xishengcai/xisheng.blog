---
title: "kuberentes webhook"
date: 2020-3-11T16:08:36+08:00
draft: true
---
> 1. [什么是webhook](#什么是webhook)
> 2. [kubernetes TLS 通信](#TLS)
> 3. [Experimenting with admission webhooks](#experimenting)
#### <span id="什么是webhook">什么是webhook</span>
WebHook是一种HTTP回调： 某些条件下触发HTTP POST请求；通过HTTP POST发送简单的事件
通知。一个基于web应用实现的WebHook会在特定事件发生时把消息发送给特定的URL.

#### 开启参数
```
--enable-admission-plugins
```
#### 概念介绍
#### MutatingWebhookConfiguration


### <span id="TLS">kubernetes TLS 通信</span>







### <id="Experimenting">Experimenting with admission webhooks</span>



参考文献:
1. https://kubernetes.io/zh/docs/reference/access-authn-authz/webhook/
2. https://www.qikqiak.com/post/k8s-admission-webhook/
3. https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#how-do-i-turn-on-an-admission-controller
