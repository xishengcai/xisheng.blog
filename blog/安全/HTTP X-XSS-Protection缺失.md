HTTP X-[XSS](https://so.csdn.net/so/search?q=XSS&spm=1001.2101.3001.7020)-Protection 响应头是Internet Explorer，Chrome和Safari的一个功能，当检测到跨站脚本攻击 (XSS)时，浏览器将停止加载页面。虽然这些保护在现代浏览器中基本上是不必要的，当网站实施一个强大的Content-Security-Policy来禁用内联的JavaScript ('unsafe-inline')时, 他们仍然可以为尚不支持 CSP 的旧版浏览器的用户提供保护。

## 解决办法

### [Nginx](https://so.csdn.net/so/search?q=Nginx&spm=1001.2101.3001.7020)配置

/usr/local/nginx/conf 里，打开nginx.conf
add_header X-Xss-Protection "1; mode=block";

•   0：禁用XSS保护；
•   1：启用XSS保护；
•   1; mode=block：启用XSS保护，并在检查到XSS攻击时，停止渲染页面（例如IE8中，检查到攻击时，整个页面会被一个#替换）；

### 重启nginx