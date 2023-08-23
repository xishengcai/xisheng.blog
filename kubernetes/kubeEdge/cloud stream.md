[toc]

## Cloud Stream Code Read(v1.7.1)



## 架构说明

![image-20220113182324643](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20220113182324643.png)

Kubeedge 提供了云边stream模块，用于支 exec， log， metricr 功能。

## StreamServer 模块功能

1. 转发 kube-apiserver 的请求
2. 根据请求的内容，找到node 名称
3. 根据node 名称找到 tunnelServer 中和node 建立的wss session
4. 生成此次请求的message ID
5. 创建一个 响应kube-apiserver 结构体，并将此次请求的response 放入其中
6. 将 4作为可以， 5作为value，进行缓存
7. 通过session 发送 请求信息
8. edge 端回复数据流信息，该信息是分段的，并且可提取出messageID
9. 根据messageID ，获取步骤5中的响应体，回写response。



## TunnelServer 模块功能

1. 提供 客户端 websocket 连接接口
2. 客户端发起的websocket 保存在session中，并进行缓存。
3. session 用于cloud 和 edge  通信



## 源码概览

### 1. cloudStream 注册 and 启动

代码：/cloud/cloudcore/app/server.go,  line 121

```go
// registerModules register all the modules started in cloudcore
func registerModules(c *v1alpha1.CloudCoreConfig) {
	cloudhub.Register(c.Modules.CloudHub)
	edgecontroller.Register(c.Modules.EdgeController, c.CommonConfig)
	devicecontroller.Register(c.Modules.DeviceController)
	synccontroller.Register(c.Modules.SyncController)
  // 模块注册
	cloudstream.Register(c.Modules.CloudStream)
	router.Register(c.Modules.Router)
	dynamiccontroller.Register(c.Modules.DynamicController)
}
```



```go
func (s *cloudStream) Start() {
   // TODO: Will improve in the future
   ok := <-cloudhub.DoneTLSTunnelCerts
   if ok {
      ts := newTunnelServer()

      // start new tunnel server
      go ts.Start()

      server := newStreamServer(ts)
      // start stream server to accept kube-apiserver connection
      go server.Start()
   }
}
```



### 2. NewTunnelServer 等待edgeStream 连接

edgeNode 在与cloud stream 建立连接的时候，会根据主机名创建key， 同时创建session 存入到CloudStream的session字典中。 该session 是 edge 与 cloud 之间建立的websocket 连接，用于将cloud 的http请求发送到edge。 该session 实现了接口 stream.SafeWriteTunneler

#### 2.1 register router

```go
func (s *TunnelServer) installDefaultHandler() {
	ws := new(restful.WebService)
	ws.Path("/v1/kubeedge/connect")
	ws.Route(ws.GET("/").
		To(s.connect))
	s.container.Add(ws)
}
```



#### 2.2 handler 入口方法

```go
func (s *TunnelServer) connect(r *restful.Request, w *restful.Response) {
	hostNameOverride := r.HeaderParameter(stream.SessionKeyHostNameOverride)
	if hostNameOverride == "" {
		// TODO: Fix SessionHostNameOverride typo, remove this in v1.7.x
		hostNameOverride = r.HeaderParameter(stream.SessionKeyHostNameOverrideOld)
	}
	internalIP := r.HeaderParameter(stream.SessionKeyInternalIP)
	if internalIP == "" {
		internalIP = strings.Split(r.Request.RemoteAddr, ":")[0]
	}
	con, err := s.upgrader.Upgrade(w, r.Request, nil)
	if err != nil {
		return
	}
	klog.Infof("get a new tunnel agent hostname %v, internalIP %v", hostNameOverride, internalIP)

	session := &Session{
		tunnel:        stream.NewDefaultTunnel(con),
		apiServerConn: make(map[uint64]APIServerConnection),
		apiConnlock:   &sync.RWMutex{},
		sessionID:     hostNameOverride,
	}

	s.addSession(hostNameOverride, session)
	s.addSession(internalIP, session)
	s.addNodeIP(hostNameOverride, internalIP)
	session.Serve()
}
```



#### 2.3 获取并转发edge端发送的信息

```go
// Serve read tunnel message ,and write to specific apiserver connection
func (s *Session) Serve() {
	defer s.Close()

	for {
		t, r, err := s.tunnel.NextReader()
		if err != nil {
			klog.Errorf("get %v reader error %v", s.String(), err)
			return
		}
		if t != websocket.TextMessage {
			klog.Errorf("Websocket message type must be %v type", websocket.TextMessage)
			return
		}
		message, err := stream.ReadMessageFromTunnel(r)
		if err != nil {
			klog.Errorf("Read message from tunnel %v error %v", s.String(), err)
			return
		}


		if err := s.ProxyTunnelMessageToApiserver(message); err != nil {
			klog.Errorf("Proxy tunnel message [%s] to kube-apiserver error %v", message.String(), err)
			continue
		}
	}
}
```



#### 2.4 根据messageID ，找到对应的api 请求发起者，flush message to requestResponse

```
func (s *Session) ProxyTunnelMessageToApiserver(message *stream.Message) error {
	s.apiConnlock.RLock()
	defer s.apiConnlock.RUnlock()
	kubeCon, ok := s.apiServerConn[message.ConnectID]
	if !ok {
		return fmt.Errorf("Can not find apiServer connection id %v in %v",
			message.ConnectID, s.String())
	}
	switch message.MessageType {
	case stream.MessageTypeRemoveConnect:
		kubeCon.SetEdgePeerDone()
	case stream.MessageTypeData:
		for i := 0; i < len(message.Data); {
			n, err := kubeCon.WriteToAPIServer(message.Data[i:])
			if err != nil {
				return err
			}
			i += n
		}
	default:
	}
	return nil
}
```



