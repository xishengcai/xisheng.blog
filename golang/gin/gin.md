https://xiaonuo.top/articles/2020/12/14/1607931833092.html





## 路由

## golang 默认路由





## middle



### 日志打印

```go
engine.Use(Logger(), Recovery())
```

```go
// Logger instances a Logger middleware that will write the logs to gin.DefaultWriter.
// By default gin.DefaultWriter = os.Stdout.
func Logger() HandlerFunc {
   return LoggerWithConfig(LoggerConfig{})
}
```

```go
// LoggerConfig defines the config for Logger middleware.
type LoggerConfig struct {
	// Optional. Default value is gin.defaultLogFormatter
	Formatter LogFormatter

	// Output is a writer where logs are written.
	// Optional. Default value is gin.DefaultWriter.
	Output io.Writer

	// SkipPaths is a url path array which logs are not written.
	// Optional.
	SkipPaths []string
}
```





## 文件服务