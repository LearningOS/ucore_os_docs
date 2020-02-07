### 页面置换机制

如果要实现页面置换机制，只考虑页替换算法的设计与实现是远远不够的，还需考虑其他问题：

- 哪些页可以被换出？
- 一个虚拟的页如何与硬盘上的扇区建立对应关系？
- 何时进行换入和换出操作？
- 如何设计数据结构以支持页替换算法？
- 如何完成页的换入换出操作？

这些问题在下面会逐一进行分析。注意，在实验三中仅实现了简单的页面置换机制，但现在还没有涉及实验四和实验五才实现的内核线程和用户进程，所以还无法通过内核线程机制实现一个完整意义上的虚拟内存页面置换功能。

#### 1. 可以被换出的页

在操作系统的设计中，一个基本的原则是：并非所有的物理页都可以交换出去的，只有映射到用户空间且被用户程序直接访问的页面才能被交换，而被内核直接使用的内核空间的页面不能被换出。这里面的原因是什么呢？操作系统是执行的关键代码，需要保证运行的高效性和实时性，如果在操作系统执行过程中，发生了缺页现象，则操作系统不得不等很长时间（硬盘的访问速度比内存的访问速度慢 2\~3 个数量级），这将导致整个系统运行低效。而且，不难想象，处理缺页过程所用到的内核代码或者数据如果被换出，整个内核都面临崩溃的危险。

但在实验三实现的 ucore 中，我们只是实现了换入换出机制，还没有设计用户态执行的程序，所以我们在实验三中仅仅通过执行 check_swap 函数在内核中分配一些页，模拟对这些页的访问，然后通过 do_pgfault 来调用 swap_map_swappable 函数来查询这些页的访问情况并间接调用相关函数，换出“不常用”的页到磁盘上。

#### 2. 虚存中的页与硬盘上的扇区之间的映射关系

如果一个页被置换到了硬盘上，那操作系统如何能简捷来表示这种情况呢？在 ucore 的设计上，充分利用了页表中的 PTE 来表示这种情况：当一个 PTE 用来描述一般意义上的物理页时，显然它应该维护各种权限和映射关系，以及应该有 PTE_P 标记；但当它用来描述一个被置换出去的物理页时，它被用来维护该物理页与 swap 磁盘上扇区的映射关系，并且该 PTE 不应该由 MMU 将它解释成物理页映射(即没有 PTE_P 标记)，与此同时对应的权限则交由 mm_struct 来维护，当对位于该页的内存地址进行访问的时候，必然导致 page fault，然后 ucore 能够根据 PTE 描述的 swap 项将相应的物理页重新建立起来，并根据虚存所描述的权限重新设置好 PTE 使得内存访问能够继续正常进行。

如果一个页（4KB/页）被置换到了硬盘某 8 个扇区（0.5KB/扇区），该 PTE 的最低位--present 位应该为 0 （即 PTE_P 标记为空，表示虚实地址映射关系不存在），接下来的 7 位暂时保留，可以用作各种扩展；而包括原来高 20 位页帧号的高 24 位数据，恰好可以用来表示此页在硬盘上的起始扇区的位置（其从第几个扇区开始）。为了在页表项中区别 0 和 swap 分区的映射，将 swap 分区的一个 page 空出来不用，也就是说一个高 24 位不为 0，而最低位为 0 的 PTE 表示了一个放在硬盘上的页的起始扇区号（见 swap.h 中对 swap_entry_t 的描述）：

```
swap_entry_t
-------------------------
| offset | reserved | 0 |
-------------------------
24 bits    7 bits   1 bit
```

考虑到硬盘的最小访问单位是一个扇区，而一个扇区的大小为 512（2\^8）字节，所以需要 8 个连续扇区才能放置一个 4KB 的页。在 ucore 中，用了第二个 IDE 硬盘来保存被换出的扇区，根据实验三的输出信息

```
“ide 1: 262144(sectors), 'QEMU HARDDISK'.”
```

我们可以知道实验三可以保存 262144/8=32768 个页，即 128MB 的内存空间。swap
分区的大小是 swapfs_init 里面根据磁盘驱动的接口计算出来的，目前 ucore
里面要求 swap 磁盘至少包含 1000 个 page，并且至多能使用 1<<24 个 page。

#### 3. 执行换入换出的时机

在实验三中， check_mm_struct 变量这个数据结构表示了目前
ucore 认为合法的所有虚拟内存空间集合，而 mm 中的每个 vma 表示了一段地址连续的合法虚拟空间。当 ucore 或应用程序访问地址所在的页不在内存时，就会产生 page fault 异常，引起调用 do_pgfault 函数，此函数会判断产生访问异常的地址属于 check_mm_struct 某个 vma 表示的合法虚拟地址空间，且保存在硬盘 swap 文件中（即对应的 PTE 的高 24 位不为 0，而最低位为 0），则是执行页换入的时机，将调用 swap_in 函数完成页面换入。

