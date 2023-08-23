# sshpass

在ssh 中使用密码



sshpass -p [password] ssh  -o "StrictHostKeyChecking no" root@172.16.11.134



```bash
for i in  host1 host2 ; do
  sshpass -p password ssh -tt root@$i << remote
  if [ -f /usr/bin/python3 -a ! /usr/bin/python ]; then
    ln -s /usr/bin/python3 /usr/bin/python
  elif [ -f /usr/bin/python -a ! /usr/bin/python3 ]; then
    ln -s /usr/bin/python /usr/bin/python3
  else
    echo "do nothing"
  fi
  exit 0
remote
done
```





## 免密钥登陆

```bash
# 生成公私钥， id_rsa.pub，id_rsa
ssh-keygen

# copy pub to remote host  ~/.ssh/authorized_keys
ssh-copy-id -i ~/.ssh/id_rsa.pub root@xxx.xxx.xxx.xxx
```



