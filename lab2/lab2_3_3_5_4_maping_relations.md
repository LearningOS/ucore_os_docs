### 系统执行中地址映射的三个阶段

原理课上讲到了页映射、段映射以及段页式映射关系，但对如何建立段页式映射关系没有详说。其实，在 lab1 和 lab2 中都会涉及如何建立映射关系的操作。在 lab1 中，我们已经碰到到了简单的段映射，即对等映射关系，保证了物理地址和虚拟地址相等，也就是通过建立全局段描述符表，让每个段的基址为 0，从而确定了对等映射关系。在 lab2 中，由于在段地址映射的基础上进一步引入了页地址映射，形成了组合式的段页式地址映射。这种方式虽然更加灵活了，但实现稍微复杂了一些。在 lab2 中，为了建立正确的地址映射关系，ld 在链接阶段生成了 ucore OS 执行代码的虚拟地址，而 bootloader 与 ucore OS 协同工作，通过在运行时对地址映射的一系列“腾挪转移”，从计算机加电，启动段式管理机制，启动段页式管理机制，在段页式管理机制下运行这整个过程中，虚拟地址到物理地址的映射产生了多次变化，实现了最终的段页式映射关系：

```
 virt addr = linear addr = phy addr + 0xC0000000
```

下面，我们来看看这是如何一步一步实现的。观察一下链接脚本，即 tools/kernel.ld 文件在 lab1 和 lab2 中的区别。在 lab1 中：

```
ENTRY(kern_init)

SECTIONS {
            /* Load the kernel at this address: "." means the current address */
            . = 0x100000;

            .text : {
                       *(.text .stub .text.* .gnu.linkonce.t.*)
            }
```

这意味着在 lab1 中通过 ld 工具形成的 ucore 的起始虚拟地址从 0x100000 开始，注意：这个地址是虚拟地址。但由于 lab1 中建立的段地址映射关系为对等关系，所以 ucore 的物理地址也是从 0x100000 开始，而 ucore 的入口函数 kern_init 的起始地址。所以在 lab1 中虚拟地址、线性地址以及物理地址之间的映射关系如下：

```
 lab1: virt addr = linear addr = phy addr
```

在 lab2 中：

```
ENTRY(kern_entry)

SECTIONS {
            /* Load the kernel at this address: "." means the current address */
            . = 0xC0100000;

            .text : {
                        *(.text .stub .text.* .gnu.linkonce.t.*)
            }
```

这意味着 lab2 中通过 ld 工具形成的 ucore 的起始虚拟地址从 0xC0100000 开始，注意：这个地址也是虚拟地址。入口函数为 kern_entry 函数（在 kern/init/entry.S 中）。这与 lab1 有很大差别。但其实在 lab1 和 lab2 中，bootloader 把 ucore 都放在了起始物理地址为 0x100000 的物理内存空间。这实际上说明了 ucore 在 lab1 和 lab2 中采用的地址映射不同。lab2 在不同阶段有不同的虚拟地址、线性地址以及物理地址之间的映射关系。

也请注意，这个起始虚拟地址的变化其实并不会影响一般的跳转和函数调用，因为它们实际上是相对跳转。但是，对于绝对寻址的全局变量的引用，就需要用 REALLOC 宏进行一些运算来确保地址是正确的。注意到这一点可能有助于您理解下面几个阶段的某些代码，以及理解为什么这样做不会出错。

**第一个阶段**（开启保护模式，创建启动段表）是 bootloader 阶段，即从 bootloader 的 start 函数（在 boot/bootasm.S 中）到执行 ucore kernel 的 kern_entry 函数之前，其虚拟地址、线性地址以及物理地址之间的映射关系与 lab1 的一样，即：

```
 lab2 stage 1: virt addr = linear addr = phy addr
```

**第二个阶段**（创建初始页目录表，开启分页模式）从 kern_entry 函数开始，到 pmm_init 函数被执行之前。

编译好的 ucore 自带了一个设置好的页目录表和相应的页表，将 0~4M 的线性地址一一映射到物理地址。

了解了一一映射的二级页表结构后，接下来就要使能分页机制了，这主要是通过几条汇编指令（在 kern/init/entry.S 中）实现的，主要做了两件事：

1. 通过`movl %eax, %cr3`指令把页目录表的起始地址存入 CR3 寄存器中；
2. 通过`movl %eax, %cr0`指令把 cr0 中的 CR0_PG 标志位设置上。

执行完这几条指令后，计算机系统进入了分页模式！虚拟地址、线性地址以及物理地址之间的临时映射关系为：

```
 lab2 stage 2 before:
     virt addr = linear addr = phy addr # 线性地址在0~4MB之内三者的映射关系
     virt addr = linear addr = phy addr + 0xC0000000 # 线性地址在0xC0000000~0xC0000000+4MB之内三者的映射关系
```

可以看到，其实仅仅比第一个阶段增加了下面一行的 0xC0000000 偏移的映射，并且作用范围缩小到了 0~4M。在下一个节点，会将作用范围继续扩充到 0~KMEMSIZE。

实际上这种映射限制了内核的大小。当内核大小超过预期的 4MB （实际上是 3M，因为内核从 0x100000 开始编址）就可能导致打开分页之后内核 crash，在某些试验中，也的确出现了这种情况。解决方法同样简单，就是正确填充更多的页目录项即可。

此时的内核（EIP）还在 0~4M 的低虚拟地址区域运行，而在之后，这个区域的虚拟内存是要给用户程序使用的。为此，需要使用一个绝对跳转来使内核跳转到高虚拟地址（代码在 kern/init/entry.S 中）：

```asm
    # update eip
    # now, eip = 0x1.....
    leal next, %eax
    # set eip = KERNBASE + 0x1.....
    jmp *%eax
next:
```

跳转完毕后，通过把 boot_pgdir[0]对应的第一个页目录表项（0\~4MB）清零来取消了临时的页映射关系：

```asm
    # unmap va 0 ~ 4M, it's temporary mapping
    xorl %eax, %eax
    movl %eax, __boot_pgdir
```

最终，离开这个阶段时，虚拟地址、线性地址以及物理地址之间的映射关系为：

```
 lab2 stage 2: virt addr = linear addr = phy addr + 0xC0000000 # 线性地址在0~4MB之内三者的映射关系
```

总结来看，这一阶段的目的就是更新映射关系的同时将运行中的内核（EIP）从低虚拟地址“迁移”到高虚拟地址，而不造成伤害。

不过，这还不是我们期望的映射关系，因为它仅仅映射了 0~4MB。对于段表而言，也缺少了运行 ucore 所需的用户态段描述符和 TSS（段）描述符相应表项。

**第三个阶段**（完善段表和页表）从 pmm_init 函数被调用开始。pmm_init 函数将页目录表项补充完成（从 0~4M 扩充到 0~KMEMSIZE）。然后，更新了段映射机制，使用了一个新的段表。这个新段表除了包括内核态的代码段和数据段描述符，还包括用户态的代码段和数据段描述符以及 TSS（段）的描述符。理论上可以在第一个阶段，即 bootloader 阶段就将段表设置完全，然后在此阶段继续使用，但这会导致内核的代码和 bootloader 的代码产生过多的耦合，于是就有了目前的设计。

这时形成了我们期望的虚拟地址、线性地址以及物理地址之间的映射关系：

```
 lab2 stage 3: virt addr = linear addr = phy addr + 0xC0000000
```

段表相应表项和 TSS 也被设置妥当。
