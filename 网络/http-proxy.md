# 一个简单的Golang实现的HTTP Proxy

2018-08-28阅读 1.9K0

>  本文为原创文章，转载注明出处，欢迎扫码关注公众号`flysnow_org`或者网站http://www.flysnow.org/，第一时间看后续精彩文章。觉得好的话，顺手分享到朋友圈吧，感谢支持。 

最近因为换了Mac，以前的Linux基本上不再使用了，但是我的SS代理还得用。SS代理大家都了解，一个很NB的Socket代理工具，但是就是因为他是Socket的，想用HTTP代理的时候很不方便。

以前在Linux下的时候，会安装一个Privoxy把Socket代理转换为HTTP代理，开机启动，也比较方便。但是Mac下使用Brew安装的Privoxy就很难用，再加上以前一个有个想法，一个软件搞定Socket和HTTP代理，这样就不用安装一个单独的软件做转换了。

想着就开始做吧，以前基本上没有搞过太多的网络编程，最近也正好在研究Go，正好练练手。

我们这里主要讲使用HTTP／1.1协议中的CONNECT方法建立起来的隧道连接，实现的HTTP Proxy。这种代理的好处就是不用知道客户端请求的数据，只需要原封不动的转发就可以了，对于处理HTTPS的请求就非常方便了，不用解析他的内容，就可以实现代理。



## 启动代理监听

要想做一个HTTP Proxy，我们需要启动一个服务器，监听一个端口，用于接收客户端的请求。Golang给我们提供了强大的net包供我们使用，我们启动一个代理服务器监听非常方便。

```javascript
	l, err := net.Listen("tcp", ":8080")
	if err != nil {
		log.Panic(err)
	}
```

以上代理我们就实现了一个在8080端口上监听的服务器，我们这里没有写ip地址，默认在所有ip地址上进行监听。如果你只想本机适用，可以使用127.0.0.1:8080，这样机器就访问不了你的代理服务器了。



## 监听接收代理请求

启动了代理服务器，就可以开始接受不了代理请求了，有了请求，我们才能做进一步的处理。

```javascript
	for {
		client, err := l.Accept()
		if err != nil {
			log.Panic(err)
		}

		go handleClientRequest(client)
	}
```

Listener接口的Accept方法，会接受客户端发来的连接数据，这是一个阻塞型的方法，如果客户端没有连接数据发来，他就是阻塞等待。接收来的连接数据，会马上交给handleClientRequest方法进行处理，这里使用一个go关键字开一个goroutine的目的是不阻塞客户端的接收，代理服务器可以马上接收下一个连接请求。



## 解析请求，获取要访问的IP和端口

有了客户端的代理请求了，我们还得从请求里提取客户端要访问的远程主机的IP和端口，这样我们的代理服务器才可以建立和远程主机的连接，代理转发。

HTTP协议的头信息里就包含有我们需要的主机名(IP)和端口信息，并且是明文的，协议很规范，类似于：

```javascript
CONNECT www.google.com:443 HTTP/1.1
Host: www.google.com:443
Proxy-Connection: keep-alive
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36
```

可以看到我们需要的在第一行,第一个行的信息以空格分开，第一部分CONNECT是请求方法，这里是CONNECT，除此之外还有GET，POST等，都是HTTP协议的标准方法。

第二部分是URL，https的请求只有host和port，http的请求是一个完成的url，等下会看个样例，就明白了。

第三部是HTTP的协议和版本，这个我们不用太关注。

以上是一个https的请求，我们看下http的：

```javascript
GET http://www.flysnow.org/ HTTP/1.1
Host: www.flysnow.org
Proxy-Connection: keep-alive
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36
```

可以看到htt的，没有端口号（默认是80）；比https多了schame–http://。

有了分析，下面我们就可以从HTTP头信息中获取请求的url和method信息了。

