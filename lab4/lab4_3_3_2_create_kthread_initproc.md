#### 创建第 1 个内核线程 initproc

第 0 个内核线程主要工作是完成内核中各个子系统的初始化，然后就通过执行 cpu_idle 函数开始过退休生活了。所以 uCore 接下来还需创建其他进程来完成各种工作，但 idleproc 内核子线程自己不想做，于是就通过调用 kernel_thread 函数创建了一个内核线程 init_main。在实验四中，这个子内核线程的工作就是输出一些字符串，然后就返回了（参看 init_main 函数）。但在后续的实验中，init_main 的工作就是创建特定的其他内核线程或用户进程（实验五涉及）。下面我们来分析一下创建内核线程的函数 kernel_thread：

```
kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags)
{
	struct trapframe tf;
	memset(&tf, 0, sizeof(struct trapframe));
	tf.tf_cs = KERNEL_CS;
	tf.tf_ds = tf_struct.tf_es = tf_struct.tf_ss = KERNEL_DS;
	tf.tf_regs.reg_ebx = (uint32_t)fn;
	tf.tf_regs.reg_edx = (uint32_t)arg;
	tf.tf_eip = (uint32_t)kernel_thread_entry;
	return do_fork(clone_flags | CLONE_VM, 0, &tf);
}
```

注意，kernel_thread 函数采用了局部变量 tf 来放置保存内核线程的临时中断帧，并把中断帧的指针传递给 do_fork 函数，而 do_fork 函数会调用 copy_thread 函数来在新创建的进程内核栈上专门给进程的中断帧分配一块空间。

给中断帧分配完空间后，就需要构造新进程的中断帧，具体过程是：首先给 tf 进行清零初始化，并设置中断帧的代码段（tf.tf_cs）和数据段(tf.tf_ds/tf_es/tf_ss)为内核空间的段（KERNEL_CS/KERNEL_DS），这实际上也说明了 initproc 内核线程在内核空间中执行。而 initproc 内核线程从哪里开始执行呢？tf.tf_eip 的指出了是 kernel_thread_entry（位于 kern/process/entry.S 中），kernel_thread_entry 是 entry.S 中实现的汇编函数，它做的事情很简单：

```
kernel_thread_entry: # void kernel_thread(void)
pushl %edx # push arg
call *%ebx # call fn
pushl %eax # save the return value of fn(arg)
call do_exit # call do_exit to terminate current thread
```

从上可以看出，kernel_thread_entry 函数主要为内核线程的主体 fn 函数做了一个准备开始和结束运行的“壳”，并把函数 fn 的参数 arg（保存在 edx 寄存器中）压栈，然后调用 fn 函数，把函数返回值 eax 寄存器内容压栈，调用 do_exit 函数退出线程执行。

do_fork 是创建线程的主要函数。kernel_thread 函数通过调用 do_fork 函数最终完成了内核线程的创建工作。下面我们来分析一下 do_fork 函数的实现（练习 2）。do_fork 函数主要做了以下 6 件事情：

1. 分配并初始化进程控制块（alloc_proc 函数）；
2. 分配并初始化内核栈（setup_stack 函数）；
3. 根据 clone_flag 标志复制或共享进程内存管理结构（copy_mm 函数）；
4. 设置进程在内核（将来也包括用户态）正常运行和调度所需的中断帧和执行上下文（copy_thread 函数）；
5. 把设置好的进程控制块放入 hash_list 和 proc_list 两个全局进程链表中；
6. 自此，进程已经准备好执行了，把进程状态设置为“就绪”态；
7. 设置返回码为子进程的 id 号。

这里需要注意的是，如果上述前 3 步执行没有成功，则需要做对应的出错处理，把相关已经占有的内存释放掉。copy_mm 函数目前只是把 current-\>mm 设置为 NULL，这是由于目前在实验四中只能创建内核线程，proc-\>mm 描述的是进程用户态空间的情况，所以目前 mm 还用不上。copy_thread 函数做的事情比较多，代码如下：

```
static void
copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf) {
	//在内核堆栈的顶部设置中断帧大小的一块栈空间
	proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE) - 1;
	*(proc->tf) = *tf; //拷贝在kernel_thread函数建立的临时中断帧的初始值
	proc->tf->tf_regs.reg_eax = 0;
	//设置子进程/线程执行完do_fork后的返回值
	proc->tf->tf_esp = esp; //设置中断帧中的栈指针esp
	proc->tf->tf_eflags |= FL_IF; //使能中断
	proc->context.eip = (uintptr_t)forkret;
	proc->context.esp = (uintptr_t)(proc->tf);
}
```

此函数首先在内核堆栈的顶部设置中断帧大小的一块栈空间，并在此空间中拷贝在 kernel_thread 函数建立的临时中断帧的初始值，并进一步设置中断帧中的栈指针 esp 和标志寄存器 eflags，特别是 eflags 设置了 FL_IF 标志，这表示此内核线程在执行过程中，能响应中断，打断当前的执行。执行到这步后，此进程的中断帧就建立好了，对于 initproc 而言，它的中断帧如下所示：

```
//所在地址位置
initproc->tf= (proc->kstack+KSTACKSIZE) – sizeof (struct trapframe);
//具体内容
initproc->tf.tf_cs = KERNEL_CS;
initproc->tf.tf_ds = initproc->tf.tf_es = initproc->tf.tf_ss = KERNEL_DS;
initproc->tf.tf_regs.reg_ebx = (uint32_t)init_main;
initproc->tf.tf_regs.reg_edx = (uint32_t) ADDRESS of "Helloworld!!";
initproc->tf.tf_eip = (uint32_t)kernel_thread_entry;
initproc->tf.tf_regs.reg_eax = 0;
initproc->tf.tf_esp = esp;
initproc->tf.tf_eflags |= FL_IF;
```

设置好中断帧后，最后就是设置 initproc 的进程上下文，（process context，也称执行现场）了。只有设置好执行现场后，一旦 uCore 调度器选择了 initproc 执行，就需要根据 initproc-\>context 中保存的执行现场来恢复 initproc 的执行。这里设置了 initproc 的执行现场中主要的两个信息：上次停止执行时的下一条指令地址 context.eip 和上次停止执行时的堆栈地址 context.esp。其实 initproc 还没有执行过，所以这其实就是 initproc 实际执行的第一条指令地址和堆栈指针。可以看出，由于 initproc 的中断帧占用了实际给 initproc 分配的栈空间的顶部，所以 initproc 就只能把栈顶指针 context.esp 设置在 initproc 的中断帧的起始位置。根据 context.eip 的赋值，可以知道 initproc 实际开始执行的地方在 forkret 函数（主要完成 do_fork 函数返回的处理工作）处。至此，initproc 内核线程已经做好准备执行了。
