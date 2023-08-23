[toc]

## edge Stream code read



## 架构介绍

![image-20220113182300616](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20220113182300616.png)

## 服务启动流程

1. beehive 注册

2. 创建tunnel stream connection

   2.1 创建session

   ```
   // TunnelSession
   type TunnelSession struct {
      Tunnel        stream.SafeWriteTunneler
      closeLock     sync.Mutex
      closed        bool // tunnel whether closed
      localCons     map[uint64]stream.EdgedConnection
      localConsLock sync.RWMutex
   }
   ```

   2.2 启动 session 服务

   ​	 启动ping gorouting

    	循环事件

   ​	  	 读取云端 message

   ​			解析 message

   ​      	 判断 msg 数据类型，根据数据请求的类型，创建stream 连接，通过msg ID 标记不同的云端请求。

   ​		  	 0:  添加 edged 的日志流连接 到 localCons

   ​			   1:  添加 edged 的exec流连接  localCons

   ​           	2:  添加 edged 的 metric 连接  localCons

   ​       

   ​			edged 从容器中获取的数据流，会直接交给 session中tunnel， 执行write msg。 该tunnel 是在创建session 的时候，和cloud stream 建立起来的wss 连接。

   ​			

   

   问题：

   1. 云端 多个request  日志请求，如果共用了一个tunnel 通道发送消息， 客户端返回的信息，云端如何将信息挑拣出来正确的返回给每个请求者的？

      答： 云端的每次请求都会生成一个唯一的messageID，同时创建一个APIServerConnection，

      将 此次请求的response 放入APIServerConnection

      从tunnel 读取message，根据messageID，获取APIServerConnection， 调用起写方法。

   ​				

   2. 共用一个通道会不会拥挤？

   

   ​									

   ​     

   ​        



### Beehive 模块注册

```go
type edgestream struct {
	enable          bool
	hostnameOveride string
	nodeIP          string
}

// Register register edgestream
func Register(s *v1alpha1.EdgeStream, hostnameOverride, nodeIP string) {
	config.InitConfigure(s)
	core.Register(newEdgeStream(s.Enable, hostnameOverride, nodeIP))
}

```



### 向云端发起websocket 连接

```go
func (e *edgestream) Start() {
	serverURL := url.URL{
		Scheme: "wss",
		Host:   config.Config.TunnelServer,
		Path:   "/v1/kubeedge/connect",  // cloud 侧的ws 接口
	}
....
		for range time.NewTicker(time.Second * 2).C {
			select {
			case <-beehiveContext.Done():
				return
			default:
			}
			err := e.TLSClientConnect(serverURL, tlsConfig)
			if err != nil {
				klog.Errorf("TLSClientConnect error %v", err)
			}
		}
	}
}

```





```go
func (e *edgestream) TLSClientConnect(url url.URL, tlsConfig *tls.Config) error {
	klog.Info("Start a new tunnel stream connection ...")

	dial := websocket.Dialer{
		TLSClientConfig:  tlsConfig,
		HandshakeTimeout: time.Duration(config.Config.HandshakeTimeout) * time.Second,
	}
	
  // head 操作略
  
  // 创建websocket 连接
	con, _, err := dial.Dial(url.String(), header)
	if err != nil {
		klog.Errorf("dial %v error %v", url.String(), err)
		return err
	}
  
  // 将websocket 连接传入， 构建一个隧道会话， 子程1
	session := NewTunnelSession(con)
  
  // 启动一个websocket 永久连接，处理cloud 端的请求
	return session.Serve()
}

```



// 子程1

```go
func NewTunnelSession(c *websocket.Conn) *TunnelSession {
   return &TunnelSession{
      closeLock:     sync.Mutex{},
      localConsLock: sync.RWMutex{},
      Tunnel:        stream.NewDefaultTunnel(c),
      localCons:     make(map[uint64]stream.EdgedConnection, 128),
   }
}
```



```go
func (s *TunnelSession) Serve() error {
	...
	for {
    // 读取云端请求
		_, r, err := s.Tunnel.NextReader()
		if err != nil {
			klog.Errorf("Read Message error %v", err)
			return err
		}

    // 解析成 标准结构信息
		mess, err := stream.ReadMessageFromTunnel(r)
		if err != nil {
			klog.Errorf("Get tunnel Message error %v", err)
			return err
		}
		
    // 根据信息类型，调用edged 创建不同的stream， （log，exec，metric）
		if mess.MessageType < stream.MessageTypeData {
			go s.ServeConnection(mess)
		}
		s.WriteToLocalConnection(mess)
	}
}
```





```go
func (s *TunnelSession) ServeConnection(m *stream.Message) {
   switch m.MessageType {
   case stream.MessageTypeLogsConnect:
      if err := s.serveLogsConnection(m); err != nil {
         klog.Errorf("Serve Logs connection error %s", m.String())
      }
   case stream.MessageTypeExecConnect:
      if err := s.serveContainerExecConnection(m); err != nil {
         klog.Errorf("Serve Container Exec connection error %s", m.String())
      }
   case stream.MessageTypeMetricConnect:
      if err := s.serveMetricsConnection(m); err != nil {
         klog.Errorf("Serve Metrics connection error %s", m.String())
      }
   default:
      panic(fmt.Sprintf("Wrong message type %v", m.MessageType))
   }

   s.DeleteLocalConnection(m.ConnectID)
   klog.V(6).Infof("Delete local connection MessageID %v Type %s", m.ConnectID, m.MessageType.String())
}
```



### ServeConnection handler message

serverConnection 会根据信息类型，分发给不同的edgedConnection 子对象处理， 下面以EdgedLogsConnection为例

1. read message
2. json marshar message
3. http request to edged
4. read resp form edged
5. write resp to ws

```go
func (s *TunnelSession) serveLogsConnection(m *stream.Message) error {
   logCon := &stream.EdgedLogsConnection{
      ReadChan: make(chan *stream.Message, 128),
   }
   if err := json.Unmarshal(m.Data, logCon); err != nil {
      klog.Errorf("unmarshal connector data error %v", err)
      return err
   }
	
  // message ID 对应 EdgedLogsConnection 
   s.AddLocalConnection(m.ConnectID, logCon)
   return logCon.Serve(s.Tunnel)
}
```



```go
func (l *EdgedLogsConnection) Serve(tunnel SafeWriteTunneler) error {
	//connect edged
	client := http.Client{}
	req, _ := http.NewRequest("GET", l.URL.String(), nil)
	req.Header = l.Header
	resp, _ := client.Do(req)
...

	defer resp.Body.Close()
 
	reader := bufio.NewReader(resp.Body)
	stop := make(chan struct{})

	go func() {
		defer close(stop)

	go func() {
		defer close(l.ReadChan)
		var data [256]byte
		for {
			n, _ := reader.Read(data[:])
			msg := NewMessage(l.MessID, MessageTypeData, data[:n])
      
      // 将msg 写到 EdgedLogsConnection.ReadChan
		  tunnel.WriteMessage(msg)
		}
	}()

	<-stop
	klog.Infof("receive stop single, so stop logs scan ...")
	return nil
}
```



```go
func (s *TunnelSession) WriteToLocalConnection(m *stream.Message) {
   if con, ok := s.GetLocalConnection(m.ConnectID); ok {
      con.CacheTunnelMessage(m)
   }
}
```

```
func (l *EdgedLogsConnection) CacheTunnelMessage(msg *Message) {
   l.ReadChan <- msg
}
```

