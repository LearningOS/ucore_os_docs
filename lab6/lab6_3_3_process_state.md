### 进程状态

在此次实验中，进程的状态之间的转换需要有一个更为清晰的表述，在 ucore 中，runnable 的进程会被放在运行队列中。值得注意的是，在具体实现中，ucore 定义的进程控制块 struct proc_struct 包含了成员变量 state,用于描述进程的运行状态，而 running 和 runnable 共享同一个状态(state)值(PROC_RUNNABLE。不同之处在于处于 running 态的进程不会放在运行队列中。进程的正常生命周期如下：

- 进程首先在 cpu 初始化或者 sys_fork 的时候被创建，当为该进程分配了一个进程控制块之后，该进程进入 uninit 态(在 proc.c 中 alloc_proc)。
- 当进程完全完成初始化之后，该进程转为 runnable 态。
- 当到达调度点时，由调度器 sched_class 根据运行队列 rq 的内容来判断一个进程是否应该被运行，即把处于 runnable 态的进程转换成 running 状态，从而占用 CPU 执行。
- running 态的进程通过 wait 等系统调用被阻塞，进入 sleeping 态。
- sleeping 态的进程被 wakeup 变成 runnable 态的进程。
- running 态的进程主动 exit 变成 zombie 态，然后由其父进程完成对其资源的最后释放，子进程的进程控制块成为 unused。
- 所有从 runnable 态变成其他状态的进程都要出运行队列，反之，被放入某个运行队列中。
