# dashboard 

```go
const END_OF_TRANSMISSION = "\u0004"

// PtyHandler is what remotecommand expects from a pty
type PtyHandler interface {
 io.Reader
 io.Writer
 remotecommand.TerminalSizeQueue
}

// TerminalSession implements PtyHandler (using a SockJS connection)
type TerminalSession struct {
 id            string
 bound         chan error
 sockJSSession sockjs.Session
 sizeChan      chan remotecommand.TerminalSize
 doneChan      chan struct{}
}

// TerminalMessage is the messaging protocol between ShellController and TerminalSession.
//
// OP      DIRECTION  FIELD(S) USED  DESCRIPTION
// ---------------------------------------------------------------------
// bind    fe->be     SessionID      Id sent back from TerminalResponse
// stdin   fe->be     Data           Keystrokes/paste buffer
// resize  fe->be     Rows, Cols     New terminal size
// stdout  be->fe     Data           Output from the process
// toast   be->fe     Data           OOB message to be shown to the user
type TerminalMessage struct {
 Op, Data, SessionID string
 Rows, Cols          uint16
}
```

```go
// SessionMap stores a map of all TerminalSession objects and a lock to avoid concurrent conflict
type SessionMap struct {
 Sessions map[string]TerminalSession
 Lock     sync.RWMutex
}
```

```go
// handleTerminalSession is Called by net/http for any new /api/sockjs connections
func handleTerminalSession(session sockjs.Session){}
```



```go
// CreateAttachHandler is called from main for /api/sockjs
func CreateAttachHandler(path string) http.Handler
```



2021/10/18 产品例会 CHS 组遗留问题： 思考对中小型开发团队，CNOPS如何简化操作流程？

预计解决时间 10月25日