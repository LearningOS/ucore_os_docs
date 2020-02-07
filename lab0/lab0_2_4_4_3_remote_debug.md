##### 使用远程调试

为了与 qemu 配合进行源代码级别的调试，需要先让 qemu 进入等待 gdb 调试器的接入并且还不能让 qemu 中的 CPU 执行，因此启动 qemu 的时候，我们需要使用参数-S –s 这两个参数来做到这一点。在使用了前面提到的参数启动 qemu 之后，qemu 中的 CPU 并不会马上开始执行，这时我们启动 gdb，然后在 gdb 命令行界面下，使用下面的命令连接到 qemu：

    (gdb)  target remote 127.0.0.1:1234

然后输入 c（也就是 continue）命令之后，qemu 会继续执行下去，但是 gdb 由于不知道任何符号信息，并且也没有下断点，是不能进行源码级的调试的。为了让 gdb 获知符号信息，需要指定调试目标文件，gdb 中使用 file 命令：

    (gdb)  file ./bin/kernel

之后 gdb 就会载入这个文件中的符号信息了。

通过 gdb 可以对 ucore 代码进行调试，以 lab1 中调试 memset 函数为例：

(1) 运行 `qemu -S -s -hda ./bin/ucore.img -monitor stdio`

(2) 运行 gdb 并与 qemu 进行连接

(3) 设置断点并执行

(4) qemu 单步调试。

运行过程以及结果如下：

<table>
<tr><td>窗口一</td><td>窗口二</td>
<tr>
<td>
chy@laptop: ~/lab1$ qemu -S -s -hda ./bin/ucore.img 
</td>
<td>
chy@laptop: ~/lab1$ gdb ./bin/kernel <br>
(gdb) target remote:1234 <br>
Remote debugging using :1234 <br>
0x0000fff0 in ?? () <br>
(gdb) break memset <br>
Breakpoint 1, memset (s=0xc029b000, c=0x0, n=0x1000) at libs/string.c:271 <br>
(gdb) continue <br>
Continuing. <br>
Breakpoint 1, memset (s=0xc029b000, c=0x0, n=0x1000) at libs/string.c:271 <br>
271     memset(void *s, char c, size_t n) { <br>
(gdb)
</td>
</tr></table>
