![image-20231114144644461](/Users/xishengcai/soft/xisheng.blog/kubernetes/image-20231114144644461.png)



问题背景：

```
grafana image info
grafana/grafana                          8.4.5             7a414d9a5e42        19 months ago       279MB
```



前端页面 链接到grafana 指标界面



解决方案：

1. 设置环境变量

   ```
           - name: GF_SERVER_ROOT_URL
             value: /api/grafana
   ```

   

2. 修改配置文件

   ```
   root_url
   sub_path
   ```

   