### 创建用户进程

在实验四中，我们已经完成了对内核线程的创建，但与用户进程的创建过程相比，创建内核线程的过程还远远不够。而这两个创建过程的差异本质上就是用户进程和内核线程的差异决定的。

#### 1. 应用程序的组成和编译

我们首先来看一个应用程序，这里我们假定是 hello 应用程序，在 user/hello.c 中实现，代码如下：

```
#include <stdio.h>
#include <ulib.h>

int main(void) {
    cprintf("Hello world!!.\n");
    cprintf("I am process %d.\n", getpid());
    cprintf("hello pass.\n");
    return 0;
}
```

hello 应用程序只是输出一些字符串，并通过系统调用 sys_getpid（在 getpid 函数中调用）输出代表 hello 应用程序执行的用户进程的进程标识--pid。

首先，我们需要了解 ucore 操作系统如何能够找到 hello 应用程序。这需要分析 ucore 和 hello 是如何编译的。修改 Makefile，把第六行注释掉。然后在本实验源码目录下执行 make，可得到如下输出：

```
……
+ cc user/hello.c

gcc -Iuser/ -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Ilibs/ -Iuser/include/ -Iuser/libs/ -c user/hello.c -o obj/user/hello.o

ld -m    elf_i386 -nostdlib -T tools/user.ld -o obj/__user_hello.out  obj/user/libs/initcode.o obj/user/libs/panic.o obj/user/libs/stdio.o obj/user/libs/syscall.o obj/user/libs/ulib.o obj/user/libs/umain.o  obj/libs/hash.o obj/libs/printfmt.o obj/libs/rand.o obj/libs/string.o obj/user/hello.o
……
ld -m    elf_i386 -nostdlib -T tools/kernel.ld -o bin/kernel  obj/kern/init/entry.o obj/kern/init/init.o …… -b binary …… obj/__user_hello.out
……
```

从中可以看出，hello 应用程序不仅仅是 hello.c，还包含了支持 hello 应用程序的用户态库：

- user/libs/initcode.S：所有应用程序的起始用户态执行地址“\_start”，调整了 EBP 和 ESP 后，调用 umain 函数。
- user/libs/umain.c：实现了 umain 函数，这是所有应用程序执行的第一个 C 函数，它将调用应用程序的 main 函数，并在 main 函数结束后调用 exit 函数，而 exit 函数最终将调用 sys_exit 系统调用，让操作系统回收进程资源。
- user/libs/ulib.[ch]：实现了最小的 C 函数库，除了一些与系统调用无关的函数，其他函数是对访问系统调用的包装。
- user/libs/syscall.[ch]：用户层发出系统调用的具体实现。
- user/libs/stdio.c：实现 cprintf 函数，通过系统调用 sys_putc 来完成字符输出。
- user/libs/panic.c：实现\_\_panic/\_\_warn 函数，通过系统调用 sys_exit 完成用户进程退出。

除了这些用户态库函数实现外，还有一些 libs/\*.[ch]是操作系统内核和应用程序共用的函数实现。这些用户库函数其实在本质上与 UNIX 系统中的标准 libc 没有区别，只是实现得很简单，但 hello 应用程序的正确执行离不开这些库函数。

【注意】libs/\*.[ch]、user/libs/\*.[ch]、user/\*.[ch]的源码中没有任何特权指令。

在 make 的最后一步执行了一个 ld 命令，把 hello 应用程序的执行码 obj/\_\_user_hello.out 连接在了 ucore kernel 的末尾。且 ld 命令会在 kernel 中会把\_\_user_hello.out 的位置和大小记录在全局变量\_binary_obj\_\_\_user_hello_out_start 和\_binary_obj\_\_\_user_hello_out_size 中，这样这个 hello 用户程序就能够和 ucore 内核一起被 bootloader 加载到内存里中，并且通过这两个全局变量定位 hello 用户程序执行码的起始位置和大小。而到了与文件系统相关的实验后，ucore 会提供一个简单的文件系统，那时所有的用户程序就都不再用这种方法进行加载了，而可以用大家熟悉的文件方式进行加载了。

