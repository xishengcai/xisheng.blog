---
title: "ansible usage"
date: 2019-10-25 T16:08:36+08:00
draft: true
---

#### 基本概念
Tasks：任务，由模板定义的操作列表
Variables：变量
Templates：模板，即使用模板语法的文件
Handlers：处理器 ，当某条件满足时，触发执行的操作
Roles：角色

#### 定制返回信息
[official example](https://github.com/ansible/ansible/blob/devel/lib/ansible/plugins/callback/log_plays.py)

#### modify config
```
bin_ansible_callbacks = True
callback_plugins = callback_plugins
callback_whitelist = self_logout
```
[task cost time codes](https://github.com/jlafon/ansible-profile)

#### 命令行工具
ansible

ansible-playbook

#### 常用 modules
- yum
- fetch
- copy
- shell

#### 优化大量的shell一起执行的速度

#### 回调脚本

#### python ansible api

#### ansible 数组写在一行不好看

#### [playbook的YAML格式](https://blog.csdn.net/yongbuyanqidk/article/details/53369197)：
    文件的起始：
       ---          以三个减号开头，也可以不用，不会影响Ansible的运行
    注释：
        #           像Python一样用一个#进行注释
    字符串：
        可以使用引号或者不使用，即使字符串中含有空格，也不完全使用引号
    布尔值：
        True | False
    列表：
        列表使用-作为分隔符：
                   - zhangsan
                   - lisi
                   - wangwu
              也可以使用内联格式：
                   [zhangsan,lisi,wangwu]
         字典：
              YAML中的字典类似于JSON中的对象，Python中的字典：
                   address: beijing
                   city: beijing
                   state: North
              也可以使用内联格式：
                   {address: beijing, city: beijing, state: North}
         折行：
              YAML中使用大于号(>)来标记折行，YAML解释器会把换行符替换为空格：
                   address: >
                         Deadfasdfadf,
                         sdfdsfdsfsd
         模块：
              apt：使用apt包管理工具安装或删除软件包
              copy：将一个文件从本地复制到主机上
              file：设置文件、符号链接或者目录的属性
              service：启动、停止或者重启一个服务
              template：从模板生成一个文件并复制到主机上
         handler：
              handler是Ansible提供的条件机制之一。handler和task很类似，但是它只是在被task通知的时候才会执行。
                   notify: restart nginx
              handler只会在所有任务执行完后执行。而且即使被通知了多次，它也只会执行一次。handler按照play中定义的顺序                                           执行，而不是被通知的顺序。
    
    2.inventory：描述你的服务器
         inventory： Ansible可管理的主机集合。
         add_host：
         group_by：

     