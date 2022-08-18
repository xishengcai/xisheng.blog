
## docker 磁盘清理

## 自动清理
```bash
docker system prune
```

已使用的镜像：指所有已被容器（包括stop的）关联的镜像，也就是docker ps -a所看到的所有容器对应的image。

未引用镜像：没有被分配或使用在容器中的镜像

悬空镜像（dangling image）：未配置任何Tag（也就是无法被引用）的镜像。通常是由于镜像编译过程中未指定-t参数配置Tag导致的。

- 删除悬空的镜像
```bash
docker image prune
```


    docker container prune：删除无用的容器。
          --默认情况下docker container prune命令会清理掉所有处于stopped状态的容器
          --如果不想那么残忍统统都删掉，也可以使用--filter标志来筛选出不希望被清理掉的容器。例子：清除掉所有停掉的容器，但24内创建的除外：
          --$ docker container prune --filter "until=24h"  
    
    docker volume prune：删除无用的卷。
    docker network prune：删除无用的网络
```

## 手动清除
对于悬空镜像和未使用镜像可以使用手动进行个别删除：

1、删除所有悬空镜像，不删除未使用镜像：

    docker rmi $(docker images -f "dangling=true" -q)
    
2、删除所有未使用镜像和悬空镜像

    docker rmi $(docker images -q)
3、清理卷

如果卷占用空间过高，可以清除一些不使用的卷，包括一些未被任何容器调用的卷（-v 详细信息中若显示 LINKS = 0，则是未被调用）：
删除所有未被容器引用的卷：

    docker volume rm $(docker volume ls -qf dangling=true)
4、容器清理
如果发现是容器占用过高的空间，可以手动删除一些：


