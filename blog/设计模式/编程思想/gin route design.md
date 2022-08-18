

## 

```go
type ResultRaw interface {
	GetResponse(int) Response
	ResMsg() string
	HasError() bool
	Error() error
}


type Operator interface {
	Run() ResultRaw
	SetAccount(ctx *gin.Context)
}

type Action func(p Operator)

// HandleOperator 操作接口operator
func HandleOperator(ctx *gin.Context, o Operator, action Action) {
	if err := Bind(ctx, o); err != nil {
		return
	}
	action(o)
}
```



```go
// ListSourceCodeRepo
// @Summary list source code repo
// @Router /delivery-center/v2/code-repos [GET]
// @Success 200 {object} app.Response
// @Security ApiKeyAuth
// @Tags  source code repo
func ListSourceCodeRepo(ctx *gin.Context) {
   o := &v2.CodeRepoList{}
   app.HandleOperator(ctx, o, func(o app.Operator) {
      app.HandleServiceResult(ctx, e.ListSourceCodeRepoFail, o.Run())
   })
}
```