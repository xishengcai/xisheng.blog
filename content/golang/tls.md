---
title: "TLS and Golang"
date: 2020-6-18T17:24:33+08:00
draft: false
---
## generate TLS script
```shell script
#!/bin/bash

# 生成根秘钥及证书
openssl req -x509 -sha256 -newkey rsa:2048 -keyout ca.key -out ca.crt -days 3560 -nodes -subj '/CN=Launcher LStack Authority'

# 生成服务器密钥，证书并使用CA证书签名
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/CN=1.1.1.1" -out server.csr
echo subjectAltName = IP:1.1.1.1 > extfile.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out server.crt -days 3650

# 生成客户端密钥，证书并使用CA证书签名
openssl req -new -newkey rsa:2048 -keyout client.key -out client.csr -nodes -subj '/CN=1.1.1.1'
openssl x509 -req -sha256 -days 3650 -in client.csr -CA ca.crt -CAkey ca.key -set_serial 02 -out client.crt

# 生成p12
openssl pkcs12 -export -clcerts -inkey client.key -in client.crt -out client.p12 -name "k8s-client"

kubectl delete secret tls-certs -n ingress-nginx

kubectl -n ingress-nginx create secret generic tls-certs \
--from-file=tls.crt=server.crt \
--from-file=tls.key=server.key \
--from-file=ca.crt=ca.crt

#curl -v --cacert ./ca.crt --cert ./client.crt --key ./client.key https://1.1.1.1

```

## server
```golang
package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"net/http"
)

type myhandler struct {
}

func (h *myhandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hi, This is an example of http service in golang!\n")
}

func main() {
	pool := x509.NewCertPool()
	caCertPath := "ca.crt"

	caCrt, err := ioutil.ReadFile(caCertPath)
	if err != nil {
		fmt.Println("ReadFile err:", err)
		return
	}
	pool.AppendCertsFromPEM(caCrt)

	s := &http.Server{
		Addr:    ":8081",
		Handler: &myhandler{},
		TLSConfig: &tls.Config{
			ClientCAs:  pool,
			ClientAuth: tls.RequireAndVerifyClientCert,
		},
	}

	err = s.ListenAndServeTLS("server.crt", "server.key")
	if err != nil {
		fmt.Println("ListenAndServeTLS err:", err)
	}
}
```


## client
```golang
package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"net/http"
)

func main() {
	pool := x509.NewCertPool()
	caCertPath := "ca.crt"

	caCrt, err := ioutil.ReadFile(caCertPath)
	if err != nil {
		fmt.Println("ReadFile err:", err)
		return
	}
	pool.AppendCertsFromPEM(caCrt)

	cliCrt, err := tls.LoadX509KeyPair("client.crt", "client.key")
	if err != nil {
		fmt.Println("Loadx509keypair err:", err)
		return
	}

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{
			RootCAs:      pool,
			Certificates: []tls.Certificate{cliCrt},
		},
	}
	client := &http.Client{Transport: tr}
	resp, err := client.Get("https://localhost:8081")
	if err != nil {
		fmt.Println("Get error:", err)
		return
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	fmt.Println(string(body))
}
```
```golang
# normal
func GetHttp(url string) (data []byte, err error) {
	klog.Infof("GetHttp url: %s", url)
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("charset", "UTF-8")

	clt := http.Client{}
	resp, err := clt.Do(req)
	if err != nil {
		return
	}
	body, err := ioutil.ReadAll(resp.Body)
	defer resp.Body.Close()
	klog.V(4).Infof("resp: %+v", resp)

	return body, err
}

# pass through nginx


type Response struct {
	ErrMsg string `json:"errMsg"`
	Body   string `json:"body"`
	Status int    `json:"status"`
}

func wrap(err error, resp *http.Response) Response {
	var r Response
	if err != nil {
		r.ErrMsg = err.Error()
	}

	if resp != nil {
		reader := resp.Body
		if resp.Header.Get("Content-Encoding") == "gzip" {
			reader, err = gzip.NewReader(resp.Body)
			if err != nil {
				klog.Errorf("gzip error: %v", err)
			}
		}
		body, err := ioutil.ReadAll(reader)

		defer resp.Body.Close()
		if err != nil {
			klog.Errorf("read resp.Body err: %v", err)
			return r
		}
		klog.Infof("body: %v", string(body))
		r.Body = string(body)
		r.Status = resp.StatusCode
	}
	return r
}
```

## trouble shouting
- 1.x509: cannot validate certificate for 1.1.1.1 because it doesn't contain any IP SANs

解决方案一：
```shell script
echo "1.1.1.1  test.com" > /etc/hosts
client use 域名调用
```

解决方案二：

关键点在于，服务端证书生成时，需要设置subjectAltName = IP:10.30.0.163，设置方式如下（通过在证书生成语句中添加-extfile extfile.cnf，实现将extfile.cnf中的内容写入到证书中）
```shell script
openssl genrsa -out server.key 2048
 
openssl req -new -key server.key -subj "/CN=1.1.1.1" -out server.csr
 
echo subjectAltName = IP:1.1.1.1 > extfile.cnf
 
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out server.crt -days 5000
```
可以使用下面命令查看服务证书内容是否有设置的服务端IP地址，如图：
```shell script
openssl x509 -in ./server.crt -noout -text
```
![image](https://xisheng.vip/images/tls-altName.png)


## link
- http://singlecool.com/2017/10/21/TLS-Go/
- https://blog.csdn.net/min19900718/article/details/87920254?utm_medium=distribute.pc_relevant_t0.none-task-blog-BlogCommendFromMachineLearnPai2-1.nonecase&depth_1-utm_source=distribute.pc_relevant_t0.none-task-blog-BlogCommendFromMachineLearnPai2-1.nonecase