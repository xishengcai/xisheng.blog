package  main

import "fmt"

type PublicBook interface{
	publishBook()
}

type BiSheng struct{
}

func (BiSheng) publishBook(){
	fmt.Println("活字印刷")
}

type PrintingPlant struct{
}

func (PrintingPlant) publishBook(){
	fmt.Println("激光印刷")
}

type PrintContext struct {
	publicBook PublicBook
}

/*策略类操作方法*/
func (context PrintContext) PublicBook(){
	context.publicBook.publishBook()
}

/*策略类构造函数*/
func NewPrintContext(publicBook PublicBook) *PrintContext{
	return &PrintContext{
		publicBook: publicBook,
	}
}

func main(){
	publishBook := NewPrintContext(BiSheng{})
	publishBook.PublicBook()


	publishBook = NewPrintContext(PrintingPlant{})
	publishBook.PublicBook()
}