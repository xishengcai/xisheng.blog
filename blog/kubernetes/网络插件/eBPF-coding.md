# eBPF coding



#### 工作原理

eBPF 的工作原理主要分为三个步骤：加载、编译和执行。

eBPF 需要在内核中运行。这通常是由用户态的应用程序完成的，它会通过系统调用来加载 eBPF 程序。在加载过程中，内核会将 eBPF 程序的代码复制到内核空间。

eBPF 程序需要经过编译和执行。这通常是由Clang/LLVM的编译器完成，然后形成字节码后，将用户态的字节码装载进内核，Verifier会对要注入内核的程序进行一些内核安全机制的检查,这是为了确保 eBPF 程序不会破坏内核的稳定性和安全性。在检查过程中，内核会对 eBPF 程序的代码进行分析，以确保它不会进行恶意操作，如系统调用、内存访问等。如果 eBPF 程序通过了内核安全机制的检查，它就可以在内核中正常运行了，其会通过通过一个JIT编译步骤将程序的通用字节码转换为机器特定指令集，以优化程序的执行速度。

下图是其架构图。

![image-20230601160943144](/Users/xishengcai/soft/xisheng.blog/blog/kubernetes/网络插件/image-20230601160943144.png)



在内核中运行时，eBPF 程序通常会挂载到一个内核钩子（hook）上，以便在特定的事件发生时被执行。例如，

- 系统调用——当用户空间函数将执行转移到内核时插入
- 函数进入和退出——拦截对预先存在的函数的调用
- 网络事件 – 在收到数据包时执行
- Kprobes 和 uprobes – 附加到内核或用户函数的探测器

最后 eBPF Maps，允许eBPF程序在调用之间保持状态，以便进行相关的数据统计，并与用户空间的应用程序共享数据。一个eBPF映射基本上是一个键值存储，其中的值通常被视为任意数据的二进制块。它们是通过带有BPF_MAP_CREATE参数的`bpf_cmd`系统调用来创建的，和Linux世界中的其他东西一样，它们是通过文件描述符来寻址。与地图的交互是通过查找/更新/删除系统调用进行的

总之，eBPF 的工作原理是通过动态加载、执行和检查**无损编译**过的代码来实现的。`[1]`



示例

```python
#!/usr/bin/python3

from bcc import BPF
from time import sleep

# 定义 eBPF 程序
bpf_text = """
#include <uapi/linux/ptrace.h>

BPF_HASH(stats, u32);

int count(struct pt_regs *ctx) {
    u32 key = 0;
    u64 *val, zero=0;
    val = stats.lookup_or_init(&key, &zero);
    (*val)++;
    return 0;
}
"""

# 编译 eBPF 程序
b = BPF(text=bpf_text, cflags=["-Wno-macro-redefined"])

# 加载 eBPF 程序
b.attach_kprobe(event="tcp_sendmsg", fn_name="count")

name = {
  0: "tcp_sendmsg"
}
# 输出统计结果
while True:
    try:
        #print("Total packets: %d" % b["stats"][0].value)
        for k, v in b["stats"].items():
           print("{}: {}".format(name[k.value], v.value))
        sleep(1)
    except KeyboardInterrupt:
        exit()
```

这个 eBPF 程序的功能是统计网络中传输的数据包数量。它通过定义一个 `BPF_HASH` 数据结构来保存统计结果（eBPF Maps），并通过捕获 `tcp_sendmsg` 事件来实现实时统计。最后，它通过每秒输出一次统计结果来展示数据。这个 eBPF 程序只是一个简单的示例，实际应用中可能需要进行更复杂的统计和分析。



第三步：运行 eBPF 程序：接下来，需要使用 eBPF 编译器将 eBPF 程序编译成内核可执行的格式（这个在上面的Python程序里你可以看到——Python引入了一个bcc的包，然后用这个包，把那段 C语言的程序编译成字节码加载在内核中并把某个函数 attach 到某个事件上）。这个过程可以使用 BPF Compiler Collection（BCC）工具来完成。BCC 工具可以通过命令行的方式将 eBPF 程序编译成内核可执行的格式，并将其加载到内核中。

