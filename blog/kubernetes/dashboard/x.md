**学习基于 dashboard 1.8 版本。**

## webshell 代码逻辑

![dashboard webshell](https://www.techclone.cn/img/k8s/k8swatchdog-webshell.jpg)

webshell 调用大体分为两部：

1. 第一步，首先通过 `https://*.dashboard.cn/api/pod/{pod name}/shell` 接口请求生成 `s essionId`
2. 第二步，携带第一步返回的 sessionId 建立 wss 连接，执行 shell 命令

下面，进行详细分析各个步骤具体细节。

### shell restful api

浏览器请求 shell 接口后，通过 golang restful 框架路由到代码 `PodShell:Get` 函数入口。路由表是在 `endpoints/install.go` 中写入的，后面具体学习。

`Get` 入口函数代码：

```
func (pod *PodShell) Get(ctx context.Context, name string, options metaV1.GetOptions) (runtime.Object, error) {
    //生成session Id
	sessionId, err := exec.GenTerminalSeesionId()
    ......
    //拿k8s client 对象
	client, dc, CloseClient := utils.GetK8sClient(ctx)
    //用完归还
	defer CloseClient(client, dc)
	exec.TerminalSessions.Set(sessionId, exec.TerminalSession{
		Id:       sessionId,
		Bound:    make(chan error),
		SizeChan: make(chan remotecommand.TerminalSize),
	})
    .......
    //新建协程 等待后端 websocket 连接
	go exec.WaitForTerminal(client, cfg, ctx, sessionId)
	.......
}
func WaitForTerminal(k8sClient kubernetes.Interface, cfg *rest.Config, ctx context.Context, sessionId string) {
    ......
	// wss 连接建立后，会通过 Bound chan 通知
	select {
	case <-TerminalSessions.Get(sessionId).Bound:
		close(TerminalSessions.Get(sessionId).Bound)

        ......
            //
			err = startProcess(k8sClient, cfg, ctx, cmd, TerminalSessions.Get(sessionId))
        .......
		TerminalSessions.Close(sessionId, 1, "Process exited")
	}
}
```

### websocket 接口

先简要说一下websocket 连接建立流程： 1. 首先，需要通过 http1 协议请求，服务端接收到请求，响应 101 状态码给客户端，告知客户端升级协议（通过header头标示升级的协议，`Connection: upgrade upgrade: websocket`）为websocket; 2. 然后，客户端通过 websocket 协议与服务端进行双向通信；

k8s-watchdog 中使用的 web shell 在 websoket 基础上封装了应用层协议：

![websocket-messages](https://www.techclone.cn/img/k8s/websocket-messages.jpg)

- `o` 是升级协议后，服务端发送该字符告知客户端，服务端已经做好准备接收数据了；

- ```
  ["Op":"命令"，"SessionID":"xxxx", Data:"xxxx", "Rows":"", "Cols"]
  ```

  - Op是操作指令：
  - `bind`: 客户端告知服务端 sessionId 绑定指令，在客户端收到 `o` 字符后，立即发送该指令，之后才完全建立双向数据传输；
  - `resize`: 调整窗口大小的指令；
  - `stdout`：服务端输出；
  - `stdin`：客户端输入；

- `h` 心跳字符，服务端定时发送给客户端

接口路由注册函数，注册 `handleTerminalSession` 到 sockjs websocket 回调中：

```
func CreateAttachHandler(path string) http.Handler {
	return sockjs.NewHandler(path, sockjs.DefaultOptions, handleTerminalSession)
}
```

websocket 入口函数代码逻辑：

```
//wss://*.dashboard.cn/ws/api/sockjs/647/y12a2jym/websocket?{sessionId}请求入口函数
func (h *handler) sockjsWebsocket(rw http.ResponseWriter, req *http.Request) {
    //协议升级响应
	conn, err := websocket.Upgrade(rw, req, nil, WebSocketReadBufSize, WebSocketWriteBufSize)
	......
    //解析 url 中的 sessionId
	sessID, _ := h.parseSessionID(req.URL)
	sess := newSession(sessID, h.options.DisconnectDelay, h.options.HeartbeatDelay)
	if h.handlerFunc != nil {
        //异步回调
		go h.handlerFunc(sess)
	}

	receiver := newWsReceiver(conn)
    //注册接收器，并启动心跳（通过定时器实现），每5秒发送一个 h 字符到客户端
	sess.attachReceiver(receiver)
	readCloseCh := make(chan struct{})
    //接收数据，塞到 session 中
	go func() {
		var d []string
		for {
			err := conn.ReadJSON(&d)
			if err != nil {
				close(readCloseCh)
				return
			}
			sess.accept(d...)
		}
	}()

	select {
	case <-readCloseCh:
	case <-receiver.doneNotify():
	}
	sess.close()
	conn.Close()
}
```

websocket 回调函数

```
func handleTerminalSession(session sockjs.Session) {
	......
	if buf, err = session.Recv(); err != nil {
		glog.Warning("handleTerminalSession: can't Recv: %v\n", err)
		return
	}

	if err = ; err != nil {
		glog.Warning("handleTerminalSession: can't UnMarshal (%v): %s\n", err, buf)
		return
	}

	if msg.Op != "bind" {
		glog.Warning("handleTerminalSession: expected 'bind' message, got: %s\n", buf)
		return
	}

	if terminalSession = TerminalSessions.Get(msg.SessionID); terminalSession.Id == "" {
		glog.Warning("handleTerminalSession: can't find session '%s'", msg.SessionID)
		return
	}

	......
	terminalSession.SockJSSession = session
	TerminalSessions.Set(msg.SessionID, terminalSession)
    //通知 shell 接口 WaitForTerminal 协程
	terminalSession.Bound <- nil
}
```

WaitForTerminal 函数：

```
func WaitForTerminal(k8sClient kubernetes.Interface, cfg *rest.Config, ctx context.Context, sessionId string) {
	shell := "bash"

	//check nil chan
	//because nil channel will block receive, and throw panic when call close function
	if TerminalSessions.Get(sessionId).Bound == nil {
		return
	}

	select {
	case <-TerminalSessions.Get(sessionId).Bound:
		close(TerminalSessions.Get(sessionId).Bound)

        //建立与k8s spdy 连接接口
        startProcess(k8sClient, cfg, ctx, cmd, TerminalSessions.Get(sessionId))

        //关闭session
		TerminalSessions.Close(sessionId, 1, "Process exited")
	}
}
func startProcess(k8sClient kubernetes.Interface, cfg *rest.Config, ctx context.Context, cmd []string, ptyHandler PtyHandler) error {
	namespace := ctx.Value("namespace").(string)
	podName := ctx.Value("name").(string)
	containerName := ctx.Value("container").(string)

	req := k8sClient.CoreV1().RESTClient().Post().
		Resource("pods").
		Name(podName).
		Namespace(namespace).
		SubResource("exec")

	req.VersionedParams(&v1.PodExecOptions{
		Container: containerName,
		Command:   cmd,
		Stdin:     true,
		Stdout:    true,
		Stderr:    true,
		TTY:       true,
	}, scheme.ParameterCodec)

	exec, err := remotecommand.NewSPDYExecutor(cfg, "POST", req.URL())
	if err != nil {
		return err
	}

    //此次阻塞直到 websocket 连接关闭
	err = exec.Stream(remotecommand.StreamOptions{
		Stdin:             ptyHandler,
		Stdout:            ptyHandler,
		Stderr:            ptyHandler,
		TerminalSizeQueue: ptyHandler,
		Tty:               true,
	})
	if err != nil {
		return err
	}

	return nil
}
```