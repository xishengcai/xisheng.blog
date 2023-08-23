搜索思想 DFS-BFS

深度优先搜索的步骤分为：

1. 递归下去
2. 回溯上来

顾名思义，深度优先，则是以深度优先为准则，先一条路走到底，直到达到目标。这里称之为递归下去



如何寻找和边界联通的O？ 从边界出发，对图进行DFS 和BFS

bfs， 递归。可以想想二叉树中如何递归的进行层序遍历

bfs    非递归。一般用队列存储。

dfs 	递归。最常用，如二叉树的先序遍历。

dfs	非递归。 一般用stack。

```
int goal_x = 9, goal_y = 9;
int n = 10, m = 10;
int graph[n][m];
int used[n][m];
int px[] = {-1, 0, 1, 0}
int py[] = {0, -1, 0, 1}
int flag = 0;

void DFS(int graph[][], int used[), int x, int y) {
		if (grph[x][y] == graph[goal_x][goal_y]){
				printf("Successful")
				flag = 1;
				return;
		}
		
		// 遍历四个方向
		for(int i =0 ;i !=4; ++i){
				int new_x = x + px[i] , new_y = y + py[i];
				if (new_x >= 0 && new_x < n && new_y >= 0 && new_y < m && 
					used[new_x][new_y] == 0 && !flag) {
							used[new_x][new_y] = 1;
							DFS(graph, used, new_x, new_y);
							used[new_x][new_y] = 0;
					}
		}
}
```





```
int n = 10, m = 10;
void BFS()
{
	queue que;
	int graph[n][m]
	int px[] = {-1, 0, 1, 0};
	int py[] = {0, -1, 0, 1};
	que.push(起点入队);
	while( !que.empty()) {
		auto temp = que.pop();
		for (int i = 0;i != 4;++i){
			if() {
			
			}
		}
	}

}
```





并查集的思想就是，同一个连通区域内的所有点的根节点是同一个。将每个点映射成一个数字。先

假设每个带你的根节点就是他们自己，然后我们以此输入连通的点对，然后将其中一个点的根节点赋成

另一个节点的根节点，这样这两个点所在的连通区域相互连通了。并查集的主要操作有：

- find(int m): 这是并查集的基本操作，查找m的根节点
- isConnected(int m, int n): 判断m，n两个点是否在一个连通区域
- union(int m, int n): 合并m， n 两个点所在的连通区域