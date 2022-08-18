#### 每篇一句

>  面试高大上，面试造飞机，工作拧螺丝  因此不能以为自己工作觉得还OK，就觉得自己技术还不错了  

如题，指的是在restful风格的url设计中，怎么实现批量删除呢？

>  这里指的删除是真删除，不是逻辑删除。如果是逻辑删除，其实就是update，使用put方法即可 

如果是需要删除一个条目，可以直接将需要删除的条目的id放进url里面，比如http://example.com/posts/2016，但是如果需要再一次请求里面**删除多个条目**，应该如何设计比较合理呢？我现在想到的是以下两种方法：

1. 用逗号分隔放进url里面：http://example.com/posts/2016,2017；
2. 将需要删除的一系列id放进请求体里面，但是似乎没有这样的标准（DELETE请求）。

先说说方法1，如果删除的数据非常多，比如超过1000个id，那很可能就超过URL的长度限制了。

>  Url长度限制： IE7.0                :url最大长度2083个字符，超过最大长度后仍然能提交，但是只能传过去2083个字符。 firefox 3.0.3     :url最大长度7764个字符，超过最大长度后无法提交。 Google Chrome 2.0.168   :url最大长度7713个字符，超过最大长度后无法提交 

从上面可以看出，这是有风险的可能提交不了的。但是话说回来，你是什么需求，需要一次性删除1000条记录，这是多么危险的操作，怎么可能通过API暴露出来呢？所以综合考虑，我个人认为，使用url的方式传递删除的值，是没有任何问题的。毕竟我们99%的情况，都是非常少量多额删除操作。

再说说方法2，其实我是不太建议的。因为我们删除操作，肯定使用DELETE请求，但是奈何我们并不建议在DELETE请求里放body体，**原因在于：根据RFC标准文档，DELETE请求的body在语义上没有任何意义。事实上一些网关、代理、防火墙在收到DELETE请求后，会把请求的body直接剥离掉。**

>  所以，万一你要放在body体里传参，请使用POST请求 

这里介绍一种比较优雅，但是比较麻烦点的方法： 分成2步完成，第一步发送POST请求，集合所有要删除的IDs然后返回一个header,然后在利用这个header调用DELETE请求。具体步骤如下: 发送POST请求，集中所有的IDs (可以存到[Redis](https://cloud.tencent.com/product/crs?from=10680)或者普通数据库) http://example.com/posts/deletes

成功后可以返回一个唯一的头文件：

HTTP/1.1 201 created, and a Location header to: http://example.com/posts/deletes/KJHJS675

然后可以利用Ajax直接发送DELETE请求: DELETE http://example.com/posts/deletes/KJHJS675

**这样就可以在不暴露IDs的情况下更加安全的删除相关条目。**

###### 最后如果要获得一个资源，一定要用GET方法么？

在一些文章中，看到获取资源的时候，一般用GET方法。我的问题是，我要获取的资源是一个账户的信息，需要实用token，我一般把token放在POST请求里面，当然也可以将token放在连接中使用GET。

其实，restful只是一种理想的情。你是否完全遵循Restful设计原则了 如果完全遵循的话, 获取账户信息应当是GET请求, **但是token通常是会放在header中**, 不在url中体现

针对我们的token这个事情，在我项目中会使用post请求根据用户信息获取一个token，然后拿着token用get方法请求资源。**另外，我也会将token放到http请求头中。**以上是个人工作经验，希望对各位有帮助

#### 最后

restful风格的url我们可以尽量去遵守，因为它对运维或者监控都非常友好。但是不要一根经，它只是理想情况，有的时候并不满足我们的需求，我们可以变通的看问题。

简明的一幅图，rest接口的命名规范： 

![image-20210716142422445](/Users/xishengcai/Library/Application Support/typora-user-images/image-20210716142422445.png)

- 1. API must has version
  2. use token rather than cookie
  3. url is not case。。，not use 大写字母
  4. use - rather then _
  5. remeber doc



 为什么会推荐用 -，而不是 _？ `-`叫做分词符，顾名思义用作分开不同词的。这个最佳实践来自于针对Google为首的SEO（搜索引擎优化）需要，Google搜索引擎会把url中出现的-当做空格对待，这样url “/it-is-crazy” 会被搜索引擎识别为与“it",“is”,“crazy"关键词或者他们的组合关键字相关。 当用户搜索”it”,“crazy”, "it is crazy"时，很容易检索到这个url，排名靠前。

`_` 这个符号如果出现在url中，会自动被Google忽略，“/it_is_crazy”被识别为与关键词 “itIsCrazy”相关。