# Nat 

- 任务

  vip（183.136.132.116） --->container ip (172.17.0.5)



- 前提条件（其实docker已经帮我开启转发了）

  echo "1" > /proc/sys/net/ipv4/ip_forward 

 

- Step1:  bind vip

```bash
ifconfig em1:82 115.231.185.82 broadcast 115.231.185.82 netmask 255.255.255.0 up
ip addr del 183.136.132.116 dev em1:116 
```

 

 

- Step2： set nat rule

```

iptables -t nat -A PREROUTING -d 183.136.132.116 -p tcp --dport 80 -j DNAT --to-destination 172.17.0.5:80
iptables -t nat -A POSTROUTING -d 172.17.05.5 -p tcp --dport 80 -j SNAT --to-source 183.136.132.120
iptables -A INPUT -d 物理机ip地址 -j DROP
 
正确的做法
iptables -I INPUT 1 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t filter -A OUTPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT  #打开ping功能
iptables -A INPUT -d 物理机ip地址 -j DROP
 
单个vip策略
iptables -t nat -A DOCKER -d 183.136.132.124 -p tcp -m tcp --dport 3306 -j DNAT --to-destination 10.0.17.5:80 #实现转发
 
 
```



# 2.3.容灾ip漂移

删除规则

```
iptables -t nat -nvL --line-number
iptables -t nat -D POSTROUTING 2
iptables -t nat -D PREROUTING 2
iptables -D INPUT 3
 
iptables -t nat -nvL --line-number | grep 183.136.132.116 | grep DNAT | awk '{print $1}'
route | grep docker0 | awk '{print $1}'  获取docker0
 
```

# 4. troub shouting

```
ssh 连接慢的问题 参考 http://blog.51cto.com/jasonyong/280993
```

iptables -I INPUT -p udp --sport 53 -j ACCEPT

iptables -I INPUT -p tcp --sport 53 -j ACCEPT





 iptables -t nat -A PREROUTING -p tcp --dport  -j REDIRECT --to-ports 8080