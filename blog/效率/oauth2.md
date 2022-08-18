[原文出处](https://blog.csdn.net/seccloud/java/article/details/8192707)

# 引言

# OAuth 2.0 协议 

OAuth 2.0 是目前比较流行的做法，它率先被Google, Yahoo, Microsoft, Facebook等使用。之所以标注为 2.0，是因为最初有一个1.0协议，但这个1.0协议被弄得太复杂，易用性差，所以没有得到普及。2.0是一个新的设计，协议简单清晰，但它并不兼容1.0，可以说与1.0没什么关系。所以，我就只介绍2.0。

# 协议参与者

从引言部分的描述我们可以看出，OAuth的参与实体至少有如下三个：

· RO (resource owner): 资源所有者，对资源具有授权能力的人。如上文中的用户Alice。

· RS (resource server): 资源服务器，它存储资源，并处理对资源的访问请求。如Google资源服务器，它所保管的资源就是用户Alice的照片。

· Client: 第三方应用，它获得RO的授权后便可以去访问RO的资源。如网易印像服务。

此外，为了支持开放授权功能以及更好地描述开放授权协议，OAuth引入了第四个参与实体：
· AS (authorization server): 授权服务器，它认证RO的身份，为RO提供授权审批流程，并最终颁发授权令牌(Access Token)。读者请注意，为了便于协议的描述，这里只是在逻辑上把AS与RS区分开来；在物理上，AS与RS的功能可以由同一个服务器来提供服务。

# 授权类型

在开放授权中，第三方应用(Client)可能是一个Web站点，也可能是在浏览器中运行的一段JavaScript代码，还可能是安装在本地的一个应用程序。这些第三方应用都有各自的安全特性。对于Web站点来说，它与RO浏览器是分离的，它可以自己保存协议中的敏感数据，这些密钥可以不暴露给RO；对于JavaScript代码和本地安全的应用程序来说，它本来就运行在RO的浏览器中，RO是可以访问到Client在协议中的敏感数据。

OAuth为了支持这些不同类型的第三方应用，提出了多种授权类型，如授权码 (Authorization Code Grant)、隐式授权 (Implicit Grant)、RO凭证授权 (Resource Owner Password Credentials Grant)、Client凭证授权 (Client Credentials Grant)。由于本文旨在帮助用户理解OAuth协议，所以我将先介绍这些授权类型的基本思路，然后选择其中最核心、最难理解、也是最广泛使用的一种授权类型——“授权码”，进行深入的介绍。

# 基本思路
![oauth flow](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/151152.bmp)

(1) Client请求RO的授权，请求中一般包含：要访问的资源路径，操作类型，Client的身份等信息。

(2) RO批准授权，并将“授权证据”发送给Client。至于RO如何批准，这个是协议之外的事情。典型的做法是，AS提供授权审批界面，让RO显式批准。这个可以参考下一节实例化分析中的描述。

(3) Client向AS请求“访问令牌(Access Token)”。此时，Client需向AS提供RO的“授权证据”，以及Client自己身份的凭证。

(4) AS验证通过后，向Client返回“访问令牌”。访问令牌也有多种类型，若为bearer类型，那么谁持有访问令牌，谁就能访问资源。

(5) Client携带“访问令牌”访问RS上的资源。在令牌的有效期内，Client可以多次携带令牌去访问资源。

(6) RS验证令牌的有效性，比如是否伪造、是否越权、是否过期，验证通过后，才能提供服务。



# 授权模式
- 授权码模式（authorization code）：这是功能最完整，流程最严密的模式。现在主流的使用OAuth2.0协议授权的服务提供商都采用了这种模式，我在下面举例也将采取这种模式。

- 简化模式（implicit）：跳过了请求授权码（Authorization Code）的步骤，直接通过浏览器向授权服务端请求令牌（Access Token）。这种模式的特点是所有步骤都在浏览器中完成，Token对用户可见，且请求令牌的时候不需要传递client_secret进行客户端认证。

- 密码模式（resource owner password credentials）：用户向第三方客户端提供自己在授权服务端的用户名和密码，客户端通过用户提供的用户名和密码向授权服务端请求令牌（Access Token）。

## 授权码模式（authorization code）授权的流程

采用Authorization Code获取Access Token的授权验证流程又被称为Web Server Flow，适用于所有有Server端的应用，如Web/Wap站点、有Server端的手机/桌面客户端应用等。一般来说总体流程包含以下几个步骤：

1. 通过client_id请求授权服务端，获取Authorization Code。
2. 通过Authorization Code、client_id、client_secret请求授权服务端，在验证完Authorization Code是否失效以及接入的客户端信息是否有效（通过传递的client_id和client_secret信息和服务端已经保存的客户端信息进行匹配）之后，授权服务端生成Access Token和Refresh Token并返回给客户端。
3. 客户端通过得到的Access Token请求资源服务应用，获取需要的且在申请的Access Token权限范围内的资源信息。

### get authorization code
- client_id：必须参数，注册应用时获得的API Key。
- response_type：必须参数，此值固定为“code”。
- redirect_uri：必须参数，授权后要回调的URI，即接收Authorization Code的URI。
- scope：非必须参数，以空格分隔的权限列表，若不传递此参数，代表请求用户的默认权限。
- state：非必须参数，用于保持请求和回调的状态，授权服务器在回调时（重定向用户浏览器到“redirect_uri”时），会在Query Parameter中原样回传该参数。- - OAuth2.0标准协议建议，利用state参数来防止CSRF攻击。
- display：非必须参数，登录和授权页面的展现样式，默认为“page”，具体参数定义请参考“自定义授权页面”一节。
- force_login：非必须参数，如传递“force_login=1”，则加载登录页时强制用户输入用户名和口令，不会从cookie中读取百度用户的登陆状态。
- confirm_login：非必须参数，如传递“confirm_login=1”且百度用户已处于登陆状态，会提示是否使用已当前登陆用户对应用授权。
- login_type：非必须参数，如传递“login_type=sms”，授权页面会默认使用短信动态密码注册登陆方式。

### by authorization code get access token
通过上面获得的Authorization Code，接下来便可以用其换取一个Access Token。获取方式是：应用在其服务端程序中发送请求（推荐使用POST）到 百度OAuth2.0授权服务的https://openapi.baidu.com/oauth/2.0/token地址，并带上以下5个必须参数：

- grant_type：必须参数，此值固定为authorization_code。
- code：必须参数，通过上面第一步所获得的Authorization Code。
- client_id：必须参数，应用的API Key。
- client_secret：必须参数，应用的Secret Key。
- redirect_uri：必须参数，该值必须与获取Authorization Code时传递的redirect_uri保持一致。

响应数据包格式：

若参数无误，服务器将返回一段JSON文本，包含以下参数：

- access_token：要获取的Access Token。
- expires_in：Access Token的有效期，以秒为单位（30天的有效期）。
- refresh_token：用于刷新Access Token 的 Refresh Token,所有应用都会返回该参数（10年的有效期）。
- scope：Access Token最终的访问范围，即用户实际授予的权限列表（用户在授权页面时，有可能会取消掉某些请求的权限）。
- session_key：基于http调用Open API时所需要的Session Key，其有效期与Access Token一致。
- session_secret：基于http调用Open API时计算参数签名用的签名密钥。