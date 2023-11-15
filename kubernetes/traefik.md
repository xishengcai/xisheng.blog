# traefik



# [基于 Traefik 的 ForwardAuth 配置](https://www.cnblogs.com/east4ming/p/17003668.html)

## 前言

[Traefik](https://traefik.io/) 是一个现代的 HTTP 反向代理和负载均衡器，使部署微服务变得容易。

Traefik 可以与现有的多种基础设施组件（Docker、Swarm 模式、Kubernetes、Marathon、Consul、Etcd、Rancher、Amazon ECS...）集成，并自动和动态地配置自己。

**系列文章：**

- [《Traefik 系列文章》](https://ewhisper.cn/tags/Traefik/)

今天我们基于 Traefik on K8S 来详细说明如何通过 forwardauth 实现认证功能，并通过 ForwardAuth 和 OAuth 2.0 或 CAS 进行集成。

ForwardAuth 中间件将身份验证委托给外部服务。如果服务响应代码为 2XX，则授予访问权限并执行原始请求。否则，将返回身份验证服务器的响应。

![ForwardAuth 功能简图](https://img2023.cnblogs.com/other/3034537/202212/3034537-20221225084741948-311111394.png)

## ForwardAuth 的简单配置

创建 ForwardAuth 中间件，具体如下：

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: forward-auth
spec:
  forwardAuth:
    # 路径视具体情况而定
    address: http://your_auth_server/oauth2.0/validate
    authResponseHeaders:
      - Authorization
    trustForwardHeader: true
```

另外一般出于安全，会再加一些安全相关的 header, 如下：

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: secure-header
spec:
  headers:
    browserXssFilter: true
    contentTypeNosniff: true
    customResponseHeaders:
      Cache-Control: max-age=31536000
      Pragma: no-cache
      Set-Cookie: secure
    forceSTSHeader: true
    stsIncludeSubdomains: true
    stsSeconds: 14400
```

当然，也是出于安全，会用到 [HTTP 重定向到 HTTPS](https://ewhisper.cn/posts/14331/#HTTP- 重定向到 -HTTPS).

之后，创建 IngressRoute 的示例配置如下：

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: alertmanager
spec:
  routes:
    - kind: Rule
      match: Host(`ewhisper.cn`) && PathPrefix(`/alertmanager/`)
      middlewares:
        - name: redirectshttps
        - name: secure-header
        - name: forward-auth
      services:
        - name: alertmanager
          port: 9093
```

🎉完成！

## 使用 OAuth Proxy 和 Traefik ForwardAuth 集成

### 创建 ForwardAuth 401 错误的中间件

Traefik v2 ForwardAuth 中间件允许 Traefik 通过 oauth2-agent 的 `/oauth2/auth` 端点对每个请求进行身份验证，该端点只返回 `202 Accepted` 响应或`401 Unauthorized`的响应，而不代理整个请求。

#### `oauth-errors` 和 `oauth-auth` 中间件

```yaml
---
# 用途：给 oauth url 加 headers
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: auth-headers
spec:
  headers:
    sslRedirect: true
    stsSeconds: 315360000
    browserXssFilter: true
    contentTypeNosniff: true
    forceSTSHeader: true
    sslHost: ewhisper.cn
    stsIncludeSubdomains: true
    stsPreload: true
    frameDeny: true
---
# 用途：forwardauth
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: oauth-auth
spec:
  forwardAuth:
    address: https://oauth.ewhisper.cn/oauth2/auth
    trustForwardHeader: true
---
# 用途：forwardauth 返回 401-403 后重定向到登录页面
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: oauth-errors
spec:
  errors:
    status:
      - "401-403"
    service: oauth-backend
    query: "/oauth2/sign_in"
```

oauth 的 IngressRoute 配置：

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: oauth
spec:
  routes:
    - kind: Rule
      match: "Host(`ewhisper.cn`, `oauth.ewhisper.cn`) && PathPrefix(`/oauth2/`)"
      middlewares:
        - name: auth-headers
      services:
        - name: oauth-backend
          port: 4180
```

需要用到 oauth 的其他应用的 IngressRoute 配置：

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: alertmanager
spec:
  routes:
    - kind: Rule
      match: Host(`ewhisper.cn`) && PathPrefix(`/alertmanager/`)
      middlewares:
        - name: redirectshttps     
        - name: oauth-errors
        - name: oauth-auth
      services:
        - name: alertmanager
          port: 9093
```

🎉完成！

## 📚️参考文档

- [ForwardAuth | Traefik | v2.0](https://doc.traefik.io/traefik/v2.0/middlewares/forwardauth/)
- [Overview | OAuth2 Proxy (oauth2-proxy.github.io)](https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/overview#configuring-for-use-with-the-traefik-v2-forwardauth-middleware)













https://www.cnblogs.com/east4ming/p/17003668.html