下面是运行上面的 Python3 程序的步骤：

```
sudo apt install python3-bpfcc
```



```
#!/usr/bin/python3

from bcc import BPF
import time

# 定义 eBPF 程序
bpf_text = """
#include <uapi/linux/ptrace.h>
#include <net/sock.h>
#include <net/inet_sock.h>
#include <bcc/proto.h>

struct packet_t {
    u64 ts, size;
    u32 pid;
    u32 saddr, daddr;
    u16 sport, dport;
};

BPF_HASH(packets, u64, struct packet_t);

int on_send(struct pt_regs *ctx, struct sock *sk, struct msghdr *msg, size_t size)
{
    u64 id = bpf_get_current_pid_tgid();
    u32 pid = id;

    // 记录数据包的时间戳和信息
    struct packet_t pkt = {}; // 结构体一定要初始化，可以使用下面的方法
                              //__builtin_memset(&pkt, 0, sizeof(pkt)); 
    pkt.ts = bpf_ktime_get_ns();
    pkt.size = size;
    pkt.pid = pid;
    pkt.saddr = sk->__sk_common.skc_rcv_saddr;
    pkt.daddr = sk->__sk_common.skc_daddr;
    struct inet_sock *sockp = (struct inet_sock *)sk;
    pkt.sport = sockp->inet_sport;
    pkt.dport = sk->__sk_common.skc_dport;

    packets.update(&id, &pkt);
    return 0;
}

int on_recv(struct pt_regs *ctx, struct sock *sk)
{
    u64 id = bpf_get_current_pid_tgid();
    u32 pid = id;

    // 获取数据包的时间戳和编号
    struct packet_t *pkt = packets.lookup(&id);
    if (!pkt) {
        return 0;
    }

    // 计算传输时间
    u64 delta = bpf_ktime_get_ns() - pkt->ts;

    // 统计结果
    bpf_trace_printk("tcp_time: %llu.%llums, size: %llu\\n", 
       delta/1000, delta%1000%100, pkt->size);

    // 删除统计结果
    packets.delete(&id);

    return 0;
}
"""

# 编译 eBPF 程序
b = BPF(text=bpf_text, cflags=["-Wno-macro-redefined"])

# 注册 eBPF 程序
b.attach_kprobe(event="tcp_sendmsg", fn_name="on_send")
b.attach_kprobe(event="tcp_v4_do_rcv", fn_name="on_recv")

# 输出统计信息
print("Tracing TCP latency... Hit Ctrl-C to end.")
while True:
    try:
        (task, pid, cpu, flags, ts, msg) = b.trace_fields()
        print("%-18.9f %-16s %-6d %s" % (ts, task, pid, msg))
    except KeyboardInterrupt:
        exit()
```





BCC（[BPF Compiler Collection](https://github.com/iovisor/bcc)）是一套开源的工具集，可以在 Linux 系统中使用 BPF（Berkeley Packet Filter）程序进行系统级性能分析和监测。BCC 包含了许多实用工具，如：

1. bcc-tools：一个包含许多常用的 BCC 工具的软件包。
2. bpftrace：一个高级语言，用于编写和执行 BPF 程序。
3. tcptop：一个实时监控和分析 TCP 流量的工具。
4. execsnoop：一个用于监控进程执行情况的工具。
5. filetop：一个实时监控和分析文件系统流量的工具。
6. trace：一个用于跟踪和分析函数调用的工具。
7. funccount：一个用于统计函数调用次数的工具。
8. opensnoop：一个用于监控文件打开操作的工具。
9. pidstat：一个用于监控进程性能的工具。
10. profile：一个用于分析系统 CPU 使用情况的工具。

下面这张图你可能见过多次了，你可以看看他可以干多少事，内核里发生什么事一览无余。



![img](https://github.com/iovisor/bcc/raw/master/images/bcc_tracing_tools_2019.png)