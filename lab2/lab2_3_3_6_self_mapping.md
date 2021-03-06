### 自映射机制

这是扩展知识。
上一小节讲述了通过 boot_map_segment 函数建立了基于一一映射关系的页目录表项和页表项，这里的映射关系为：

virtual addr (KERNBASE\~KERNBASE+KMEMSIZE) = physical_addr
(0\~KMEMSIZE)

这样只要给出一个虚地址和一个物理地址，就可以设置相应 PDE 和 PTE，就可完成正确的映射关系。

如果我们这时需要按虚拟地址的地址顺序显示整个页目录表和页表的内容，则要查找页目录表的页目录表项内容，根据页目录表项内容找到页表的物理地址，再转换成对应的虚地址，然后访问页表的虚地址，搜索整个页表的每个页目录项。这样过程比较繁琐。

我们需要有一个简洁的方法来实现这个查找。ucore 做了一个很巧妙的地址自映射设计，把页目录表和页表放在一个连续的 4MB 虚拟地址空间中，并设置页目录表自身的虚地址<--\>物理地址映射关系。这样在已知页目录表起始虚地址的情况下，通过连续扫描这特定的 4MB 虚拟地址空间，就很容易访问每个页目录表项和页表项内容。

具体而言，ucore 是这样设计的，首先设置了一个常量（memlayout.h）：

VPT=0xFAC00000， 这个地址的二进制表示为：

1111 1010 1100 0000 0000 0000 0000 0000

高 10 位为 1111 1010
11，即 10 进制的 1003，中间 10 位为 0，低 12 位也为 0。在 pmm.c 中有两个全局初始化变量

pte_t \* const vpt = (pte_t \*)VPT;

pde_t \* const vpd = (pde_t \*)PGADDR(PDX(VPT), PDX(VPT), 0);

并在 pmm_init 函数执行了如下语句：

boot_pgdir[PDX(VPT)] = PADDR(boot_pgdir) | PTE_P | PTE_W;

这些变量和语句有何特殊含义呢？其实 vpd 变量的值就是页目录表的起始虚地址 0xFAFEB000，且它的高 10 位和中 10 位是相等的，都是 10 进制的 1003。当执行了上述语句，就确保了 vpd 变量的值就是页目录表的起始虚地址，且 vpt 是页目录表中第一个目录表项指向的页表的起始虚地址。此时描述内核虚拟空间的页目录表的虚地址为 0xFAFEB000，大小为 4KB。页表的理论连续虚拟地址空间 0xFAC00000\~0xFB000000，大小为 4MB。因为这个连续地址空间的大小为 4MB，可有 1M 个 PTE，即可映射 4GB 的地址空间。

但 ucore 实际上不会用完这么多项，在 memlayout.h 中定义了常量

```c
#define KERNBASE 0xC0000000
#define KMEMSIZE 0x38000000 // the maximum amount of physical memory
#define KERNTOP (KERNBASE + KMEMSIZE)
```

表示 ucore 只支持 896MB 的物理内存空间，这个 896MB 只是一个设定，可以根据情况改变。则最大的内核虚地址为常量

```c
#define KERNTOP (KERNBASE + KMEMSIZE)=0xF8000000
```

所以最大内核虚地址 KERNTOP 的页目录项虚地址为

```
vpd+0xF8000000/0x400000*4=0xFAFEB000+0x3E0*4=0xFAFEBF80
```

最大内核虚地址 KERNTOP 的页表项虚地址为：

```
vpt+0xF8000000/0x1000*4=0xFAC00000+0xF8000*4=0xFAFE0000
```

> 需要注意，页目录项和页表项是 4 字节对齐的。从上面的设置可以看出 KERNTOP/4M 后的值是 4 字节对齐的，所以这样算出来的页目录项和页表项地址的最后两位一定是 0。

在 pmm.c 中的函数 print_pgdir 就是基于 ucore 的页表自映射方式完成了对整个页目录表和页表的内容扫描和打印。注意，这里不会出现某个页表的虚地址与页目录表虚地址相同的情况。

print_pgdir 函数使得 ucore 具备和 qemu 的 info pg 相同的功能，即 print pgdir 能
够从内存中，将当前页表内有效数据（PTE_P）印出来。拷贝出的格式如下所示:

```
PDE(0e0)  c0000000-f8000000  38000000  urw
|-- PTE(38000) c0000000-f8000000  38000000 -rw
PDE(001)  fac00000-fb000000  00400000  -rw
|-- PTE(000e0)  faf00000-fafe0000  000e0000  urw
|-- PTE(00001)  fafeb000-fafec000  00001000  -rw
```

上面中的数字包括括号里的，都是十六进制。

主要的功能是从页表中将具备相同权限的 PDE 和 PTE
项目组织起来。比如上表中：

```
PDE(0e0) c0000000-f8000000 38000000 urw
```

• PDE(0e0)：0e0 表示 PDE 表中相邻的 224 项具有相同的权限；
• c0000000-f8000000：表示 PDE 表中,这相邻的两项所映射的线性地址的范围；
• 38000000：同样表示范围，即 f8000000 减去 c0000000 的结果；
• urw：PDE 表中所给出的权限位，u 表示用户可读，即 PTE_U，r 表示 PTE_P，w 表示用
户可写，即 PTE_W。

```
PDE(001) fac00000-fb000000 00400000 -rw
```

表示仅 1 条连续的 PDE 表项具备相同的属性。相应的，在这条表项中遍历找到 2
组 PTE 表项，输出如下:

```
|-- PTE(000e0) faf00000-fafe0000 000e0000 urw
|-- PTE(00001) fafeb000-fafec000 00001000 -rw
```

注意：

1. PTE 中输出的权限是 PTE 表中的数据给出的，并没有和 PDE
   表中权限做与运算。
2.

整个 print_pgdir 函数强调两点：第一是相同权限，第二是连续。 3.
print_pgdir 中用到了 vpt 和 vpd 两个变量。可以参
考 VPT 和 PGADDR 两个宏。

自映射机制还可方便用户态程序访问页表。因为页表是内核维护的，用户程序很难知道自己页表的映射结构。VPT
实际上在内核地址空间的，我们可以用同样的方式实现一个用户地址空间的映射（比如
pgdir[UVPT] = PADDR(pgdir) | PTE_P | PTE_U，注意，这里不能给写权限，并且
pgdir 是每个进程的 page table，不是
boot_pgdir），这样，用户程序就可以用和内核一样的 print_pgdir
函数遍历自己的页表结构了。
