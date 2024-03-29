# shell 判断

shell判断文件,目录是否存在或者具有权限 

```bash
#!/bin/sh 
myPath="/var/log/httpd/" 
myFile="/var /log/httpd/access.log" 
```

### 这里的-x 参数判断$myPath是否存在并且是否具有可执行权限 
```bash
if [ ! -x "$myPath"]; then 
mkdir "$myPath" 
fi 
```

### 这里的-d 参数判断$myPath是否存在 
```bash
if [ ! -d "$myPath"]; then 
 mkdir "$myPath" 
fi 
```


### 这里的-f参数判断$myFile是否存在 
```bash
if [ ! -f "$myFile" ]; then 
touch "$myFile" 
fi 
```


### 其他参数还有-n,-n是判断一个变量是否是否有值 
```bash
if [ ! -n "$myVar" ]; then 
echo "$myVar is empty" 
exit 0 
fi 
```


### 两个变量判断是否相等 
```bash
if [ "$var1" = "$var2" ]; then 
echo '$var1 eq $var2' 
else 
echo '$var1 not eq $var2' 
fi 
```


```bash
-a file exists. 
-b file exists and is a block special file. 
-c file exists and is a character special file. 
-d file exists and is a directory. 
-e file exists (just the same as -a). 
-f file exists and is a regular file. 
-g file exists and has its setgid(2) bit set. 
-G file exists and has the same group ID as this process. 
-k file exists and has its sticky bit set. 
-L file exists and is a symbolic link. 
-n string length is not zero. 
-o Named option is set on. 
-O file exists and is owned by the user ID of this process. 
-p file exists and is a first in, first out (FIFO) special file or 
named pipe. 
-r file exists and is readable by the current process. 
-s file exists and has a size greater than zero. 
-S file exists and is a socket. 
-t file descriptor number fildes is open and associated with a 
terminal device. 
-u file exists and has its setuid(2) bit set. 
-w file exists and is writable by the current process. 
-x file exists and is executable by the current process. 
-z string length is zero.
```

### shell 参数名解析
```bash
while [ $# -gt 0 ]
do
    key="$1"
    case $key in
        --image-name)
            export IMAGE_NAME=$2
            shift
        ;;
        --version)
            export VERSION=$2
            shift
        ;;
         --update-latest)
            export UPDATE_LATEST=$2
            shift
        ;;
        *)
            echo "unknown option [$key]"
            exit 1
        ;;
    esac
    shift
done
```

=

