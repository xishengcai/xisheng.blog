# kubeblocks（v0.7）



## overview

kubeblocks 是一款 云原生 数据库管理平台，提供数据库的创建、监控、备份、恢复等功能。支持多个云厂商的基础设施。

关键特性

- 兼容AWS、GCP、Azure、阿里云。
- 支持MySQL, PostgreSQL, Redis, MongoDB, Kafka等。
- 提供生产级性能、弹性、可伸缩性和可观察性。
- 简化升级、扩展、监控、备份和恢复等第二天的操作。
- 包含一个强大而直观的命令行工具。
- 在几分钟内设置一个全栈、生产就绪的数据基础设施。

## Architecture

![KubeBlocks Architecture](https://kubeblocks.io/assets/images/kubeblocks-architecture-d6ba033fdd4424e46d3de5233f2becb6.png)

# Supported add-ons

KubeBlocks, as a cloud-native data infrastructure based on Kubernetes, providing management and control for relational databases, NoSQL databases, vector databases, and stream computing systems; and these databases can be all added as addons.

| Add-ons                               | Description                                                  |
| ------------------------------------- | ------------------------------------------------------------ |
| apecloud-mysql                        | ApeCloud MySQL is a database that is compatible with MySQL syntax and achieves high availability through the utilization of the RAFT consensus protocol. |
| clickhouse                            |                                                              |
| elasticsearch                         | Elasticsearch is a distributed, RESTful search engine optimized for speed and relevance on production-scale workloads. |
| etcd                                  | etcd is a strongly consistent, distributed key-value store that provides a reliable way to store data that needs to be accessed by a distributed system or cluster of machines. |
| foxlake                               | ApeCloud FoxLake is an open-source cloud-native data warehouse. |
| ggml                                  | GGML is a tensor library for machine learning to enable large models and high performance on commodity hardware. |
| greptimedb                            | GreptimeDB is an open-source time-series database with a special focus on scalability, analytical capabilities and efficiency. |
| kafka                                 | Apache Kafka is an open-source distributed event streaming platform used by thousands of companies for high-performance data pipelines, streaming analytics, data integration, and mission-critical applications. |
| mariadb                               | MariaDB is a high performance open source relational database management system that is widely used for web and application servers. |
| milvus                                | Milvus is a flexible, reliable, & blazing-fast cloud-native, open-source vector database. |
| mongodb                               | MongoDB is a document-oriented NoSQL database used for high volume data storage. |
| mysql (Primary-Secondary replication) |                                                              |
| nebula                                | NebulaGraph is an open source graph database that can store and process graphs with trillions of edges and vertices. |
| neon                                  | Neon is Serverless Postgres built for the cloud.             |
| oceanbase                             | Unlimited scalable distributed database for data-intensive transactional and real-time operational analytics workloads, with ultra-fast performance that has once achieved world records in the TPC-C benchmark test. OceanBase has served over 400 customers across the globe and has been supporting all mission critical systems in Alipay. |
| official-postgresql                   | An official PostgreSQL cluster definition Helm chart for Kubernetes. |
| openldap                              | The OpenLDAP Project is a collaborative effort to develop a robust, commercial-grade, fully featured, and open source LDAP suite of applications and development tools. This chart provides KubeBlocks. |
| opensearch                            | Open source distributed and RESTful search engine.           |
| oracle-mysql                          | MySQL is a widely used, open-source relational database management system (RDBMS). |
| oriolebd                              | OrioleDB is a new storage engine for PostgreSQL, bringing a modern approach to database capacity, capabilities and performance to the world's most-loved database platform. |
| pika                                  | Pika is a persistent huge storage service, compatible with the vast majority of redis interfaces, including string, hash, list, zset, set and management interfaces. |
| polardb-x                             | PolarDB-X is a cloud native distributed SQL Database designed for high concurrency, massive storage, complex querying scenarios. |
| postgresql                            | PostgreSQL is an advanced, enterprise class open source relational database that supports both SQL (relational) and JSON (non-relational) querying. |
| pulsar                                | Apache® Pulsar™ is an open-source, distributed messaging and streaming platform built for the cloud. |
| qdrant                                | Qdrant is a vector database & vector similarity search engine. |
| redis                                 | Redis is a fast, open source, in-memory, key-value data store. |
| risingwave                            | RisingWave is a distributed SQL database for stream processing. It is designed to reduce the complexity and cost of building real-time applications. |
| starrocks                             | StarRocks is a next-gen, high-performance analytical data warehouse that enables real-time, multi-dimensional, and highly concurrent data analysis. |
| tdengine                              | TDengine™ is an industrial data platform purpose-built for the Industrial IoT, combining a time series database with essential features like stream processing, data subscription, and caching. |
| vllm                                  | vLLM is a fast and easy-to-use library for LLM inference and serving. |
| weaviate                              | Weaviate is an open-source vector database.                  |
| zookeeper                             | Apache ZooKeeper is a centralized service for maintaining configuration information, naming, providing distributed synchronization, and providing group services. |



## Supported functions of add-ons

| Add-on (v0.7.0)                       | version                                 | Vscale | Hscale | Volumeexpand | Stop/Start | Restart | Backup/Restore | Logs | Config | Upgrade (DB engine version) | Account | Failover | Switchover | Monitor |
| ------------------------------------- | --------------------------------------- | ------ | ------ | ------------ | ---------- | ------- | -------------- | ---- | ------ | --------------------------- | ------- | -------- | ---------- | ------- |
| apecloud-mysql                        | 8.0.30                                  | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | ✔️              | ✔️    | ✔️      | N/A                         | ✔️       | ✔️        | ✔️          | ✔️       |
| clickhouse                            | 22.9.4                                  | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| elasticsearch                         | 8.8.2                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| etcd                                  | 3.5.6                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| foxlake                               | 0.2.0                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| ggml                                  | N/A                                     |        | N/A    | N/A          | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| greptimedb                            | 0.3.2                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| kafka                                 | 3.3.2                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | ✔️      | N/A                         | N/A     | N/A      | N/A        | ✔️       |
| mariadb                               | 10.6.15                                 | ✔️      | N/A    | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| milvus                                | 2.2.4                                   | ✔️      | N/A    | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| mongodb                               | 4.0 4.2 4.4 5.0 5.0.20 6.0 sharding-5.0 | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | ✔️              | ✔️    | ✔️      | N/A                         | N/A     | ✔️        | ✔️          | ✔️       |
| mysql (Primary-Secondary replication) | 5.7.42 8.0.33                           | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | ✔️       |
| nebula                                | 3.5.0                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| neon                                  | latest                                  | ✔️      | N/A    | N/A          | N/A        | N/A     | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| oceanbase                             | 4.2.0.0-100010032023083021              |        | ✔️      | ✔️            | N/A        | N/A     | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| official-postgresql                   | 12.15 14.7 14.7-zhparser                | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| openldap                              | 2.4.57                                  | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| opensearch                            | 2.7.0                                   | ✔️      | N/A    | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| oracle-mysql                          | 8.0.32 8.0.32-perf                      | ✔️      | N/A    | ✔️            | ✔️          | ✔️       | ✔️              | N/A  | ✔️      | N/A                         | N/A     | N/A      | N/A        | N/A     |
| orioledb                              | beta1                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| polardb-x                             | 2.3                                     | ✔️      | ✔️      | N/A          | ✔️          | N/A     | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | ✔️       |
| postgresql                            | 12.14.0 12.14.1 12.15.0 14.7.2 14.8.0   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | ✔️              | ✔️    | ✔️      | ✔️                           | ✔️       | ✔️        | ✔️          | ✔️       |
| pulsar                                | 2.11.2                                  | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | ✔️      | N/A                         | N/A     | N/A      | N/A        | ✔️       |
| qdrant                                | 1.5.0                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | ✔️              | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | ✔️       |
| redis                                 | 7.0.6                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | ✔️              | ✔️    | ✔️      | N/A                         | ✔️       | ✔️        | N/A        | ✔️       |
| risingwave                            | 1.0.0                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| starrocks                             | 3.1.1                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| tdengine                              | 3.0.5.0                                 | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| vllm                                  | N/A                                     | N/A    | N/A    | N/A          | ✔️          | ✔️       | N/A            | N/A  | N/A    | N/A                         | N/A     | N/A      | N/A        | N/A     |
| weaviate                              | 1.18.0                                  | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | N/A  | ✔️      | N/A                         | N/A     | N/A      | N/A        | ✔️       |
| zookeeper                             | 3.7.1                                   | ✔️      | ✔️      | ✔️            | ✔️          | ✔️       | N/A            | ✔️    | ✔️      | N/A                         | N/A     | N/A      | N/A        | N/A     |



# Add-ons of KubeBlocks

KubeBlocks is a control and management platform to manage a bunch of database engines and other add-ons.

This series provides basic knowledge of add-ons, so you can get a quick start and become a member of the KubeBlocks community.

KubeBlocks features a rich add-on ecosystem with major databases, streaming and vector databases, including:

- Relational Database: ApeCloud-MySQL (MySQL RaftGroup cluster), PostgreSQL (Replication cluster)
- NoSQL Database: MongoDB, Redis
- Graph Database: Nebula (from community contributors)
- Time Series Database: TDengine, Greptime (from community contributors)
- Vector Database: Milvus, Qdrant, Weaviate, etc.
- Streaming: Kafka, Pulsar

Adding an add-on to KubeBlocks is easy, you can just follow this guide to add the add-on to KubeBlocks as long as you know the followings:

1. How to write a YAML file (e.g., You should know how many spaces to add when indenting with YAML).
2. Knowledge about Helm (e.g. What is Helm and Helm chart).
3. Have tried K8s (e.g., You should know what a pod is, or have installed an operator on K8s with Helm).
4. Grasp basic concepts of KubeBlocks, such as ClusterDefinition, ClusterVersion and Cluster. If you have any question, you can join our [slack channel](https://join.slack.com/t/kubeblocks/shared_invite/zt-22cx2f84x-BPZvnLRqBOGdZ_XSjELh4Q) to ask.



## source code

### dataprotection



### lorry



### maage



### reloader

Reloader is a service that watch changes in ConfigMap and trigger a config dynamic reload without process restart.  Reloader is capable of killing containers or processes in pod, serviced through GRPC API, the controller do rolling upgrades on Pods by using the API.

Reloader是一个服务，它监视ConfigMap中的变化，并触发配置动态加载，而不需要重启进程。Reloader能够杀死pod中的容器或进程，通过GRPC API提供服务，控制器使用API在pod上进行滚动升级。