### 项目组成

```
├── boot
├── kern
│ ├── debug
│ │ ├── kdebug.c
│ │ └── ……
│ ├── mm
│ │ ├── memlayout.h
│ │ ├── pmm.c
│ │ ├── pmm.h
│ │ ├── ......
│ │ ├── vmm.c
│ │ └── vmm.h
│ ├── process
│ │ ├── proc.c
│ │ ├── proc.h
│ │ └── ......
│ ├── schedule
│ │ ├── sched.c
│ │ └── ......
│ ├── sync
│ │ └── sync.h
│ ├── syscall
│ │ ├── syscall.c
│ │ └── syscall.h
│ └── trap
│ ├── trap.c
│ ├── trapentry.S
│ ├── trap.h
│ └── vectors.S
├── libs
│ ├── elf.h
│ ├── error.h
│ ├── printfmt.c
│ ├── unistd.h
│ └── ......
├── tools
│ ├── user.ld
│ └── ......
└── user
├── hello.c
├── libs
│ ├── initcode.S
│ ├── syscall.c
│ ├── syscall.h
│ └── ......
└── ......
```

相对与实验四，实验五主要增加的文件如上表红色部分所示，主要修改的文件如上表紫色部分所示。主要改动如下：

◆ kern/debug/

kdebug.c：修改：解析用户进程的符号信息表示（可不用理会）

◆ kern/mm/ （与本次实验有较大关系）

memlayout.h：修改：增加了用户虚存地址空间的图形表示和宏定义 （需仔细理解）。

pmm.[ch]：修改：添加了用于进程退出（do_exit）的内存资源回收的 page_remove_pte、unmap_range、exit_range 函数和用于创建子进程（do_fork）中拷贝父进程内存空间的 copy_range 函数，修改了 pgdir_alloc_page 函数

vmm.[ch]：修改：扩展了 mm_struct 数据结构，增加了一系列函数

- mm_map/dup_mmap/exit_mmap：设定/取消/复制/删除用户进程的合法内存空间

- copy_from_user/copy_to_user：用户内存空间内容与内核内存空间内容的相互拷贝的实现

- user_mem_check：搜索 vma 链表，检查是否是一个合法的用户空间范围

◆ kern/process/ （与本次实验有较大关系）

proc.[ch]：修改：扩展了 proc_struct 数据结构。增加或修改了一系列函数

- setup_pgdir/put_pgdir：创建并设置/释放页目录表

- copy_mm：复制用户进程的内存空间和设置相关内存管理（如页表等）信息

- do_exit：释放进程自身所占内存空间和相关内存管理（如页表等）信息所占空间，唤醒父进程，好让父进程收了自己，让调度器切换到其他进程

- load_icode：被 do_execve 调用，完成加载放在内存中的执行程序到进程空间，这涉及到对页表等的修改，分配用户栈

- do_execve：先回收自身所占用户空间，然后调用 load_icode，用新的程序覆盖内存空间，形成一个执行新程序的新进程

- do_yield：让调度器执行一次选择新进程的过程

- do_wait：父进程等待子进程，并在得到子进程的退出消息后，彻底回收子进程所占的资源（比如子进程的内核栈和进程控制块）

- do_kill：给一个进程设置 PF_EXITING 标志（“kill”信息，即要它死掉），这样在 trap 函数中，将根据此标志，让进程退出

- KERNEL_EXECVE/\_\_KERNEL_EXECVE/\_\_KERNEL_EXECVE2：被 user_main 调用，执行一用户进程

◆ kern/trap/

trap.c：修改：在 idt_init 函数中，对 IDT 初始化时，设置好了用于系统调用的中断门（idt[T\_SYSCALL]）信息。这主要与 syscall 的实现相关

◆ user/\*

新增的用户程序和用户库
