# Linux command



**copy**

```bash
cp -r dir /target/    # 带目录拷贝
cp -r dir/ target/    # 不带目录拷贝
```



**统计代码行数**
```bash
find ./e2e -name "*.go" |xargs cat|grep -v ^$|wc -l
```



**Macos 查看端口命令**

```
a. `netstat -nat | grep <端口号>`  , 如命令 `netstat -nat | grep 3306`
b. `netstat -nat |grep LISTEN`
```

