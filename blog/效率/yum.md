# yum usage





#### download rpm package

```
yum install --downloadonly RPM_Name
```



#### download rpm package to target dir

```
yum install --downloadonly --downloaddir=/usr/package rpm_name
```



#### yum install remote file server rpm

```
yum localinstall http://{{ nginx_file_server }}/rpm
```





