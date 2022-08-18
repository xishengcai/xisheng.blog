# mongodb 入门

mongoDB是目前比较流行的一个基于分布式文件存储的数据库，它是一个介于关系数据库和非关系数据库(NoSQL)之间的产品，是非关系数据库当中功能最丰富，最像关系数据库的。

### mongoDB介绍
mongoDB是目前比较流行的一个基于分布式文件存储的数据库，它是一个介于关系数据库和非关系数据库(NoSQL)之间的产品，是非关系数据库当中功能最丰富，最像关系数据库的。

mongoDB中将一条数据存储为一个文档（document），数据结构由键值（key-value）对组成。 其中文档类似于我们平常编程中用到的JSON对象。 文档中的字段值可以包含其他文档，数组及文档数组

### 相关概念
|MongoDB术语/概念 | 说明 | 对比SQL术语/概念 |
|:----|:---- |:----- |
|database|	数据库|	database|
|collection	|集合|	table|
|document	|文档|	row|
|field	|字段	|column|
|index	|index	|索引|
|primary key	|主键 MongoDB自动将_id字段设置为主键|	primary key|

### BSON
MongoDB中的JSON文档存储在名为BSON(二进制编码的JSON)的二进制表示中。与其他将JSON数据存储为简单字
符串和数字的数据库不同，BSON编码扩展了JSON表示，使其包含额外的类型，如int、long、date、浮点数和
decimal128。这使得应用程序更容易可靠地处理、排序和比较数据。

连接MongoDB的Go驱动程序中有两大类型表示BSON数据：D和Raw。

类型D家族被用来简洁地构建使用本地Go类型的BSON对象。这对于构造传递给MongoDB的命令特别有用。D家族包括四类:

- D：一个BSON文档。这种类型应该在顺序重要的情况下使用，比如MongoDB命令。
- M：一张无序的map。它和D是一样的，只是它不保持顺序。
- A：一个BSON数组。
- E：D里面的一个元素。


### 实践出真理
#### start one container and connect
```
docker run -d -p 27017:27017 -e MONGO_INITDB_ROOT_USERNAME=root -e MONGO_INITDB_ROOT_PASSWORD=123456 registry.cn-hangzhou.aliyuncs.com/launcher/mongo:4.2.1
docker exec -it  $container_id sh
#mongo 192.168.1.200:27017/test -u user -p password
mongo -u root -p 123456
```

#### base operation
```
show dbs;
use test;
db.createCollection("hello");
show collections;
db.hello.insert({"name":"testdb"});
db.hello.drop()
```
#### Index
```
在hello集合上，建立对ID字段的索引，1代表升序。
>db.hello.ensureIndex({ID:1})
在hello集合上，建立对ID字段、Name字段和Gender字段建立索引
>db.hello.ensureIndex({ID:1,Name:1,Gender:-1})
查看hello集合上的所有索引
>db.hello.getIndexes()
删除索引用db.collection.dropIndex()，有一个参数，可以是建立索引时指定的字段，也可以是getIndex看到的索引名称。
>db.hello.dropIndex( "IDIdx" )
>db.hello.dropIndex({ID:1})
```
### 插入
```
db.inventory.insertMany([
   { item: "journal", qty: 25, size: { h: 14, w: 21, uom: "cm" }, status: "A" },
   { item: "notebook", qty: 50, size: { h: 8.5, w: 11, uom: "in" }, status: "A" },
   { item: "paper", qty: 100, size: { h: 8.5, w: 11, uom: "in" }, status: "D" },
   { item: "planner", qty: 75, size: { h: 22.85, w: 30, uom: "cm" }, status: "D" },
   { item: "postcard", qty: 45, size: { h: 10, w: 15.25, uom: "cm" }, status: "A" }
]);
```

### 查询
#### 一般查询
```
db.inventory.find( { status: "D" } )
SELECT * FROM inventory WHERE status = "D"
```

```
db.inventory.find( { status: { $in: [ "A", "D" ] } } )
db.inventory.find( { status: "A", qty: { $lt: 30 } } )
```

