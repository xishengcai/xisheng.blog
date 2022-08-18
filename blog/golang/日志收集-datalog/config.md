# config



intergration_config.go

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
