# linux 监控shell



```shell
#!/bin/bash

# 获取内存大小
total_memory=$(dmidecode -t memory | grep Capacity | awk '{print $3}')

# 获取硬盘大小数组
disk_size_array=$(fdisk -l | grep Disk | grep bytes | awk '{print $5}')

# 获取 CPU 数量
cpu_num=$(grep -c "model name" /proc/cpuinfo)

# 初始化硬盘大小总和
total_disk=0

# 对硬盘大小数组中的每个元素进行加法操作
for disk_size in $disk_size_array; do
    let total_disk+=disk_size/1024/1024/1024
done

# 输出结果
echo "{\"total_memory\": $total_memory,\"total_disk\": $total_disk,\"cpu_num\": $cpu_num}"

```

