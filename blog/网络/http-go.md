## 简介

[toc]

[origin text]( https://www.cnblogs.com/charlieroro/p/11409153.html)



## http 地址组成



## transport

### 作用解释

transport实现了RoundTripper接口，该接口只有一个方法RoundTrip()，故transport的入口函数就是RoundTrip()。transport的主要功能其实就是缓存了长连接，用于大量http请求场景下的连接复用，减少发送请求时TCP(TLS)连接建立的时间损耗，同时transport还能对连接做一些限制，如连接超时时间，每个host的最大连接数等。transport对长连接的缓存和控制仅限于TCP+(TLS)+HTTP1，不对HTTP2做缓存和限制。

tranport包含如下几个主要概念：

- 连接池：在idleConn中保存了不同类型(connectMethodKey)的请求连接(persistConn)。当发生请求时，首先会尝试从连接池中取一条符合其请求类型的连接使用
- readLoop/writeLoop：连接之上的功能，循环处理该类型的请求(发送request，返回response)
- roundTrip：请求的真正入口，接收到一个请求后会交给writeLoop和readLoop处理。

一对readLoop/writeLoop只能处理一条连接，如果这条连接上没有更多的请求，则关闭连接，退出循环，释放系统资源

### 结构体定义

```go
type transport struct{
  wantIdle                                                要求关闭所有idle的persistConn
  reqCanceler map[*Request]func(error)                    用于取消request
  idleConn   map[connectMethodKey][]*persistConn          idle状态的persistConn连接池，最大值受maxIdleConnsPerHost限制
  idleConnCh map[connectMethodKey]chan *persistConn       用于给调用者传递persistConn
  connPerHostCount     map[connectMethodKey]int           表示一类连接上的host数目，最大值受MaxConnsPerHost限制
  connPerHostAvailable map[connectMethodKey]chan struct{} 与connPerHostCount配合使用，判断该类型的连接数目是否已经达到上限
  idleLRU    connLRU                                      长度受MaxIdleConns限制，队列方式保存所有idle的pconn
  altProto   atomic.Value                                 nil or map[string]RoundTripper，key为URI scheme，表示处理该scheme的RoundTripper实现。注意与TLSNextProto的不同，前者表示URI的scheme，后者表示tls之上的协议。如前者不会体现http2，后者会体现http2
  Proxy func(*Request) (*url.URL, error)                  为request返回一个代理的url
  DisableKeepAlives bool                                  是否取消长连接
  DisableCompression bool                                 是否取消HTTP压缩
  MaxIdleConns int                                        所有host的idle状态的最大连接数目，即idleConn中所有连接数
  MaxIdleConnsPerHost int                                 每个host的idle状态的最大连接数目，即idleConn中的key对应的连接数
  MaxConnsPerHost                                         每个host上的最大连接数目，含dialing/active/idle状态的connections。http2时，每个host只允许有一条idle的conneciton
  DialContext func(ctx context.Context, network, addr string) (net.Conn, error) 创建未加密的tcp连接，比Dial函数增加了context控制
  Dial func(network, addr string) (net.Conn, error)       创建未加密的tcp连接，废弃，使用DialContext
  DialTLS func(network, addr string) (net.Conn, error)    为非代理模式的https创建连接的函数，如果该函数非空，则不会使用Dial函数，且忽略TLSClientConfig和TLSHandshakeTimeout；反之使用Dila和TLSClientConfig。即有限使用DialTLS进行tls协商
  TLSClientConfig *tls.Config                             tls client用于tls协商的配置
  IdleConnTimeout                                         连接保持idle状态的最大时间，超时关闭pconn
  TLSHandshakeTimeout time.Duration                       tls协商的超时时间
  ResponseHeaderTimeout time.Duration                     发送完request后等待serve response的时间
  TLSNextProto map[string]func(authority string, c *tls.Conn) RoundTripper 在tls协商带NPN/ALPN的扩展后，transport如何切换到其他协议。指tls之上的协议(next指的就是tls之上的意思)
  ProxyConnectHeader Header                               在CONNECT请求时，配置request的首部信息，可选
  MaxResponseHeaderBytes                                  指定server响应首部的最大字节数
}


```



### 入口方法

```go
func (t *Transport) RoundTrip(req *Request) (resp *Response, err error) {
    ...
    pconn, err := t.getConn(req, cm)
    if err != nil {
        t.setReqCanceler(req, nil)
        req.closeBody()
        return nil, err
    }

    return pconn.roundTrip(treq)
}
```

前面对输入的错误处理部分我们忽略， 其实就2步，先获取一个TCP长连接，所谓TCP长连接就是三次握手建立连接后不`close`而是一直保持重复使用（节约环保） 然后调用这个持久连接persistConn 这个struct的roundTrip方法



### 获取可用的持久连接

先获取一个TCP长连接，所谓TCP长连接就是三次握手建立连接后不`close`而是一直保持重复使用（节约环保） 然后调用这个持久连接persistConn 这个struct的roundTrip方法

```go
func (t *Transport) getConn(req *Request, cm connectMethod) (*persistConn, error) {
    if pc := t.getIdleConn(cm); pc != nil {
        // set request canceler to some non-nil function so we
        // can detect whether it was cleared between now and when
        // we enter roundTrip
        t.setReqCanceler(req, func() {})
        return pc, nil
    }
 
    type dialRes struct {
        pc  *persistConn
        err error
    }
    dialc := make(chan dialRes)
    //定义了一个发送 persistConn的channel

    prePendingDial := prePendingDial
    postPendingDial := postPendingDial

    handlePendingDial := func() {
        if prePendingDial != nil {
            prePendingDial()
        }
        go func() {
            if v := <-dialc; v.err == nil {
                t.putIdleConn(v.pc)
            }
            if postPendingDial != nil {
                postPendingDial()
            }
        }()
    }

    cancelc := make(chan struct{})
    t.setReqCanceler(req, func() { close(cancelc) })
 
    // 启动了一个goroutine, 这个goroutine 获取里面调用dialConn搞到
    // persistConn, 然后发送到上面建立的channel  dialc里面，    
    go func() {
        pc, err := t.dialConn(cm)
        dialc <- dialRes{pc, err}
    }()

    idleConnCh := t.getIdleConnCh(cm)
    select {
    case v := <-dialc:
        // dialc 我们的 dial 方法先搞到通过 dialc通道发过来了
        return v.pc, v.err
    case pc := <-idleConnCh:
        // 这里代表其他的http请求用完了归还的persistConn通过idleConnCh这个    
        // channel发送来的
        handlePendingDial()
        return pc, nil
    case <-req.Cancel:
        handlePendingDial()
        return nil, errors.New("net/http: request canceled while waiting for connection")
    case <-cancelc:
        handlePendingDial()
        return nil, errors.New("net/http: request canceled while waiting for connection")
    }
}
```

这里面的代码写的很有讲究 , 上面代码里面我也注释了， 定义了一个发送 `persistConn`的channel` dialc`， 启动了一个`goroutine`, 这个`goroutine` 获取里面调用`dialConn`搞到`persistConn`, 然后发送到`dialc`里面，主协程`goroutine`在 `select`里面监听多个`channel`,看看哪个通道里面先发过来 `persistConn`，就用哪个，然后`return`。



这里要注意的是 `idleConnCh` 这个通道里面发送来的是其他的http请求用完了归还的`persistConn`， 如果从这个通道里面搞到了，`dialc`这个通道也等着发呢，不能浪费，就通过`handlePendingDial`这个方法把`dialc`通道里面的`persistConn`也发到`idleConnCh`，等待后续给其他http请求使用。



还有就是，读者可以翻一下代码，每个新建的persistConn的时候都把tcp连接里地输入流，和输出流用br（`br *bufio.Reader`）,和bw(`bw *bufio.Writer`)包装了一下，往bw写就写到tcp输入流里面了，读输出流也是通过br读，并启动了读循环和写循环

```
pconn.br = bufio.NewReader(noteEOFReader{pconn.conn, &pconn.sawEOF})
pconn.bw = bufio.NewWriter(pconn.conn)
go pconn.readLoop()
go pconn.writeLoop()
```



我们跟踪第二步`pconn.roundTrip` 调用这个持久连接persistConn 这个struct的`roundTrip`方法。
先瞄一下 `persistConn` 这个struct

```go
type persistConn struct {
    t        *Transport
    cacheKey connectMethodKey
    conn     net.Conn
    tlsState *tls.ConnectionState
    br       *bufio.Reader       // 从tcp输出流里面读
    sawEOF   bool                // whether we've seen EOF from conn; owned by readLoop
    bw       *bufio.Writer       // 写到tcp输入流
     reqch    chan requestAndChan // 主goroutine 往channnel里面写，读循环从     
                                 // channnel里面接受
    writech  chan writeRequest   // 主goroutine 往channnel里面写                                      
                                 // 写循环从channel里面接受
    closech  chan struct{}       // 通知关闭tcp连接的channel 
    
    writeErrCh chan error

    lk                   sync.Mutex // guards following fields
    numExpectedResponses int
    closed               bool // whether conn has been closed
    broken               bool // an error has happened on this connection; marked broken so it's not reused.
    canceled             bool // whether this conn was broken due a CancelRequest
    // mutateHeaderFunc is an optional func to modify extra
    // headers on each outbound request before it's written. (the
    // original Request given to RoundTrip is not modified)
    mutateHeaderFunc func(Header)
}
```





## roundTrip

```go
type RoundTripper interface {
    RoundTrip(*Request) (*Response, error)
}
```







## handler

```go
// A Handler responds to an HTTP request.
//
// ServeHTTP should write reply headers and data to the ResponseWriter
// and then return. Returning signals that the request is finished; it
// is not valid to use the ResponseWriter or read from the
// Request.Body after or concurrently with the completion of the
// ServeHTTP call.
//
// Depending on the HTTP client software, HTTP protocol version, and
// any intermediaries between the client and the Go server, it may not
// be possible to read from the Request.Body after writing to the
// ResponseWriter. Cautious handlers should read the Request.Body
// first, and then reply.
//
// Except for reading the body, handlers should not modify the
// provided Request.
//
// If ServeHTTP panics, the server (the caller of ServeHTTP) assumes
// that the effect of the panic was isolated to the active request.
// It recovers the panic, logs a stack trace to the server error log,
// and either closes the network connection or sends an HTTP/2
// RST_STREAM, depending on the HTTP protocol. To abort a handler so
// the client sees an interrupted response but the server doesn't log
// an error, panic with the value ErrAbortHandler.
type Handler interface {
    ServeHTTP(ResponseWriter, *Request) //路由具体实现
}
```
