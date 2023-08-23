### 安装 docker shell 脚本



```bash
#!/usr/bin/env bash

echo "clean env"
yum remove -y docker docker-common container-selinux docker-selinux docker-engine
rm -rf /var/lib/docker

echo "install docker 18.09.8"
sudo yum install -y yum-utils

sudo yum-config-manager \
    --add-repo \
    https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum clean packages
#查看docker-ce版本并且安装
yum list docker-ce --showduplicates | sort -r   
sudo yum install -y docker-ce-19.03.14 


echo "config docker daemon"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "/data/docker",
  "storage-driver": "overlay2",
  "exec-opts": [
    "native.cgroupdriver=systemd",
    "overlay2.override_kernel_check=true"
  ],
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  }
}
EOF

systemctl daemon-reload
systemctl enable docker
systemctl restart docker
docker info

```



```bash
#修改启动文件
echo "[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network.target firewalld.service

[Service]
Type=notify
#ExecStart=/usr/bin/dockerd  -H unix:///var/run/docker.sock -H tcp://0.0.0.0:6071 --insecure-registry=0.0.0.0/0
ExecStart=/usr/bin/dockerd  -H unix:///var/run/docker.sock  --insecure-registry=0.0.0.0/0
ExecReload=/bin/kill -s HUP
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target" > /usr/lib/systemd/system/docker.service
```



```
# default native.cgroupdriver=systemd

##如果要开启tls
#	https://blog.csdn.net/laodengbaiwe0838/article/details/79340805
#	--service
#		-H=tcp://0.0.0.0:2376 # 修改端口号为2376
#		-H=unix:///var/run/docker.sock
#		--tlsverify
#		--tlscacert=/etc/docker/ca.pem
#		--tlscert=/etc/docker/server-cert.pem
#		--tlskey=/etc/docker/server-key.pem


```



```
#校验
export http_proxy=''
export https_proxy=''
curl localhost:6071/info
```

