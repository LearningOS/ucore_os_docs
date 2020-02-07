#### 创建第 0 个内核线程 idleproc

在 init.c::kern_init 函数调用了 proc.c::proc_init 函数。proc_init 函数启动了创建内核线程的步骤。首先当前的执行上下文（从 kern_init 启动至今）就可以看成是 uCore 内核（也可看做是内核进程）中的一个内核线程的上下文。为此，uCore 通过给当前执行的上下文分配一个进程控制块以及对它进行相应初始化，将其打造成第 0 个内核线程 -- idleproc。具体步骤如下：

首先调用 alloc_proc 函数来通过 kmalloc 函数获得 proc_struct 结构的一块内存块-，作为第 0 个进程控制块。并把 proc 进行初步初始化（即把 proc_struct 中的各个成员变量清零）。但有些成员变量设置了特殊的值，比如：

```
 proc->state = PROC_UNINIT;  设置进程为“初始”态
 proc->pid = -1;             设置进程pid的未初始化值
 proc->cr3 = boot_cr3;       使用内核页目录表的基址
 ...
```

上述三条语句中,第一条设置了进程的状态为“初始”态，这表示进程已经
“出生”了，正在获取资源茁壮成长中；第二条语句设置了进程的 pid 为-1，这表示进程的“身份证号”还没有办好；第三条语句表明由于该内核线程在内核中运行，故采用为 uCore 内核已经建立的页表，即设置为在 uCore 内核页表的起始地址 boot_cr3。后续实验中可进一步看出所有内核线程的内核虚地址空间（也包括物理地址空间）是相同的。既然内核线程共用一个映射内核空间的页表，这表示内核空间对所有内核线程都是“可见”的，所以更精确地说，这些内核线程都应该是从属于同一个唯一的“大内核进程”—uCore 内核。

接下来，proc_init 函数对 idleproc 内核线程进行进一步初始化：

```
idleproc->pid = 0;
idleproc->state = PROC_RUNNABLE;
idleproc->kstack = (uintptr_t)bootstack;
idleproc->need_resched = 1;
set_proc_name(idleproc, "idle");
```

需要注意前 4 条语句。第一条语句给了 idleproc 合法的身份证号--0，这名正言顺地表明了 idleproc 是第 0 个内核线程。通常可以通过 pid 的赋值来表示线程的创建和身份确定。“0”是第一个的表示方法是计算机领域所特有的，比如 C 语言定义的第一个数组元素的小标也是“0”。第二条语句改变了 idleproc 的状态，使得它从“出生”转到了“准备工作”，就差 uCore 调度它执行了。第三条语句设置了 idleproc 所使用的内核栈的起始地址。需要注意以后的其他线程的内核栈都需要通过分配获得，因为 uCore 启动时设置的内核栈直接分配给 idleproc 使用了。第四条很重要，因为 uCore 希望当前 CPU 应该做更有用的工作，而不是运行 idleproc 这个“无所事事”的内核线程，所以把 idleproc-\>need_resched 设置为“1”，结合 idleproc 的执行主体--cpu_idle 函数的实现，可以清楚看出如果当前 idleproc 在执行，则只要此标志为 1，马上就调用 schedule 函数要求调度器切换其他进程执行。
