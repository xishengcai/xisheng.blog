# multipart/form-data



#### 一个 HTML 表单中的 enctype 有三种类型

- application/x-www-urlencoded
- multipart/form-data
- text-plain



默认情况下是 `application/x-www-urlencoded`，当表单使用 POST 请求时，数据会被以 x-www-urlencoded 方式编码到 Body 中来传送，
 而如果 GET 请求，则是附在 url 链接后面来发送。

GET 请求只支持 ASCII 字符集，因此，如果我们要发送更大字符集的内容，我们应使用 POST 请求。



#### 注意

`"application/x-www-form-urlencoded"` 编码的格式是 ASCII，如果 form 中传递的是二进制等 Media Type 类型的数据，那么 `application/x-www-form-urlencoded` 会把其编码转换成 ASCII 类型。对于 1 个 non-ASCII 字符，它需要用 3 个 ASCII字符来表示，如果要发送大量的二进制数据（non-ASCII），`"application/x-www-form-urlencoded"` 显然是低效的。因此，这种情况下，应该使用 `"multipart/form-data"` 格式。

The content type "application/x-www-form-urlencoded" is inefficient for sending large quantities of binary data or text containing non-ASCII characters. The content type "multipart/form-data" should be used for submitting forms that contain files, non-ASCII data, and binary data



​	
