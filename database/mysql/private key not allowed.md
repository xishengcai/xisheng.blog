## [Public Key Retrieval is not allowed](https://www.cnblogs.com/bgtong/p/16695859.html)

mysql从5.1.6升级到8.0.22，项目启动报错：Public Key Retrieval is not allowed

导致“Public Key Retrieval is not allowed”主要是由于当禁用SSL/TLS协议传输后，客户端会使用服务器的公钥进行传输，默认情况下客户端不会主动去找服务器拿公钥，此时就会出现上述错误。

经过查阅官方文档，出现Public Key Retrieval的场景可以概括为在禁用SSL/TLS协议传输切当前用户在服务器端没有登录缓存的情况下，客户端没有办法拿到服务器的公钥。具体的场景如下：

1. 新建数据库用户，首次登录；
2. 数据库的用户名、密码发生改变后登录；
3. 服务器端调用FLUSH PRIVELEGES指令刷新服务器缓存。

针对上述错误，有如下的解决方案：

1. 在条件允许的情况下，不要禁用SSL/TLS协议，即不要在CLI客户端使用--ssl-mode=disabled，或在JDBC连接串中加入useSSL=false；
2. 如果必须禁用SSL/TLS协议，则可以尝试使用CLI客户端登录一次MySQL数据库制造登录缓存；
3. 如果必须禁用SSL/TLS协议，则可以通过增加如下参数允许客户端获得服务器的公钥：

- **在JDBC连接串中加入allowPublicKeyRetrieval=true参数；**
- 在CLI客户端连接时加入--get-server-public-key参数；
- 在CLI客户端连接时加入--server-public-key-path=file_name参数，指定存放在本地的公钥文件。

参考文章：https://zhuanlan.zhihu.com/p/371161553

本文来自博客园，作者：[bgtong](https://www.cnblogs.com/bgtong/)，转载请注明原文链接：https://www.cnblogs.com/bgtong/p/16695859.html