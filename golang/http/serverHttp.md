

# [GO-net/http源码阅读](https://segmentfault.com/a/1190000017036460)

[![头像](https://avatar-static.segmentfault.com/205/623/2056238673-5ab883fac0829_huge128)**刘一****36**1](https://segmentfault.com/u/liuyi_276)

[发布于2018-11-16](https://segmentfault.com/a/1190000017036460/revision)

 

## GO-net/http源码阅读

[转载](https://segmentfault.com/a/1190000017036460?utm_source=sf-similar-article)

### net/http处理Http请求的基本流程

![基本流程](https://segmentfault.com/img/remote/1460000017036463?w=542&h=517)

### Http包的三个关键类型

1. `Handler接口`：所有请求的处理器、路由ServeMux都满足该接口。

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

2. `ServeMux结构体`：HTTP请求的多路转接器（路由），它负责将每一个接收到的请求的URL与一个注册模式的列表进行匹配，并调用和URL最匹配的模式的处理器。它内部用一个map来保存所有处理器Handler。

   ```go
   type ServeMux struct {
       mu sync.RWMutex   //锁，由于请求涉及到并发处理，因此这里需要一个锁机制
       m  map[string]muxEntry  // 路由规则，一个string对应一个mux实体，这里的string就是注册的路由表达式
       hosts bool // 是否在任意的规则中带有host信息
   } 
   ```

   其中的`muxEntry结构体`类型，则是保存了Handler请求处理器和匹配的模式字符串。

   ```go
   type muxEntry struct {
       h        Handler // 这个路由表达式对应哪个handler
       pattern  string  //匹配字符串
   }
   ```

   - http包有一个包级别变量DefaultServeMux，表示默认路由：var DefaultServeMux = NewServeMux()，使用包级别的http.Handle()、http.HandleFunc()方法注册处理器时都是注册到该路由中。

     ```go
     // NewServeMux allocates and returns a new ServeMux.
     func NewServeMux() *ServeMux { return new(ServeMux) }
     
     // DefaultServeMux is the default ServeMux used by Serve.
     var DefaultServeMux = &defaultServeMux
     
     var defaultServeMux ServeMux
     ```

   - ServeMux结构体有ServeHTTP()方法（满足Handler接口），主要用于间接调用它所保存的muxEntry中保存的Handler处理器的ServeHTTP()方法。

3. 关注了上面两个结构体后就产生了一个问题，我们的请求处理函数并没有显式实现ServeHTTP(ResponseWriter, *Request)，它是怎么能转换为Handler类型的对象？这里就涉及了第三个重要类型，`HandlerFunc适配器`：

   ```go
   // The HandlerFunc type is an adapter to allow the use of
   // ordinary functions as HTTP handlers. If f is a function
   // with the appropriate signature, HandlerFunc(f) is a
   // Handler that calls f.
   type HandlerFunc func(ResponseWriter, *Request)
   
   // ServeHTTP calls f(w, r).
   func (f HandlerFunc) ServeHTTP(w ResponseWriter, r *Request) {
       f(w, r)
   }
   ```

   - 自行定义的处理函数转换为Handler类型就是HandlerFunc调用之后的结果，这个类型默认就实现了ServeHTTP这个接口，即我们调用了HandlerFunc(f),强制类型转换f成为HandlerFunc类型，这样f就拥有了ServeHTTP方法。

#### HTTP服务器的执行流程

1. 通过`http.ListenAndServe(addr string, handler Handler)`启动服务，通过给定函数构造Server类型对象，然后调用Server对象的`ListenAndServer`方法，并将该方法的返回值error返回给调用方。

   ```go
   // ListenAndServe listens on the TCP network address addr and then calls
   // Serve with handler to handle requests on incoming connections.
   // Accepted connections are configured to enable TCP keep-alives.
   //
   // The handler is typically nil, in which case the DefaultServeMux is used.
   //
   // ListenAndServe always returns a non-nil error.
   func ListenAndServe(addr string, handler Handler) error {
       server := &Server{Addr: addr, Handler: handler}
       return server.ListenAndServe()
   }
   ```

2. `server.ListenAndServe()`内部调用`net.Listen("tcp", addr)`，该方法内部又调用`net.ListenTCP()`创建并返回一个net.Listener监听器ln。

   ```go
   // ListenAndServe listens on the TCP network address srv.Addr and then
   // calls Serve to handle requests on incoming connections.
   // Accepted connections are configured to enable TCP keep-alives.
   //
   // If srv.Addr is blank, ":http" is used.
   //
   // ListenAndServe always returns a non-nil error. After Shutdown or Close,
   // the returned error is ErrServerClosed.
   func (srv *Server) ListenAndServe() error {
       if srv.shuttingDown() {
           return ErrServerClosed
       }
       addr := srv.Addr
       if addr == "" {
           addr = ":http"
       }
       ln, err := net.Listen("tcp", addr)
       if err != nil {
           return err
       }
       return srv.Serve(tcpKeepAliveListener{ln.(*net.TCPListener)})
   }
   ```

   - ln通过断言转换为了net.TCPListener类型，并将转换后的类型作为参数转换为tcpKeepAliveListener对象，然后将tcpKeepAliveListener对象传给srv.Serve()函数作为参数。

3. `TCPListener`实现了Listener接口，此处tcpKeepAliveListener重写了`Accept()`方法从而实现了Listener接口。

   ```go
   // tcpKeepAliveListener sets TCP keep-alive timeouts on accepted
   // connections. It's used by ListenAndServe and ListenAndServeTLS so
   // dead TCP connections (e.g. closing laptop mid-download) eventually
   // go away.
   type tcpKeepAliveListener struct {
       *net.TCPListener
   }
   
   func (ln tcpKeepAliveListener) Accept() (net.Conn, error) {
       tc, err := ln.AcceptTCP()
       if err != nil {
           return nil, err
       }
       tc.SetKeepAlive(true) //发送心跳
       tc.SetKeepAlivePeriod(3 * time.Minute) //设置发送周期
       return tc, nil
   }
   ```

   - `Accept()`函数首先调用TCPListener对象的AcceptTCP()函数获取一个TCP连接对象tc，然后tc调用SetKeepAlive(true)，让操作系统为收到的每一个连接启动发送keepalive消息(心跳，为了保持连接不断开)。

4. `func (srv *Server) Serve(l net.Listener) error`函数处理接收到的客户端的请求信息。这个函数里有一个for{}，首先通过Listener接收请求，其次创建一个Conn，最后单独开了一个goroutine，把这个请求的数据当做参数扔给这个conn去服务：go c.serve()。这个就是高并发体现了，用户的每一次请求都是在一个新的goroutine去服务，相互不影响。

   ```go
   // Serve accepts incoming connections on the Listener l, creating a
   // new service goroutine for each. The service goroutines read requests and
   // then call srv.Handler to reply to them.
   //
   // HTTP/2 support is only enabled if the Listener returns *tls.Conn
   // connections and they were configured with "h2" in the TLS
   // Config.NextProtos.
   //
   // Serve always returns a non-nil error and closes l.
   // After Shutdown or Close, the returned error is ErrServerClosed.
   func (srv *Server) Serve(l net.Listener) error {
       if fn := testHookServerServe; fn != nil {
           fn(srv, l) // call hook with unwrapped listener
       }
   
       l = &onceCloseListener{Listener: l}
       defer l.Close()
   
       if err := srv.setupHTTP2_Serve(); err != nil {
           return err
       }
   
       if !srv.trackListener(&l, true) {
           return ErrServerClosed
       }
       defer srv.trackListener(&l, false)
   
       var tempDelay time.Duration     // how long to sleep on accept failure
       baseCtx := context.Background() // base is always background, per Issue 16220
       ctx := context.WithValue(baseCtx, ServerContextKey, srv) //新建一个context来管理每个连接conn的Go程
       for {
           rw, e := l.Accept() //调用tcpKeepAliveListener对象的 Accept() 方法
           if e != nil {
               select {
               case <-srv.getDoneChan():
                   return ErrServerClosed //退出Serve方法，并执行延迟调用（从缓存中删除当前监听器）
               default:
               }
               //如果发生了net.Error错误，则隔一段时间就重试一次，间隔时间每次翻倍，最大为1秒
               if ne, ok := e.(net.Error); ok && ne.Temporary() {
                   if tempDelay == 0 {
                       tempDelay = 5 * time.Millisecond
                   } else {
                       tempDelay *= 2
                   }
                   if max := 1 * time.Second; tempDelay > max {
                       tempDelay = max
                   }
                   srv.logf("http: Accept error: %v; retrying in %v", e, tempDelay)
                   time.Sleep(tempDelay)
                   continue
               }
               return e
           }
           tempDelay = 0
           c := srv.newConn(rw) //该方法根据net.Conn、srv构造了一个新的http.conn类型
           c.setState(c.rwc, StateNew) // before Serve can return
           go c.serve(ctx)
       }
   }
   ```

5. `func (srv *Server) newConn(rwc net.Conn) *conn`创建一个conn对象，如果debugServerConnections为真，则通过newLoggingConn将rwc中的loggingConn的name信息包装一下，添加一部分信息。

   ```go
   // debugServerConnections controls whether all server connections are wrapped
   // with a verbose logging wrapper.
   const debugServerConnections = false
   
   // Create new connection from rwc.
   func (srv *Server) newConn(rwc net.Conn) *conn {
       c := &conn{
           server: srv,
           rwc:    rwc,
       }
       if debugServerConnections {
           c.rwc = newLoggingConn("server", c.rwc)
       }
       return c
   }
   ```

6. `func (c *conn) setState(nc net.Conn, state ConnState)`通过传入一个连接和状态，根据状态的值改变服务器中该连接的追踪情况。

   ```go
   func (c *conn) setState(nc net.Conn, state ConnState) {
       srv := c.server
       switch state {
       case StateNew:
           srv.trackConn(c, true)
       case StateHijacked, StateClosed:
           srv.trackConn(c, false)
       }
       if state > 0xff || state < 0 {
           panic("internal error")
       }
       packedState := uint64(time.Now().Unix()<<8) | uint64(state)
       atomic.StoreUint64(&c.curState.atomic, packedState)
       if hook := srv.ConnState; hook != nil {
           hook(nc, state)
       }
   }
   ```

7. `c.serve(ctx)`调用`func (c *conn) serve(ctx context.Context)`读取请求，然后根据conn内保存的server来构造一个serverHandler类型，并调用它的ServeHTTP()方法：serverHandler{c.server}.ServeHTTP(w, w.req)。`ServeHTTP`路由器接收到请求之后进行判断，如果是*那么关闭链接，不然调用mux.Handler(r)返回对应设置路由的处理Handler，然后执行h.ServeHTTP(w, r)。

   ```go
   // ServeHTTP dispatches the request to the handler whose
   // pattern most closely matches the request URL.
   func (mux *ServeMux) ServeHTTP(w ResponseWriter, r *Request) {
       if r.RequestURI == "*" {
           if r.ProtoAtLeast(1, 1) {
               w.Header().Set("Connection", "close")
           }
           w.WriteHeader(StatusBadRequest)
           return
       }
       h, _ := mux.Handler(r)
       h.ServeHTTP(w, r)
   }
   ```

8. `h.ServeHTTP(w, r)`调用对应路由的handler的ServerHTTP接口,handler的ServerHTTP接口根据用户请求的URL和路由器里面存储的map去匹配的，当匹配到之后返回存储的handler，调用这个handler的ServeHTTP接口就可以执行到相应的函数。

   ```go
   func (mux *ServeMux) Handler(r *Request) (h Handler, pattern string) {
       if r.Method != "CONNECT" {
           if p := cleanPath(r.URL.Path); p != r.URL.Path {
               _, pattern = mux.handler(r.Host, p)
               return RedirectHandler(p, StatusMovedPermanently), pattern
           }
       }    
       return mux.handler(r.Host, r.URL.Path)
   }
   
   func (mux *ServeMux) handler(host, path string) (h Handler, pattern string) {
       mux.mu.RLock()
       defer mux.mu.RUnlock()
   
       // Host-specific pattern takes precedence over generic ones
       if mux.hosts {
           h, pattern = mux.match(host + path)
       }
       if h == nil {
           h, pattern = mux.match(path)
       }
       if h == nil {
           h, pattern = NotFoundHandler(), ""
       }
       return
   }
   ```

9. http包自带了几个创建常用处理器的函数：FileServer，NotFoundHandler、RedirectHandler、StripPrefix、TimeoutHandler。而RedirectHandler函数就是用来重定向的：它返回一个请求处理器，该处理器会对每个请求都使用状态码code重定向到网址url。

   ```go
   // RedirectHandler returns a request handler that redirects
   // each request it receives to the given url using the given
   // status code.
   //
   // The provided code should be in the 3xx range and is usually
   // StatusMovedPermanently, StatusFound or StatusSeeOther.
   func RedirectHandler(url string, code int) Handler {
       return &redirectHandler{url, code}
   }
   ```

### GO Http执行流程

- 首先调用Http.HandleFunc

  按顺序做了几件事：

  1 调用了DefaultServeMux的HandleFunc

  2 调用了DefaultServeMux的Handle

  3 往DefaultServeMux的map[string]muxEntry中增加对应的handler和路由规则

- 其次调用http.ListenAndServe(":9090", nil) - nil使用默认路由器

  按顺序做了几件事情：

  1 实例化Server

  2 调用Server的ListenAndServe()

  3 调用net.Listen("tcp", addr)监听端口

  4 启动一个for循环，在循环体中Accept请求

  5 对每个请求实例化一个Conn，并且开启一个goroutine为这个请求进行服务go c.serve()

  6 读取每个请求的内容w, err := c.readRequest()

  7 判断handler是否为空，如果没有设置handler（这个例子就没有设置handler），handler就设置为DefaultServeMux

  8 调用handler的ServeHttp

  9 在这个例子中，下面就进入到DefaultServeMux.ServeHttp

  10 根据request选择handler，并且进入到这个handler的ServeHTTP

  ```reasonml
  mux.handler(r).ServeHTTP(w, r)
  ```

  11 选择handler：

  A 判断是否有路由能满足这个request（循环遍历ServeMux的muxEntry）

  B 如果有路由满足，调用这个路由handler的ServeHTTP

  C 如果没有路由满足，调用NotFoundHandler的ServeHTTP