# OAuth2
OAuth2 是一种身份验证协议，用于使用其他服务提供商来对应用程序中的用户进行身份验证和授权。



# github Register App
向github申请注册一个application,一个application对应一个项目，我们需要拿到一个client id和secret来用于后续的登陆认证
- https://github.com/settings/developers

  

**fill out form**
```
Application Name： 这个是GitHub 用来标识我们的APP的
Authorization callback url:就是上面我特意用红色字体标识的的，很关键
Homepage url 这个是展示用的，在我们接下来的登录中用不到，随便写就行了
```



**get result data**

```
cliendt_id 这是GitHub用来标识我们的APP的接下来我们需要通过这个字段来构建我们的登录url
client Secret 这个很关键，等会我们就靠它来认证的，要好好保存。我这个只是演示教程，用完就销毁了，所以直接公开了。
```


# login with clientID link && return code

构造相关的登陆连接，引导用户点击登陆， 这一步需要用到上面的clientID

- request url: https://github.com/login/oauth/authorize?client_id=xxxxxxxxxxxxxxxx
- response: response: http://localhost:8080/?code=xxxxxxxxxxxx



# use code to get token

用户同意登陆后，third-side可以拿到一个code，通过这个code可以向Github拿到用户的token

- https://github.com/login/oauth/access_token?client_id=%s&client_secret=%s&code=%s
- http://localhost:8080/welcome.html?access_token=xxxxxxxxxxxxx



# example code

https://github.com/sohamkamani/go-oauth-example.git