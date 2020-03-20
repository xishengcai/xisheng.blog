---
title: "ovftool usage"
date: 2019-10-23T16:08:36+08:00
draft: false
---


# export ovf
ovftool vi://root@8.16.0.119:443/template ./

目的：可以实现跨越物理机克隆esxi虚拟机
利用VMware workstation（本人使用的pro版）的 OVF Tool导出。
假设你的ESXi的服务器ip是172.28.1.1，要备份的虚拟机的名字叫做ubuntu，workstation装在windows上。

首先进入VMware workstation安装目录，找到\OVFTool\ovftool.exe，执行命令
.\ovftool.exe vi://root:@172.28.1.1/ubuntu C:
输入ESXi root用户的密码后，备份开始，保存在windows的C盘中，至少要包含一个ovf文件和一个vmdk文件。
OVF的全称是Open Virtualization Format。

直接拷贝虚拟机的vmdk文件也是可以的，但是如果虚拟机的硬盘是厚制备的话，vmdk文件太大了。举个例子，我的ubuntu虚拟机vmdk文件大小500GB，导出为OVF后只需要大约10GB。另外OVFTool应该是开源软件，如果你不想安装VMware家的workstation，可以找一找开源的OVFTool。
blog.csdn.net/weixin_43808555/article/details/919720323/terraform-provider-esxi_v1.5.3
[参考链接](https://blog.csdn.net/weixin_43808555/article/details/91972032)