### 3.一次日志流请求流程

```go
func (s *StreamServer) getContainerLogs(r *restful.Request, w *restful.Response) {
	....

	sessionKey := strings.Split(r.Request.Host, ":")[0]
	session, ok := s.tunnel.getSession(sessionKey)

	w.Header().Set("Transfer-Encoding", "chunked")
	w.WriteHeader(http.StatusOK)

	if _, ok := w.ResponseWriter.(http.Flusher); !ok {
		err = fmt.Errorf("Unable to convert %v into http.Flusher, cannot show logs", reflect.TypeOf(w))
		return
	}
  // Flusher 接口由 ResponseWriters 实现，它允许 HTTP 处理程序将缓冲数据刷新到客户端。
  // 默认的 HTTP/1.x 和 HTTP/2 ResponseWriter实现支持 Flusher，但ResponseWriter包装器可能不支持。 处理程序应始终在运行时测试此能力。
	fw := flushwriter.Wrap(w.ResponseWriter)

  // 缓存此次请求的request and response
	logConnection, err := session.AddAPIServerConnection(s, &ContainerLogsConnection{
		r:            r,
		flush:        fw,  // 后面edge 返回的信息通过 flush 回写给请求者
		session:      session,
		ctx:          r.Request.Context(),
		edgePeerStop: make(chan struct{}),
	})

	if err = logConnection.Serve(); err != nil {
		err = fmt.Errorf("apiconnection Serve %s in %s error %v",
			logConnection.String(), session.String(), err)
		return
	}
}

```



```go
func (s *Session) AddAPIServerConnection(ss *StreamServer, connection APIServerConnection) (APIServerConnection, error) {
  // cloudStream messageID 递增
  // 每次log stream 都有一个唯一的mssageID
  // session 是唯一的，但是session 里面的api 连接是随着每次请求递增的
  // 请求结束需要从session 中删除api连接
  // api连接是一个流（长链接）接口：实现类有（log， exec， metrics）
   id := atomic.AddUint64(&(ss.nextMessageID), 1)
   s.apiConnlock.Lock()
   defer s.apiConnlock.Unlock()
   if s.tunnelClosed {
      return nil, fmt.Errorf("The tunnel connection of %v has closed", s.String())
   }
   connection.SetMessageID(id)
   s.apiServerConn[id] = connection
   klog.Infof("Add a new apiserver connection %s in to %s", connection.String(), s.String())
   return connection, nil
}
```

```go
func (s *StreamServer) getContainerLogs(r *restful.Request, w *restful.Response) {
	sessionKey := strings.Split(r.Request.Host, ":")[0]
	session, _ := s.tunnel.getSession(sessionKey)
	w.Header().Set("Transfer-Encoding", "chunked")
	w.WriteHeader(http.StatusOK)
  w.ResponseWriter.(http.Flusher)
	fw := flushwriter.Wrap(w.ResponseWriter)
  
  
	logConnection, _ := session.AddAPIServerConnection(s, &ContainerLogsConnection{
		r:            r,
		flush:        fw,
		session:      session,
		ctx:          r.Request.Context(),
		edgePeerStop: make(chan struct{}),
	})

  
	logConnection.Serve()

}

```



### 4. logConnection Server logic

```go
func (l *ContainerLogsConnection) Serve() error {
	defer func() {
		klog.Infof("%s end successful", l.String())
	}()

	// first send connect message
  // 只管向ws 写msg
  // 自动读
	if _, err := l.SendConnection(); err != nil {
		klog.Errorf("%s send %s info error %v", l.String(), stream.MessageTypeLogsConnect, err)
		return err
	}

	for {
		select {
		case <-l.ctx.Done():
			// if apiserver request end, send close message to edge
			msg := stream.NewMessage(l.MessageID, stream.MessageTypeRemoveConnect, nil)
			for retry := 0; retry < 3; retry++ {
				if err := l.WriteToTunnel(msg); err != nil {
					klog.Warningf("%v send %s message to edge error %v", l, msg.MessageType, err)
				} else {
					break
				}
			}
			klog.Infof("%s send close message to edge successfully", l.String())
			return nil
		case <-l.EdgePeerDone():
			err := fmt.Errorf("%s find edge peer done, so stop this connection", l.String())
			return err
		}
	}
}
```



```go
func (l *ContainerLogsConnection) SendConnection() (stream.EdgedConnection, error) {
  // 引入边缘节点的接口对象
	connector := &stream.EdgedLogsConnection{
		MessID: l.MessageID,
    // 构建 ContainerLogsConnection 的时候，将Reqeust 传入
		URL:    *l.r.Request.URL,
		Header: l.r.Request.Header,
	}
	connector.URL.Scheme = httpScheme
	connector.URL.Host = net.JoinHostPort(defaultServerHost, fmt.Sprintf("%v", constants.ServerPort))
  
  //将请求转化成 edgeStream 可识别的 message 结构体
	m, _ := connector.CreateConnectMessage()

  // 在edge connect to cloud 的时候， 会创建session
	l.WriteToTunnel(m)

	return connector, nil
}
```



```go
func (l *EdgedLogsConnection) CreateConnectMessage() (*Message, error) {
	data, err := json.Marshal(l)
	if err != nil {
		return nil, err
	}
	return NewMessage(l.MessID, MessageTypeLogsConnect, data), nil
}
```



```go
func (l *ContainerLogsConnection) WriteToTunnel(m *stream.Message) error {
	return l.session.WriteMessageToTunnel(m)
}
```



```go

func (s *Session) WriteMessageToTunnel(m *stream.Message) error {
	return s.tunnel.WriteMessage(m)
}

```

​					