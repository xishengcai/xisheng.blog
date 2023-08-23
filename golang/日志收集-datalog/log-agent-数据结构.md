





数据结构



LogSource   存放 LogSource 信道，和LogSource数组

LogsConfig

LogStatus

Messages

SourceType 

LatencyStats: StatusTracker:  LatencyStats跟踪来自此源的消息在处理管道中花费的时间的内部统计信息，即:
//消息被尾/侦听器/解码器解码到消息被发送者处理之间的时间间隔



Scheduler： 在不同输入类型的日志收集上创建一个新的源和服务用户启动或停止

一个“源”代表了一个文件配置、docker 标签或pod注解的 日志配置。

一个服务代表了一个进程，例如一个运行在主机上的容器

```go
// Schedule creates new sources and services from a list of integration configs.
// An integration config can be mapped to a list of sources when it contains a Provider,
// while an integration config can be mapped to a service when it contains an Entity.
// An entity represents a unique identifier for a process that be reused to query logs.
func (s *Scheduler) Schedule(configs []integration.Config) {}

schedule 从一系列的集成配置中创建新的源和服务。
当他包含一个供应商的时候一个集成配置能个映射到一系列的源。
当包含一个实体的时候，集成配置可以映射到一个服务
一个实体代表一个进程的唯一识别号，其能够被用来重复查询日志

```



```go
// LogsConfig represents a log source config, which can be for instance
// a file to tail or a port to listen to.
type LogsConfig struct {
   Type string

   Port int    // Network
   Path string // File, Journald

   Encoding     string   `mapstructure:"encoding" json:"encoding"`             // File
   ExcludePaths []string `mapstructure:"exclude_paths" json:"exclude_paths"`   // File
   TailingMode  string   `mapstructure:"start_position" json:"start_position"` // File

   IncludeUnits  []string `mapstructure:"include_units" json:"include_units"`   // Journald
   ExcludeUnits  []string `mapstructure:"exclude_units" json:"exclude_units"`   // Journald
   ContainerMode bool     `mapstructure:"container_mode" json:"container_mode"` // Journald

   Image string // Docker
   Label string // Docker
   // Name contains the container name
   Name string // Docker
   // Identifier contains the container ID
   Identifier string // Docker

   ChannelPath string `mapstructure:"channel_path" json:"channel_path"` // Windows Event
   Query       string // Windows Event

   // used as input only by the Channel tailer.
   // could have been unidirectional but the tailer could not close it in this case.
   // TODO(remy): strongly typed to an AWS Lambda LogMessage, we should probably use
   // a more generic type here.
   //Channel chan aws.LogMessage

   Service         string
   Source          string
   SourceCategory  string
   Tags            []string
   ProcessingRules []*ProcessingRule `mapstructure:"log_processing_rules" json:"log_processing_rules"`
}
```



```
// Messages holds messages and warning that can be displayed in the status
// Warnings are display at the top of the log section in the status and
// messages are displayed in the log source that generated the message
type Messages struct {
   messages map[string]string
   lock     *sync.Mutex
}



```



