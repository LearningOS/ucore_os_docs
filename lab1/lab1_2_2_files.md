### 项目组成

lab1 的整体目录结构如下所示：

```
.
├── boot
│   ├── asm.h
│   ├── bootasm.S
│   └── bootmain.c
├── kern
│   ├── debug
│   │   ├── assert.h
│   │   ├── kdebug.c
│   │   ├── kdebug.h
│   │   ├── kmonitor.c
│   │   ├── kmonitor.h
│   │   ├── panic.c
│   │   └── stab.h
│   ├── driver
│   │   ├── clock.c
│   │   ├── clock.h
│   │   ├── console.c
│   │   ├── console.h
│   │   ├── intr.c
│   │   ├── intr.h
│   │   ├── kbdreg.h
│   │   ├── picirq.c
│   │   └── picirq.h
│   ├── init
│   │   └── init.c
│   ├── libs
│   │   ├── readline.c
│   │   └── stdio.c
│   ├── mm
│   │   ├── memlayout.h
│   │   ├── mmu.h
│   │   ├── pmm.c
│   │   └── pmm.h
│   └── trap
│       ├── trap.c
│       ├── trapentry.S
│       ├── trap.h
│       └── vectors.S
├── libs
│   ├── defs.h
│   ├── elf.h
│   ├── error.h
│   ├── printfmt.c
│   ├── stdarg.h
│   ├── stdio.h
│   ├── string.c
│   ├── string.h
│   └── x86.h
├── Makefile
└── tools
    ├── function.mk
    ├── gdbinit
    ├── grade.sh
    ├── kernel.ld
    ├── sign.c
    └── vector.c

10 directories, 48 files
```

其中一些比较重要的文件说明如下：

**_bootloader 部分_**

- boot/bootasm.S ：定义并实现了 bootloader 最先执行的函数 start，此函数进行了一定的初始化，完成了从实模式到保护模式的转换，并调用 bootmain.c 中的 bootmain 函数。
- boot/bootmain.c：定义并实现了 bootmain 函数实现了通过屏幕、串口和并口显示字符串。bootmain 函数加载 ucore 操作系统到内存，然后跳转到 ucore 的入口处执行。
- boot/asm.h：是 bootasm.S 汇编文件所需要的头文件，主要是一些与 X86 保护模式的段访问方式相关的宏定义。

**_ucore 操作系统部分_**

系统初始化部分：

- kern/init/init.c：ucore 操作系统的初始化启动代码

内存管理部分：

- kern/mm/memlayout.h：ucore 操作系统有关段管理（段描述符编号、段号等）的一些宏定义
- kern/mm/mmu.h：ucore 操作系统有关 X86 MMU 等硬件相关的定义，包括 EFLAGS 寄存器中各位的含义，应用/系统段类型，中断门描述符定义，段描述符定义，任务状态段定义，NULL 段声明的宏 SEG_NULL, 特定段声明的宏 SEG，设置中
  断门描述符的宏 SETGATE（在练习 6 中会用到）
- kern/mm/pmm.[ch]：设定了 ucore 操作系统在段机制中要用到的全局变量：任务状态段 ts，全局描述符表 gdt[]，加载全局描述符表寄存器的函数 lgdt，临时的内核栈 stack0；以及对全局描述符表和任务状态段的初始化函数 gdt_init

外设驱动部分：

- kern/driver/intr.[ch]：实现了通过设置 CPU 的 eflags 来屏蔽和使能中断的函数；
- kern/driver/picirq.[ch]：实现了对中断控制器 8259A 的初始化和使能操作；
- kern/driver/clock.[ch]：实现了对时钟控制器 8253 的初始化操作；- kern/driver/console.[ch]：实现了对串口和键盘的中断方式的处理操作；

中断处理部分：

- kern/trap/vectors.S：包括 256 个中断服务例程的入口地址和第一步初步处理实现。注意，此文件是由 tools/vector.c 在编译 ucore 期间动态生成的；
- kern/trap/trapentry.S：紧接着第一步初步处理后，进一步完成第二步初步处理；并且有恢复中断上下文的处理，即中断处理完毕后的返回准备工作；
- kern/trap/trap.[ch]：紧接着第二步初步处理后，继续完成具体的各种中断处理操作；