#### 2. 用户进程的虚拟地址空间

在 tools/user.ld 描述了用户程序的用户虚拟空间的执行入口虚拟地址：

```
SECTIONS {
    /* Load programs at this address: "." means the current address */
    . = 0x800020;
```

在 tools/kernel.ld 描述了操作系统的内核虚拟空间的起始入口虚拟地址：

```
SECTIONS {
    /* Load the kernel at this address: "." means the current address */
    . = 0xC0100000;
```

这样 ucore 把用户进程的虚拟地址空间分了两块，一块与内核线程一样，是所有用户进程都共享的内核虚拟地址空间，映射到同样的物理内存空间中，这样在物理内存中只需放置一份内核代码，使得用户进程从用户态进入核心态时，内核代码可以统一应对不同的内核程序；另外一块是用户虚拟地址空间，虽然虚拟地址范围一样，但映射到不同且没有交集的物理内存空间中。这样当 ucore 把用户进程的执行代码（即应用程序的执行代码）和数据（即应用程序的全局变量等）放到用户虚拟地址空间中时，确保了各个进程不会“非法”访问到其他进程的物理内存空间。

这样 ucore 给一个用户进程具体设定的虚拟内存空间（kern/mm/memlayout.h）如下所示：

![image](../lab5_figs/image001.png)

#### 3. 创建并执行用户进程

在确定了用户进程的执行代码和数据，以及用户进程的虚拟空间布局后，我们可以来创建用户进程了。在本实验中第一个用户进程是由第二个内核线程 initproc 通过把 hello 应用程序执行码覆盖到 initproc 的用户虚拟内存空间来创建的，相关代码如下所示：

```
    // kernel_execve - do SYS_exec syscall to exec a user program called by user_main kernel_thread
    static int
    kernel_execve(const char *name, unsigned char *binary, size_t size) {
    int ret, len = strlen(name);
    asm volatile (
        "int %1;"
        : "=a" (ret)
        : "i" (T_SYSCALL), "0" (SYS_exec), "d" (name), "c" (len), "b" (binary), "D" (size)
        : "memory");
    return ret;
   }

    #define __KERNEL_EXECVE(name, binary, size) ({                          \
            cprintf("kernel_execve: pid = %d, name = \"%s\".\n",        \
                    current->pid, name);                                \
            kernel_execve(name, binary, (size_t)(size));                \
        })

    #define KERNEL_EXECVE(x) ({                                             \
            extern unsigned char _binary_obj___user_##x##_out_start[],  \
                _binary_obj___user_##x##_out_size[];                    \
            __KERNEL_EXECVE(#x, _binary_obj___user_##x##_out_start,     \
                            _binary_obj___user_##x##_out_size);         \
        })
……
// init_main - the second kernel thread used to create kswapd_main & user_main kernel threads
static int
init_main(void *arg) {
    #ifdef TEST
    KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE);
    #else
    KERNEL_EXECVE(hello);
    #endif
    panic("kernel_execve failed.\n");
    return 0;
}
```

对于上述代码，我们需要从后向前按照函数/宏的实现一个一个来分析。Initproc 的执行主体是 init_main 函数，这个函数在缺省情况下是执行宏 KERNEL_EXECVE(hello)，而这个宏最终是调用 kernel_execve 函数来调用 SYS_exec 系统调用，由于 ld 在链接 hello 应用程序执行码时定义了两全局变量：

- \_binary_obj\_\_\_user_hello_out_start：hello 执行码的起始位置
- \_binary_obj\_\_\_user_hello_out_size 中：hello 执行码的大小

