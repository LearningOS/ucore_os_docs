#### 使用优先队列实现 Stride Scheduling

在上述的实现描述中，对于每一次 pick_next 函数，我们都需要完整地扫描来获得当前最小的 stride 及其进程。这在进程非常多的时候是非常耗时和低效的，有兴趣的同学可以在实现了基于列表扫描的 Stride 调度器之后比较一下 priority 程序在 Round-Robin 及 Stride 调度器下各自的运行时间。考虑到其调度选择于优先队列的抽象逻辑一致，我们考虑使用优化的优先队列数据结构实现该调度。

优先队列是这样一种数据结构：使用者可以快速的插入和删除队列中的元素，并且在预先指定的顺序下快速取得当前在队列中的最小（或者最大）值及其对应元素。可以看到，这样的数据结构非常符合 Stride 调度器的实现。

本次实验提供了 libs/skew_heap.h
作为优先队列的一个实现，该实现定义相关的结构和接口，其中主要包括：

```
1   // 优先队列节点的结构
2   typedef struct skew_heap_entry  skew_heap_entry_t;
3   // 初始化一个队列节点
4   void skew_heap_init(skew_heap_entry_t *a);
5   // 将节点 b 插入至以节点 a 为队列头的队列中去，返回插入后的队列
6   skew_heap_entry_t  *skew_heap_insert(skew_heap_entry_t  *a,
7                                        skew_heap_entry_t  *b,
8                                        compare_f comp);
9   // 将节点 b 插入从以节点 a 为队列头的队列中去，返回删除后的队列
10      skew_heap_entry_t  *skew_heap_remove(skew_heap_entry_t  *a,
11                                           skew_heap_entry_t  *b,
12                                           compare_f comp);
```

其中优先队列的顺序是由比较函数 comp 决定的，sched_stride.c 中提供了 proc_stride_comp_f 比较器用来比较两个 stride 的大小，你可以直接使用它。当使用优先队列作为 Stride 调度器的实现方式之后，运行队列结构也需要作相关改变，其中包括：

- struct
  run_queue 中的 lab6_run_pool 指针，在使用优先队列的实现中表示当前优先队列的头元素，如果优先队列为空，则其指向空指针（NULL）。

- struct
  proc_struct 中的 lab6_run_pool 结构，表示当前进程对应的优先队列节点。本次实验已经修改了系统相关部分的代码，使得其能够很好地适应 LAB6 新加入的数据结构和接口。而在实验中我们需要做的是用优先队列实现一个正确和高效的 Stride 调度器，如果用较简略的伪代码描述，则有：

- init(rq):  
  – Initialize rq-\>run_list  
  – Set rq-\>lab6_run_pool to NULL  
  – Set rq-\>proc_num to 0

- enqueue(rq, proc)  
  – Initialize proc-\>time_slice  
  – Insert proc-\>lab6_run_pool into rq-\>lab6_run_pool  
  – rq-\>proc_num ++

- dequeue(rq, proc)  
  – Remove proc-\>lab6_run_pool from rq-\>lab6_run_pool  
  – rq-\>proc_num --

- pick_next(rq)  
  – If rq-\>lab6_run_pool == NULL, return NULL  
  – Find the proc corresponding to the pointer rq-\>lab6_run_pool  
  – proc-\>lab6_stride += BIG_STRIDE / proc-\>lab6_priority  
  – Return proc

- proc_tick(rq, proc):  
  – If proc-\>time_slice \> 0, proc-\>time_slice --  
  – If proc-\>time_slice == 0, set the flag proc-\>need_resched
