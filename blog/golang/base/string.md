# golang string usage
strings 包中有一些常用的字符串操作方法，记录一下，方便查阅。
1、strings.HasPrefix (s string, prefix string) bool：判断字符串 s 是否以 prefix 开头
```go
/*输出：true*/
ok := strings.HasPrefix("beijing", "bei")
```

2、strings.HasSuffix (s string, suffix string) bool：判断字符串 s 是否以 suffix 结尾
```go
/*输出：true*/
ok := strings.HasSuffix("beijing", "ing")
```

3、strings.Index (s string, str string) int：判断 str 在 s 中首次出现的位置，如果没有出现，则返回 - 1
```go
/*输出：3*/
index := strings.Index("I love Golang", "ov")
```

4、strings.LastIndex (s string, str string) int：判断 str 在 s 中最后出现的位置，如果没有出现，则返回 - 1
```go
/*输出：8*/
index := strings.LastIndex("I love Golang", "o")
```

5、strings.Replace (str string, old string, new string, n int)：将字符串 str 中的 old，替换成 new，n 表示替换 n 个

```go
/*输出：I leve Golang*/
newString := strings.Replace("I love Golang", "o", "e", 1)
```

6、strings.ReplaceAll (str string, old string, new string)：将字符串 str 中的 old，全部替换成 new
```go
/*输出：I leve Gelang*/
newString := strings.ReplaceAll("I love Golang", "o", "e")
```

7、strings.Count (str string, substr string) int：计算 str 字符串中总共出现多少次 substr
```go
/*输出：2*/
index := strings.Count("I love love Golang", "ov")
```

8、strings.Repeat (str string, count int) string：重复 count 次 str
```go
/*输出：love love love*/
str := strings.Repeat("love ", 3)
```

9、strings.ToLower (str string) string：转为小写
```go
/*输出：love*/
str := strings.ToLower("LOVE")
```

10、strings.ToUpper (str string) string：转为大写
```go
/*输出：LOVE*/
str := strings.ToUpper("love")
```

11、strings.TrimSpace (str string)：去掉字符串首尾空白字符
```go
/*输出：love*/
str := strings.TrimSpace("   love   ")
```

12、strings.Trim (str string, cut string)：去掉字符串首尾 cut 字符
```go
/*输出：love*/
str := strings.Trim("@love@", "@")
```

13、strings.TrimLeft (str string, cut string)：去掉字符串首 cut 字符
```go
/*输出：love@*/
str := strings.TrimLeft("@love@", "@")
```

14、strings.TrimRight (str string, cut string)：去掉字符串右边 cut 字符
```go
/*输出：@love*/
str := strings.TrimRight("@love@", "@")
```

15、strings.Fields (str string)：返回 str 空格分隔的所有子串的 slice
```go
/*输出：[I love beijing]*/
sli := strings.Fields("I love beijing")
```

16、strings.Split (str string, split string)：返回 str split 分隔的所有子串的 slice
```go
/*输出：[I love beijing]*/
sli := strings.Split("I@love@beijing", "@")
```

17、strings.Join (s1 [] string, sep string)：用 sep 把 s1 中的所有元素链接起来
```go
/*输出：I@love@beijing*/
str := strings.Join([]string{"I", "love", "beijing"}, "@")
```

18、strconv.Itoa (i int)：把一个整数 i 转成字符串
```go
/*输出：string*/
str := strconv.Itoa(22)
fmt.Printf("%T", str)
```

19、strconv.Atoi (str string)(int, error)：把一个字符串转成整数
```go
/*输出：int*/
i, _ := strconv.Atoi("22")
fmt.Printf("%T", i)
```

————————————————
原文作者：一根毛毛闯天下
转自链接：https://learnku.com/articles/43150
版权声明：著作权归作者所有。商业转载请联系作者获得授权，非商业转载请保留以上作者信息和原文链接。