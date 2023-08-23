# 源码分析之shadow-shocket



Socks is an internet protocol that exchanges network packets between a client an server through a proxy server



### 2.2 socks协议有什么用

对于广大的中国网友来说，一提到代理，肯定会想到翻墙，而socks5作为一种代理协议，肯定也能用来翻墙嘛。不过遗憾的是，虽然它是代理协议，然而并不能用于翻墙。因为它的数据都是明文传输，会被墙轻易阻断。

socks协议历史悠久，它面世时中国的互联网尚未成型，更别说墙，因此它并不是为翻墙而设计的协议。互联网早期，企业内部网络为了保证安全性，都是置于防火墙之后，这样带来的副作用就是访问内部资源会变得很麻烦，socks协议就是为了解决这个问题而诞生的。

socks相当于在防火墙撕了一道口子，让合法的用户可以通过这个口子连接到内部，从而访问内部的一些资源和进行管理。



### 2.3 什么是socks5协议

socks5顾名思义就是socks协议的第五个版本，作为socks4的一个延伸，在socks4的基础上新增**UDP转发**和**认证功能**。唯一遗憾的是socks5并不兼容socks4协议。socks5由IETF在1996年正式发布，经过这么多年的发展，互联网上基本上都以socks5为主，socks4已经退出了历史的舞台。

实际上，你并不需要回头去看socks4协议，因为socks5协议完全可以取代socks4，因此读者对此不必感觉有心理压力。



### 2.4 工作过程

在开始介绍socks5协议工作工程之前，先来了解一下浏览器不设置代理情况下的请求过程。假设读者通过浏览器访问本博(假设读者使用的是HTTP协议)，流程如下:

1. 建立TCP连接

   浏览器向本博所在服务器建立TCP连接，经过3次握手后成功双方建立一条连接，用于数据传输

2. 发起HTTP请求

   TCP连接建立成功后，浏览器通过建立的连接发送HTTP请求

   ```
   GET /
   Host wiyi.org
   ```