内核调试部分：

- kern/debug/kdebug.[ch]：提供源码和二进制对应关系的查询功能，用于显示调用栈关系。其中补全 print_stackframe 函数是需要完成的练习。其他实现部分不必深究。
- kern/debug/kmonitor.[ch]：实现提供动态分析命令的 kernel monitor，便于在 ucore 出现 bug 或问题后，能够进入 kernel monitor 中，查看当前调用关系。实现部分不必深究。
- kern/debug/panic.c | assert.h：提供了 panic 函数和 assert 宏，便于在发现错误后，调用 kernel monitor。大家可在编程实验中充分利用 assert 宏和 panic 函数，提高查找错误的效率。

**_公共库部分_**

- libs/defs.h：包含一些无符号整型的缩写定义。
- Libs/x86.h：一些用 GNU C 嵌入式汇编实现的 C 函数（由于使用了 inline 关键字，所以可以理解为宏）。

**_工具部分_**

- Makefile 和 function.mk：指导 make 完成整个软件项目的编译，清除等工作。
- sign.c：一个 C 语言小程序，是辅助工具，用于生成一个符合规范的硬盘主引导扇区。
- tools/vector.c：生成 vectors.S，此文件包含了中断向量处理的统一实现。

编译方法

首先下载 lab1.tar.bz2，然后解压 lab1.tar.bz2。在 lab1 目录下执行 make，可以生成 ucore.img（生成于 bin 目录下）。ucore.img 是一个包含了 bootloader 或 OS 的硬盘镜像，通过执行如下命令可在硬件虚拟环境 qemu 中运行 bootloader 或 OS：

```
	$ make qemu
```

则可以得到如下显示界面（仅供参考）

```
(THU.CST) os is loading ...

Special kernel symbols:
 entry  0x00100000 (phys)
 etext  0x00103468 (phys)
 edata  0x0010ea18 (phys)
 end    0x0010fd80 (phys)
Kernel executable memory footprint: 64KB
ebp:0x00007b38 eip:0x00100a55 args:0x00010094 0x00010094 0x00007b68 0x00100084
   kern/debug/kdebug.c:305: print_stackframe+21
ebp:0x00007b48 eip:0x00100d3a args:0x00000000 0x00000000 0x00000000 0x00007bb8
   kern/debug/kmonitor.c:125: mon_backtrace+10
ebp:0x00007b68 eip:0x00100084 args:0x00000000 0x00007b90 0xffff0000 0x00007b94
   kern/init/init.c:48: grade_backtrace2+19
ebp:0x00007b88 eip:0x001000a5 args:0x00000000 0xffff0000 0x00007bb4 0x00000029
   kern/init/init.c:53: grade_backtrace1+27
ebp:0x00007ba8 eip:0x001000c1 args:0x00000000 0x00100000 0xffff0000 0x00100043
   kern/init/init.c:58: grade_backtrace0+19
ebp:0x00007bc8 eip:0x001000e1 args:0x00000000 0x00000000 0x00000000 0x00103480
   kern/init/init.c:63: grade_backtrace+26
ebp:0x00007be8 eip:0x00100050 args:0x00000000 0x00000000 0x00000000 0x00007c4f
   kern/init/init.c:28: kern_init+79
ebp:0x00007bf8 eip:0x00007d61 args:0xc031fcfa 0xc08ed88e 0x64e4d08e 0xfa7502a8
   <unknow>: -- 0x00007d60 --
++ setup timer interrupts
0: @ring 0
0:  cs = 8
0:  ds = 10
0:  es = 10
0:  ss = 10
+++ switch to  user  mode +++
1: @ring 3
1:  cs = 1b
1:  ds = 23
1:  es = 23
1:  ss = 23
+++ switch to kernel mode +++
2: @ring 0
2:  cs = 8
2:  ds = 10
2:  es = 10
2:  ss = 10
100 ticks
100 ticks
100 ticks
100 ticks
```