```javascript
	var b [1024]byte
	n, err := client.Read(b[:])
	if err != nil {
		log.Println(err)
		return
	}
	var method, host, address string
	fmt.Sscanf(string(b[:bytes.IndexByte(b[:], '\n')]), "%s%s", &method, &host)
	hostPortURL, err := url.Parse(host)
	if err != nil {
		log.Println(err)
		return
	}
```

然后需要进一步对url进行解析，获取我们需要的远程服务器信息

```javascript
	if hostPortURL.Opaque == "443" { //https访问
		address = hostPortURL.Scheme + ":443"
	} else { //http访问
		if strings.Index(hostPortURL.Host, ":") == -1 { //host不带端口， 默认80
			address = hostPortURL.Host + ":80"
		} else {
			address = hostPortURL.Host
		}
	}
```

这样就完整了获取了要请求服务器的信息，他们可能是以下几种格式

```javascript
ip:port
hostname:port
domainname:port
```

就是有可能是ip（v4orv6），有可能是主机名（内网），有可能是域名(dns解析)



## 代理服务器和远程服务器建立连接

有了远程服务器的信息了，就可以进行拨号建立连接了，有了连接，才可以通信。

```javascript
	//获得了请求的host和port，就开始拨号吧
	server, err := net.Dial("tcp", address)
	if err != nil {
		log.Println(err)
		return
	}
```



## 数据转发

拨号成功后，就可以进行数据代理传输了

```javascript
if method == "CONNECT" {
		fmt.Fprint(client, "HTTP/1.1 200 Connection established\r\n\r\n")
	} else {
		server.Write(b[:n])
	}
	//进行转发
	go io.Copy(server, client)
	io.Copy(client, server)
```

其中对CONNECT方法有单独的回应，客户端说要建立连接，代理服务器要回应建立好了，然后才可以像HTTP一样请求访问。



## 运行外国外VPS上

到这里，我们的代理服务器全部开发完成了，下面是完整的源代码：

```javascript
package main

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"net"
	"net/url"
	"strings"
)

func main() {
	log.SetFlags(log.LstdFlags|log.Lshortfile)
	l, err := net.Listen("tcp", ":8081")
	if err != nil {
		log.Panic(err)
	}

	for {
		client, err := l.Accept()
		if err != nil {
			log.Panic(err)
		}

		go handleClientRequest(client)
	}
}

func handleClientRequest(client net.Conn) {
	if client == nil {
		return
	}
	defer client.Close()

	var b [1024]byte
	n, err := client.Read(b[:])
	if err != nil {
		log.Println(err)
		return
	}
	var method, host, address string
	fmt.Sscanf(string(b[:bytes.IndexByte(b[:], '\n')]), "%s%s", &method, &host)
	hostPortURL, err := url.Parse(host)
	if err != nil {
		log.Println(err)
		return
	}

	if hostPortURL.Opaque == "443" { //https访问
		address = hostPortURL.Scheme + ":443"
	} else { //http访问
		if strings.Index(hostPortURL.Host, ":") == -1 { //host不带端口， 默认80
			address = hostPortURL.Host + ":80"
		} else {
			address = hostPortURL.Host
		}
	}

	//获得了请求的host和port，就开始拨号吧
	server, err := net.Dial("tcp", address)
	if err != nil {
		log.Println(err)
		return
	}
	if method == "CONNECT" {
		fmt.Fprint(client, "HTTP/1.1 200 Connection established\r\n\r\n")
	} else {
		server.Write(b[:n])
	}
	//进行转发
	go io.Copy(server, client)
	io.Copy(client, server)
}
```

把源代码编译，然后放到你国外的VPS上，在自己机器上配置好HTTP代理，就可以`到处`访问，自由自在了。

>  本文为原创文章，转载注明出处，欢迎扫码关注公众号`flysnow_org`或者网站http://www.flysnow.org/，第一时间看后续精彩文章。觉得好的话，顺手分享到朋友圈吧，感谢支持。