kernel_execve 把这两个变量作为 SYS_exec 系统调用的参数，让 ucore 来创建此用户进程。当 ucore 收到此系统调用后，将依次调用如下函数

```
vector128(vectors.S)--\>
\_\_alltraps(trapentry.S)--\>trap(trap.c)--\>trap\_dispatch(trap.c)--
--\>syscall(syscall.c)--\>sys\_exec（syscall.c）--\>do\_execve(proc.c)
```

最终通过 do_execve 函数来完成用户进程的创建工作。此函数的主要工作流程如下：

- 首先为加载新的执行码做好用户态内存空间清空准备。如果 mm 不为 NULL，则设置页表为内核空间页表，且进一步判断 mm 的引用计数减 1 后是否为 0，如果为 0，则表明没有进程再需要此进程所占用的内存空间，为此将根据 mm 中的记录，释放进程所占用户空间内存和进程页表本身所占空间。最后把当前进程的 mm 内存管理指针为空。由于此处的 initproc 是内核线程，所以 mm 为 NULL，整个处理都不会做。

- 接下来的一步是加载应用程序执行码到当前进程的新创建的用户态虚拟空间中。这里涉及到读 ELF 格式的文件，申请内存空间，建立用户态虚存空间，加载应用程序执行码等。load_icode 函数完成了整个复杂的工作。

load_icode 函数的主要工作就是给用户进程建立一个能够让用户进程正常运行的用户环境。此函数有一百多行，完成了如下重要工作：

1. 调用 mm_create 函数来申请进程的内存管理数据结构 mm 所需内存空间，并对 mm 进行初始化；

2. 调用 setup_pgdir 来申请一个页目录表所需的一个页大小的内存空间，并把描述 ucore 内核虚空间映射的内核页表（boot_pgdir 所指）的内容拷贝到此新目录表中，最后让 mm-\>pgdir 指向此页目录表，这就是进程新的页目录表了，且能够正确映射内核虚空间；

3. 根据应用程序执行码的起始位置来解析此 ELF 格式的执行程序，并调用 mm_map 函数根据 ELF 格式的执行程序说明的各个段（代码段、数据段、BSS 段等）的起始位置和大小建立对应的 vma 结构，并把 vma 插入到 mm 结构中，从而表明了用户进程的合法用户态虚拟地址空间；

4. 调用根据执行程序各个段的大小分配物理内存空间，并根据执行程序各个段的起始位置确定虚拟地址，并在页表中建立好物理地址和虚拟地址的映射关系，然后把执行程序各个段的内容拷贝到相应的内核虚拟地址中，至此应用程序执行码和数据已经根据编译时设定地址放置到虚拟内存中了；

5. 需要给用户进程设置用户栈，为此调用 mm_mmap 函数建立用户栈的 vma 结构，明确用户栈的位置在用户虚空间的顶端，大小为 256 个页，即 1MB，并分配一定数量的物理内存且建立好栈的虚地址<--\>物理地址映射关系；

6. 至此,进程内的内存管理 vma 和 mm 数据结构已经建立完成，于是把 mm-\>pgdir 赋值到 cr3 寄存器中，即更新了用户进程的虚拟内存空间，此时的 initproc 已经被 hello 的代码和数据覆盖，成为了第一个用户进程，但此时这个用户进程的执行现场还没建立好；

7. 先清空进程的中断帧，再重新设置进程的中断帧，使得在执行中断返回指令“iret”后，能够让 CPU 转到用户态特权级，并回到用户态内存空间，使用用户态的代码段、数据段和堆栈，且能够跳转到用户进程的第一条指令执行，并确保在用户态能够响应中断；

至此，用户进程的用户环境已经搭建完毕。此时 initproc 将按产生系统调用的函数调用路径原路返回，执行中断返回指令“iret”（位于 trapentry.S 的最后一句）后，将切换到用户进程 hello 的第一条语句位置\_start 处（位于 user/libs/initcode.S 的第三句）开始执行。
