# heap

#### 1.什么是堆
堆分为最大堆和最小堆，其实就是完全二叉树。

最大堆要求节点的元素都要不小于其孩子，最小堆要求节点元素都不大于其左右孩子，两者对左右孩子的大小关系不做任何要求，其实很好理解。

有了上面的定义，我们可以得知，处于最大堆的根节点的元素一定是这个堆中的最大值。

堆排序是利用堆这种数据结构而设计的一种排序算法，堆排序是一种选择排序，它的最坏，最好，平均时间复杂度均为O(nlogn)，它也是不稳定排序。首先简单了解下堆结构。

性质： 一个完全二叉树的第一个非叶子节点的索引 (maxIndex-1)/2

#### 2.构建最小二叉堆

用随机生成的数组,以依次插入的方式构建一个最小二叉堆

```go
package main

import (
	"fmt"
	"math"
	"math/rand"
)

// 堆是一个完全二叉树，必须满足根节点大于两个叶子节点
// 从一个数组中构建堆：1.转二叉树 2.对半 3.siftDown
type ElementType int

type Heap struct {
	List     []ElementType
	Size     int
	Capacity int
}

func (h *Heap) size() int {
	return len(h.List)
}

// 入列, 从堆尾插入，然后向上移动
func (h *Heap) Push(data ElementType) {
	h.List = append(h.List, data)
	j := h.size() - 1
	k := (j - 1) / 2
	for j > 0 {
		if h.List[k] > h.List[j] {
			h.List[k], h.List[j] = h.List[j], h.List[k]
			j = k
			k = (j - 1) / 2
		} else {
			break
		}
	}
}

// 出列
func (h *Heap) Pop() ElementType {
	minData := h.List[0]
	if h.size() == 1 {
		h.List = []ElementType{}
		return minData
	}
	lastData := h.List[h.size()-1]
	h.List = h.List[0 : h.size()-1]
	h.List[0] = lastData
	h.ShiftDown()
	return minData
}

// 向下移动
func (h *Heap) ShiftDown() {
	c := h.size()
	for x := 0; x < c; {
		min := 2*x + 1
		if min >= c {
			break
		}

		if min+1 < c {
			if h.List[min+1] < h.List[min] {
				min += 1
			}
		}

		if h.List[min] < h.List[x] {
			h.List[x], h.List[min] = h.List[min], h.List[x]
		}

		x = min

	}
}

func RandInt(min, max int) ElementType {
	if min >= max {
		panic("min > max")
	}
	x := rand.Intn(max-min) + min
	return ElementType(x)
}

func main() {
	// 无序数组
	var heap Heap
	for i := 0; i < 20; i++ {
		heap.Push(RandInt(-100, 100))
	}

	fmt.Println("打印堆")

	line := 1
	x := 1
	maxLevel := int(math.Log2(float64(20)) + 1)
	for i := 0; i < 20; i++ {
		if x == line {
			space := math.Pow(2, float64(maxLevel-line)) - 1
			for x := space / 2; x > 0; x-- {
				fmt.Print(" ")
			}
			x += 1
		}
		fmt.Print(heap.List[i], " ")

		if math.Pow(2, float64(line))-2 == float64(i) {
			line += 1
			fmt.Println()
		}
	}
	fmt.Println()

	fmt.Println("排序")
	for heap.size() > 0 {
		fmt.Print(heap.Pop(), " ")
	}
}
```
#### 3. 堆排序步骤
- 2.1 找到第一个非叶子节点 
将一个数组假设成一个二叉堆，索引从0开始，
如下图first node is  (8-1)/2=3
![big-point-heap](https://cai-hello-1253732611.cos.ap-shanghai.myqcloud.com/share/151354.png)
- 2.2 shift down
- 2.3 依次对其他非叶子节点重复第2步

算法复杂度:

将n个元素逐个插入到一个空堆中，算法复杂度是O(nlogn)

heapify的过程， 算法复杂度为O(n)

code
```go
package main
 
import (
   "fmt"
   "math"
)
 
// 堆是一个完全二叉树，必须满足根节点大于两个叶子节点
// 从一个数组中构建堆：1.转二叉树 2.对半 3.siftDown
type ElementType int
 
 
type Heap struct {
   List []ElementType
}
// 入列, 从堆尾插入，然后向上移动
func (h *Heap)Push(data ElementType) {
   j := len(h.List)
   h.List = append(h.List, data)
   k := (j-1)/2
   for k>-1 {
      if h.List[k] > h.List[j] {
         h.List[k], h.List[j] = h.List[j], h.List[k]
         j = k
         k = (j-1)/2
      } else {
         break
      }
   }
}
 
// 出列
func (h *Heap)Pop() ElementType {
   minData := h.List[0]
   j := len(h.List)
   if j == 1{
      h.List = []ElementType{}
      return minData
   }
   lastData := h.List[j-1]
   h.List = h.List[0:j-1]
   h.ShiftDown(lastData,0)
   return minData
}
 
// 向下移动
func (heap *Heap)ShiftDown(data ElementType, begin int){
   // 从堆顶构建最小堆, 在堆顶放入一个元素
   //循环条件 begin < len(heap)
   list := heap.List
   if len(heap.List) == 1{
      heap.List[0] = data
      return
   }
   for 2*begin+1 < len(heap.List){
      minIndex := 2*begin+1
      if ((minIndex+1) < len(list)) && (list[minIndex+1] < list[minIndex]){
         minIndex +=1
      }
      if data < list[minIndex]{
         list[begin] = data
         break          //当不发生上下交换的时候,说明已经满足堆这种数据结构的性质
      }else{
         list[begin] = list[minIndex]
         list[minIndex] = data
         begin = minIndex
      }
   }
}
 
func main(){
   // 无序数组
   list := []ElementType{9,3,12,100,1000,-11,-34}
   fmt.Printf("初始无序列表:%v\r\n", list)
   var heap Heap
   heap.List = list
 
   // 将一个无序数组构建成堆，假设后半部分的数据就是一个堆的叶子节点，然后在上面一层开始从左往右构建二叉树，
   // 这里的二叉树是一个抽象的感念，真实的情况是：这个堆仍然是个数组，它的的数据是分层存储的
   half := len(list)/2
   for root:= half; root>=0; root--{
      heap.ShiftDown(list[root],root)
   }
 
   fmt.Println("往堆中插入新的数据: -100, 30, -15, -95")
   heap.Push(-100)
   heap.Push(30)
   heap.Push(-15)
   heap.Push(-95)
 
 
   fmt.Println("打印堆")
   level := 1
   for i, data := range(heap.List){
      maxIndex := 1* math.Pow(2,float64(level)) -1
      if i+1 == int(maxIndex){
         level += 1
         fmt.Printf("%v\r\n",data)
      }else{
         fmt.Printf("%v ",data)
      }
   }
 
   fmt.Println("\r\n 从堆中取数据")
   for i:=len(heap.List); i>0; i--{
      fmt.Println(len(heap.List), "   ",heap.Pop())
   }
}
```
