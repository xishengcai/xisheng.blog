
## linux下删除空行的几种方法
### 1. grep
```bash
grep -v '^$' file
```

### 2. sed
```bash

sed '/^$/d'  file 或 sed -n '/./p' file

#转义
sed -i 's/\[toc\]/<!-- toc -->/g' *.md

# 批量替换多个文件中的字符
sed -i 's/Always/IfNotPresent/g *.yaml `grep -rl "Always" . `
```

### 3.awk
```bash
awk '/./ {print}' file 或 awk '{if($0!=" ") print}'
```



### 4.tr

```bash
tr -s "n"
```