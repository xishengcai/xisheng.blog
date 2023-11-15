# Grafana 日志聚合工具 Loki

*发表于 December 14, 2018*

##### 标签: [kubernetes](https://www.qikqiak.com/tags/kubernetes/)  [prometheus](https://www.qikqiak.com/tags/prometheus/)  [grafana](https://www.qikqiak.com/tags/grafana/)  [loki](https://www.qikqiak.com/tags/loki/)  [日志](https://www.qikqiak.com/tags/日志/) 

![img](https://www.qikqiak.com/img/posts/grafana-loki-cover.png)`Loki`是 Grafana Labs 团队最新的开源项目，是一个水平可扩展，高可用性，多租户的日志聚合系统。它的设计非常经济高效且易于操作，因为它不会为日志内容编制索引，而是为每个日志流编制一组标签。项目受 Prometheus 启发，官方的介绍就是：`Like Prometheus, but for logs.`，类似于 Prometheus 的日志系统。

## 介绍

与其他日志聚合系统相比，`Loki`具有下面的一些特性：

- 不对日志进行全文索引。通过存储压缩非结构化日志和仅索引元数据，Loki 操作起来会更简单，更省成本。
- 通过使用与 Prometheus 相同的标签记录流对日志进行索引和分组，这使得日志的扩展和操作效率更高。
- 特别适合储存 Kubernetes Pod 日志; 诸如 Pod 标签之类的元数据会被自动删除和编入索引。
- 受 Grafana 原生支持。

Loki 由以下3个部分组成：

- `loki`是主服务器，负责存储日志和处理查询。
- `promtail`是代理，负责收集日志并将其发送给 loki 。
- `Grafana`用于 UI 展示。

## 安装

DockerHub 上提供了[Loki](https://hub.docker.com/r/grafana/loki/)和[Promtail](https://hub.docker.com/r/grafana/promtail/)的 Docker 镜像，为了方便我们这里直接使用 docker-compose 进行一键安装，其他方式可以参考`Loki`的[文档介绍](https://github.com/grafana/loki)。

首先直接 Clone 源代码：

```shell
$ git clone https://github.com/grafana/loki.git
# 进入 docs 目录
$ cd loki/docs
```

在 docs 目录下面有我们运行的 yaml 文件：(docker-compose.yaml)

```yaml
version: "3"

networks:
  loki:

services:
  loki:
    image: grafana/loki:master
    ports:
      - "3100:3100"
    volumes:
      - $PWD:/etc/loki
    command: -config.file=/etc/loki/loki-local-config.yaml
    networks:
      - loki

  promtail:
    image: grafana/promtail:make-images-static-26a87c9
    volumes:
      - $PWD:/etc/promtail
      - /var/log:/var/log
    command:
      -config.file=/etc/promtail/promtail-docker-config.yaml
    networks:
      - loki

  grafana:
    image: grafana/grafana:master
    ports:
      - "3000:3000"
    environment:
      GF_EXPLORE_ENABLED: "true"
    networks:
      - loki
```

然后直接使用 docker-compose 启动即可：

```shell
$ docker-compose up -d
```

上面的命令会去默认使用当前文件夹下面的`docker-compose.yaml`文件创建，创建完成后查看创建的容器：

```shell
$ docker-compose ps
     Name                    Command               State               Ports
-----------------------------------------------------------------------------------------
docs_grafana_1    /run.sh                          Up      0.0.0.0:3000->3000/tcp
docs_loki_1       /bin/loki -config.file=/et ...   Up      0.0.0.0:3100->3100/tcp, 80/tcp
docs_promtail_1   /usr/bin/promtail -config. ...   Up
```

到这里证明已经安装成功了。

## 使用

安装完成后，访问上面节点的 3000 端口访问 grafana，默认情况下使用(admin:admin)访问 -> 选择添加数据源：

![grafana-loki-dashsource](https://www.qikqiak.com/img/posts/grafana-loki-dashsource.png)

在数据源列表中选择`Loki`，配置 Loki 源地址：

![grafana-loki-dashsource-config](https://www.qikqiak.com/img/posts/grafana-loki-dashsource-config.png)

源地址配置`http://loki:3100`即可，保存。

保存完成后，切换到 grafana 左侧区域的`Explore`，即可进入到`Loki`的页面：

![grafana-loki](https://www.qikqiak.com/img/posts/grafana-loki.png)

然后我们点击`Log labels`就可以把当前系统采集的日志标签给显示出来，可以根据这些标签进行日志的过滤查询：

![grafana-loki-log-labels](https://www.qikqiak.com/img/posts/grafana-loki-log-labels.png)

比如我们这里选择`/var/log/messages`，就会把该文件下面的日志过滤展示出来，不过由于时区的问题，可能还需要设置下时间才可以看到数据：

![grafana-loki-logs](https://www.qikqiak.com/img/posts/grafana-loki-logs.png)

## 选择器

对于查询表达式的标签部分，将其包装在花括号中`{}`，然后使用键值对的语法来选择标签，多个标签表达式用逗号分隔，比如：

```shell
{app="mysql",name="mysql-backup"}
```

目前支持以下标签匹配运算符：

- `=`等于
- `!=`不相等
- `=~`正则表达式匹配
- `!~`不匹配正则表达式

比如：

```shell
{name=~"mysql.+"}
{name!~"mysql.+"}
```

适用于`Prometheus`标签选择器规则同样也适用于`Loki`日志流选择器。

想要了解`Loki`的原始设计文档的可以点击查看这里的文档：[`Loki`设计文档](https://docs.google.com/document/d/11tjK_lvp1-SVsFZjgOTr1vV3-q6vBAsZYIQ5ZeYBkyM/view)



## grafana dashboard



```json
{
  "annotations": {
    "list": [
      {
        "$$hashKey": "object:75",
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "target": {
          "limit": 100,
          "matchAny": false,
          "tags": [],
          "type": "dashboard"
        },
        "type": "dashboard"
      }
    ]
  },
  "description": "Log Viewer Dashboard for Loki",
  "editable": false,
  "fiscalYearStartMonth": 0,
  "gnetId": 13639,
  "graphTooltip": 0,
  "id": 21,
  "iteration": 1699946386957,
  "links": [
    {
      "$$hashKey": "object:59",
      "icon": "bolt",
      "includeVars": true,
      "keepTime": true,
      "tags": [],
      "targetBlank": true,
      "title": "View In Explore",
      "type": "link",
      "url": "/explore?orgId=1&left=[\"now-1h\",\"now\",\"Loki\",{\"expr\":\"{job=\\\"$app\\\"}\"},{\"ui\":[true,true,true,\"none\"]}]"
    },
    {
      "$$hashKey": "object:61",
      "icon": "external link",
      "tags": [],
      "targetBlank": true,
      "title": "Learn LogQL",
      "type": "link",
      "url": "https://grafana.com/docs/loki/latest/logql/"
    }
  ],
  "liveNow": false,
  "panels": [
    {
      "aliasColors": {},
      "bars": true,
      "dashLength": 10,
      "dashes": false,
      "datasource": {
        "type": "loki",
        "uid": "e9jG8wVIk"
      },
      "fieldConfig": {
        "defaults": {
          "links": []
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 3,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 6,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": false,
        "total": false,
        "values": false
      },
      "lines": false,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "8.4.5",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "sum(count_over_time({job=\"$app\"} |= \"$search\" [$__interval]))",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeRegions": [],
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "mode": "time",
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "$$hashKey": "object:168",
          "format": "short",
          "logBase": 1,
          "show": false
        },
        {
          "$$hashKey": "object:169",
          "format": "short",
          "logBase": 1,
          "show": false
        }
      ],
      "yaxis": {
        "align": false
      }
    },
    {
      "datasource": {
        "type": "loki",
        "uid": "e9jG8wVIk"
      },
      "gridPos": {
        "h": 25,
        "w": 24,
        "x": 0,
        "y": 3
      },
      "id": 2,
      "maxDataPoints": "",
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [
        {
          "expr": "{job=\"$app\"} |= \"$search\" | logfmt",
          "hide": false,
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "transparent": true,
      "type": "logs"
    }
  ],
  "refresh": false,
  "schemaVersion": 35,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": [
      {
        "current": {
          "selected": true,
          "text": "iss-dev/drs-api",
          "value": "iss-dev/drs-api"
        },
        "datasource": {
          "type": "loki",
          "uid": "e9jG8wVIk"
        },
        "definition": "label_values(job)",
        "hide": 0,
        "includeAll": false,
        "label": "App",
        "multi": false,
        "name": "app",
        "options": [],
        "query": "label_values(job)",
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 0,
        "tagValuesQuery": "",
        "tagsQuery": "",
        "type": "query",
        "useTags": false
      },
      {
        "current": {
          "selected": false,
          "text": "",
          "value": ""
        },
        "hide": 0,
        "label": "String Match",
        "name": "search",
        "options": [
          {
            "selected": true,
            "text": "",
            "value": ""
          }
        ],
        "query": "",
        "skipUrlSync": false,
        "type": "textbox"
      }
    ]
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {
    "hidden": false,
    "refresh_intervals": [
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "Logs / App",
  "uid": "sadlil-loki-apps-dashboard",
  "version": 1,
  "weekStart": ""
}
```

