# 搭建NFS server

## 1.安装软件包

```
yum install -y nfs-utils
```

## 2.编辑exports文件，添加从机
```
vim /etc/exports
/data/nfs 8.210.84.124(rw,sync,fsid=0) 192.168.222.202(rw,sync,fsid=0)
```

配置说明

第一部分： /home/nfs, 这个是本地主要共享出去的目录

第二部分： 192.168.222.0/24, 允许访问的主机，可以是一个IP：192.168.222.201, 也可以是一个IP段：192.168.222.0/24，也可用，拼接多个ip地址段
	
第三部分： 括号中的部分
	rw ： 表示可读写， ro只读；

	sync ： 同步模式， 内存中数据实时写入磁盘；
	
	async ：不同步，把内存中数据定期写入磁盘中；
	
	no_root_squash  : 加上这个选项后， root用户就会对共享目录拥有最高的控制权，就像是对本机的目录操作一样。不安全， 不建议使用；
	
	root_squash  : 和上面的选项对应， root用户对共享目录的权限不高，只用普通用户权限；
	
	all_squash  : 不管使用NFS的用户是谁，他的身份都会被限定成为一个指定的普通用户。
	
	anonuid/anongid: 要和root_squash 以及 all_squash 一同使用， 用于指定使用NFS的用户限定后的uid和gid， 前提是本机的/etc/passwd中存在这个uid和gid。
	
	fsid=0 表示将/home/nfs 真个目录包装成根目录  
	
	/opt/test/  192.168.222.0/24(rw, no_roo_squash, no_all_squash, anonuid=501,anongid=501)

## 3.启动A机上的nfs服务

### 3.1 先为rpcbind和nfs做开机启动：
```
	systemctl enable rpcbind.service
	systemctl enable nfs-server.service
```

### 3.2 分别启动rpcbind和nfs服务
```
	systemctl start rpcbind.service
	systemctl start nfs-server.service
```

### 3.3 确认NFS服务器启动成功
```
		#通过查看service列中是否有nfs服务来确认NFS是否启动
		rpcinfo -p
		
		#查看可挂载目录及可连接的IP
		showmount -e 192.168.222.200
```

### 4. 关闭A机上的防火墙或者给防火墙配置NFS的通过规则

### 5. 在其他机器上配置client端
	1.安装nfs，并启动服务
		yum install -y nfs-utils
		systemctl enable rpcbind.service
		systemctl start rpcbind.service
		客户端不需要启动nfs服务，只需要启动rpcbind服务
		
	2.检查NFS服务器端是否有目录共享
		showmount -e 192.168.222.200
	
	3.使用mount挂载A服务器端的目录/home/nfs到客户端B目录的/home/nfs下
		mkdir /home/nfs
		mount -t nfs 192.168.222.200:/home/nfs /home/nfs
		df -h
		...
		192.168.222.200:/home/nfs    11G   1.3G  13%  /home/nfs
		
	4.挂载完成，可以正常访问本机下的/home/nfs, 如果在服务端A的共享目录/home/nfs中写入文件，B、C机上可以看到， 但是不能在这个目录中写入文件


### 6. 在多个服务器中建立一个共享目录，并且可以允许A、B、C写入共享目录

```
	6.1 在B、C机上取得root用户ID号
	   id root
	   uid=0(root)   gid=0(root)  group=0(root)
	
	6.2 在A服务器上再建立一个共享目录
		mkdir   /home/nfs1
		vim  /etc/nfs1
		/home/nfs  192.168.222.201(rw, sync,fsid=0)  192.168.222.202(rw, sync, fsid=0)
		/home/nfs1 192.168.222.0/24(rw, sync,all_squash, anonuid=0, anongid=0)
		加入第二行， anonuid=0， anongid=0， 即为root用户id
		
	6.3 让修改过的配置文件生效
		exportfs -arv
		使用exportfs命令， 当改变/etc/exports 配置文件后， 不用重启nfs服务器直接用这个exportfs即可，它的常用选项为[-aruv]
		-a:  全部挂载或者卸载
		-r:  重新挂载
		-u: 卸载某一个目录
		-v: 显示共享的目录
		
	6.4 查看新的可挂载目录以及可连接的IP
		showmount -e 192.168.222.200
	
	6.5 在B、C client端新挂载一个目录
		showmount -e 192.168.222.200  查看新的共享目录是否有了
		mkdir nfs1
		mount -t nfs 192.168.222.200:/home/nfs1/  /home/nfs1/
		ll / > /home/nfs1/ll.txt
		卸载：
	  umount /home/nfs1
```

### 7. 想在客户端上实现开机挂载， 则需要编辑/etc/fstab:

  ```
  vim /etc/fstab
     加入以下内容：
     192.168.222.200：/home/nfs             /home/nfs    nfs  nolock   0  0
     192.168.222.200 : /home/nfs1            /home/nfs1   nfs1  nolock  0 0
  
  保存后， 重新挂载
  mount -a
  ```

  
