#### 调度并执行内核线程 initproc

在 uCore 执行完 proc_init 函数后，就创建好了两个内核线程：idleproc 和 initproc，这时 uCore 当前的执行现场就是 idleproc，等到执行到 init 函数的最后一个函数 cpu_idle 之前，uCore 的所有初始化工作就结束了，idleproc 将通过执行 cpu_idle 函数让出 CPU，给其它内核线程执行，具体过程如下：

```
void
cpu_idle(void) {
	while (1) {
		if (current->need_resched) {
			schedule();
			……
```

首先，判断当前内核线程 idleproc 的 need_resched 是否不为 0，回顾前面“创建第一个内核线程 idleproc”中的描述，proc_init 函数在初始化 idleproc 中，就把 idleproc-\>need_resched 置为 1 了，所以会马上调用 schedule 函数找其他处于“就绪”态的进程执行。

uCore 在实验四中只实现了一个最简单的 FIFO 调度器，其核心就是 schedule 函数。它的执行逻辑很简单：

1．设置当前内核线程 current-\>need_resched 为 0；
2．在 proc_list 队列中查找下一个处于“就绪”态的线程或进程 next；
3．找到这样的进程后，就调用 proc_run 函数，保存当前进程 current 的执行现场（进程上下文），恢复新进程的执行现场，完成进程切换。

至此，新的进程 next 就开始执行了。由于在 proc10 中只有两个内核线程，且 idleproc 要让出 CPU 给 initproc 执行，我们可以看到 schedule 函数通过查找 proc_list 进程队列，只能找到一个处于“就绪”态的 initproc 内核线程。并通过 proc_run 和进一步的 switch_to 函数完成两个执行现场的切换，具体流程如下：

1. 让 current 指向 next 内核线程 initproc；
2. 设置任务状态段 ts 中特权态 0 下的栈顶指针 esp0 为 next 内核线程 initproc 的内核栈的栈顶，即 next-\>kstack + KSTACKSIZE ；
3. 设置 CR3 寄存器的值为 next 内核线程 initproc 的页目录表起始地址 next-\>cr3，这实际上是完成进程间的页表切换；
4. 由 switch_to 函数完成具体的两个线程的执行现场切换，即切换各个寄存器，当 switch_to 函数执行完“ret”指令后，就切换到 initproc 执行了。

注意，在第二步设置任务状态段 ts 中特权态 0 下的栈顶指针 esp0 的目的是建立好内核线程或将来用户线程在执行特权态切换（从特权态 0<--\>特权态 3，或从特权态 3<--\>特权态 3）时能够正确定位处于特权态 0 时进程的内核栈的栈顶，而这个栈顶其实放了一个 trapframe 结构的内存空间。如果是在特权态 3 发生了中断/异常/系统调用，则 CPU 会从特权态 3--\>特权态 0，且 CPU 从此栈顶（当前被打断进程的内核栈顶）开始压栈来保存被中断/异常/系统调用打断的用户态执行现场；如果是在特权态 0 发生了中断/异常/系统调用，则 CPU 会从从当前内核栈指针 esp 所指的位置开始压栈保存被中断/异常/系统调用打断的内核态执行现场。反之，当执行完对中断/异常/系统调用打断的处理后，最后会执行一个“iret”指令。在执行此指令之前，CPU 的当前栈指针 esp 一定指向上次产生中断/异常/系统调用时 CPU 保存的被打断的指令地址 CS 和 EIP，“iret”指令会根据 ESP 所指的保存的址 CS 和 EIP 恢复到上次被打断的地方继续执行。

在页表设置方面，由于 idleproc 和 initproc 都是共用一个内核页表 boot_cr3，所以此时第三步其实没用，但考虑到以后的进程有各自的页表，其起始地址各不相同，只有完成页表切换，才能确保新的进程能够正常执行。

第四步 proc_run 函数调用 switch_to 函数，参数是前一个进程和后一个进程的执行现场：process context。在上一节“设计进程控制块”中，描述了 context 结构包含的要保存和恢复的寄存器。我们再看看 switch.S 中的 switch_to 函数的执行流程：

```
.globl switch_to
switch_to: # switch_to(from, to)
# save from's registers
movl 4(%esp), %eax # eax points to from
popl 0(%eax) # esp--> return address, so save return addr in FROM’s
context
movl %esp, 4(%eax)
……
movl %ebp, 28(%eax)
# restore to's registers
movl 4(%esp), %eax # not 8(%esp): popped return address already
# eax now points to to
movl 28(%eax), %ebp
……
movl 4(%eax), %esp
pushl 0(%eax) # push TO’s context’s eip, so return addr = TO’s eip
ret # after ret, eip= TO’s eip
```

首先，保存前一个进程的执行现场，前两条汇编指令（如下所示）保存了进程在返回 switch_to 函数后的指令地址到 context.eip 中

```
movl 4(%esp), %eax # eax points to from
popl 0(%eax) # esp--> return address, so save return addr in FROM’s
context
```

在接下来的 7 条汇编指令完成了保存前一个进程的其他 7 个寄存器到 context 中的相应成员变量中。至此前一个进程的执行现场保存完毕。再往后是恢复向一个进程的执行现场，这其实就是上述保存过程的逆执行过程，即从 context 的高地址的成员变量 ebp 开始，逐一把相关成员变量的值赋值给对应的寄存器，倒数第二条汇编指令“pushl 0(%eax)”其实把 context 中保存的下一个进程要执行的指令地址 context.eip 放到了堆栈顶，这样接下来执行最后一条指令“ret”时，会把栈顶的内容赋值给 EIP 寄存器，这样就切换到下一个进程执行了，即当前进程已经是下一个进程了。uCore 会执行进程切换，让 initproc 执行。在对 initproc 进行初始化时，设置了 initproc-\>context.eip = (uintptr_t)forkret，这样，当执行 switch_to 函数并返回后，initproc 将执行其实际上的执行入口地址 forkret。而 forkret 会调用位于 kern/trap/trapentry.S 中的 forkrets 函数执行，具体代码如下：

```
.globl __trapret
 __trapret:
 # restore registers from stack
 popal
 # restore %ds and %es
 popl %es
 popl %ds
 # get rid of the trap number and error code
 addl $0x8, %esp
 iret
 .globl forkrets
 forkrets:
 # set stack to this new process's trapframe
 movl 4(%esp), %esp //把esp指向当前进程的中断帧
 jmp __trapret
```

可以看出，forkrets 函数首先把 esp 指向当前进程的中断帧，从\_trapret 开始执行到 iret 前，esp 指向了 current-\>tf.tf_eip，而如果此时执行的是 initproc，则 current-\>tf.tf_eip=kernel_thread_entry，initproc-\>tf.tf_cs = KERNEL_CS，所以当执行完 iret 后，就开始在内核中执行 kernel_thread_entry 函数了，而 initproc-\>tf.tf_regs.reg_ebx = init_main，所以在 kernl_thread_entry 中执行“call %ebx”后，就开始执行 initproc 的主体了。Initprocde 的主体函数很简单就是输出一段字符串，然后就返回到 kernel_tread_entry 函数，并进一步调用 do_exit 执行退出操作了。本来 do_exit 应该完成一些资源回收工作等，但这些不是实验四涉及的，而是由后续的实验来完成。至此，实验四中的主要工作描述完毕。
