## Go语言标准库操作Redis数据库

![img](https://pic.cnblogs.com/avatar/622406/20151012214116.png)
本文作者：** [timelesszhuang](https://www.cnblogs.com/timelesszhuang)

**本文链接：** https://www.cnblogs.com/timelesszhuang/p/go-redis.html

**关于博主：** 评论和私信会在第一时间回复。或者[直接私信](https://msg.cnblogs.com/msg/send/timelesszhuang)我。

**版权声明：** 本博客所有文章除特别声明外，均采用 [BY-NC-SA](https://creativecommons.org/licenses/by-nc-nd/4.0/) 许可协议。转载请注明出处！

**声援博主：** 如果您觉得文章对您有帮助，可以点击文章右下角**【[推荐](javascript:void(0);)】**一下。



[toc]

**快速了解 Redis 数据库**
描述: Redis是一个开源的内存数据库, Redis提供了多种不同类型的数据结构，很多业务场景下的问题都可以很自然地映射到这些数据结构上。除此之外，通过复制、持久化和客户端分片等特性，我们可以很方便地将Redis扩展成一个能够包含数百GB数据、每秒处理上百万次请求的系统。

**Redis 支持的数据结构**

- 字符串（strings）
- 哈希（hashes）
- 列表（lists）
- 集合（sets）
- 带范围查询的排序集合（sorted sets）
- 位图（bitmaps）
- hyperloglogs
- 带半径查询和流的地理空间索引等数据结构（geospatial indexes）

**Redis 应用场景**

- 高速缓存系统：减轻主数据库（MySQL）的压力 `set keyname`
  。
- 计数场景：比如微博、抖音中的关注数和粉丝数 `incr keyname`
  。
- 热门排行榜: 需要排序的场景特别适合使用 `ZSET`
  。
- 实现消息队列的功能: 简单的队列操作使用list类型实现,L表示从左边(头部)开始插与弹出，R表示从右边(尾部)开始插与弹出,例如`"lpush / rpop" - (满足先进先出的队列模式)`
  和`"rpush / lpop" - (满足先进先出的队列模式)`
  。

### Redis 环境准备

描述: 此处使用Docker快速启动一个redis环境，如有不会的朋友可以看我前面关于Docker文章或者百度。

以下是启动一个redis server，利用docker启动一个名为redis的容器,注意此处的版本为5.0.8、容器名和端口号请根据自己需要设置。



```shell
# -- Server
$ docker run --name redis -p 6379:6379 -d redis:5.0.8

# -- 查看运行的 redis 容器
$ docker ps | grep "redis"
24eb3c6f7bab  redis   "docker-entrypoint.s…"   19 months ago   Up 2 weeks  0.0.0.0:6379->6379/tcp   redis

# -- 查询redis容器资源使用状态 (扩展)
$ docker stats redis
CONTAINER ID        NAME                CPU %               MEM USAGE / LIMIT   MEM %               NET I/O             BLOCK I/O           PIDS
24eb3c6f7bab        redis               0.10%               9.02MiB / 2.77GiB   0.32%               20.8MB / 126MB      33.5MB / 16.2MB     4
```

以下方法是启动一个 redis-cli 连接上面的 redis server



```shell
# -- Client 
docker run -it --network host --rm redis:5.0.8 redis-cli

# -- 交互式
$ docker exec -it redis bash
root@24eb3c6f7bab:/data# redis-cli
127.0.0.1:6379> ping
(error) NOAUTH Authentication required.
127.0.0.1:6379> auth weiyigeek.top
OK
127.0.0.1:6379> ping
PONG
```

### Redis 客户端库安装

描述: 在网页项目开发中redis数据库的使用也比较频繁，本节将介绍在Go语言中如何连接操作Redis数据库以及客户库的基本安装和使用。

Go 语言中常用的Redis Client库:

- redigo : https://github.com/gomodule/redigo
- go-redis : https://github.com/go-redis/redis

Tips: 此处我们采用go-redis来连接Redis数据库并进行一系列的操作,因为其支持连接哨兵及集群模式的Redis。

使用命令下载安装go-redis库: `go get -u github.com/go-redis/redis`

### Redis 数据库连接

描述: 前面我们下载并安装了`go-redis`
第三方库, 下面我将分别进行单节点连接和集群连接演示, 并将其封装为package方便后续试验进行调用.

#### 1.Redis单节点连接



```go
// weiyigeek.top/studygo/Day09/MySQL/mypkg/initredis.go
package mypkg
import (
	"fmt"
	"github.com/go-redis/redis"
)

// 定义一个RedisSingleObj结构体
type RedisSingleObj struct {
	Redis_host string
	Redis_port uint16
	Redis_auth string
	Database   int
	Db         *redis.Client
}

// 结构体InitSingleRedis方法: 用于初始化redis数据库
func (r *RedisSingleObj) InitSingleRedis() (err error) {
	// Redis连接格式拼接
	redisAddr := fmt.Sprintf("%s:%d", r.Redis_host, r.Redis_port)
	// Redis 连接对象: NewClient将客户端返回到由选项指定的Redis服务器。
	r.Db = redis.NewClient(&redis.Options{
		Addr:        redisAddr,    // redis服务ip:port
		Password:    r.Redis_auth, // redis的认证密码
		DB:          r.Database,   // 连接的database库
		IdleTimeout: 300,          // 默认Idle超时时间
		PoolSize:    100,          // 连接池
	})
	fmt.Printf("Connecting Redis : %v\n", redisAddr)

	// 验证是否连接到redis服务端
	res, err := r.Db.Ping().Result()
	if err != nil {
		fmt.Printf("Connect Failed! Err: %v\n", err)
		return err
	} else {
		fmt.Printf("Connect Successful! Ping => %v\n", res)
		return nil
	}
}
```

调用程序:



```go
// weiyigeek.top/studygo/Day09/MySQL/demo6/singeredis.go
package main

import (
	"weiyigeek.top/studygo/Day09/MySQL/mypkg"
)

func main() {
	// 实例化RedisSingleObj结构体
	conn := &mypkg.RedisSingleObj{
		Redis_host: "10.20.172.248",
		Redis_port: 6379,
		Redis_auth: "weiyigeek.top",
	}

	// 初始化连接 Single Redis 服务端
	err := conn.InitSingleRedis()
	if err != nil {
		panic(err)
	}

	// 程序执行完毕释放资源
	defer conn.Db.Close()
}
```

执行结果:



```go
Connecting Redis : 10.20.172.248:6379
Connect Successful! Ping() => PONG
```

#### 2.Redis哨兵模式连接



```go
// 定义一个RedisClusterObj结构体
type RedisSentinelObj struct {
  Redis_master string
	Redis_addr []string
	Redis_auth string
	Db         *redis.Client
}

// 结构体方法
func (r *RedisSentinelObj) initSentinelClient()(err error){
	r.Db = redis.NewFailoverClient(&redis.FailoverOptions{
		MasterName:    "master",
		SentinelAddrs: []string{"x.x.x.x:26379", "xx.xx.xx.xx:26379", "xxx.xxx.xxx.xxx:26379"},
	})
	_, err = rdb.Ping().Result()
	if err != nil {
		return err
	}
	return nil
}
```

#### 3.Redis集群模式连接



```go
// 定义一个RedisClusterObj结构体
type RedisClusterObj struct {
	Redis_addr []string
	Redis_auth string
	Db         *redis.Client
}

// 结构体方法
func (r *RedisSingleObj) initClusterClient()(err error){
	r.Db = redis.NewClusterClient(&redis.ClusterOptions{
		Addrs: []string{":7000", ":7001", ":7002", ":7003", ":7004", ":7005"},
	})
	_, err = rdb.Ping().Result()
	if err != nil {
		return err
	}
	return nil
}
```

#### 4.V8新版本连接方式(重点)

描述: 最新版本的`go-redis`
库是v8版本, 在使用前我们必须进行安装：`go get github.com/go-redis/redis/v8`
。
项目地址: https://pkg.go.dev/github.com/go-redis/redis/v8

注意最新版本的`go-redis`
库相关命令新增了上下文操作，所以需要传递`context.Context`
参数，例如：



```go
package main
import (
	"context"
	"fmt"
	"time"
	"github.com/go-redis/redis/v8" // 注意导入的是新版本
)
var (
	rdb *redis.Client
)
// 初始化连接
func initClient() (err error) {
	rdb = redis.NewClient(&redis.Options{
		Addr:     "localhost:16379",
		Password: "",  // no password set
		DB:       0,   // use default DB
		PoolSize: 100, // 连接池大小
	})

  // 需要使用context库
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = rdb.Ping(ctx).Result()
	return err
}

func V8Example() {
	ctx := context.Background()
	if err := initClient(); err != nil {
		return
	}
  // 设置Key
	err := rdb.Set(ctx, "key", "value", 0).Err()
	if err != nil {
		panic(err)
	}
  // 获取存在的Key
	val, err := rdb.Get(ctx, "key").Result()
	if err != nil {
		panic(err)
	}
	fmt.Println("key", val)

  // 获取不存在的Key
	val2, err := rdb.Get(ctx, "key2").Result()
	if err == redis.Nil {
		fmt.Println("key2 does not exist")
	} else if err != nil {
		panic(err)
	} else {
		fmt.Println("key2", val2)
	}
}

// Output: key value
// key2 does not exist
```

### Redis 数据类型指令操作实践

描述: 在使用`go-redis`
来操作redis前,我们可以通过redis-cli命令进入到交互式的命令行来执行相关命令并查看执行后相应的效果便于读者理解。

Step 1.首先我们连接到服务端.



```shell
// 连接到redis服务器 -a 指定认证字符串
redis-cli -a weiyigeek.top

// 验证连接状态
127.0.0.1:6379> ping  
PONG // 表示连接正常
```

Step 2. Redis 字符串数据类型的相关命令用于管理 redis 字符串值



```shell
// 设置key并指定字符串(String)
127.0.0.1:6379> set myname "weiyigeek" EX 60
OK
// 获取指定key存在的字符串(String)
127.0.0.1:6379> get myname
"weiyigeek"
127.0.0.1:6379> get myname  // 等待60s后该keys失效
(nil)
```

Step 3. Redis hash 特别适合用于存储对象它是一个 string 类型的 field（字段） 和 value（值） 的映射表



```shell
127.0.0.1:6379> HMSET mymsets name "weiygeek" age 13 hobby "Study Go!"
OK
127.0.0.1:6379> HGET mymsets name  // 指定键的指定字段值
"weiygeek"
127.0.0.1:6379> HGETALL mymsets   // 获取在哈希表中指定 key 的所有字段和值
1) "name"
2) "weiygeek"
3) "age"
4) "13"
5) "hobby"
6) "Study Go!"
```

Step 4. Redis List 是简单的字符串列表，按照插入顺序排序。



```shell
127.0.0.1:6379>  LPUSH mylpush one "C" tow "C#" there "Java" four "Go" // 头部插入
(integer) 8
127.0.0.1:6379>  LRANGE mylpush 0 7  // 从0开始到1的范围内数据
1) "Go"
2) "four"
3) "Java"
4) "there"
5) "C#"
6) "tow"
7) "C"
8) "one"
127.0.0.1:6379> LINDEX mylpush 0  // 获取索引为0的值
"Go"
127.0.0.1:6379> LINDEX mylpush 1  // 获取索引为1的值
"four"
127.0.0.1:6379> LPOP mylpush      // 移除列表第一个元素，返回值为移除的元素。0 ->
"Go"
127.0.0.1:6379> RPOP mylpush      // 移除列表的最后一个元素，返回值为移除的元素。-1 <-  
"one"
127.0.0.1:6379> RPUSH mylpush "末尾"  // 向末尾进行插入值
(integer) 7
127.0.0.1:6379> LINDEX mylpush -1    // 
"\xe6\x9c\xab\xe5\xb0\xbe"
```

Step 5. Set是 String 类型的无序集合且集合成员是唯一的



```shell
127.0.0.1:6379> SADD mysadds 1 redis 8 mongodb 3 mysql 4 oracle 5 db2
(integer) 10
127.0.0.1:6379> SMEMBERS mysadds // 返回集合中的所有成员
 1) "8"
 2) "5"
 3) "3"
 4) "4"
 5) "mongodb"
 6) "oracle"
 7) "mysql"
 8) "db2"
 9) "1"
10) "redis"
127.0.0.1:6379> SCARD mysadds  // 获取集合的成员数
(integer) 10
127.0.0.1:6379> SPOP mysadds   // 随机移除成员
"db2"
127.0.0.1:6379> SPOP mysadds
"mysql"
```

Step 6. Redis 有序集合是 string 类型元素的集合且不允许重复的成员, 但是会通过分数来为集合中的成员进行从小到大的排序。



```shell
127.0.0.1:6379> ZADD mysets 100 "Go" 90 "Python" 80 "Ruby" 70 "C"
(integer) 4
127.0.0.1:6379> ZRANGE mysets 0 5 withscores  // 指定范围
1) "C"
2) "70"
3) "Ruby"
4) "80"
5) "Python"
6) "90"
7) "Go"
8) "100"
127.0.0.1:6379> ZRANGE mysets 0 -1   // 整个集合
1) "C"
2) "Ruby"
3) "Python"
4) "Go"
127.0.0.1:6379> ZRANGE mysets -1 3   // 获取分数最高的值-1代表倒数第一个。
1) "Go"
127.0.0.1:6379> ZRANGE mysets -2 2
1) "Python"
127.0.0.1:6379> ZRANGE mysets -3 1
1) "Ruby"
127.0.0.1:6379> ZRANGE mysets -4 0
1) "C"
```

Step 7. Redis HyperLogLog 是用来做基数统计的算法，HyperLogLog 的优点是，在输入元素的数量或者体积非常非常大时，计算基数所需的空间总是固定 的、并且是很小的。



```shell
127.0.0.1:6379> PFADD myhlkey "redis"  // 添加指定元素到 HyperLogLog 中。
(integer) 1
127.0.0.1:6379> PFADD myhlkey "memcache"
(integer) 1
127.0.0.1:6379> PFADD myhlkey "mysql"
(integer) 1
127.0.0.1:6379> PFADD myhlkey "redis"  
(integer) 0
127.0.0.1:6379> PFCOUNT myhlkey  // 返回给定 HyperLogLog 的基数估算值。
(integer) 3
```

Step 8. 发布订阅 (pub/sub) 是一种消息通信模式：发送者 (pub) 发送消息，订阅者 (sub) 接收消息。



```shell
# 第一个 redis-cli 客户端，在我们实例中我们创建了订阅频道名为 weiyigeekChat:
redis 127.0.0.1:6379> SUBSCRIBE weiyigeekChat
Reading messages... (press Ctrl-C to quit)
1) "subscribe"
2) "weiyigeekChat"
3) (integer) 1

# 第二个 redis-cli 客户端,在同一个频道 weiyigeekChat 发布两次消息，订阅者就能接收到消息。
redis 127.0.0.1:6379> PUBLISH weiyigeekChat "Redis PUBLISH test"
(integer) 1
redis 127.0.0.1:6379> PUBLISH weiyigeekChat "Learn redis by weiyigeek.top"
(integer) 1

# 订阅者的客户端会显示如下消息
1) "subscribe"
2) "weiyigeekChat"
3) (integer) 1

1) "message"
2) "weiyigeekChat"
3) "Redis PUBLISH test"

1) "message"
2) "weiyigeekChat"
3) "Learn redis by weiyigeek.top"
```

Step 9.Redis 事务可以一次执行多个命令, 一个事务从开始到执行会经历以下三个阶段：`开始事务`
,`命令入队`
,`执行事务`
。



```shell
redis 127.0.0.1:6379> MULTI  # 开启事务
OK

redis 127.0.0.1:6379> SET book-name "Mastering C++ in 21 days"
QUEUED
redis 127.0.0.1:6379> GET book-name
QUEUED
redis 127.0.0.1:6379> SADD tag "C++" "Programming" "Mastering Series"
QUEUED
redis 127.0.0.1:6379> SMEMBERS tag
QUEUED

redis 127.0.0.1:6379> EXEC  # 执行所有事务块内的命令
1) OK
2) "Mastering C++ in 21 days"
3) (integer) 3
4) 1) "Mastering Series"
   2) "C++"
   3) "Programming"
```

Step 10. Redis GEO 主要用于存储地理位置信息，并对存储的信息进行操作，该功能在 Redis 3.2 版本新增。



```shell
# 1.将一个或多个经度(longitude)|、纬度(latitude)-、位置名称(member)添加到指定的 key 中
# 重庆 经度:106.55 纬度:29.57
# 四川成都 经度:104.06	纬度:30.67
GEOADD cityAddr 106.55 29.57 ChongQing 104.06 30.67 SichuanChengDu

# 2.返回所有指定名称(member)的位置（经度和纬度），不存在的返回 nil。
GEOPOS cityAddr ChongQing SichuanChengDu NonExistKey
1) 1) "106.5499994158744812"
   2) "29.5700000136221135"
2) 1) "104.05999749898910522"
   2) "30.67000055930392222"
3) (nil)

# 3.用于返回两个给定位置之间的距离,此处计算重庆与程度的距离（m ：米，默认单位、km ：千米、mi ：英里、ft ：英尺）。
GEODIST cityAddr ChongQing SichuanChengDu km
"268.9827"

# 4.以给定的经纬度为中心， 返回键包含的位置元素当中， 与中心的距离不超过给定最大距离的所有位置元素。
# WITHDIST: 在返回位置元素的同时， 将位置元素与中心之间的距离也一并返回。
# WITHCOORD: 将位置元素的经度和纬度也一并返回。
# WITHHASH: 以 52 位有符号整数的形式， 返回位置元素经过原始 geohash 编码的有序集合分值。这个选项主要用于底层应用或者调试， 实际中的作用并不大。
127.0.0.1:6379> GEORADIUS cityAddr 105 29 200 km WITHDIST WITHCOORD
1) 1) "ChongQing"
   2) "163.1843"
   3) 1) "106.5499994158744812"
      2) "29.5700000136221135"

# 5.geohash 用于获取一个或多个位置元素的 geohash 值。
GEOHASH cityAddr ChongQing SichuanChengDu
127.0.0.1:6379> GEOHASH cityAddr ChongQing SichuanChengDu
1) "wm7b0x53dz0"
2) "wm3yrzq1tw0"
```

Step 11.Redis Stream 主要用于消息队列（MQ，Message Queue），Redis 本身是有一个 Redis 发布订阅 (pub/sub) 来实现消息队列的功能，但它有个缺点就是消息无法持久化，如果出现网络断开、Redis 宕机等，消息就会被丢弃，它是Redis 5.0 版本新增加的数据结构。



```shell
# 使用 XADD 向队列添加消息，如果指定的队列不存在，则创建一个队列
XADD mystreams * Name "WeiyiGeek" Age 25 Hobby "Computer"
"1640313258699-0"
XADD mystreams * Addr ChongQing
"1640313276946-0"

# 消息队列长度
127.0.0.1:6379> XLEN mystreams
(integer) 2

# 打印队列存储的字段与值( - 表示最小值 ,+ 表示最大值 )
127.0.0.1:6379> XRANGE mystreams - +
1) 1) "1640313258699-0"
   2) 1) "Name"
      2) "WeiyiGeek"
      3) "Age"
      4) "25"
      5) "Hobby"
      6) "Computer"
2) 1) "1640313276946-0"
   2) 1) "Addr"
      2) "ChongQing"

#  使用 XTRIM 对流进行修剪，限制长度， 语法格式：
127.0.0.1:6379> XTRIM mystreams MAXLEN 1
(integer) 1
127.0.0.1:6379> XRANGE mystreams - +
1) 1) "1640313276946-0"
   2) 1) "Addr"
      2) "ChongQing"

# 从 Stream 头部读取两条消息
127.0.0.1:6379> XADD mystreams * Name "WeiyiGeek" Age 25 Hobby "Computer"
127.0.0.1:6379> XREAD COUNT 2 STREAMS mystreams  writers 0-0 0-0
1) 1) "mystreams"
   2) 1) 1) "1640313276946-0"
         2) 1) "Addr"
            2) "ChongQing"
      2) 1) "1640313910204-0"
         2) 1) "Name"
            2) "WeiyiGeek"
            3) "Age"
            4) "25"
            5) "Hobby"
            6) "Computer"

# 从 Stream 头部读取1条消息
127.0.0.1:6379> XREAD COUNT 1 STREAMS mystreams  writers 0-0 0-0
1) 1) "mystreams"
   2) 1) 1) "1640313276946-0"
         2) 1) "Addr"
            2) "ChongQing"


# 使用 XGROUP CREATE 创建消费者组,此处从头部消费,如果想从尾部消费请将0-0改成$
127.0.0.1:6379> XGROUP CREATE mystreams consumer-group-name 0-0
OK

# 使用 XREADGROUP GROUP 读取消费组中的消息
# XREADGROUP GROUP group consumer [COUNT count] [BLOCK milliseconds] [NOACK] STREAMS key [key ...] ID [ID ...]
# group ：消费组名
# consumer ：消费者名。
# count ：读取数量。
# milliseconds ：阻塞毫秒数。
# key ：队列名。
# ID ：消息 ID。
127.0.0.1:6379> XREADGROUP GROUP consumer-group-name consumer-name COUNT 1 STREAMS mystreams >
1) 1) "mystreams"
   2) 1) 1) "1640313276946-0"
         2) 1) "Addr"
            2) "ChongQing"
127.0.0.1:6379> XREADGROUP GROUP consumer-group-name consumer-name COUNT 1 STREAMS mystreams >
1) 1) "mystreams"
   2) 1) 1) "1640313910204-0"
         2) 1) "Name"
            2) "WeiyiGeek"
            3) "Age"
            4) "25"
            5) "Hobby"
            6) "Computer"
127.0.0.1:6379> XREADGROUP GROUP consumer-group-name consumer-name COUNT 1 STREAMS mystreams >
(nil)
```

### Redis 客户端库基本使用

#### Go-Redis V8 初始化连接

描述: 此处采用Go-Redis V8 版本, 下述将其封装为包以便后续调用。



```go
// weiyigeek.top/studygo/Day09/MySQL/mypkg/initredis.go
package mypkg

import (
	"context"
	"fmt"
	"time"

	"github.com/go-redis/redis/v8"
)

// 定义一个全局变量
var (
	RedisClient *redis.Client
)

// 定义一个RedisSingleObj结构体
type RedisSingleObj struct {
	Redis_host string
	Redis_port uint16
	Redis_auth string
	Database   int
}

// 结构体InitSingleRedis方法: 用于初始化redis数据库
func (r *RedisSingleObj) InitSingleRedis() (*redis.Client, error) {
	// Redis连接格式拼接
	redisAddr := fmt.Sprintf("%s:%d", r.Redis_host, r.Redis_port)
	// Redis 连接对象: NewClient将客户端返回到由选项指定的Redis服务器。
	RedisClient = redis.NewClient(&redis.Options{
		Addr:        redisAddr,    // redis服务ip:port
		Password:    r.Redis_auth, // redis的认证密码
		DB:          r.Database,   // 连接的database库
		IdleTimeout: 300,          // 默认Idle超时时间
		PoolSize:    100,          // 连接池
	})
	fmt.Printf("Connecting Redis : %v\n", redisAddr)

	// go-redis库v8版本相关命令都需要传递context.Context参数,Background 返回一个非空的Context,它永远不会被取消，没有值，也没有期限。
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// 验证是否连接到redis服务端
	res, err := RedisClient.Ping(ctx).Result()
	if err != nil {
		fmt.Printf("Connect Failed! Err: %v\n", err)
		return nil, err
	}

	// 输出连接成功标识
	fmt.Printf("Connect Successful! \nPing => %v\n", res)
	return RedisClient, nil
}
```

**调用演示:**



```go
package main
import (
	"context"
	"fmt"
	"time"
	"github.com/go-redis/redis/v8"
	"weiyigeek.top/studygo/Day09/MySQL/mypkg"
)

// 最新版本的go-redis库的相关命令都需要传递context.Context参数
var ctx = context.Background()

func main() {
	// 实例化RedisSingleObj结构体
	conn := &mypkg.RedisSingleObj{
		Redis_host: "10.20.172.248",
		Redis_port: 6379,
		Redis_auth: "weiyigeek.top",
	}
	// 初始化连接 Single Redis 服务端
	redisClient, err := conn.InitSingleRedis()
	if err != nil {
		fmt.Printf("[Error] - %v\n", err)
		return
	}
	// 程序执行完毕释放资源
	defer redisClient.Close()
}
```

### Redis 基本指令操作示例

#### 字符串(string)类型操作

**常用方法:**

- Keys():根据正则获取keys
- Type():获取key对应值得类型
- Del():删除缓存项
- Exists():检测缓存项是否存在
- Expire(),ExpireAt():设置有效期
- TTL(),PTTL():获取有效期
- DBSize():查看当前数据库key的数量
- FlushDB():清空当前数据
- FlushAll():清空所有数据库
- Set():设置键缓存
- SetEX():设置并指定过期时间
- SetNX():设置并指定过期时间,仅当key不存在的时候才设置。
- Get():获取键值
- GetRange():字符串截取
- Incr():增加+1
- IncrBy():按指定步长增加
- Decr():减少-1
- DecrBy():按指定步长减少
- Append():追加
- StrLen():获取长度

**示例1.redis数据库中字符串的set与get操作实践.**



```go
// Redis String Set/Get 示例
func setGetExample(rdb *redis.Client, ctx context.Context) {
	// 1.Set 设置 key 如果设置为-1则表示永不过期
	err := rdb.Set(ctx, "score", 100, 60*time.Second).Err()
	if err != nil {
		fmt.Printf("set score failed, err:%v\n", err)
		panic(err)
	}

	// 2.Get 获取已存在的Key其存储的值
	val1, err := rdb.Get(ctx, "score").Result() // 获取其值
	if err != nil {
		fmt.Printf("get score failed, err:%v\n", err)
		panic(err)
	}
	fmt.Printf("val1 -> score ：%v\n", val1)

	// Get 获取一个不存在的值返回redis.Nil 则说明不存在
	val2, err := rdb.Get(ctx, "name").Result()
	if err == redis.Nil {
		fmt.Println("[ERROR] - Key [name] not exist")
	} else if err != nil {
		fmt.Printf("get name failed, err:%v\n", err)
		panic(err)
	}
	// Exists() 方法用于检测某个key是否存在
	n, _ := rdb.Exists(ctx, "name").Result()
	if n > 0 {
		fmt.Println("name key 存在!")
	} else {
		fmt.Println("name key 不存在!")
		rdb.Set(ctx, "name", "weiyi", 60*time.Second)
	}
	val2, _ = rdb.Get(ctx, "name").Result()
	fmt.Println("val2 -> name : ", val2)

	// 3.SetNX 当不存在key时将进行设置该可以并设置其过期时间
	val3, err := rdb.SetNX(ctx, "username", "weiyigeek", 0).Result()
	if err != nil {
		fmt.Printf("set username failed, err:%v\n", err)
		panic(err)
	}
	fmt.Printf("val3 -> username: %v\n", val3)

	// 4.Keys() 根据正则获取keys, DBSize() 查看当前数据库key的数量.
	keys, _ := rdb.Keys(ctx, "*").Result()
	num, err := rdb.DBSize(ctx).Result()
	if err != nil {
		panic(err)
	}
	fmt.Printf("All Keys : %v, Keys number : %v \n", keys, num)

  // 根据前缀获取Key
  vals, _ := rdb.Keys(ctx, "user*").Result()


	// 5.Type() 方法用户获取一个key对应值的类型
	vType, err := rdb.Type(ctx, "username").Result()
	if err != nil {
		panic(err)
	}
	fmt.Printf("username key type : %v\n", vType)

	// 6.Expire()方法是设置某个时间段(time.Duration)后过期，ExpireAt()方法是在某个时间点(time.Time)过期失效.
	val4, _ := rdb.Expire(ctx, "name", time.Minute*2).Result()
	if val4 {
		fmt.Println("name 过期时间设置成功", val4)
	} else {
		fmt.Println("name 过期时间设置失败", val4)
	}
	val5, _ := rdb.ExpireAt(ctx, "username", time.Now().Add(time.Minute*2)).Result()
	if val5 {
		fmt.Println("username 过期时间设置成功", val5)
	} else {
		fmt.Println("username 过期时间设置失败", val5)
	}

	// 7.TTL()与PTTL()方法可以获取某个键的剩余有效期
	userTTL, _ := rdb.TTL(ctx, "user").Result() // 获取其key的过期时间
	usernameTTL, _ := rdb.PTTL(ctx, "username").Result()
	fmt.Printf("user TTL : %v, username TTL : %v\n", userTTL, usernameTTL)

	// 8.Del():删除缓存项与FlushDB():清空当前数据
  // 当通配符匹配的key的数量不多时，可以使用Keys()得到所有的key在使用Del命令删除。
	num, err = rdb.Del(ctx, "user", "username").Result()
	if err != nil {
		panic(err)
	}
	fmt.Println("Del() : ", num)
  // 如果key的数量非常多的时候，我们可以搭配使用Scan命令和Del命令完成删除。
  iter := rdb.Scan(ctx, 0, "user*", 0).Iterator()
  for iter.Next(ctx) {
    err := rdb.Del(ctx, iter.Val()).Err()
    if err != nil {
      panic(err)
    }
  }
  if err := iter.Err(); err != nil {
    panic(err)
  }

	// 9.清空当前数据库，因为连接的是索引为0的数据库，所以清空的就是0号数据库
	flag, err := rdb.FlushDB(ctx).Result()
	if err != nil {
		panic(err)
	}
	fmt.Println("FlushDB() : ", flag)


}

// main 调用
// String 数据类型操作
setGetExample(redisClient, ctx)
```

执行结果:



```shell
// # Go execute
Connecting Redis : 10.20.172.248:6379
Connect Successful! 
Ping => PONG
val1 -> score ：100
[ERROR] - Key [name] not exist
name key 不存在!
val2 -> name :  weiyi
val3 -> username: true
All Keys : [name username score], Keys number : 3 
username key type : string
name 过期时间设置成功 true
username 过期时间设置成功 true
user TTL : -2ns, username TTL : 2m1.679s
Del() :  1
FlushDB() :  OK

// # Redis-cli
127.0.0.1:6379> get score
"100"
127.0.0.1:6379> get name
(nil)
127.0.0.1:6379> get username
"weiyigeek"
127.0.0.1:6379> TTL username  // 生存周期60s
(integer) 50
........ 
127.0.0.1:6379> keys *   // 执行后全部key为空
(empty list or set)
```

**示例2.redis数据库中字符串与整型操作实践.**



```go
// stringIntExample 数据类型演示
func stringIntExample(rdb *redis.Client, ctx context.Context) {
	// 设置字符串类型的key
	err := rdb.Set(ctx, "hello", "Hello World!", 0).Err()
	if err != nil {
		panic(err)
	}
	// GetRange ：字符串截取
	// 注：即使key不存在，调用GetRange()也不会报错，只是返回的截取结果是空"",可以使用fmt.Printf("%q\n", val)来打印测试
	val1, _ := rdb.GetRange(ctx, "hello", 1, 4).Result()
	fmt.Printf("key: hello, value: %v\n", val1) //截取到的内容为: ello

	// Append()表示往字符串后面追加元素，返回值是字符串的总长度
	length1, _ := rdb.Append(ctx, "hello", " Go Programer").Result()
	val2, _ := rdb.Get(ctx, "hello").Result()
	fmt.Printf("当前缓存key的长度为: %v，值: %v \n", length1, val2)

	// 设置整形的key
	err = rdb.SetNX(ctx, "number", 1, 0).Err()
	if err != nil {
		panic(err)
	}
	// Incr()、IncrBy()都是操作数字，对数字进行增加的操作
	// Decr()、DecrBy()方法是对数字进行减的操作，和Incr正好相反
	// incr是执行原子加1操作
	val3, _ := rdb.Incr(ctx, "number").Result()
	fmt.Printf("Incr -> key当前的值为: %v\n", val3) // 2
	// incrBy是增加指定的数
	val4, _ := rdb.IncrBy(ctx, "number", 6).Result()
	fmt.Printf("IncrBy -> key当前的值为: %v\n", val4) // 8

	// StrLen 也可以返回缓存key的长度
	length2, _ := rdb.StrLen(ctx, "number").Result()
	fmt.Printf("number 值长度: %v\n", length2)
}

// main 函数中调用
// 字符串整形数据类型
stringIntExample(redisClient, ctx)
```

执行结果:



```shell
# ➜ demo6 go run .
Connecting Redis : 10.20.172.248:6379
Connect Successful! 
Ping => PONG
key: hello, value: ello
当前缓存key的长度为: 25，值: Hello World! Go Programer 
Incr -> key当前的值为: 9
IncrBy -> key当前的值为: 15
number 值长度: 2

# redis-cli
127.0.0.1:6379> keys *
1) "hello"
2) "number"
127.0.0.1:6379> get hello
"Hello World! Go Promgram"
127.0.0.1:6379> get number
"8"
```

#### 列表(list)类型操作

**常用方法:**

- LPush():将元素压入链表
- LInsert():在某个位置插入新元素
- LSet():设置某个元素的值
- LLen():获取链表元素个数
- LIndex():获取链表下标对应的元素
- LRange():获取某个选定范围的元素集
- LPop()从链表左侧弹出数据
- LRem():根据值移除元素

**简单示例**



```go
func listExample(rdb *redis.Client, ctx context.Context) {
	// 插入指定值到list列表中，返回值是当前列表元素的数量
	// 使用LPush()方法将数据从左侧压入链表（后进先出）,也可以从右侧压如链表对应的方法是RPush()
	count, _ := rdb.LPush(ctx, "list", 1, 2, 3).Result()
	fmt.Println("插入到list集合中元素的数量: ", count)

	// LInsert() 在某个位置插入新元素
	// 在名为key的缓存项值为2的元素前面插入一个值，值为123 ， 注意只会执行一次
	_ = rdb.LInsert(ctx, "list", "before", "2", 123).Err()
	// 在名为key的缓存项值为2的元素后面插入一个值，值为321
	_ = rdb.LInsert(ctx, "list", "after", "2", 321).Err()

	// LSet() 设置某个元素的值
	//下标是从0开始的
	val1, _ := rdb.LSet(ctx, "list", 2, 256).Result()
	fmt.Println("是否成功将下标为2的元素值改成256: ", val1)

	// LLen() 获取链表元素个数
	length, _ := rdb.LLen(ctx, "list").Result()
	fmt.Printf("当前链表的长度为: %v\n", length)

	// LIndex() 获取链表下标对应的元素
	val2, _ := rdb.LIndex(ctx, "list", 2).Result()
	fmt.Printf("下标为2的值为: %v\n", val2)

	// 从链表左侧弹出数据
	val3, _ := rdb.LPop(ctx, "list").Result()
	fmt.Printf("弹出下标为0的值为: %v\n", val3)

	// LRem() 根据值移除元素 lrem key count value
	n, _ := rdb.LRem(ctx, "list", 2, "256").Result()
	fmt.Printf("移除了: %v 个\n", n)
}
```

执行结果:



```shell
Connecting Redis : 10.20.172.248:6379
Connect Successful! 
Ping => PONG
插入到list集合中元素的数量:  3
是否成功将下标为2的元素值改成256:  OK
当前链表的长度为: 5
下标为2的值为: 256
弹出下标为0的值为: 3
移除了: 1 个

# redis-cli
127.0.0.1:6379> keys lis*
1) "list"
127.0.0.1:6379> LINDEX list 0
"123"
127.0.0.1:6379> LPOP list
"123"
127.0.0.1:6379> LLEN list
(integer) 2
```

#### 集合(set)类型操作

常用方法:

- SAdd():添加元素
- SPop():随机获取一个元素
- SRem():删除集合里指定的值
- SSMembers():获取所有成员
- SIsMember():判断元素是否在集合中
- SCard():获取集合元素个数
- SUnion():并集,SDiff():差集,SInter():交集

Tips：集合数据的特征，元素不能重复保持唯一性, 元素无序不能使用索引(下标)操作

**简单示例**



```go
func setExample(rdb *redis.Client, ctx context.Context) {
	// 集合元素缓存设置
	keyname := "Program"
	mem := []string{"C", "Golang", "C++", "C#", "Java", "Delphi", "Python", "Golang"}
	// //由于Golang已经被添加到Program集合中，所以重复添加时无效的
	for _, v := range mem {
		rdb.SAdd(ctx, keyname, v)
	}

	// SCard() 获取集合元素个数
	total, _ := rdb.SCard(ctx, keyname).Result()
	fmt.Println("golang集合成员个数: ", total)

	// SPop() 随机获取一个元素 （无序性，是随机的）
	val1, _ := rdb.SPop(ctx, keyname).Result()
	// SPopN()  随机获取多个元素.
	val2, _ := rdb.SPopN(ctx, keyname, 2).Result()

	// SSMembers() 获取所有成员
	val3, _ := rdb.SMembers(ctx, keyname).Result()
	fmt.Printf("随机获取一个元素: %v , 随机获取多个元素: %v \n所有成员: %v\n", val1, val2, val3)

	// SIsMember() 判断元素是否在集合中
	exists, _ := rdb.SIsMember(ctx, keyname, "golang").Result()
	if exists {
		fmt.Println("golang 存在 Program 集合中.") // 注意:我们存入的是Golang而非golang
	} else {
		fmt.Println("golang 不存在 Program 集合中.")
	}

	// SUnion():并集, SDiff():差集, SInter():交集
	rdb.SAdd(ctx, "setA", "a", "b", "c", "d")
	rdb.SAdd(ctx, "setB", "a", "d", "e", "f")

	//并集
	union, _ := rdb.SUnion(ctx, "setA", "setB").Result()
	fmt.Println("并集", union)

	//差集
	diff, _ := rdb.SDiff(ctx, "setA", "setB").Result()
	fmt.Println("差集", diff)

	//交集
	inter, _ := rdb.SInter(ctx, "setA", "setB").Result()
	fmt.Println("交集", inter)

  // 删除集合中指定元素(返回成功)
  n, _ := rdb.SRem(ctx, "setB", "a", "f").Result()
  fmt.Println("已成功删除元素的个数: ",n)
}
```

执行结果:



```shell
Connecting Redis : 10.20.172.248:6379
Connect Successful! 
Ping => PONG
golang集合成员个数:  7
随机获取一个元素: Java , 随机获取多个元素: [Golang C++] 
所有成员: [C Python C# Delphi]
golang 不存在 Program 集合中.
并集 [a d c e f b]
差集 [c b]
交集 [a d]
已成功删除元素的个数: 2

# redis-cli
127.0.0.1:6379> keys Prog*
1) "Program"
127.0.0.1:6379> SRANDMEMBER Program
"Python"
127.0.0.1:6379> SRANDMEMBER Program
"Delphi"
127.0.0.1:6379> SCARD Program
(integer) 2
```

#### 有序集合(zset)类型操作

常用方法:

- ZAdd():添加元素
- ZIncrBy():增加元素分值
- ZRange()、ZRevRange():获取根据score排序后的数据段
- ZRangeByScore()、ZRevRangeByScore():获取score过滤后排序的数据段
- ZCard():获取元素个数
- ZCount():获取区间内元素个数
- ZScore():获取元素的score
- ZRank()、ZRevRank():获取某个元素在集合中的排名
- ZRem():删除元素
- ZRemRangeByRank():根据排名来删除
- ZRemRangeByScore():根据分值区间来删除

**简单示例:**



```go
func zsetExample(rdb *redis.Client, ctx context.Context) {
	// 有序集合成员与分数设置
	// zSet类型需要使用特定的类型值*redis.Z，以便作为排序使用
	lang := []*redis.Z{
		&redis.Z{Score: 90.0, Member: "Golang"},
		&redis.Z{Score: 98.0, Member: "Java"},
		&redis.Z{Score: 95.0, Member: "Python"},
		&redis.Z{Score: 97.0, Member: "JavaScript"},
		&redis.Z{Score: 99.0, Member: "C/C++"},
	}
	//插入ZSet类型
	num, err := rdb.ZAdd(ctx, "language_rank", lang...).Result()
	if err != nil {
		fmt.Printf("zadd failed, err:%v\n", err)
		return
	}
	fmt.Printf("zadd %d succ.\n", num)

	// 将ZSet中的某一个元素顺序值增加: 把Golang的分数加10
	newScore, err := rdb.ZIncrBy(ctx, "language_rank", 10.0, "Golang").Result()
	if err != nil {
		fmt.Printf("zincrby failed, err:%v\n", err)
		return
	}
	fmt.Printf("Golang's score is %f now.\n", newScore)

	// 根据分数排名取出元素:取分数最高的3个
	ret, err := rdb.ZRevRangeWithScores(ctx, "language_rank", 0, 2).Result()
	if err != nil {
		fmt.Printf("zrevrange failed, err:%v\n", err)
		return
	}
	fmt.Printf("zsetKey前3名热度的是: %v\n,Top 3 的 Memeber 与 Score 是:\n", ret)
	for _, z := range ret {
		fmt.Println(z.Member, z.Score)
	}

	// ZRangeByScore()、ZRevRangeByScore():获取score过滤后排序的数据段
	// 此处表示取95~100分的
	op := redis.ZRangeBy{
		Min: "95",
		Max: "100",
	}
	ret, err = rdb.ZRangeByScoreWithScores(ctx, "language_rank", &op).Result()
	if err != nil {
		fmt.Printf("zrangebyscore failed, err:%v\n", err)
		return
	}
	// 输出全部成员及其score分数
	fmt.Println("language_rank 键存储的全部元素:")
	for _, z := range ret {
		fmt.Println(z.Member, z.Score)
	}
}
```

执行结果:



```shell
# go run .
Connecting Redis : 10.20.172.248:6379
Connect Successful! 
Ping => PONG
zadd 0 succ.
Golang\'s score is 100.000000 now.
zsetKey前3名热度的是: [{100 Golang} {99 C/C++} {98 Java}]
,Top 3 的 Memeber 与 Score 是:
Golang 100
C/C++ 99
Java 98
language_rank 键存储的全部元素:
Python 95
JavaScript 97
Java 98
C/C++ 99
Golang 100

# redis-cli
127.0.0.1:6379> keys language_rank*
1) "language_rank"
127.0.0.1:6379> keys language_rank*
1) "language_rank"
127.0.0.1:6379> ZCARD language_rank
(integer) 5
127.0.0.1:6379> ZRANGE language_rank 1 3  # 1-3 索引的成员名称
1) "JavaScript"
2) "Java"
3) "C/C++"
127.0.0.1:6379> ZRANGEBYSCORE language_rank 99 100 WITHSCORES
1) "C/C++"
2) "99"
3) "Golang"
4) "100"
```

#### 哈希(hash)类型操作

常用方法:

- HSet():设置
- HMset():批量设置
- HGet():获取某个元素
- HGetAll():获取全部元素
- HDel():删除某个元素
- HExists():判断元素是否存在
- HLen():获取长度

**简单示例:**



```go
// hash 是一个 string 类型的 field（字段） 和 value（值） 的映射表，hash 特别适合用于存储对象。
func hashExample(rdb *redis.Client, ctx context.Context) {
	// (1) HSet() 设置字段和值
	rdb.HSet(ctx, "huser", "key1", "value1", "key2", "value2")
	rdb.HSet(ctx, "huser", []string{"key3", "value3", "key4", "value4"})
	rdb.HSet(ctx, "huser", map[string]interface{}{"key5": "value5", "key6": "value6"})

	// (2) HMset():批量设置
	rdb.HMSet(ctx, "hmuser", map[string]interface{}{"name": "WeiyiGeek", "age": 88, "address": "重庆"})

	// (3) HGet() 获取某个元素
	address, _ := rdb.HGet(ctx, "hmuser", "address").Result()
	fmt.Println("hmuser.address -> ", address)

	// (4) HGetAll() 获取全部元素
	hmuser, _ := rdb.HGetAll(ctx, "hmuser").Result()
	fmt.Println("hmuser :=> ", hmuser)

	// (5) HExists 判断元素是否存在
	flag, _ := rdb.HExists(ctx, "hmuser", "address").Result()
	fmt.Println("address 是否存在 hmuser 中: ", flag)

	// (6) HLen() 获取长度
	length, _ := rdb.HLen(ctx, "hmuser").Result()
	fmt.Println("hmuser hash 键长度: ", length)

	// (7) HDel() 支持一次删除多个元素
	count, _ := rdb.HDel(ctx, "huser", "key3", "key4").Result()
	fmt.Println("删除元素的个数: ", count)
}
```

执行结果:



```shell
Connecting Redis : 10.20.172.248:6379
Connect Successful! 
Ping => PONG
hmuser.address ->  重庆
hmuser :=>  map[address:重庆 age:88 name:WeiyiGeek]
address 是否存在 hmuser 中: true
hmuser hash 键长度: 3
删除元素的个数: 2

# redis-cli
127.0.0.1:6379> keys *user
1) "hmuser"
2) "huser"
127.0.0.1:6379> HGETALL huser
1) "key1"
2) "value1"
3) "key2"
4) "value2"
5) "key6"
6) "value6"
7) "key5"
8) "value5"
127.0.0.1:6379> HGET hmuser name
"WeiyiGeek"
127.0.0.1:6379> HLEN hmuser
(integer) 3
```

#### 基数统计 HyperLogLog 类型操作

描述: 用来做基数统计的算法，HyperLogLog 的优点是，在输入元素的数量或者体积非常非常大时，计算基数所需的空间总是固定 的、并且是很小的。

Tips: 每个 HyperLogLog 键只需要花费 12 KB 内存，就可以计算接近 2^64 个不同元素的基数.

**示例代码:**



```go
func hyperLogLogExample(rdb *redis.Client, ctx context.Context) {
	log.Println("Start ExampleClient_HyperLogLog")
	defer log.Println("End ExampleClient_HyperLogLog")
	//  设置 HyperLogLog 类型的键  pf_test_1
	for i := 0; i < 5; i++ {
		rdb.PFAdd(ctx, "pf_test_1", fmt.Sprintf("pf1key%d", i))
	}
	ret, err := rdb.PFCount(ctx, "pf_test_1").Result()
	log.Println(ret, err)

	//  设置 HyperLogLog 类型的键  pf_test_2
	for i := 0; i < 10; i++ {
		rdb.PFAdd(ctx, "pf_test_2", fmt.Sprintf("pf2key%d", i))
	}
	ret, err = rdb.PFCount(ctx, "pf_test_2").Result()
	log.Println(ret, err)

	//  合并两个 HyperLogLog 类型的键  pf_test_1 + pf_test_1
	rdb.PFMerge(ctx, "pf_test", "pf_test_2", "pf_test_1")
	ret, err = rdb.PFCount(ctx, "pf_test").Result()
	log.Println(ret, err)
}
```

**执行结果:**



```shell
Connecting Redis : 10.20.172.248:6379
Connect Successful! 
Ping => PONG
2021/12/27 09:26:11 Start ExampleClient_HyperLogLog
2021/12/27 09:26:11 5 <nil>
2021/12/27 09:26:11 10 <nil>
2021/12/27 09:26:11 15 <nil>
2021/12/27 09:26:11 End ExampleClient_HyperLogLog

# redis-cli
127.0.0.1:6379> keys  pf_test*
1) "pf_test"
2) "pf_test_2"
3) "pf_test_1"
127.0.0.1:6379> PFCOUNT pf_test
(integer) 15
127.0.0.1:6379> PFCOUNT pf_test_1
(integer) 5
```

#### 自定义redis指令操作

描述: 我们可以采用go-redis提供的Do方法，可以让我们直接执行redis-cli中执行的相关指令, 可以极大的便于使用者上手。

**简单示例:**



```go
func ExampleClient_CMD(rdb *redis.Client, ctx context.Context) {
	log.Println("Start ExampleClient_CMD")
	defer log.Println("End ExampleClient_CMD")

	// 1.执行redis指令 Set 设置缓存
	v := rdb.Do(ctx, "set", "NewStringCmd", "redis-cli").String()
	log.Println(">", v)

	// 2.执行redis指令 Get 设置缓存
	v = rdb.Do(ctx, "get", "NewStringCmd").String()
	log.Println("Method1 >", v)

	// 3.匿名方式执行自定义redis命令
	// Set
	Set := func(client *redis.Client, ctx context.Context, key, value string) *redis.StringCmd {
		cmd := redis.NewStringCmd(ctx, "set", key, value) // 关键点
		client.Process(ctx, cmd)
		return cmd
	}
	v, _ = Set(rdb, ctx, "NewCmd", "go-redis").Result()
	log.Println("> set NewCmd go-redis:", v)

	// Get
	Get := func(client *redis.Client, ctx context.Context, key string) *redis.StringCmd {
		cmd := redis.NewStringCmd(ctx, "get", key) // 关键点
		client.Process(ctx, cmd)
		return cmd
	}
	v, _ = Get(rdb, ctx, "NewCmd").Result()
	log.Println("Method2 > get NewCmd:", v)

	// 4.执行redis指令 hset 设置哈希缓存 (实践以下方式不行)
	// kv := map[string]interface{}{"key5": "value5", "key6": "value6"}
	// v, _ = rdb.Do(ctx, "hmset", "NewHashCmd", kv)
	// log.Println("> ", v)
}
```

**执行结果:**



```shell
Connecting Redis : 10.20.172.248:6379
Connect Successful! 
Ping => PONG
2021/12/27 12:11:43 Start ExampleClient_CMD
2021/12/27 12:11:43 > set NewStringCmd redis-cli: OK
2021/12/27 12:11:43 Method1 > get NewStringCmd: redis-cli
2021/12/27 12:11:43 > set NewCmd go-redis: OK
2021/12/27 12:11:43 Method2 > get NewCmd: go-redis
2021/12/27 12:11:43 End ExampleClient_CMD

# redis-cli
127.0.0.1:6379> keys New*
1) "NewCmd"
2) "NewStringCmd"
127.0.0.1:6379> get NewCmd
"go-redis"
```

#### Redis Pipeline 通道操作

描述: Pipeline 主要是一种网络优化,它本质上意味着客户端缓冲一堆命令并一次性将它们发送到服务器。这些命令不能保证在事务中执行。这样做的好处是节省了每个命令的网络往返时间（RTT）。

Pipeline 基本示例如下：



```go
pipe := rdb.Pipeline()

incr := pipe.Incr("pipeline_counter")
pipe.Expire("pipeline_counter", time.Hour)

_, err := pipe.Exec()
fmt.Println(incr.Val(), err)
```

上面的代码相当于将以下两个命令一次发给`redis server`
端执行与不使用Pipeline相比能减少一次RTT。



```shell
INCR pipeline_counter
EXPIRE pipeline_counts 3600
```

也可以使用Pipelined:



```go
var incr *redis.IntCmd
_, err := rdb.Pipelined(func(pipe redis.Pipeliner) error {
	incr = pipe.Incr("pipelined_counter")
	pipe.Expire("pipelined_counter", time.Hour)
	return nil
})
fmt.Println(incr.Val(), err)
```

所以在某些场景下，当我们有多条命令要执行时，就可以考虑使用pipeline来优化redis缓冲效率。

#### MULTI/EXEC 事务处理操作

描述: Redis是单线程的，因此单个命令始终是原子的，但是来自不同客户端的两个给定命令可以依次执行，例如在它们之间交替执行。但是`Multi/exec`
能够确保在其两个语句之间的命令之间没有其他客户端正在执行命令。

在这种场景我们需要使用TxPipeline, 它总体上类似于上面的Pipeline, 但是它内部会使用`MULTI/EXEC`
包裹排队的命令。例如：



```go
pipe := rdb.TxPipeline()
incr := pipe.Incr("tx_pipeline_counter")
pipe.Expire("tx_pipeline_counter", time.Hour)
_, err := pipe.Exec()
fmt.Println(incr.Val(), err)

// # 上面代码相当于在一个RTT下执行了下面的redis命令：
MULTI
INCR pipeline_counter
EXPIRE pipeline_counts 3600
EXEC

// # 还有一个与上文类似的TxPipelined方法，使用方法如下：
var incr *redis.IntCmd
_, err := rdb.TxPipelined(func(pipe redis.Pipeliner) error {
	incr = pipe.Incr("tx_pipelined_counter")
	pipe.Expire("tx_pipelined_counter", time.Hour)
	return nil
})
fmt.Println(incr.Val(), err)
```

**简单示例:**



```go
func TxPipelineExample(rdb *redis.Client, ctx context.Context) {
	// 开pipeline与事务
	pipe := rdb.TxPipeline()
	// 设置TxPipeline键缓存
	v, _ := rdb.Do(ctx, "set", "TxPipeline", 1023.0).Result()
	log.Println(v)
	// 自增+1.0
	incr := pipe.IncrByFloat(ctx, "TxPipeline", 1026.0)
	log.Println(incr) // 未提交时  incr.Val() 值 为 0
	// 设置键过期时间
	pipe.Expire(ctx, "TxPipeline", time.Hour)
	// 提交事务
	_, err := pipe.Exec(ctx)
	if err != nil {
		log.Println("执行失败, 进行回滚操作!")
		return
	}
	fmt.Println("事务执行成功,已提交!")
	log.Println("TxPipeline :", incr.Val()) // 提交后值 为 2049
}
```

执行结果:



```shell
Connecting Redis : 10.20.172.248:6379
Connect Successful! 
Ping => PONG
2021/12/27 13:20:15 OK
2021/12/27 13:20:15 incrbyfloat TxPipeline 1026: 0
事务执行成功,已提交!
2021/12/27 13:20:15 TxPipeline : 2049

// # redis-cli
127.0.0.1:6379> TYPE TxPipeline
string
127.0.0.1:6379> get TxPipeline
"2049"
```

#### Watch 监听操作

描述: 在某些场景下我们除了要使用`MULTI/EXEC`
命令外，还需要配合使用WATCH命令, 用户使用WATCH命令监视某个键之后，直到该用户执行EXEC命令的这段时间里，如果有其他用户抢先对被监视的键进行了替换、更新、删除等操作，那么当用户尝试执行EXEC的时候，事务将失败并返回一个错误，用户可以根据这个错误选择重试事务或者放弃事务。

Watch方法接收一个函数和一个或多个key作为参数,其函数原型:



```go
Watch(fn func(*Tx) error, keys ...string) error 
```

基本使用示例如下：



```go
// 监视watch_count的值，并在值不变的前提下将其值+1
key := "watch_count"
err = client.Watch(func(tx *redis.Tx) error {
	n, err := tx.Get(key).Int()
	if err != nil && err != redis.Nil {
		return err
	}
	_, err = tx.Pipelined(func(pipe redis.Pipeliner) error {
		pipe.Set(key, n+1, 0)
		return nil
	})
	return err
}, key)
```

go-redis V8版本中: 使用`GET和SET`
命令以事务方式递增Key的值的示例，仅当Key的值不发生变化时提交一个事务。



```go
func transactionDemo() {
	var (
		maxRetries   = 1000
		routineCount = 10
	)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Increment 使用GET和SET命令以事务方式递增Key的值 (匿名函数)
	increment := func(key string) error {
		// 事务函数
		txf := func(tx *redis.Tx) error {
			// 获得key的当前值或零值
			n, err := tx.Get(ctx, key).Int()
			if err != nil && err != redis.Nil {
				return err
			}

			// 实际的操作代码（乐观锁定中的本地操作）
			n++

			// 操作仅在 Watch 的 Key 没发生变化的情况下提交
			_, err = tx.TxPipelined(ctx, func(pipe redis.Pipeliner) error {
				pipe.Set(ctx, key, n, 0)
				return nil
			})
			return err
		}

		// 最多重试 maxRetries 次
		for i := 0; i < maxRetries; i++ {
			err := rdb.Watch(ctx, txf, key)
			if err == nil {
				// 成功
				return nil
			}
			if err == redis.TxFailedErr {
				// 乐观锁丢失 重试
				continue
			}
			// 返回其他的错误
			return err
		}

		return errors.New("increment reached maximum number of retries")
	}

	// 模拟 routineCount 个并发同时去修改 counter3 的值
	var wg sync.WaitGroup
	wg.Add(routineCount)
	for i := 0; i < routineCount; i++ {
		go func() {
			defer wg.Done()
			if err := increment("counter3"); err != nil {
				fmt.Println("increment error:", err)
			}
		}()
	}
	wg.Wait()

	n, err := rdb.Get(context.TODO(), "counter3").Int()
	fmt.Println("ended with", n, err)
}
```

#### Script 脚本操作

描述: 从 Redis 2.6.0 版本开始的，使用内置的 Lua 解释器，可以对 Lua 脚本进行求值, 所以我们可直接在redis客户端中执行一些脚本。

redis Eval 命令基本语法如下：`EVAL script numkeys key [key ...] arg [arg ...]`

- script: 参数是一段 Lua 5.1 脚本程序。脚本不必(也不应该)定义为一个 Lua 函数。
- numkeys: 用于指定键名参数的个数。
- key [key ...]: 从 EVAL 的第三个参数开始算起，表示在脚本中所用到的那些 Redis 键(key)，这些键名参数可以在 Lua 中通过全局变量 KEYS 数组，用 1 为基址的形式访问`( KEYS[1] ， KEYS[2] ，以此类推)`
  。
- arg [arg ...]: 附加参数，在 Lua 中通过全局变量 ARGV 数组访问，访问的形式和 KEYS 变量类似`( ARGV[1] 、 ARGV[2] ，诸如此类)`
  。

`redis.call()`
与 `redis.pcall()`
唯一的区别是当redis命令执行结果返回错误时 redis.call() 将返回给调用者一个错误，而redis.pcall()会将捕获的错误以Lua表的形式返回



```shell
# 利用eval执行脚本
127.0.0.1:6379> set name weiyigeek
OK
127.0.0.1:6379> eval "return redis.call('get','name')" 0
"weiyigeek"
127.0.0.1:6379> eval "return redis.call('set','foo','bar')" 0
OK
127.0.0.1:6379> eval "return redis.pcall('get','foo')" 0
"bar"
127.0.0.1:6379> eval "return {KEYS[1],ARGV[1],KEYS[2],ARGV[2]}" 2 name age weiyigeek 25
1) "name"
2) "weiyigeek"
3) "age"
4) "25"


# Lua 数据类型和 Redis 数据类型之间转换
> eval "return 10" 0
(integer) 10

> eval "return {1,2,{3,'Hello World!'}}" 0
1) (integer) 1
2) (integer) 2
3) 1) (integer) 3
   2) "Hello World!"

> eval "return redis.call('get','foo')" 0
"bar"
```

那在`go-redis`
客户端中如何执行脚本操作?

**简单示例:**



```go
func ScriptExample(rdb *redis.Client, ctx context.Context) {
	// Lua脚本定义1. 传递key输出指定格式的结果
	EchoKey := redis.NewScript(`
		if redis.call("GET", KEYS[1]) ~= false then
			return {KEYS[1],"==>",redis.call("get", KEYS[1])}
		end
		return false
	`)

	err := rdb.Set(ctx, "xx_name", "WeiyiGeek", 0).Err()
	if err != nil {
		panic(err)
	}
	val1, err := EchoKey.Run(ctx, rdb, []string{"xx_name"}).Result()
	log.Println(val1, err)

	// Lua脚本定义2. 传递key与step使得，key值等于`键值+step`
	IncrByXX := redis.NewScript(`
		if redis.call("GET", KEYS[1]) ~= false then
			return redis.call("INCRBY", KEYS[1], ARGV[1])
		end
		return false
	`)

	// 判断键是否存在，存在就删除该键
	exist, err := rdb.Exists(ctx, "xx_counter").Result()
	if exist > 0 {
		res, err := rdb.Del(ctx, "xx_counter").Result()
		log.Printf("is Exists?: %v, del xx_counter: %v, err: %v \n", exist, res, err)
	}

	// 首次调用
	val2, err := IncrByXX.Run(ctx, rdb, []string{"xx_counter"}, 2).Result()
	log.Println("首次调用 IncrByXX.Run ->", val2, err)

	// 写入 xx_counter 键
	err = rdb.Set(ctx, "xx_counter", 40, 0).Err()
	if err != nil {
		panic(err)
	}
	// 二次调用
	val3, err := IncrByXX.Run(ctx, rdb, []string{"xx_counter"}, 2).Result()
	log.Println("二次调用 IncrByXX.Run ->", val3, err)
}
```

执行结果:



```shell
Connecting Redis : 10.20.172.248:6379
Connect Successful! 
Ping => PONG
2021/12/27 15:00:18 [xx_name ==> WeiyiGeek] <nil>
2021/12/27 15:00:18 is Exists?: 1, del xx_counter: 1, err: <nil> 
2021/12/27 15:00:18 首次调用 IncrByXX.Run -> <nil> redis: nil
2021/12/27 15:00:18 二次调用 IncrByXX.Run -> 42 <nil>

# redis-cli
127.0.0.1:6379> keys xx*
1) "xx_counter"
2) "xx_name"
127.0.0.1:6379> get xx_counter
"42"
127.0.0.1:6379> get "xx_name"
"WeiyiGeek"
127.0.0.1:6379> TTL xx_counter
(integer) -1

登录后复制
```

至此在使用go-Redis客户端库操作实践Redis数据库完毕!