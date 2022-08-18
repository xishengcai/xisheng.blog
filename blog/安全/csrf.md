

web安全基础篇-跨站点请求伪造（CSRF)

[DXR嗯嗯呐 ](https://www.freebuf.com/author/DXR嗯嗯呐)2022-05-25 16:00:05 90579

## 前言

此文章学习于《白帽子讲WEB安全》

CSRF的全名是Cross Site Request Forgery，翻译为中文就是跨站点请求伪造。

它是web攻击中常见的一种，CSRF也是web安全中最容易被忽略的一种攻击方式。但是CSRF在某些时候却能够产生强大的破坏性。

## 一、CSRF简介

攻击者盗用了你的身份，以你的名义发送恶意请求，对服务器来说这个请求是完全合法的，但是却完成了攻击者所期望的一个操作，比如以你的名义发送邮件、发消息，盗取你的账号，添加系统管理员，甚至于购买商品、虚拟货币转账等。 如下：其中Web A为存在CSRF漏洞的网站，Web B为攻击者构建的恶意网站，User C为Web A网站的合法用户。

**CSRF攻击攻击原理及过程如下：**

1. 用户C打开浏览器，访问受信任网站A，输入用户名和密码请求登录网站A；

2.在用户信息通过验证后，网站A产生Cookie信息并返回给浏览器，此时用户登录网站A成功，可以正常发送请求到网站A；

1. 用户未退出网站A之前，在同一浏览器中，打开一个网页访问网站B；
2. 网站B接收到用户请求后，返回一些攻击性代码，并发出一个请求要求访问第三方站点A；
3. 浏览器在接收到这些攻击性代码后，根据网站B的请求，在用户不知情的情况下携带Cookie信息，向网站A发出请求。网站A并不知道该请求其实是由B发起的，所以会根据用户C的Cookie信息以C的权限处理该请求，导致来自网站B的恶意代码被执行。

网站B通过user C权限操作网站A，这种伪造的请求，所以叫做跨站点请求伪造攻击。

## 二、CSRF进阶

### 2.1 浏览器的Cookie策略

浏览器所支持的Cookie分为两种：一种是“Session Cookie" 又被称为 临时cookie；另外一种是”Third-party" ，也被称为本地cookie。

两者的区别在于，Third-party Cookie 是服务器在Set-Cookie时指定了Expire时间，只有到了Expire时间后Cookie才会失效，而Session Cookie保存在浏览器进程的内存空间中，所以浏览器关闭后，session cookie就失效了。

如果浏览器从一个域的页面中，要加载另一个域的资源，由于安全原因，某些浏览器会阻止Third-party Cookie的发送。

下面举个例子

```
<?php
header("Set-Cookie: cookie1=123;");
header("Set-Cookie: cookie2=456;expires=Thu, 23-May-2022 00:00:01 GMT;", false);
?>
```

访问这个界面，发现浏览器同时接收两个cookie

![1653465358_628de10e1e6117f15b672.png!small?1653465360576](https://image.3001.net/images/20220525/1653465358_628de10e1e6117f15b672.png!small?1653465360576)

这时候，再打开一个新的浏览器界面，访问同一个域的不同界面，因为新的界面在同一个浏览器进程中，因此session cookie将被发送

![1653465366_628de116709ecb8f2734f.png!small?1653465369070](https://image.3001.net/images/20220525/1653465366_628de116709ecb8f2734f.png!small?1653465369070)

此时在另一个域中，有一个页面http://192.168.163.128/1.html, 此界面构造了csrf以访问http://192.168.163.131/test/index.html

```
<iframe src="http://192.168.163.131/test/1.php" ></iframe>
```

通过IE浏览器访问，我们会发现，只能发送Session cookie，而Third-party Cookie被禁止了。是因为IE处于安全考虑，默认禁止了浏览器在< img>、< iframe>、< script>等标签中发送第三方cookie。

在Firefox中，默认策略是允许发送第三方cookie的

![1653465378_628de1225ea43bd4c65fe.png!small?1653465380819](https://image.3001.net/images/20220525/1653465378_628de1225ea43bd4c65fe.png!small?1653465380819)

在上面案例中，用户使用Firefox浏览器，所以我们成功获取了用于认证的Third-party Cookie，最终导致CSRF成功。

但若csrf攻击的目标并不需要使用cookie，则也不必顾虑浏览器的cookie策略了。

主流浏览器默认拦截Third-party Cookie有：IE6、IE7、IE8、Safari等

### 2.2 P3P头的副作用

虽然CSRF攻击不需要认证，不需要发送cookie，但是不可否认的是大部分敏感的操作是在认证之后的，因此浏览器拦截第三方cookie的发送，在某种程度上降低了CSRF攻击的威力，可是这一情况在P3P头介入变得复杂起来。

P3P Header是W3C定制的一项关于隐私的标准，全称The Platform for Privacy Preferences

如果网站返回给浏览器的HTTP头中包含有P3P头，则某种程度上来说，将浏览器发送给第三方cookie。在IE下即使是< script>等标签也将不在拦截第三方cookie发送。

在网站业务中，P3P头主要用于类似广告等需要跨域访问的页面。

### 2.3 GET? POST?

CSRF不只是通过GET请求发送，还可以通过POST方法，之前我们发起CSRF攻击主要使用HTML标签< img>、< iframe>等中的src属性。这类标签只能发送一次GET请求，而不能发起POST请求。而对于很多网站的应用来说，一些重要的操作并未严格的区分get与post，攻击者可以使用get请求表单的提交地址。比如在PHP中，如果使用的是$_REQUEST,而非 $ _POST获取变量，则会出现这个问题。

对于一个表单来说，用户往往也可以使用get方式提交参数，比如以下表单：

```
<form action="/1.html" id="register" method="post">
<input type=text name="username" value=""/>
<input type=password name="password" value="" />
<input type=submit name="submit" value="submit" />
</form>
```

我们抓包看到正常填报的请求是post请求

![1653465391_628de12f676f877a5c0ac.png!small?1653465393879](https://image.3001.net/images/20220525/1653465391_628de12f676f877a5c0ac.png!small?1653465393879)

用户也可以尝试构造一个get请求

```
http://192.168.163.131/1.html?username=test&password=passwd
```

尝试提交，若服务器未对请求方法进行限制，则这个请求会通过

![1653465398_628de136aca283eb4ae4a.png!small?1653465401155](https://image.3001.net/images/20220525/1653465398_628de136aca283eb4ae4a.png!small?1653465401155)

如果服务器端已经区分了get或者post，攻击者也可以通过其他若干个方法构造post请求。

最简单的方法就是在一个页面中构造好一个form表单，然后使用JavaScript自动提交这个表单，比如攻击者在http://192.168.163.132/1.html中编写如下代码

```
<form action="http://192.168.163.131/1.html" id="register" method="post">
<input type=text name="username" value=""/>
<input type=password name="password" value="" />
<input type=submit name="submit" value="submit" />
</form>
<script>
var f = document.getElementById("register")
f.inputs[0].value = "test";
f.inputs[1].value = "passwd";
f.submit();
</script>
```

攻击者甚至可以将这个页面隐藏在一个不可以见的iframe窗口中，那么整改自动提交表单的过程对于用户来说也是不可见的。

### 2.4 Flash CSRF

Flash也有很多种方式能够发起网络请求，包括POST，比如下面这段代码

```
import flash.net.URLRequest;
import flash.net.Security
var url = net URLRequest("http://www.a.com");
var param = new URLVariables();
param = "test=123";
url.method="POST";
url.data = param;
sendToURL(url);
stop();
```

除了URLRequest(),还有getURL,loadVars等方式发起请求。

在IE6、IE7中，Flash发送的网络请求均可以带上本地cookie，但从IE 8 开始，Flash发起的网络请求已经不再发送本地cookie。

## 三、CSRF防御

CSRF是一种比较奇特的攻击，我们通过什么方式防御呢。

### 3.1 验证码

验证码被认为是对抗CSRF攻击最简洁而有效的防御方法。

CSRF攻击过程往往是用户不知情下构造了网络请求，而验证码，则强制用户与应用交互，才能完成请求。但是验证码不是万能的，用户不能给全部操作都加验证码，这样系统就没办法用了，所以验证码是能作为防御CSRF防御的辅助手段，而不是作为主要的解决方案。

### 3.2 Referer Check

Referer Check 在互联网中最常见的应用就是防止图片盗链，同理，Referer Check也可以用于检查请求是否来自合法的“源”。

即便咱们能够经过检查 referer 是否合法来判断用户是否被 csrf 攻击，也仅仅是知足了防护的充分条件。

referer check 的缺陷在于，服务器并非何时都能去到 referer。（不少用户出于隐私保护的考虑，限制了 referer 的发送。在某些状况下，浏览器也不会发送referer，好比从 https 跳转到 http ，出于安全的考虑，浏览器也不会发送 referer）。

出于以上原因，我们无法依赖于Referer Check 作为防御CSRF的主要手段，但是通过Referer Check 来监控csrf攻击的发生，倒是可行的方法。

### 3.3 Anti CSRF Token

针对CSRF的防御，一般都是使用一个Token。在介绍此方法之前，首先了解一下csrf的本质。

#### 3.3.1 CSRF的本质

CSRF为什么能够攻击成功？其本质原因是重要操作的参数都是可以被攻击者猜测的。

攻击者只有预测处URL的所有参数于参数值，才能成功地构造一个伪造的请求；反之，攻击者将无法攻击成功。

出于这个原因，可以想到一个解决方案：把参数加密，或者使用一些随机数，从而让攻击者无法猜测到参数值。这是 不可预测性原则。

因为对参数加密会导致某些网站收藏有问题，所有就衍生出来新增一个Token参数。这个Token的值是随机的，不可预测的：

```
http://www.a.com/delete?username=test&item=123&token=[random(seed)]
```

Token需要足够的随机，必须使用足够安全的随机数生成算法，或者采用真随机数生成器。Token应该作为一个密码，为用户与服务器所共同持有，不能被第三者知晓。实际应用时，Token可以放在用户的session中或者浏览器的cookie中。

由于Token的存在，攻击者无法再构造处一个完整的url实施CSRF攻击。

Token需要同时放在表单和Session中，在提交请求时，服务器只需要验证表单中的Token，与用户session或者cookie的token是否一致，如果一致，则认为是合法请求，如果不一致，或者有一个为空，则认为请求不合法，可能是csrf攻击。

#### 3.3.2 Token的使用原则

Anti CSRF Token使用注意事项：

防御CSRF的Token，是根据不可预测性原则涉及的方案，所以Token的生成一定要足够随机，需要使用安全的随机数生成器。

Token的目的不是为了防止重复提交，所以为了使用方便，可以允许在一个用户的有效生命周期内，在Token消耗掉前都使用同一个Token。但是如果用户已经提交了表单，则这个Token已经消耗掉，应该在次重新生成一个新的Token。

如果Token保存在cookie中，而不是服务端的session中，则会带来一个新的问题。如果一个用户打开几个相同页面同时操作，当某个页面消耗掉Token后，其他页面的表单内保存的还是被消耗掉的那个Token，因此其他页面消耗掉Token后，会出现Token错误，在这种情况下考虑生成多个有效的Token，以解决多页面共存的场景。

使用Toke时应该注意Token的保密性。比如URL中包含Token，就可以导致泄露：

```
http://www.a.com/delete?username=test&item=123&token=[random]
```

因此使用Token时，应该尽量把Token放在表单中。把敏感操作由get修改为post。以form表单或者AJAX的形式提交，避免导致Token泄露。

还有一些其他途径泄露Token，比如XSS漏洞或者一些跨域漏洞，都可能让Token被攻击者窃取。

Token仅仅用于对抗CSRF攻击，当网站还同时存在xss漏洞时，这个方案就会失效，因为XSS可以模拟客户端浏览器任意执行操作。在xss攻击下，攻击者完全可以请求页面后，读出页面内容中的Token，然后在构造出来一个合法的请求，这个过程称为XSRF，和CSRF以示区别。

## 四、总结

CSRF攻击时攻击者利用用户的身份操作用户账户的一种攻击方式，设计CSRF的防御必须理解CSRF攻击的原理和本质。

根据不可预测性原则，我们通常使用token来防御CSRF攻击，使用时要注意Token的保密性和随机性。