**链接地址/虚地址/物理地址/加载地址以及 edata/end/text 的含义**

**链接脚本简介**

ucore
kernel 各个部分由组成 kernel 的各个.o 或.a 文件构成，且各个部分在内存中地址位置由 ld 工具根据 kernel.ld 链接脚本（linker
script）来设定。ld 工具使用命令-T 指定链接脚本。链接脚本主要用于规定如何把输入文件（各个.o 或.a 文件）内的 section 放入输出文件（lab2/bin/kernel，即 ELF 格式的 ucore 内核）内，
并控制输出文件内各部分在程序地址空间内的布局。下面简单分析一下/lab2/tools/kernel.ld，来了解一下 ucore 内核的地址布局情况。kernel.ld 的内容如下所示：

```
/* Simple linker script for the ucore kernel.
   See the GNU ld 'info' manual ("info ld") to learn the syntax. */

OUTPUT_FORMAT("elf32-i386", "elf32-i386", "elf32-i386")
OUTPUT_ARCH(i386)
ENTRY(kern_entry)

SECTIONS {
    /* Load the kernel at this address: "." means the current address */
    . = 0xC0100000;

    .text : {
        *(.text .stub .text.* .gnu.linkonce.t.*)
    }

    PROVIDE(etext = .); /* Define the 'etext' symbol to this value */

    .rodata : {
        *(.rodata .rodata.* .gnu.linkonce.r.*)
    }

    /* Include debugging information in kernel memory */
    .stab : {
        PROVIDE(__STAB_BEGIN__ = .);
        *(.stab);
        PROVIDE(__STAB_END__ = .);
        BYTE(0)     /* Force the linker to allocate space
                   for this section */
    }

    .stabstr : {
        PROVIDE(__STABSTR_BEGIN__ = .);
        *(.stabstr);
        PROVIDE(__STABSTR_END__ = .);
        BYTE(0)     /* Force the linker to allocate space
                   for this section */
    }

    /* Adjust the address for the data segment to the next page */
    . = ALIGN(0x1000);

    /* The data segment */
    .data : {
        *(.data)
    }

    PROVIDE(edata = .);

    .bss : {
        *(.bss)
    }

    PROVIDE(end = .);

    /DISCARD/ : {
        *(.eh_frame .note.GNU-stack)
    }
}
```

其实从链接脚本的内容，可以大致猜出它指定告诉链接器的各种信息：

- 内核加载地址：0xC0100000
- 入口（起始代码）地址： ENTRY(kern_entry)
- cpu 机器类型：i386

其最主要的信息是告诉链接器各输入文件的各 section 应该怎么组合：应该从哪个地址开始放，各个 section 以什么顺序放，分别怎么对齐等等，最终组成输出文件的各 section。除此之外，linker
script 还可以定义各种符号（如.text、.data、.bss 等），形成最终生成的一堆符号的列表（符号表），每个符号包含了符号名字，符号所引用的内存地址，以及其他一些属性信息。符号实际上就是一个地址的符号表示，其本身不占用的程序运行的内存空间。

**链接地址/加载地址/虚地址/物理地址**

ucore 设定了 ucore 运行中的虚地址空间，具体设置可看
lab2/kern/mm/memlayout.h 中描述的"Virtual memory map
"图，可以了解虚地址和物理地址的对应关系。lab2/tools/kernel.ld 描述的是执行代码的链接地址（link_addr），比如内核起始地址是 0xC0100000，这是一个虚地址。所以我们可以认为链接地址等于虚地址。在 ucore 建立内核页表时，设定了物理地址和虚地址的虚实映射关系是：

phy addr + 0xC0000000 = virtual addr

即虚地址和物理地址之间有一个偏移。但 boot loader 把 ucore
kernel 加载到内存时，采用的是加载地址（load
addr），这是由于 ucore 还没有运行，即还没有启动页表映射，导致这时采用的寻址方式是段寻址方式，用的是 boot
loader 在初始化阶段设置的段映射关系，其映射关系（可参看 bootasm.S 的末尾处有关段描述符表的内容）是：

linear addr = phy addr = virtual addr

查看 bootloader 的实现代码 bootmain::bootmain.c

readseg(ph-\>p_va & 0xFFFFFF, ph-\>p_memsz, ph-\>p_offset);

这里的 ph-\>p_va=0xC0XXXXXX，就是 ld 工具根据 kernel.ld 设置的链接地址，且链接地址等于虚地址。考虑到 ph-\>p_va
& 0xFFFFFF == 0x0XXXXXX，所以 bootloader 加载 ucore
kernel 的加载地址是 0x0XXXXXX, 这实际上是 ucore 内核所在的物理地址。简言之：
OS 的链接地址（link addr） 在 tools/kernel.ld 中设置好了，是一个虚地址（virtual
addr）；而 ucore kernel 的加载地址（load addr）在 boot
loader 中的 bootmain 函数中指定，是一个物理地址。

小结一下，ucore 内核的链接地址==ucore 内核的虚拟地址；boot
loader 加载 ucore 内核用到的加载地址==ucore 内核的物理地址。

**edata/end/text 的含义**

在基于 ELF 执行文件格式的代码中，存在一些对代码和数据的表述，基本概念如下：

- BSS 段（bss
  segment）：指用来存放程序中未初始化的全局变量的内存区域。BSS 是英文 Block
  Started by Symbol 的简称。BSS 段属于静态内存分配。
- 数据段（data
  segment）：指用来存放程序中已初始化的全局变量的一块内存区域。数据段属于静态内存分配。
- 代码段（code segment/text
  segment）：指用来存放程序执行代码的一块内存区域。这部分区域的大小在程序运行前就已经确定，并且内存区域通常属于只读,
  某些架构也允许代码段为可写，即允许修改程序。在代码段中，也有可能包含一些只读的常数变量，例如字符串常量等。

在 lab2/kern/init/init.c 的 kern_init 函数中，声明了外部全局变量：

```c
extern char edata[], end[];
```

但搜寻所有源码文件\*.[ch]，没有发现有这两个变量的定义。那这两个变量从哪里来的呢？其实在 lab2/tools/kernel.ld 中，可以看到如下内容：

```
…
.text : {
        *(.text .stub .text.* .gnu.linkonce.t.*)
}
…
    .data : {
        *(.data)
}
…
PROVIDE(edata = .);
…
    .bss : {
        *(.bss)
}
…
PROVIDE(end = .);
…
```

这里的“.”表示当前地址，“.text”表示代码段起始地址，“.data”也是一个地址，可以看出，它即代表了代码段的结束地址，也是数据段的起始地址。类推下去，“edata”表示数据段的结束地址，“.bss”表示数据段的结束地址和 BSS 段的起始地址，而“end”表示 BSS 段的结束地址。

这样回头看 kerne_init 中的外部全局变量，可知 edata[]和
end[]这些变量是 ld 根据 kernel.ld 链接脚本生成的全局变量，表示相应段的起始地址或结束地址等，它们不在任何一个.S、.c 或.h 文件中定义。
