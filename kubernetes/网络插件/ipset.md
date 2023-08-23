# # ipset



*[作者：Linux_woniu](https://www.huaweicloud.com/articles/a59f79bb4d48c06097c2c902f71ed1d6.html#)* 时间: 2021-02-05 08:53:35

[标签：](https://www.huaweicloud.com/articles/topic-A-1.html)[ipset](https://www.huaweicloud.com/articles/topic_536d13e79fd33eb6157466465ec8a9c6.html)[防火墙](https://www.huaweicloud.com/articles/topic_8606f66d0bcb4cc1983e1a85adbcd253.html)

```
【摘要】ipset是iptables的扩展，可以让你添加规则来匹配地址集合。不同于常规的iptables链是线性的存储和遍历，ipset是用索引数据结构存储，甚至对于大型集合，查询效率非常都优秀。Besides the obvious situations where you might imagine this would be useful, such as blocking long list...
```

ipset是iptables的扩展，可以让你添加规则来匹配地址集合。不同于常规的iptables链是线性的存储和遍历，ipset是用索引数据结构存储，甚至对于大型集合，查询效率非常都优秀。

Besides the obvious situations where you might imagine this would be useful, such as blocking long lists of "bad" hosts without worry of killing system resources or causing network congestion, IP sets also open up new ways of approaching certain aspects of firewall design and simplify many configuration scenarios.

除了可以看见的解决方案，例如防止长主机列表造成的系统资源耗尽，ipset还开创了新方式来设计防火墙和简化许多规则。

## Getting ipset

TODO

## iptables Overview

TODO

## Enter ipset

ipset is a "match extension" for iptables. To use it, you create and populate uniquely named "sets" using the ipset command-line tool, and then separately reference those sets in the match specification of one or more iptables rules.

ipset用于iptables的"匹配扩展"。要使用它，需要通过ipset的命令行工具创建一个集合，然后分别在一个或多格iptables规则中引用这个set

A set is simply a list of addresses stored efficiently for fast lookup.

Take the following normal iptables commands that would block inbound traffic from 1.1.1.1 and 2.2.2.2:

```javascript
iptables -A INPUT -s 1.1.1.1 -j DROP
iptables -A INPUT -s 2.2.2.2 -j DROP
```

The match specification syntax -s 1.1.1.1 above means "match packets whose source address is 1.1.1.1". To block both 1.1.1.1 and 2.2.2.2, two separate iptables rules with two separate match specifications (one for 1.1.1.1 and one for 2.2.2.2) are defined above.

Alternatively, the following ipset/iptables commands achieve the same result:

```javascript
ipset -N myset iphash
ipset -A myset 1.1.1.1ipset -A myset 2.2.2.2iptables -A INPUT -m set --set myset src -j DROP
```

The ipset commands above create a new set (myset of type iphash) with two addresses (1.1.1.1 and 2.2.2.2).

The iptables command then references the set with the match specification -m set --set myset src, which means "match packets whose source header matches (that is, is contained within) the set named myset".

The flag src means match on "source". The flag dst would match on "destination", and the flag src,dst would match on both source and destination.

In the second version above, only one iptables command is required, regardless of how many additional IP addresses are contained within the set. Although this example uses only two addresses, you could just as easily define 1,000 addresses, and the ipset-based config still would require only a single iptables rule, while the previous approach, without the benefit of ipset, would require 1,000 iptables rules.

在上面的第二个版本，尽管这个例子只写了两个地址。但是不管ipset包含多少个ip地址，都只需要一条iptables命令。你可以定义1000个地址，iptables依然只需要一条规则。在第一个版本中，没有ipset，所以需要1000个iptables规则。

## Set Types

Each set is of a specific type, which defines what kind of values can be stored in it (IP addresses, networks, ports and so on) as well as how packets are matched (that is, what part of the packet should be checked and how it's compared to the set). Besides the most common set types, which check the IP address, additional set types are available that check the port, the IP address and port together, MAC address and IP address together and so on.

每一个set都需要一个特定的类型，用于定义它可以存储什么样的类型(IP地址、网络、端口等等)以及包如何匹配(即，包的什么部分应该被检查以及它是如何和set做匹配)。除了检查IP地址这个最常用的set类型，还有端口、IP地址和端口一起、MAC地址和IP地址一起，等等。

Each set type has its own rules for the type, range and distribution of values it can contain. Different set types also use different types of indexes and are optimized for different scenarios. The best/most efficient set type depends on the situation.

The most flexible set types are iphash, which stores lists of arbitrary IP addresses, and nethash, which stores lists of arbitrary networks (IP/mask) of varied sizes. Refer to the ipset man page for a listing and description of all the set types (there are 11 in total at the time of this writing).

最灵活的set类型是iphash，可以存储任意的IP地址列表和任意的网络(IP/MASK)列表。ipset的man page列出和描述了所有的set类型(在写这篇文章时总共有11种类型)

The special set type setlist also is available, which allows grouping several sets together into one. This is required if you want to have a single set that contains both single IP addresses and networks, for example.

## Advantages of ipset

Besides the performance gains, ipset also allows for more straightforward configurations in many scenarios.

除开性能上的获取，ipset还允许在许多场景下做更多简洁的配置。

If you want to define a firewall condition that would match everything but packets from 1.1.1.1 or 2.2.2.2 and continue processing in mychain, notice that the following does not work:

```javascript
iptables -A INPUT -s ! 1.1.1.1 -g mychain
iptables -A INPUT -s ! 2.2.2.2 -g mychain
```

If a packet came in from 1.1.1.1, it would not match the first rule (because the source address is 1.1.1.1), but it would match the second rule (because the source address is not 2.2.2.2). If a packet came in from 2.2.2.2, it would match the first rule (because the source address is not 1.1.1.1). The rules cancel each other out—all packets will match, including 1.1.1.1 and 2.2.2.2.

Although there are other ways to construct the rules properly and achieve the desired result without ipset, none are as intuitive or straightforward:

```javascript
ipset -N myset iphash
ipset -A myset 1.1.1.1ipset -A myset 2.2.2.2iptables -A INPUT -m set ! --set myset src -g mychain
```

In the above, if a packet came in from 1.1.1.1, it would not match the rule (because the source address 1.1.1.1 does match the set myset). If a packet came in from 2.2.2.2, it would not match the rule (because the source address 2.2.2.2 does match the set myset).

Although this is a simplistic example, it illustrates the fundamental benefit associated with fitting a complete condition in a single rule. In many ways, separate iptables rules are autonomous from each other, and it's not always straightforward, intuitive or optimal to get separate rules to coalesce into a single logical condition, especially when it involves mixing normal and inverted tests. ipset just makes life easier in these situations.

// TODO

Another benefit of ipset is that sets can be manipulated independently of active iptables rules. Adding/changing/removing entries is a trivial matter because the information is simple and order is irrelevant. Editing a flat list doesn't require a whole lot of thought. In iptables, on the other hand, besides the fact that each rule is a significantly more complex object, the order of rules is of fundamental importance, so in-place rule modifications are much heavier and potentially error-prone operations.

## Excluding WAN, ××× and Other Routed Networks from the NAT—the Right Way

Outbound NAT (SNAT or IP masquerade) allows hosts within a private LAN to access the Internet. An appropriate iptables NAT rule matches Internet-bound packets originating from the private LAN and replaces the source address with the address of the gateway itself (making the gateway appear to be the source host and hiding the private "real" hosts behind it).

// TODO Outbound NAT?

NAT automatically tracks the active connections so it can forward return packets back to the correct internal host (by changing the destination from the address of the gateway back to the address of the original internal host).

NAT自动跟踪活动的链接，所以它可以返回包到正确的内部主机(通过网络地址改回目的地址到原来的内部主机地址)

Here is an example of a simple outbound NAT rule that does this, where 10.0.0.0/24 is the internal LAN:

```javascript
iptables -t nat -A POSTROUTING \ -s 10.0.0.0/24 -j MASQUERADE
```

This rule matches all packets coming from the internal LAN and masquerades them (that is, it applies "NAT" processing). This might be sufficient if the only route is to the Internet, where all through traffic is Internet traffic. If, however, there are routes to other private networks, such as with ××× or physical WAN links, you probably don't want that traffic masqueraded.

这个规则匹配所有来至局域网内部的数据包，并且伪装他们(即，它适用NAT处理#TODO?)。如果唯一的路由是通向Internet，所有通过的流量都是Internet流量，也许会比较足够。但是，会有一些到私有网络的路由，比如×××或屋里WAN链路，你应该不希望流量伪装。 #TODO 这一段翻译的好蛋疼

One simple way (partially) to overcome this limitation is to base the NAT rule on physical interfaces instead of network numbers (this is one of the most popular NAT rules given in on-line examples and tutorials):

```javascript
iptables -t nat -A POSTROUTING \ -o eth0 -j MASQUERADE
```

This rule assumes that eth0 is the external interface and matches all packets that leave on it. Unlike the previous rule, packets bound for other networks that route out through different interfaces won't match this rule (like with Open××× links).

这条规则假设eth0是外网口并且匹配所有通过它出去的数据包。不同于前一条规则，绑定其他网络通过不同的网卡出去的数据包不会匹配这条规则(例如Open×××链路)

Although many network connections may route through separate interfaces, it is not safe to assume that all will. A good example is KAME-based IPsec ××× connections (such as Openswan) that don't use virtual interfaces like other user-space ×××s (such as Open×××).

尽管许多网络连接可能会通过不同的网卡出去，但假设所有都会并不安全。一个很好的例子就是KAME-based IPsec ×××连接(例如Openswan)不会像其他user-space ×××s(例如Open×××)一样使用虚拟网卡。

Another situation where the above interface match technique wouldn't work is if the outward facing ("external") interface is connected to an intermediate network with routes to other private networks in addition to a route to the Internet. It is entirely plausible for there to be routes to private networks that are several hops away and on the same path as the route to the Internet.

// TODO

Designing firewall rules that rely on matching of physical interfaces can place artificial limits and dependencies on network topology, which makes a strong case for it to be avoided if it's not actually necessary.

As it turns out, this is another great application for ipset. Let's say that besides acting as the Internet gateway for the local private LAN (10.0.0.0/24), your box routes directly to four other private networks (10.30.30.0/24, 10.40.40.0/24, 192.168.4.0/23 and 172.22.0.0/22). Run the following commands:

```javascript
ipset -N routed_nets nethash
ipset -A routed_nets 10.30.30.0/24ipset -A routed_nets 10.40.40.0/24ipset -A routed_nets 192.168.4.0/23ipset -A routed_nets 172.22.0.0/22iptables -t nat -A POSTROUTING \ -s 10.0.0.0/24 \ -m set ! --set routed_nets dst \ -j MASQUERADE
```

As you can see, ipset makes it easy to zero in on exactly what you want matched and what you don't. This rule would masquerade all traffic passing through the box from your internal LAN (10.0.0.0/24) except those packets bound for any of the networks in your routed_nets set, preserving normal direct IP routing to those networks. Because this configuration is based purely on network addresses, you don't have to worry about the types of connections in place (type of ×××s, number of hops and so on), nor do you have to worry about physical interfaces and topologies.

This is how it should be. Because this is a pure layer-3 (network layer) implementation, the underlying classifications required to achieve it should be pure layer-3 as well.

## Limiting Certain PCs to Have Access Only to Certain Public Hosts

Let's say the boss is concerned about certain employees playing on the Internet instead of working and asks you to limit their PCs' access to a specific set of sites they need to be able to get to for their work, but he doesn't want this to affect all PCs (such as his).

To limit three PCs (10.0.0.5, 10.0.0.6 and 10.0.0.7) to have outside access only to worksite1.com, worksite2.com and worksite3.com, run the following commands:

```javascript
ipset -N limited_hosts iphash
ipset -A limited_hosts 10.0.0.5ipset -A limited_hosts 10.0.0.6ipset -A limited_hosts 10.0.0.7ipset -N allowed_sites iphash
ipset -A allowed_sites worksite1.com
ipset -A allowed_sites worksite2.com
ipset -A allowed_sites worksite3.com
iptables -I FORWARD \ -m set --set limited_hosts src \ -m set ! --set allowed_sites dst \ -j DROP
```

This example matches against two sets in a single rule. If the source matches limited_hosts and the destination does not match allowed_sites, the packet is dropped (because limited_hosts are allowed to communicate only with allowed_sites).

Note that because this rule is in the FORWARD chain, it won't affect communication to and from the firewall itself, nor will it affect internal traffic (because that traffic wouldn't even involve the firewall).

## Blocking Access to Hosts for All but Certain PCs (Inverse Scenario)

Let's say the boss wants to block access to a set of sites across all hosts on the LAN except his PC and his assistant's PC. For variety, in this example, let's match the boss and assistant PCs by MAC address instead of IP. Let's say the MACs are 11:11:11:11:11:11 and 22:22:22:22:22:22, and the sites to be blocked for everyone else are badsite1.com, badsite2.com and badsite3.com.

In lieu of using a second ipset to match the MACs, let's utilize multiple iptables commands with the MARK target to mark packets for processing in subsequent rules in the same chain:

```javascript
ipset -N blocked_sites iphash
ipset -A blocked_sites badsite1.com
ipset -A blocked_sites badsite2.com
ipset -A blocked_sites badsite3.com
iptables -I FORWARD -m mark --mark 0x187 -j DROP
iptables -I FORWARD \ -m mark --mark 0x187 \ -m mac --mac-source 11:11:11:11:11:11 \ -j MARK --set-mark 0x0iptables -I FORWARD \ -m mark --mark 0x187 \ -m mac --mac-source 22:22:22:22:22:22 \ -j MARK --set-mark 0x0iptables -I FORWARD \ -m set --set blocked_sites dst \ -j MARK --set-mark 0x187
```

As you can see, because you're not using ipset to do all the matching work as in the previous example, the commands are quite a bit more involved and complex. Because there are multiple iptables commands, it's necessary to recognize that their order is vitally important.

Notice that these rules are being added with the -I option (insert) instead of -A (append). When a rule is inserted, it is added to the top of the chain, pushing all the existing rules down. Because each of these rules is being inserted, the effective order is reversed, because as each rule is added, it is inserted above the previous one.

The last iptables command above actually becomes the first rule in the FORWARD chain. This rule matches all packets with a destination matching the blocked_sites ipset, and then marks those packets with 0x187 (an arbitrarily chosen hex number). The next two rules match only packets from the hosts to be excluded and that are already marked with 0x187. These two rules then set the marks on those packets to 0x0, which "clears" the 0x187 mark.

Finally, the last iptables rule (which is represented by the first iptables command above) drops all packets with the 0x187 mark. This should match all packets with destinations in the blocked_sites set except those packets coming from either of the excluded MACs, because the mark on those packets is cleared before the DROP rule is reached.

This is just one way to approach the problem. Other than using a second ipset, another way would be to utilize user-defined chains.

If you wanted to use a second ipset instead of the mark technique, you wouldn't be able to achieve the exact outcome as above, because ipset does not have a machash set type. There is a macipmap set type, however, but this requires matching on IP and MACs together, not on MAC alone as above.

Cautionary note: in most practical cases, this solution would not actually work for Web sites, because many of the hosts that might be candidates for the blocked_sites set (like Facebook, MySpace and so on) may have multiple IP addresses, and those IPs may change frequently. A general limitation of iptables/ipset is that hostnames should be specified only if they resolve to a single IP.

Also, hostname lookups happen only at the time the command is run, so if the IP address changes, the firewall rule will not be aware of the change and still will reference the old IP. For this reason, a better way to accomplish these types of Web access policies is with an HTTP proxy solution, such as Squid. That topic is obviously beyond the scope of this article.

## Automatically Ban Hosts That Attempt to Access Invalid Services

ipset also provides a "target extension" to iptables that provides a mechanism for dynamically adding and removing set entries based on any iptables rule. Instead of having to add entries manually with the ipset command, you can have iptables add them for you on the fly.

For example, if a remote host tries to connect to port 25, but you aren't running an SMTP server, it probably is up to no good. To deny that host the opportunity to try anything else proactively, use the following rules:

```javascript
ipset -N banned_hosts iphash
iptables -A INPUT \ -p tcp --dport 25 \ -j SET --add-set banned_hosts src
iptables -A INPUT \ -m set --set banned_hosts src \ -j DROP
```

If a packet arrives on port 25, say with source address 1.1.1.1, it instantly is added to banned_hosts, just as if this command were run:

```javascript
ipset -A banned_hosts 1.1.1.1
```

All traffic from 1.1.1.1 is blocked from that moment forward because of the DROP rule.

Note that this also will ban hosts that try to run a port scan unless they somehow know to avoid port 25.

## Clearing the Running Config

If you want to clear the ipset and iptables config (sets, rules, entries) and reset to a fresh open firewall state (useful at the top of a firewall script), run the following commands:

```javascript
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -t filter -F
iptables -t raw -F
iptables -t nat -F
iptables -t mangle -F
ipset -F
ipset -X
```

Sets that are "in use", which means referenced by one or more iptables rules, cannot be destroyed (with ipset -X). So, in order to ensure a complete "reset" from any state, the iptables chains have to be flushed first (as illustrated above).

## Conclusion

ipset adds many useful features and capabilities to the already very powerful netfilter/iptables suite. As described in this article, ipset not only provides new firewall configuration possibilities, but it also simplifies many setups that are difficult, awkward or less efficient to construct with iptables alone.

Any time you want to apply firewall rules to groups of hosts or addresses at once, you should be using ipset. As I showed in a few examples, you also can combine ipset with some of the more exotic iptables features, such as packet marking, to accomplish all sorts of designs and network policies.

The next time you're working on your firewall setup, consider adding ipset to the mix. I think you will be surprised at just how useful and flexible it can be.

## Resources

Netfilter/iptables Project Home Page: http://www.netfilter.org

ipset Home Page: http://ipset.netfilter.org

------

# Man IPSET

Ref: [http://ipset.netfilter.org/ipset.man.html]

ipset -- administration tool for IP sets

```javascript
ipset [ OPTIONS ] COMMAND [ COMMAND-OPTIONS ]COMMANDS := { create | add | del | test | destroy | list | save | restore | flush | rename | swap | help | version | - }OPTIONS := { -exist | -output { plain | save | xml } | -quiet | -resolve | -sorted }ipset create SETNAME TYPENAME [ CREATE-OPTIONS ]ipset add SETNAME ADD-ENTRY [ ADD-OPTIONS ]ipset del SETNAME DEL-ENTRY [ DEL-OPTIONS ]ipset test SETNAME TEST-ENTRY [ TEST-OPTIONS ]ipset destroy [ SETNAME ]ipset list [ SETNAME ]ipset save [ SETNAME ]ipset restore

ipset flush [ SETNAME ]ipset rename SETNAME-FROM SETNAME-TO

ipset swap SETNAME-FROM SETNAME-TO

ipset help [ TYPENAME ]ipset version

ipset -
```

ipset有三种存储方式：

- bitmao
- hash
- list

bitmap和list方式使用一个固定大小的存储。hash方式使用一个hash来存储元素。

ipset 配合ip/port/mac/net等可以组成多种类型

## 基本操作

```javascript
create SETNAME TYPENAME [ CREATE-OPTIONS ]新建一个set

add SETNAME ADD-ENTRY [ ADD-OPTIONS ]给已有的set添加一个entry(entry可以理解为一条匹配规则)del SETNAME DEL-ENTRY [ DEL-OPTIONS ]删除一条entry

test SETNAME TEST-ENTRY [ TEST-OPTIONS ]测试一个地址是否匹配这个set(即set中有一条entry符合)x, destroy [ SETNAME ]删除set，如果没有指定set名，则删除所有set

list [ SETNAME ]根据set名列出set相关信息，没有接set名称则列出所有

save [ SETNAME ]输出一个restory操作可读的格式到标准输出，用于导出数据

restore
通过标准输入恢复save操作产生的数据

flush [ SETNAME ]清空指定set的所有entry
```

一组类型包括该数据的存储方式和存储类型

```javascript
TYPENAME = method:datatype[,datatype[,datatype]]
```

当前的存储方式有bitmap, hash, list

数据类型有ip, mac, port

bitmap和list方式使用一个固定大小的存储。hash方式使用一个hash来存储元素

## Set Type

### bitmap:ip

此集合类型使用内存段来存储 IPv4主机(默认) 或 IPv4网络地址

一个此类型可以存储最多 65536 个 entry

```javascript
CREATE-OPTIONS := range fromip-toip|ip/cidr [ netmask cidr ] [ timeout value ]ADD-ENTRY := { ip | fromip-toip | ip/cidr }ADD-OPTIONS := [ timeout value ]DEL-ENTRY := { ip | fromip-toip | ip/cidr }TEST-ENTRY := ip
```

必选参数: range fromip-toip|ip/cidr 创建一个指定IPv4地址范围的集合，范围的大小(entry个数)最大个数是65536个

可选参数: netmask cidr 当可选的netmask参数指定时，网络地址将取代IP主机地址存储在集合众。

举例:

```javascript
ipset create foo bitmap:ip range 192.168.0.0/16ipset add foo 192.168.1/24ipset test foo 192.168.1.1
```

### bitmap:ip,mac

存储一个IPv4和MAC地址对。此类型最多存储65536个entry。

```javascript
CREATE-OPTIONS := range fromip-toip|ip/cidr [ timeout value ]ADD-ENTRY := ip[,macaddr]ADD-OPTIONS := [ timeout value ]DEL-ENTRY := ip[,macaddr]TEST-ENTRY := ip[,macaddr]
```

// TODO

举例：

```javascript
ipset create foo bitmap:ip,mac range 192.168.0.0/16ipset add foo 192.168.1.1,12:34:56:78:9A:BC
ipset test foo 192.168.1.1
```

### bitmap:port

端口集合最多可存储 65536 个

```javascript
CREATE-OPTIONS := range fromport-toport [ timeout value ]ADD-ENTRY := { port | fromport-toport }ADD-OPTIONS := [ timeout value ]DEL-ENTRY := { port | fromport-toport }TEST-ENTRY := port
```

举例：

```javascript
ipset create foo bitmap:port range 0-1024ipset add foo 80ipset test foo 80% ipset add foo 1025ipset v6.17: Element is out of the range of the set
```

### hash:ip

```javascript
CREATE-OPTIONS := [ family { inet | inet6 } ] | [ hashsize value ] [ maxelem value ] [ netmask cidr ] [ timeout value ]ADD-ENTRY := ipaddr
ADD-OPTIONS := [ timeout value ]DEL-ENTRY := ipaddr
TEST-ENTRY := ipaddr// ipaddr := { ip | fromaddr-toaddr | ip/cidr }
```

Note:

netmask cidr When the optional netmask parameter specified, network addresses will be stored in the set instead of IP host addresses. The cidr prefix value must be between 1-32 for IPv4 and between 1-128 for IPv6. An IP address will be in the set if the network address, which is resulted by masking the address with the netmask calculated from the prefix, can be found in the set.

意思就是当默认是存储单个ip地址(ip address)，如果指定掩码，则默认是存储的网络地址，见下面的例子

举例：

```javascript
ipset create foo hash:ip netmask 30ipset add foo 192.168.1.0 // 则默认会添加network address: 192.168.1.0/30ipset add foo 192.168.1.0/24ipset test foo 192.168.1.2
```

### hash:net

hash:net用于使用hash来存储不同范围大小的ip网络地址。

```javascript
CREATE-OPTIONS := [ family { inet | inet6 } ] | [ hashsize value ] [ maxelem value ] [ timeout value ]ADD-ENTRY := ip[/cidr]ADD-OPTIONS := [ timeout value ]DEL-ENTRY := ip[/cidr]TEST-ENTRY := ip[/cidr]
```

When adding/deleting/testing entries, if the cidr prefix parameter is not specified, then the host prefix value is assumed. When adding/deleting entries, the exact element is added/deleted and overlapping elements are not checked by the kernel. When testing entries, if a host address is tested, then the kernel tries to match the host address in the networks added to the set and reports the result accordingly.

当添加/删除/测试一条entry时，如果cidr没有指定，则相当于一个host address。

当添加/删除entry时，精确的元素会添加/删除并覆盖原来的

当测试entry时，如果host address被测试，则内核尝试在添加的network中匹配这个host address。

举例：

```javascript
ipset create foo hash:net
ipset add foo 192.168.0.0/24ipset add foo 10.1.0.0/16ipset test foo 192.168.0/24
```

### hash:ip,port

此类型使用hash存储ip和port对。这个端口号随协议一起被解析(默认是tcp)

```javascript
CREATE-OPTIONS := [ family { inet | inet6 } ] | [ hashsize value ] [ maxelem value ] [ timeout value ]ADD-ENTRY := ipaddr,[proto:]port
ADD-OPTIONS := [ timeout value ]DEL-ENTRY := ipaddr,[proto:]port
TEST-ENTRY := ipaddr,[proto:]port//ipaddr := { ip | fromaddr-toaddr | ip/cidr }
```

举例：

```javascript
ipset create foo hash:ip,port
ipset add foo 192.168.1.0/24,80-82ipset add foo 192.168.1.1,udp:53ipset add foo 192.168.1.1,vrrp:0ipset test foo 192.168.1.1,80
```

详细例子见下面的场景3

### hash:net,port

相当于hash:net和hash:port的结合

### hash:ip,port,ip

需要三个src/dst匹配，具体见下面的场景三

### hash:ip,port,net

同上一个

### list:set

此类型使用一个简单的list，可以存储如set名称

```javascript
CREATE-OPTIONS := [ size value ] [ timeout value ]ADD-ENTRY := setname [ { before | after } setname ]ADD-OPTIONS := [ timeout value ]DEL-ENTRY := setname [ { before | after } setname ]TEST-ENTRY := setname [ { before | after } setname ]
```

TODO

## 额外的评论

If you want to store same size subnets from a given network (say /24 blocks from a /8 network), use the bitmap:ip set type. If you want to store random same size networks (say random /24 blocks), use the hash:ip set type. If you have got random size of netblocks, use hash:net.

- 如果想在一个给定的网络范围里存储相同子网大小的段，可以使用bitmap:ip
- 如果想存储掩码长度相同，网络号随机的网络地址，可以使用hash:ip
- 如果想存储随机的网络范围(掩码长度和主机号都不一样)，可以使用hash:net
- iptree和iptreemap set类型都被移除。如果使用他们，则会自动被替换为hash:ip

# 应用场景

## 场景1

```javascript
iptables -A INPUT -s 1.1.1.1 -j DROP
iptables -A INPUT -s 2.2.2.2 -j DROP...iptables -A INPUT -s 100.100.100.100 -j DROP
```

这样会导致iptables规则非常多，降低效率 如果使用ipset

```javascript
ipset -N myset hash:ip
ipset -A myset 1.1.1.1ipset -A myset 2.2.2.2...ipset -A myset 100.100.100.100iptables -A INPUT -m set --set myset src -j DROP
```

iptables只需要一条规则，不但提高效率，还易于管理

## 场景2

比如有以下两条iptables规则：

```javascript
iptables -A INPUT -s ! 1.1.1.1 -g mychain
iptables -A INPUT -s ! 2.2.2.2 -g mychain
```

如果packet来至1.1.1.1，则不会匹配第一条规则，但是会匹配第二条规则

如果packet来至2.2.2.2，则不会匹配第二条规则，但是会匹配第一条规则

这样就互相矛盾了，它实际会匹配所有的packet

用ipset就可以很简单的解决这个问题：

```javascript
ipset -N myset iphash
ipset -A myset 1.1.1.1ipset -A myset 2.2.2.2iptables -A INPUT -m set ! --set myset src -g mychain
```

如果来至1.1.1.1和2.2.2.2的packet，都会不匹配这条规则，但其他packet可以匹配

## 场景3(*)

比如我们要设置一个ip黑名单，禁止访问本机80端口

### 方式1

参考:http://daemonkeeper.net/781/mass-blocking-ip-addresses-with-ipset/

```javascript
ipset create blacklist hash:ip hashsize 4096iptables -I INPUT  -m set --match-set blacklist src -p TCP \ --destination-port 80 -j REJECT
ipset add blacklist 192.168.0.5 ipset add blacklist 192.168.0.100 ipset add blacklist 192.168.0.220
```

这样blacklist里面的ip都回被禁止访问本机80端口

### 方式2

假设本机ip是192.168.0.5

```javascript
ipset create foo hash:ip,port
iptables -I INPUT -m set --match-set foo dst,dst -j REJECT// 上面这句就是把foo里面的ip,port都当目的ip和目的port来匹配ipset add foo 192.168.0.5,80// 这样当外面访问本机的80端口时，会被REJECT
```

这个的效果和上面类似，不过可以理解hash:ip,port的作用。

在hash:ip,port手册里有这么一句话：

The hash:ip,port type of sets require two src/dst parameters of the set match and SET target kernel modules.

先开始一直不明白是什么意思，参考http://serverfault.com/questions/384132/iptables-limit-rate-of-a-specific-incoming-ip后才弄懂

如果使用hash:ip,port类型，就需要指定两个scr/dst，第一个指定ip是src还是dst的，第二个指定port是src还是dst的。这么控制真是太灵活and牛逼了

包括hash:ip,port,ip等需要三个src/dst都是一样的意思

# 补充

Size in memory 的单位是?(暂时猜测是字节) References 是指被iptables引用的个数，值为非0时表示有被引用的，这时不能用ipset destroy清除

------

timeout 属性用于设置规则多久自动清除 必须在set类型设置了timeout后, entry才能使用set设置的默认timeout或自己设置timeout

nomatch 用于匹配 hash:*net*的类型, 表示这些entry不匹配, 相当于 逻辑非 操作

转载：http://bigsec.net/one/tool/ipset.html