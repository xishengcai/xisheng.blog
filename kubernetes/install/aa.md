[首页](https://help.aliyun.com/)[容器服务 Kubernetes 版 ACK](https://help.aliyun.com/zh/ack/)[产品概述](https://help.aliyun.com/zh/ack/product-overview/)[产品发布记录](https://help.aliyun.com/zh/ack/product-overview/release-notes-1/)[运行时发布记录](https://help.aliyun.com/zh/ack/product-overview/release-notes-for-runtime/)Containerd运行时发布记录

# Containerd运行时发布记录

更新时间：2023-05-23 11:09:29[提交缺陷](https://xing.aliyun.com/submit?documentId=207873&website=cn&language=zh)

[产品详情](https://www.aliyun.com/product/kubernetes)

[相关技术圈](https://developer.aliyun.com/group/kubernetes/)

[我的收藏](https://help.aliyun.com/my_favorites.html)

Containerd是一个工业级标准的容器运行时，可以在宿主机中管理完整的容器生命周期。Containerd为您提供更精简、更稳定的容器运行时。本文介绍Containerd运行时的变更记录。

## 背景信息

关于Containerd运行时与其他运行时的对比详情，请参见[如何选择Docker运行时、Containerd运行时、或者安全沙箱运行时？](https://help.aliyun.com/zh/ack/ack-managed-and-ack-dedicated/user-guide/comparison-of-docker-containerd-and-sandboxed-container#task-2455499)。

## 2023年05月

|      |      |      |      |
| ---- | ---- | ---- | ---- |
|      |      |      |      |

| **版本号** | **变更时间**   | **变更内容**                                                 | **变更影响**                 |
| ---------- | -------------- | ------------------------------------------------------------ | ---------------------------- |
| 1.6.20     | 2023年05月17日 | 升级至Containerd第一个正式长期稳定（long-term stable，LTS）版本的最新版本。详情请参见[Release Notes](https://github.com/containerd/containerd/blob/v1.6.20/releases/v1.6.20.toml)。升级Go至1.18.8版本。修复多个CVE问题：[CVE-2022-41717](https://nvd.nist.gov/vuln/detail/CVE-2022-41717)[CVE-2022-41720](https://nvd.nist.gov/vuln/detail/CVE-2022-41720)[CVE-2022-41716](https://nvd.nist.gov/vuln/detail/CVE-2022-41716)[CVE-2022-27191](https://nvd.nist.gov/vuln/detail/CVE-2022-27191)新增支持自定义仓库，默认使用cert.d配置自定义Host。升级runC至v1.1.5版本。 | 此次升级不会对业务造成影响。 |

## 2022年09月

|      |      |      |      |
| ---- | ---- | ---- | ---- |
|      |      |      |      |

| **版本号** | **变更时间**   | **变更内容**                                                 | **变更影响**                 |
| ---------- | -------------- | ------------------------------------------------------------ | ---------------------------- |
| 1.5.13     | 2022年09月08日 | 修复CVE问题：[CVE-2022-24769](https://nvd.nist.gov/vuln/detail/CVE-2022-24769)[CVE-2022-31030](https://nvd.nist.gov/vuln/detail/CVE-2022-31030)解决当Cgroup被删除时FD泄漏的问题。需要Unpack容器时确保MaxConcurrentDownloads最高并发下载生效。将为Dockerfile中的Volume临时创建的Mount更改为ReadOnly。 | 此次升级不会对业务造成影响。 |

## 2022年03月

|      |      |      |      |
| ---- | ---- | ---- | ---- |
|      |      |      |      |

| **版本号** | **变更时间**   | **变更内容**                                                 | **变更影响**                 |
| ---------- | -------------- | ------------------------------------------------------------ | ---------------------------- |
| 1.5.10     | 2022年03月22日 | 修复CVE问题：[CVE-2022-23648](https://nvd.nist.gov/vuln/detail/CVE-2022-23648)[CVE-2021-43816](https://nvd.nist.gov/vuln/detail/CVE-2021-43816)[CVE-2021-41190](https://nvd.nist.gov/vuln/detail/CVE-2021-41190)升级runC至1.0.3版本。修复PID泄漏时，runC管道阻塞导致的节点NotReady等问题。 | 此次升级不会对业务造成影响。 |

## 2021年08月

|      |      |      |      |
| ---- | ---- | ---- | ---- |
|      |      |      |      |

| **版本号** | **变更时间**   | **变更内容**                                                 | **变更影响**                 |
| ---------- | -------------- | ------------------------------------------------------------ | ---------------------------- |
| 1.4.8      | 2021年08月03日 | 解决因负载高导致的Sandbox创建超时，进而导致IP资源泄漏的问题。修复CVE问题：[CVE-2021-32760](https://nvd.nist.gov/vuln/detail/CVE-2021-32760)。 | 此次升级不会对业务造成影响。 |

## 2021年06月

|      |      |      |      |
| ---- | ---- | ---- | ---- |
|      |      |      |      |

| **版本号** | **变更时间**   | **变更内容**                                                 | **变更影响**                 |
| ---------- | -------------- | ------------------------------------------------------------ | ---------------------------- |
| 1.4.6      | 2021年06月03日 | 修复CVE问题：[CVE-2021-30465](https://nvd.nist.gov/vuln/detail/CVE-2021-30465)。 | 此次升级不会对业务造成影响。 |

## 2021年03月

| **版本号** | **变更时间** | **变更内容** | **变更影响** |
| ---------- | ------------ | ------------ | ------------ |
|            |              |              |              |

| **版本号** | **变更时间**   | **变更内容**                                                 | **变更影响**                 |
| ---------- | -------------- | ------------------------------------------------------------ | ---------------------------- |
| 1.4.4      | 2021年03月16日 | 创建集群时，支持使用Containerd运行时。**说明**Containerd运行时功能处于公测阶段。 | 此次升级不会对业务造成影响。 |

## 相关文档

- [Docker运行时发布记录](https://help.aliyun.com/zh/ack/product-overview/release-notes-for-docker#task-2058522)
- [安全沙箱运行时发布记录](https://help.aliyun.com/zh/ack/product-overview/release-notes-of-sandboxed-container#task-2453570)