## 附录“关于 A20 Gate”

【参考“关于 A20 Gate” http://hengch.blog.163.com/blog/static/107800672009013104623747/ 】

【参考“百度文库 激活 A20 地址线详解” http://wenku.baidu.com/view/d6efe68fcc22bcd126ff0c00.html】

Intel 早期的 8086 CPU 提供了 20 根地址线,可寻址空间范围即 0~2^20(00000H~FFFFFH)的 1MB 内存空间。但 8086 的数据处理位宽位 16 位，无法直接寻址 1MB 内存空间，所以 8086 提供了段地址加偏移地址的地址转换机制。PC 机的寻址结构是 segment:offset，segment 和 offset 都是 16 位的寄存器，最大值是 0ffffh，换算成物理地址的计算方法是把 segment 左移 4 位，再加上 offset，所以 segment:offset 所能表达的寻址空间最大应为 0ffff0h + 0ffffh = 10ffefh（前面的 0ffffh 是 segment=0ffffh 并向左移动 4 位的结果，后面的 0ffffh 是可能的最大 offset），这个计算出的 10ffefh 是多大呢？大约是 1088KB，就是说，segment:offset 的地址表示能力，超过了 20 位地址线的物理寻址能力。所以当寻址到超过 1MB 的内存时，会发生“回卷”（不会发生异常）。但下一代的基于 Intel 80286 CPU 的 PC AT 计算机系统提供了 24 根地址线，这样 CPU 的寻址范围变为 2^24=16M,同时也提供了保护模式，可以访问到 1MB 以上的内存了，此时如果遇到“寻址超过 1MB”的情况，系统不会再“回卷”了，这就造成了向下不兼容。为了保持完全的向下兼容性，IBM 决定在 PC AT 计算机系统上加个硬件逻辑，来模仿以上的回绕特征，于是出现了 A20 Gate。他们的方法就是把 A20 地址线控制和键盘控制器的一个输出进行 AND 操作，这样来控制 A20 地址线的打开（使能）和关闭（屏蔽\禁止）。一开始时 A20 地址线控制是被屏蔽的（总为 0），直到系统软件通过一定的 IO 操作去打开它（参看 bootasm.S）。很显然，在实模式下要访问高端内存区，这个开关必须打开，在保护模式下，由于使用 32 位地址线，如果 A20 恒等于 0，那么系统只能访问奇数兆的内存，即只能访问 0--1M、2-3M、4-5M......，这样无法有效访问所有可用内存。所以在保护模式下，这个开关也必须打开。

在保护模式下，为了使能所有地址位的寻址能力，需要打开 A20 地址线控制，即需要通过向键盘控制器 8042 发送一个命令来完成。键盘控制器 8042 将会将它的的某个输出引脚的输出置高电平，作为 A20 地址线控制的输入。一旦设置成功之后，内存将不会再被绕回(memory wrapping)，这样我们就可以寻址整个 286 的 16M 内存，或者是寻址 80386 级别机器的所有 4G 内存了。

键盘控制器 8042 的逻辑结构图如下所示。从软件的角度来看，如何控制 8042 呢？早期的 PC 机，控制键盘有一个单独的单片机 8042，现如今这个芯片已经给集成到了其它大片子中，但其功能和使用方法还是一样，当 PC 机刚刚出现 A20 Gate 的时候，估计为节省硬件设计成本，工程师使用这个 8042 键盘控制器来控制 A20 Gate，但 A20 Gate 与键盘管理没有一点关系。下面先从软件的角度简单介绍一下 8042 这个芯片。

![键盘控制器8042的逻辑结构图](../lab1_figs/image012.png "键盘控制器8042的逻辑结构图")
图 13 键盘控制器 8042 的逻辑结构图

8042 键盘控制器的 IO 端口是 0x60 ～ 0x6f，实际上 IBM PC/AT 使用的只有 0x60 和 0x64 两个端口（0x61、0x62 和 0x63 用于与 XT 兼容目的）。8042 通过这些端口给键盘控制器或键盘发送命令或读取状态。输出端口 P2 用于特定目的。位 0（P20 引脚）用于实现 CPU 复位操作，位 1（P21 引脚）用户控制 A20 信号线的开启与否。系统向输入缓冲（端口 0x64）写入一个字节，即发送一个键盘控制器命令。可以带一个参数。参数是通过 0x60 端口发送的。 命令的返回值也从端口 0x60 去读。8042 有 4 个寄存器：

- 1 个 8-bit 长的 Input buffer；Write-Only；
- 1 个 8-bit 长的 Output buffer； Read-Only；
- 1 个 8-bit 长的 Status Register；Read-Only；
- 1 个 8-bit 长的 Control Register；Read/Write。

有两个端口地址：60h 和 64h，有关对它们的读写操作描述如下：

- 读 60h 端口，读 output buffer
- 写 60h 端口，写 input buffer
- 读 64h 端口，读 Status Register
- 操作 Control Register，首先要向 64h 端口写一个命令（20h 为读命令，60h 为写命令），然后根据命令从 60h 端口读出 Control Register 的数据或者向 60h 端口写入 Control Register 的数据（64h 端口还可以接受许多其它的命令）。

Status Register 的定义（要用 bit 0 和 bit 1）：

<table>
<tr><td>bit</td><td>meaning</td></tr>
<tr><td>0</td><td>output register (60h) 中有数据</td></tr>
<tr><td>1</td><td>input register (60h/64h) 有数据</td></tr>
<tr><td>2</td><td>系统标志（上电复位后被置为0）</td></tr>
<tr><td>3</td><td>data in input register is command (1) or data (0)</td></tr>
<tr><td>4</td><td>1=keyboard enabled, 0=keyboard disabled (via switch)</td></tr>
<tr><td>5</td><td>1=transmit timeout (data transmit not complete)</td></tr>
<tr><td>6</td><td>1=receive timeout (data transmit not complete)</td></tr>
<tr><td>7</td><td>1=even parity rec'd, 0=odd parity rec'd (should be odd)</td></tr>
</table>

除了这些资源外，8042 还有 3 个内部端口：Input Port、Outport Port 和 Test Port，这三个端口的操作都是通过向 64h 发送命令，然后在 60h 进行读写的方式完成，其中本文要操作的 A20 Gate 被定义在 Output Port 的 bit 1 上，所以有必要对 Outport Port 的操作及端口定义做一个说明。

- 读 Output Port：向 64h 发送 0d0h 命令，然后从 60h 读取 Output Port 的内容
- 写 Output Port：向 64h 发送 0d1h 命令，然后向 60h 写入 Output Port 的数据
- 禁止键盘操作命令：向 64h 发送 0adh
- 打开键盘操作命令：向 64h 发送 0aeh

有了这些命令和知识，就可以实现操作 A20 Gate 来从实模式切换到保护模式了。
理论上讲，我们只要操作 8042 芯片的输出端口（64h）的 bit 1，就可以控制 A20 Gate，但实际上，当你准备向 8042 的输入缓冲区里写数据时，可能里面还有其它数据没有处理，所以，我们要首先禁止键盘操作，同时等待数据缓冲区中没有数据以后，才能真正地去操作 8042 打开或者关闭 A20 Gate。打开 A20 Gate 的具体步骤大致如下（参考 bootasm.S）：

1. 等待 8042 Input buffer 为空；
2. 发送 Write 8042 Output Port （P2）命令到 8042 Input buffer；
3. 等待 8042 Input buffer 为空；
4. 将 8042 Output Port（P2）得到字节的第 2 位置 1，然后写入 8042 Input buffer；