换出页面的时机相对复杂一些，针对不同的策略有不同的时机。ucore 目前大致有两种策略，即积极换出策略和消极换出策略。积极换出策略是指操作系统周期性地（或在系统不忙的时候）主动把某些认为“不常用”的页换出到硬盘上，从而确保系统中总有一定数量的空闲页存在，这样当需要空闲页时，基本上能够及时满足需求；消极换出策略是指，只是当试图得到空闲页时，发现当前没有空闲的物理页可供分配，这时才开始查找“不常用”页面，并把一个或多个这样的页换出到硬盘上。

在实验三中的基本练习中，支持上述的第二种情况。对于第一种积极换出策略，即每隔 1 秒执行一次的实现积极的换出策略，可考虑在扩展练习中实现。对于第二种消极的换出策略，则是在 ucore 调用 alloc_pages 函数获取空闲页时，此函数如果发现无法从物理内存页分配器获得空闲页，就会进一步调用 swap_out 函数换出某页，实现一种消极的换出策略。

#### 4. 页替换算法的数据结构设计

到实验二为止，我们知道目前表示内存中物理页使用情况的变量是基于数据结构 Page 的全局变量 pages 数组，pages 的每一项表示了计算机系统中一个物理页的使用情况。为了表示物理页可被换出或已被换出的情况，可对 Page 数据结构进行扩展：

```c
struct Page {
……
list_entry_t pra_page_link;
uintptr_t pra_vaddr;
};
```

pra_page_link 可用来构造按页的第一次访问时间进行排序的一个链表，这个链表的开始表示第一次访问时间最近的页，链表结尾表示第一次访问时间最远的页。当然链表头可以就可设置为 pra_list_head（定义在 swap_fifo.c 中），构造的时机是在 page fault 发生后，进行 do_pgfault 函数时。pra_vaddr 可以用来记录此物理页对应的虚拟页起始地址。

当一个物理页 （struct Page） 需要被 swap 出去的时候，首先需要确保它已经分配了一个位于磁盘上的 swap page（由连续的 8 个扇区组成）。这里为了简化设计，在 swap_check 函数中建立了每个虚拟页唯一对应的 swap page，其对应关系设定为：虚拟页对应的 PTE 的索引值 = swap page 的扇区起始位置\*8。

为了实现各种页替换算法，我们设计了一个页替换算法的类框架 swap_manager:

```c
struct swap_manager
{
    const char *name;
    /* Global initialization for the swap manager */
    int (*init) (void);
    /* Initialize the priv data inside mm_struct */
    int (*init_mm) (struct mm_struct *mm);
    /* Called when tick interrupt occured */
    int (*tick_event) (struct mm_struct *mm);
    /* Called when map a swappable page into the mm_struct */
    int (*map_swappable) (struct mm_struct *mm, uintptr_t addr, struct Page *page, int swap_in);
    /* When a page is marked as shared, this routine is called to delete the addr entry from the swap manager */
    int (*set_unswappable) (struct mm_struct *mm, uintptr_t addr);
    /* Try to swap out a page, return then victim */
    int (*swap_out_victim) (struct mm_struct *mm, struct Page *ptr_page, int in_tick);
    /* check the page relpacement algorithm */
    int (*check\_swap)(void);
};
```

这里关键的两个函数指针是 map_swappable 和 swap_out_vistim，前一个函数用于记录页访问情况相关属性，后一个函数用于挑选需要换出的页。显然第二个函数依赖于第一个函数记录的页访问情况。tick_event 函数指针也很重要，结合定时产生的中断，可以实现一种积极的换页策略。

#### 5. swap_check 的检查实现

下面具体讲述一下实验三中实现置换算法的页面置换的检查执行逻辑，便于大家实现练习 2。实验三的检查过程在函数 swap_check（kern/mm/swap.c 中）中，其大致流程如下。

1. 调用 mm_create 建立 mm 变量，并调用 vma_create 创建 vma 变量，设置合法的访问范围为 4KB\~24KB；
2. 调用 free_page 等操作，模拟形成一个只有 4 个空闲 physical page；并设置了从 4KB\~24KB 的连续 5 个虚拟页的访问操作；
3. 设置记录缺页次数的变量 pgfault_num=0，执行 check_content_set 函数，使得起始地址分别对起始地址为 0x1000, 0x2000, 0x3000, 0x4000 的虚拟页按时间顺序先后写操作访问，由于之前没有建立页表，所以会产生 page fault 异常，如果完成练习 1，则这些从 4KB\~20KB 的 4 虚拟页会与 ucore 保存的 4 个物理页帧建立映射关系；
4. 然后对虚页对应的新产生的页表项进行合法性检查；
5. 然后进入测试页替换算法的主体，执行函数 check_content_access，并进一步调用到\_fifo_check_swap 函数，如果通过了所有的 assert。这进一步表示 FIFO 页替换算法基本正确实现；
6. 最后恢复 ucore 环境。
