# 闭包

一般情况下 一个函数 是无法直接使用 其他函数 内的局部变量的，由此产生了必包的概念。

定义： 在函数嵌套的前提下，内函数使用外函数的变量，返回的内函数叫闭包



## 作用
- 将函数用作值传递
- 词法作用域是静态作用域

一句话总结: 重复使用函数内的局部变量, 在重复使用的过程中保护这个局部变量不被污染的一种机制





## 构造闭包
1. 用外层函数包裹要保护的变量和内层函数。

2. 外层函数将内层函数返回到外部。

3. 调用外层函数，获得内层函数的对象，保存在外部的变量中——形成了闭包。

   


## 闭包形成的原因: 
外层函数调用后，外层函数的函数作用域（AO）对象无法释放，被内层函数引用着。



## 闭包的缺点：
1.比普通函数占用更多的内存。
    
## 解决：
1.闭包不在使用时，要及时释放。
2.将引用内层函数对象的变量赋值为null。



[source doc](https://www.cnblogs.com/jiajialove/p/9049612.html)
[视频解释](https://www.bilibili.com/video/av70284152?p=3)