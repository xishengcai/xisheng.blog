本文录自 https://zhuanlan.zhihu.com/p/599699193?utm_id=0&eqid=f47f3d63000c2dff0000000464904e1d



## **Loki 简介**

Loki 的第一个稳定版本于 2019 年 11 月 19 日发布，是 Grafana Labs 团队最新的开源项目，是一个水平可扩展，高可用性，多租户的日志聚合系统。Loki 是专门用于聚集日志数据，重点是高可用性和可伸缩性。与竞争对手不同的是，它确实易于安装且资源效率极高。

项目地址：**[https://github.com/grafana/loki/](https://link.zhihu.com/?target=https%3A//github.com/grafana/loki/)** 。

![img](https://pic2.zhimg.com/80/v2-e6aa73ec1c7720d34e3cc5ba3d1ca6c1_720w.webp)

与其他日志聚合系统相比，Loki 具有下面的一些特性：

- 不对日志进行全文索引。通过存储压缩非结构化日志和仅索引元数据，Loki 操作起来会更简单，更省成本。
- 通过使用与 Prometheus 相同的标签记录流对日志进行索引和分组，这使得日志的扩展和操作效率更高，能对接 alertmanager。
- 特别适合储存 Kubernetes Pod 日志；诸如 Pod 标签之类的元数据会被自动删除和编入索引。
- 受 Grafana 原生支持，避免 kibana 和 grafana 来回切换。

我们来简单总结一下 Loki 的优缺点。

**优点** ：

1. Loki 的架构非常简单，使用了和 Prometheus 一样的标签来作为索引，通过这些标签既可以查询日志的内容也可以查询到监控的数据，不但减少了两种查询之间的切换成本，也极大地降低了日志索引的存储。
2. 与 ELK 相比，消耗的成本更低，具有成本效益。
3. 在日志的收集以及可视化上可以连用 Grafana，实现在日志上的筛选以及查看上下行的功能。

**缺点** ：

1. 技术比较新颖，相对应的论坛不是非常活跃。
2. 功能单一，只针对日志的查看，筛选有好的表现，对于数据的处理以及清洗没有 ELK 强大，同时与 ELK 相比，对于后期，ELK 可以连用各种技术进行日志的大数据处理，但是 loki 不行。

## **Loki 架构**

Loki 的架构如下：

![img](https://pic2.zhimg.com/80/v2-549593541aa4754c7e272adbba9f90c1_720w.webp)

不难看出，Loki 的架构非常简单，使用了和 Prometheus 一样的标签来作为索引，也就是说，你通过这些标签既可以查询日志的内容也可以查询到监控的数据，不但减少了两种查询之间的切换成本，也极大地降低了日志索引的存储。Loki 将使用与 Prometheus 相同的服务发现和标签重新标记库，编写了 pormtail，在 Kubernetes 中 promtail 以 DaemonSet 方式运行在每个节点中，通过 Kubernetes API 等到日志的正确元数据，并将它们发送到 Loki。下面是日志的存储架构：

![img](https://pic1.zhimg.com/80/v2-d16624383375819f35e3e530cd29d9dc_720w.webp)

## **Loki 组成**

1. Loki 是主服务器，负责存储日志和处理查询。
2. Promtail 是代理，负责收集日志并将其发送给 Loki 。
3. Grafana 用于 UI 展示。

## **Loki 实战**

本次安装使用 Docker 部署

### **1.0 安装 docker-compose**

```bash
curl -L "https://github.com/docker/compose/releases/download/1.28.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### **2.0 下载 yaml 文件**

```yaml
wget https://raw.githubusercontent.com/grafana/loki/v2.2.0/production/docker-compose.yaml -O docker-compose.yaml
version: "3"

networks:
  loki:

services:
  loki:
    image: grafana/loki:2.0.0
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - loki

  promtail:
    image: grafana/promtail:2.0.0
    volumes:
      - /var/log:/var/log
    command: -config.file=/etc/promtail/config.yml
    networks:
      - loki

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    networks:
      - loki
```

### **3.0 启动服务**

```text
docker-compose -f docker-compose.yaml up
```

### **4.0 检查服务**

![img](https://pic2.zhimg.com/80/v2-efc229e2dfa71fe9a4513b0611957351_720w.webp)

### **5.0 配置服务**

[http://192.168.106.202:3000/](https://link.zhihu.com/?target=http%3A//192.168.106.202%3A3000/)

默认 Granfna 密码 admin/admin

### **5.1 配置数据源**

![img](https://pic3.zhimg.com/80/v2-a45b7ddf538ab6d71d2854cdadd2ea0a_720w.webp)

配置 ip 和默认数据源，配置完成点击测试/保存

![img](https://pic1.zhimg.com/80/v2-de88b9a553a02c449e4fde13443b049c_720w.webp)

### **5.2 配置数据源**

explore 查询样例

![img](https://pic1.zhimg.com/80/v2-d01bd5accc03c973fb4c52f619feac30_720w.webp)

### **5.3 输出匹配日志信息**

![img](https://pic2.zhimg.com/80/v2-eb17a5dcefb6d52525a88bb3f6420e81_720w.webp)

至此一次样例日志查询完成

### **6.0 promtail 配置详解**

promtail 容器为日志采集容器，配置文件在 promtail 容器/etc/promtail/config.yml，将该容器部署在需要采集日志的服务器上就能正常采集日志传回 loki 服务收集整理

```yaml
root@2a0cc144dd58:/#  cat  /etc/promtail/config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push     #这里配置的地址为loki服务器日志收集的信息

scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      job: varlogs                       #这里为刚才选择job下子标签
      __path__: /var/log/*log            #将采集的日志放在/var/log/*log下自动发现
```

### **7.0 增加一台服务器日志采集**

### **7.1 编写 promtail 的配置文件 config.yml**

```yaml
mkdir  /root/promtail  &&cd  /root/promtail

[root@node2 promtail]# cat config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://192.168.106.202:3100/loki/api/v1/push     #这里配置的地址为loki服务器日志收集的信息

scrape_configs:
- job_name: mysql
  static_configs:
  - targets:
      - localhost
    labels:
      job: mysql                         #这里为刚才选择job下子标签
      __path__: /var/log/*log            #将采集的日志放在/var/log/*log下自动发现
```

### **7.2 编写 docker-compose.yaml 配置文件**

```yaml
[root@node2 promtail]# cat  docker-compose.yaml
version: "v1"

services:
  promtail:
    image: grafana/promtail:2.0.0               #拉去镜像
    container_name: promtail-node              #镜像名称
    volumes:
      - /root/promtail/config.yml:/etc/promtail/config.yml    #挂载目录
      - /var/log:/var/log
    network_mode: 'host'
```

### **7.3 启动**

```text
docker-compose up -d
```

### **8.0 去 loki 上查看检索**

![img](https://pic4.zhimg.com/80/v2-7bf9335ce4624f268fa04c17c278a333_720w.webp)

![img](https://pic4.zhimg.com/80/v2-87567ef84501990f726336c4bc017647_720w.webp)

![img](https://pic3.zhimg.com/80/v2-c36564ae604def7cb15a181bed78d83a_720w.webp)

可以根据数据查询到相应日志信息。

## 后记

自荐一个非常不错的 Java 教程类开源项目：[JavaGuide](https://link.zhihu.com/?target=https%3A//javaguide.cn/) ，目前这个项目在 Github 上收到了 125k+ 的 star。

![img](https://pic3.zhimg.com/80/v2-728fb636e52fe98ee24dd825f2149932_720w.webp)

并且，这个项目还推出了一个 PDF 版本：**[完结撒花！时隔 596 天，《JavaGuide 面试突击版》5.0 来啦！](https://link.zhihu.com/?target=https%3A//mp.weixin.qq.com/s/csn6_HPuu4aFPwmZSIPOrw)**。

**PDF 版本内容概览**（附带暗黑模式版本） ：

![img](https://pic3.zhimg.com/80/v2-2d6a4fc93ec501cb25364a925b162956_720w.webp)

目录清晰，都是细节：

![img](https://pic3.zhimg.com/80/v2-7124849fb46006540fb5d1a234719dde_720w.webp)









Helm charts

https://github.com/grafana/helm-charts/blob/main/charts/promtail/values.yaml