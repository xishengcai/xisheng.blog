---
title: "科学上网"
date: 2019-10-04T16:10:09+08:00
draft: false
---

# proxy
由于墙的存在,无法拉取镜像,建议科学上网

下面介绍怎么搭建代理

### server
在境外代理机器上通过pip安装shadowsocks,并且启动服务端程序

[如果您还没有代理机,可以选择在阿里云上购买一台香港服务器,虽然有点贵，但是稳定不，不会被墙](https://promotion.aliyun.com/ntms/yunparter/invite.html?userCode=j7wyhezj)
```shell script
yum -y install epel-release python-pip automake
pip install shadowsocks
 ```

```shell script
cat <<EOF> /etc/shadowsocks.conf
{
        "server":"0.0.0.0",
        "server_port": 12345 ,
        "local_port":1080,
        "password":"yourpassword",
        "timeout":600,
        "method":"aes-256-cfb",
        "workers":1
}
EOF
   ```

```shell script
ssserver -c /etc/shadowsocks.conf -d start //后台启动
```

    
### client
在境内服务器安装一个代理转换程序privoxy,将shaodows加密的流支持http协议

```shell script
yum -y install epel-release python-pip shadowsocks
```
编写配置文件,将server_ip修改为你境外的服务器ip地址 <br>
12345是境外服务器shadowSocket暴露的端口 <br>
local_port是你本地shadowSocket监听的端口

```shell script
cat <<EOF> /etc/shadowsocks.conf
{
        "server":"server_ip",
        "server_port":12345 ,
        "local_port":1080,
        "password":"password",
        "timeout":600,
        "method":"aes-256-cfb",
        "workers":1
}
EOF
```

启动shadow sockets 客户端服务

```shell script
sslocal  -c /etc/shadowsocks.conf -d start //后台启动
```

Autoconf 及 Automake 这两套工具来协助我们自动产生 Makefile文件

```shell script
yum -y install gcc wget autoconf
```
install privoxy,用于将shadowSocket加密的数据转换为http协议<br>
可以编译安装 也可以 直接 pip install privoxy 安装
```shell script
#wget http://www.privoxy.org/sf-download-mirror/Sources/3.0.26%20%28stable%29/privoxy-3.0.26-stable-src.tar.gz
wget http://115.238.145.60:20003/privoxy-3.0.26-stable-src.tar.gz
tar -zxvf privoxy-3.0.26-stable-src.tar.gz
cd privoxy-3.0.26-stable
```

编译安装
```shell script
useradd privoxy
autoheader && autoconf
./configure
make && make install
```

在文件/usr/local/etc/privoxy/config中找到下面两行,去掉注释
```shell script
cat <<EOF>> /usr/local/etc/privoxy/config
forward-socks5t   /               127.0.0.1:1080
listen-address  127.0.0.1:8118/
EOF
```
    
启动协议转换代理：
`privoxy --user privoxy /usr/local/etc/privoxy/config  # 以用户privoxy 的身份运行指定配置文件`
    
### 配置环境变量
```shell script
export http_proxy=http://127.0.0.1:8118 <br>
export https_proxy=http://127.0.0.1:8118 <br>
export ftp_proxy=http://127.0.0.1:8118 <br>
```


### windows client
[windows 小飞机代理工具](https://github.com/shadowsocks/shadowsocks-windows/releases)


### 总结
```
服务端（socket5 协议）  - - - - -  客户端 （socket5协议）
			             |
			             |
			privoxy（socket5 和 http协议互转）
			             |
			             |
                        具体应用curl, yum,wget等
```


### trouble shouting
q1: AttributeError: /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1: undefined symbol: EVP_CIPHER_CTX_cleanup

fix method:
```
vim /usr/local/lib/python2.7/dist-packages/shadowsocks/crypto/openssl.py (该路径请根据自己的系统情况自行修改，如果不知道该文件在哪里的话，可以使用find命令查找文件位置)
#跳转到52行（shadowsocks2.8.2版本，其他版本搜索一下cleanup）
将第52行libcrypto.EVP_CIPHER_CTX_cleanup.argtypes = (c_void_p,) 
改为libcrypto.EVP_CIPHER_CTX_reset.argtypes = (c_void_p,)
再次搜索cleanup（全文件共2处，此处位于111行），将libcrypto.EVP_CIPHER_CTX_cleanup(self._ctx) 
改为libcrypto.EVP_CIPHER_CTX_reset(self._ctx)
保存并退出
启动shadowsocks服务：service shadowsocks start 或 sslocal -c ss配置文件目录
```
