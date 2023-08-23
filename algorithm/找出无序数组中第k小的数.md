## [找出无序数组中第k小的数](https://www.cnblogs.com/biyeymyhjob/archive/2012/10/05/2711907.html)

**题目描述：**

给定一个无序整数数组，返回这个数组中第k小的数。

 

**解析：**

最平常的思路是将数组排序，最快的排序是快排，然后返回已排序数组的第k个数，算法时间复杂度为O（nlogn），空间复杂度为O（1）。使用快排的思想，但是每次只对patition之后的数组的一半递归，这样可以将时间复杂度将为O（n）。

 

**代码实现：**

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
#include <iostream>
#include <string>
#include <cstring>
#include <vector>
#include <algorithm>

using namespace std;

void swap(int *p, int *q)
{
    int t;
    t = *p;
    *p = *q;
    *q = t;
}

int findNumberK(vector<int> &vec, int k, int s, int e)
{
    int roll = vec[s], be = 0, j = s;
    for(int i = s+1 ; i<= e ; i++)
    {
        if(vec[i] < roll)
        {
            j++;
            swap(&vec[i], &vec[j]);
            be++;
        }
    }

    swap(&vec[s], &vec[j]);

    if(be == k -1 )
        return roll;
    else if (be < k - 1)
    {
        return findNumberK(vec, k - be - 1, j + 1, e);
    }
    else
        return findNumberK(vec, k, s, j - 1);
}

int main()
{
    vector<int> a;
    int temp, k;

    cout << "input data:" << endl;
    cin >> temp;

    while(temp != 0)
    {
        a.push_back(temp);
        cin >> temp;
    }

    cout << "input K: " << endl;

    cin >> k;

    int re = findNumberK(a , k, 0 ,a.size() - 1);

    cout << "Test Result: "  << re << endl;

    sort(a.begin(), a.end(), less<int>());

    cout << "real Result: "  << a[k-1] << endl;
    return 0;
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

 

**执行效果：**

![img](https://pic002.cnblogs.com/images/2012/426620/2012100501351880.jpg)

 