```
db.inventory.find( { status: "A", qty: { $lt: 30 } } )
SELECT * FROM inventory WHERE status = "A" AND qty < 30
```

```
db.inventory.find( { $or: [ { status: "A" }, { qty: { $lt: 30 } } ] } )
SELECT * FROM inventory WHERE status = "A" OR qty < 30
```


```
db.inventory.find( {
     status: "A",
     $or: [ { qty: { $lt: 30 } }, { item: /^p/ } ]
} )

SELECT * FROM inventory WHERE status = "A" AND ( qty < 30 OR item LIKE "p%")
```

#### Query on Embedded/Nested Documents
```
db.inventory.find(  { size: { w: 21, h: 14, uom: "cm" } }  )
db.inventory.find( { "size.h": { $lt: 15 } } )
db.inventory.find( { "size.h": { $lt: 15 }, "size.uom": "in", status: "D" } )
```

### Query an Array

```
db.inventory.insertMany([
   { item: "journal", qty: 25, tags: ["blank", "red"], dim_cm: [ 14, 21 ] },
   { item: "notebook", qty: 50, tags: ["red", "blank"], dim_cm: [ 14, 21 ] },
   { item: "paper", qty: 100, tags: ["red", "blank", "plain"], dim_cm: [ 14, 21 ] },
   { item: "planner", qty: 75, tags: ["blank", "red"], dim_cm: [ 22.85, 30 ] },
   { item: "postcard", qty: 45, tags: ["blue"], dim_cm: [ 10, 15.25 ] }
]);
```

> * 有顺序要求
```
db.inventory.find( { tags: ["red", "blank"] } )  # 只能查询到一条
```

> * 没有顺序要求
```
db.inventory.find( { tags: { $all: ["red", "blank"] } } )  # 可以查询到3条
```

> * Query an Array for an Element
> * To query if the array field contains at least one element with the specified value, 
use the filter { <field>: <value> } where <value> is the element value.
```
db.inventory.find( { tags: "red" } )
```
### 更新 
syntax: db.collection.update(criteria, objNew, upsert, multi )
> * criteria:update的查询条件，类似sql update查询内where后面的
> * objNew:update的对象和一些更新的操作符（如$,$inc...）等，也可以理解为sql update查询内set后面的。
> * upsert : 如果不存在update的记录，是否插入objNew,true为插入，默认是false，不插入。
> * multi : mongodb默认是false,只更新找到的第一条记录，如果这个参数为true,就把按条件查出来多条记录全部更新。

#### 匹配数组中单个字段
> * 将第一个文档中grade字段中值为85更新为1000，如果不知道数组中元素的位置，可以使用位置$操作符
> * 请记住，位置$操作符充当更新文档查询中第一个匹配的占位符, 只修改匹配到的第一个，假设有2个85， 需要执行两次才能全部更新。

```
db.collection.update(
   { <query selector> },
   { <update operator>: { "array.$.field" : value } }
)
```

```
db.students.insert({_id:1,grades:[80,85,90]})
db.students.insert({_id:2,grades:[88,90,92]})
db.students.insert({_id:3,grades:[85,100,90,85]})

db.students.update({_id:3, grades:85},{$set:{'grades.$':1000}})
```

#### 匹配数组中多个字段 
> * 位置操作符$能够更新第一个匹配的数组元素通过$elemMatch()操作符匹配多个内嵌文档的查询条件
> * 在golang中 的eleMatch 是match

如下语句会更新嵌套文档中的std值为6，条件是文档的主键是4，字段grades的嵌套文档字段grade字段值小于等于90mean字段值大于80

```
db.students.update(
   {
     _id: 4,
     grades: { $elemMatch: { grade: { $lte: 90 }, mean: { $gt: 80 } } }
   },
   { $set: { "grades.$.std" : 6 } }
)
```

#### 根据数组特定位置的元素 大小来查询
> * Using dot notation, you can specify query conditions for an element at a particular index or position of the array. The array uses zero-based indexing.
```
db.inventory.find( { "dim_cm.1": { $gt: 25 } } )
```