3. 服务器响应浏览器一段HTML内容，浏览器收到后对页面进行渲染

   ![~replace~/assets/images/socks5/client-server.png](https://bigbyto.gitee.io/assets/images/socks5/client-server.png)

上面是正常的请求过程，如果读者给浏览器设置了一个socks5代理，情况会复杂一些。在这里我们假设socks5代理位于读者本地，端口为7582，它的工作流程如下:

1. 浏览器和socks5代理建立TCP连接

   和上面不同的时，浏览器和服务器之间多了一个中间人，即socks5，因此浏览器需要跟socks5服务器建立一条连接。

2. socks5协商阶段

   在浏览器正式向socks5服务器发起请求之前，双方需要协商，包括协议版本，支持的认证方式等，双方需要协商成功才能进行下一步。协商的细节将会在下一小节详细描述。

3. socks5请求阶段

   协商成功后，浏览器向socks5代理发起一个请求。请求的内容包括，它要访问的服务器域名或ip，端口等信息。

4. socks5 relay阶段

   scoks5收到浏览器请求后，解析请求内容，然后向目标服务器建立TCP连接。

5. 数据传输阶段

   经过上面步骤，我们成功建立了浏览器 –> socks5，socks5–>目标服务器之间的连接。这个阶段浏览器开始把数据传输给scoks5代理，socks5代理把数据转发到目标服务器。

上面的步骤虽然变多，但本质不变，非常容易理解，简单整理为下图

![~replace~/assets/images/socks5/client-socks5_f.jpg](https://bigbyto.gitee.io/assets/images/socks5/client-socks5_f.jpg)

**图2.2**

### 2.5 协议细节

在上一个小节介绍了socks5代理简要的工作流程，我们可以把它的的过程总结为3个阶段，分别为:握手阶段、请求阶段，Relay阶段。

#### 2.5.1 握手阶段

握手阶段包含协商和子协商阶段，我们把它拆分为两个分别讨论

**2.5.1.1 协商阶段**

在这个阶段，客户端向socks5发起请求，内容如下:

```
+----+----------+----------+
|VER | NMETHODS | METHODS  |
+----+----------+----------+
| 1  |    1     | 1 to 255 |
+----+----------+----------+

#上方的数字表示字节数，下面的表格同理，不再赘述
```

VER: 协议版本，socks5为`0x05`

NMETHODS: 支持认证的方法数量

METHODS: 对应NMETHODS，NMETHODS的值为多少，METHODS就有多少个字节。RFC预定义了一些值的含义，内容如下:

- X’00’ NO AUTHENTICATION REQUIRED
- X’01’ GSSAPI
- X’02’ USERNAME/PASSWORD
- X’03’ to X’7F’ IANA ASSIGNED
- X’80’ to X’FE’ RESERVED FOR PRIVATE METHODS
- X’FF’ NO ACCEPTABLE METHODS

![~replace~/assets/images/socks5/socks5_ne_01.jpg](https://bigbyto.gitee.io/assets/images/socks5/socks5_ne_01.jpg)

socks5服务器需要选中一个METHOD返回给客户端，格式如下:

```
+----+--------+
|VER | METHOD |
+----+--------+
| 1  |   1    |
+----+--------+
```

当客户端收到`0x00`时，会跳过认证阶段直接进入请求阶段; 当收到`0xFF`时，直接断开连接。其他的值进入到对应的认证阶段。

![~replace~/assets/images/socks5/socks5_ne_02.jpg](https://bigbyto.gitee.io/assets/images/socks5/socks5_ne_02.jpg)

**2.5.1.2 认证阶段(也叫子协商)**

认证阶段作为协商的一个子流程，它**不是必须**的。socks5服务器可以决定是否需要认证，如果不需要认证，那么认证阶段会被直接略过。

如果需要认证，客户端向socks5服务器发起一个认证请求，这里以`0x02`的认证方式举例:

```
+----+------+----------+------+----------+
|VER | ULEN |  UNAME   | PLEN |  PASSWD  |
+----+------+----------+------+----------+
| 1  |  1   | 1 to 255 |  1   | 1 to 255 |
+----+------+----------+------+----------+
```

VER: 版本，通常为`0x01`

ULEN: 用户名长度

UNAME: 对应用户名的字节数据

PLEN: 密码长度

PASSWD: 密码对应的数据

![~replace~/assets/images/socks5/socks5_ne_03_auth.jpg](https://bigbyto.gitee.io/assets/images/socks5/socks5_ne_03_auth.jpg)

socks5服务器收到客户端的认证请求后，解析内容，验证信息是否合法，然后给客户端响应结果。响应格式如下:

```
+----+--------+
|VER | STATUS |
+----+--------+
| 1  |   1    |
+----+--------+
```

STATUS字段如果为`0x00`表示认证成功，其他的值为认证失败。当客户端收到认证失败的响应后，它将会断开连接。

![~replace~/assets/images/socks5/socks5_ne_04_auth.jpg](https://bigbyto.gitee.io/assets/images/socks5/socks5_ne_04_auth.jpg)

#### 2.5.2 请求阶段

顺利通过协商阶段后，客户端向socks5服务器发起请求细节，格式如下:

```
+----+-----+-------+------+----------+----------+
|VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
+----+-----+-------+------+----------+----------+
| 1  |  1  | X'00' |  1   | Variable |    2     |
+----+-----+-------+------+----------+----------+
```

- VER 版本号，socks5的值为`0x05`
- CMD
  - `0x01`表示CONNECT请求
  - `0x02`表示BIND请求
  - `0x03`表示UDP转发
- RSV 保留字段，值为`0x00`
- ATYP 目标地址类型，DST.ADDR的数据对应这个字段的类型。
  - `0x01`表示IPv4地址，DST.ADDR为4个字节
  - `0x03`表示域名，DST.ADDR是一个可变长度的域名
  - `0x04`表示IPv6地址，DST.ADDR为16个字节长度
- DST.ADDR 一个可变长度的值
- DST.PORT 目标端口，固定2个字节

上面的值中，DST.ADDR是一个变长的数据，它的数据长度根据ATYP的类型决定。我们可以通过掐头去尾解析出这部分数据。

![~replace~/assets/images/socks5/socks5_05_req_01.jpg](https://bigbyto.gitee.io/assets/images/socks5/socks5_05_req_01.jpg)

socks5服务器收到客户端的请求后，需要返回一个响应，结构如下

```
+----+-----+-------+------+----------+----------+
|VER | REP |  RSV  | ATYP | BND.ADDR | BND.PORT |
+----+-----+-------+------+----------+----------+
| 1  |  1  | X'00' |  1   | Variable |    2     |
+----+-----+-------+------+----------+----------+
```

- VER socks版本，这里为`0x05`
- REP Relay field,内容取值如下
  - X’00’ succeeded
  - X’01’ general SOCKS server failure
  - X’02’ connection not allowed by ruleset
  - X’03’ Network unreachable
  - X’04’ Host unreachable
  - X’05’ Connection refused
  - X’06’ TTL expired
  - X’07’ Command not supported
  - X’08’ Address type not supported
  - X’09’ to X’FF’ unassigned
- RSV 保留字段
- ATYPE 同请求的ATYPE
- BND.ADDR 服务绑定的地址
- BND.PORT 服务绑定的端口DST.PORT

针对响应的结构中，`BND.ADDR`和`BND.PORT`值得特别关注一下，可能有朋友在这里会产生困惑，返回的地址和端口是用来做什么的呢？

我们回过头看**图2.2**，可以发现在图中socks5既充当socks服务器，又充当relay服务器。实际上这两个是可以被拆开的，当我们的socks5 server和relay server不是一体的，就需要告知客户端relay server的地址，这个地址就是BND.ADDR和BND.PORT。

当我们的relay server和socks5 server是同一台服务器时，`BND.ADDR`和`BND.PORT`的值全部为0即可。

#### 2.5.3 Relay阶段

socks5服务器收到请求后，解析内容。如果是UDP请求，服务器直接转发; 如果是TCP请求，服务器向目标服务器建立TCP连接，后续负责把客户端的所有数据转发到目标服务。

## 3.总结 & 下载

本文简单介绍了下socks5协议的作用以及处理过程，下一篇文章，将会手把手用Java实现一个socks5代理服务器，进一步认识socks5协议的处理过程。

读者可以点击[socks5.pcapng](https://wiyi.org/assets/files/socks5.pcapng)下载抓包数据，使用[wireshark](https://www.wireshark.org/)可以查看本文事例的抓包数据。

## 4. 相关阅读

- [手把手使用Java实现一个Socks5代理](https://wiyi.org/socks5-implementation.html)

## 5.参考资料

https://en.wikipedia.org/wiki/SOCKS
https://datatracker.ietf.org/doc/html/rfc1928
https://datatracker.ietf.org/doc/html/rfc1929
https://www.rapidseedbox.com/blog/guide-to-socks5-proxy

本文链接: https://wiyi.org/socks5-protocol-in-deep.html

This work is licensed under a [Attribution-NonCommercial 4.0 International](https://creativecommons.org/licenses/by-nc/4.0/) license.
