### 关键数据结构和相关函数分析

对于第一个问题的出现，在于实验二中有关内存的数据结构和相关操作都是直接针对实际存在的资源--物理内存空间的管理，没有从一般应用程序对内存的“需求”考虑，即需要有相关的数据结构和操作来体现一般应用程序对虚拟内存的“需求”。一般应用程序的对虚拟内存的“需求”与物理内存空间的“供给”没有直接的对应关系，ucore 是通过 page
fault 异常处理来间接完成这二者之间的衔接。

page_fault 函数不知道哪些是“合法”的虚拟页，原因是 ucore 还缺少一定的数据结构来描述这种不在物理内存中的“合法”虚拟页。为此 ucore 通过建立 mm_struct 和 vma_struct 数据结构，描述了 ucore 模拟应用程序运行所需的合法内存空间。当访问内存产生 page
fault 异常时，可获得访问的内存的方式（读或写）以及具体的虚拟内存地址，这样 ucore 就可以查询此地址，看是否属于 vma_struct 数据结构中描述的合法地址范围中，如果在，则可根据具体情况进行请求调页/页换入换出处理（这就是练习 2 涉及的部分）；如果不在，则报错。mm_struct 和 vma_struct 数据结构结合页表表示虚拟地址空间和物理地址空间的示意图如下所示：

图 虚拟地址空间和物理地址空间的示意图

![image](../lab3_figs/image001.png)

在 ucore 中描述应用程序对虚拟内存“需求”的数据结构是 vma_struct（定义在 vmm.h 中），以及针对 vma_struct 的函数操作。这里把一个 vma_struct 结构的变量简称为 vma 变量。vma_struct 的定义如下：

```c
struct vma_struct {
    // the set of vma using the same PDT
    struct mm_struct *vm_mm;
    uintptr_t vm_start; // start addr of vma
    uintptr_t vm_end; // end addr of vma
    uint32_t vm_flags; // flags of vma
    //linear list link which sorted by start addr of vma
    list_entry_t list_link;
};
```

vm_start 和 vm_end 描述了一个连续地址的虚拟内存空间的起始位置和结束位置，这两个值都应该是 PGSIZE 对齐的，而且描述的是一个合理的地址空间范围（即严格确保 vm_start < vm_end 的关系）；list_link 是一个双向链表，按照从小到大的顺序把一系列用 vma_struct 表示的虚拟内存空间链接起来，并且还要求这些链起来的 vma_struct 应该是不相交的，即 vma 之间的地址空间无交集；vm_flags 表示了这个虚拟内存空间的属性，目前的属性包括：

```c
#define VM_READ 0x00000001 //只读
#define VM_WRITE 0x00000002 //可读写
#define VM_EXEC 0x00000004 //可执行
```

vm_mm 是一个指针，指向一个比 vma_struct 更高的抽象层次的数据结构 mm_struct，这里把一个 mm_struct 结构的变量简称为 mm 变量。这个数据结构表示了包含所有虚拟内存空间的共同属性，具体定义如下

```c
struct mm_struct {
    // linear list link which sorted by start addr of vma
    list_entry_t mmap_list;
    // current accessed vma, used for speed purpose
    struct vma_struct *mmap_cache;
    pde_t *pgdir; // the PDT of these vma
    int map_count; // the count of these vma
    void *sm_priv; // the private data for swap manager
};
```

mmap_list 是双向链表头，链接了所有属于同一页目录表的虚拟内存空间，mmap_cache 是指向当前正在使用的虚拟内存空间，由于操作系统执行的“局部性”原理，当前正在用到的虚拟内存空间在接下来的操作中可能还会用到，这时就不需要查链表，而是直接使用此指针就可找到下一次要用到的虚拟内存空间。由于 mmap_cache 的引入，可使得 mm_struct 数据结构的查询加速 30% 以上。pgdir
所指向的就是 mm_struct 数据结构所维护的页表。通过访问 pgdir 可以查找某虚拟地址对应的页表项是否存在以及页表项的属性等。map_count 记录 mmap_list 里面链接的 vma_struct 的个数。sm_priv 指向用来链接记录页访问情况的链表头，这建立了 mm_struct 和后续要讲到的 swap_manager 之间的联系。

涉及 vma_struct 的操作函数也比较简单，主要包括三个：

- vma_create--创建 vma
- insert_vma_struct--插入一个 vma
- find_vma--查询 vma。

vma_create 函数根据输入参数 vm_start、vm_end、vm_flags 来创建并初始化描述一个虚拟内存空间的 vma_struct 结构变量。insert_vma_struct 函数完成把一个 vma 变量按照其空间位置[vma-\>vm\_start,vma-\>vm\_end]从小到大的顺序插入到所属的 mm 变量中的 mmap_list 双向链表中。find_vma 根据输入参数 addr 和 mm 变量，查找在 mm 变量中的 mmap_list 双向链表中某个 vma 包含此 addr，即 vma-\>vm_start<=addr <vma-\>end。这三个函数与后续讲到的 page fault 异常处理有紧密联系。

涉及 mm_struct 的操作函数比较简单，只有 mm_create 和 mm_destroy 两个函数，从字面意思就可以看出是是完成 mm_struct 结构的变量创建和删除。在 mm_create 中用 kmalloc 分配了一块空间，所以在 mm_destroy 中也要对应进行释放。在 ucore 运行过程中，会产生描述虚拟内存空间的 vma_struct 结构，所以在 mm_destroy 中也要进对这些 mmap_list 中的 vma 进行释放。