#### Query an Array by Array Length
> * Use the $size operator to query for arrays by number of elements. For example, the following selects documents where the array tags has 3 elements.
```
db.inventory.find( { "tags": { $size: 3 } } )
```

### Query an Array of Embedded Documents
#### Query for a Document Nested in an Array
> * The following example selects all documents where an element in the instock array matches the specified document:
```
db.inventory.insertMany( [
   { item: "journal", instock: [ { warehouse: "A", qty: 5 }, { warehouse: "C", qty: 15 } ] },
   { item: "notebook", instock: [ { warehouse: "C", qty: 5 } ] },
   { item: "paper", instock: [ { warehouse: "A", qty: 60 }, { warehouse: "B", qty: 15 } ] },
   { item: "planner", instock: [ { warehouse: "A", qty: 40 }, { warehouse: "B", qty: 5 } ] },
   { item: "postcard", instock: [ { warehouse: "B", qty: 15 }, { warehouse: "C", qty: 35 } ] }
]);

db.inventory.find( { "instock": { warehouse: "A", qty: 5 } } )
```

#### Equality matches on the whole embedded/nested document require an exact match of the specified document, including the field order. For example, the following query does not match any documents in the inventory collection:
```
db.inventory.find( { "instock": { qty: 5, warehouse: "A" } } )
```

#### Specify a Query Condition on a Field in an Array of Documents
```
db.inventory.find( { 'instock.qty': { $lte: 20 } } )
```

#### Use the Array Index to Query for a Field in the Embedded Document
```
db.inventory.find( { 'instock.0.qty': { $lte: 20 } } )
```

#### Specify Multiple Conditions for Array of Document
> * When specifying conditions on more than one field nested in an array of documents, you can specify the 
query such that either a single document meets these condition or any combination of documents (including 
a single document) in the array meets the conditions.
```
db.inventory.find( { "instock": { $elemMatch: { qty: 5, warehouse: "A" } } } )
db.inventory.find( { "instock": { $elemMatch: { qty: { $gt: 10, $lte: 20 } } } } )
```

#### Combination of Elements Satisfies the Criteria
If the compound query conditions on an array field do not use the $elemMatch operator, the query selects those 
documents whose array contains any combination of elements that satisfies the conditions.

For example, the following query matches documents where any document nested in the instock array has the qty 
field greater than 10 and any document (but not necessarily the same embedded document) in the array has the 
qty field less than or equal to 20:
```
db.inventory.find( { "instock.qty": { $gt: 10,  $lte: 20 } } )
db.inventory.find( { "instock.qty": 5, "instock.warehouse": "A" } )
```

### Project Fields to Return from Query
#### Return the Specified Fields and the _id Field Only
```
db.inventory.insertMany( [
  { item: "journal", status: "A", size: { h: 14, w: 21, uom: "cm" }, instock: [ { warehouse: "A", qty: 5 } ] },
  { item: "notebook", status: "A",  size: { h: 8.5, w: 11, uom: "in" }, instock: [ { warehouse: "C", qty: 5 } ] },
  { item: "paper", status: "D", size: { h: 8.5, w: 11, uom: "in" }, instock: [ { warehouse: "A", qty: 60 } ] },
  { item: "planner", status: "D", size: { h: 22.85, w: 30, uom: "cm" }, instock: [ { warehouse: "A", qty: 40 } ] },
  { item: "postcard", status: "A", size: { h: 10, w: 15.25, uom: "cm" }, instock: [ { warehouse: "B", qty: 15 }, { warehouse: "C", qty: 35 } ] }
]);

db.inventory.find( { status: "A" }, { item: 1, status: 1 } )
```

[原文链接](https://blog.csdn.net/yaomingyang/article/details/78696759)
[mongodb_doc](https://docs.mongodb.com/manual/reference/method/db.collection.aggregate/)
[group_aggregate](https://segmentfault.com/a/1190000016629733)
