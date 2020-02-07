### 物理内存页分配算法实现

如果要在 ucore 中实现连续物理内存分配算法，则需要考虑的事情比较多，相对课本上的物理内存分配算法描述要复杂不少。下面介绍一下如果要实现一个 FirstFit 内存分配算法的大致流程。

lab2 的第一部分是完成 first_fit 的分配算法。原理 FirstFit 内存分配算法上很简单，但要在 ucore 中实现，需要充分了解和利用 ucore 已有的数据结构和相关操作、关键的一些全局变量等。

**关键数据结构和变量**

first_fit 分配算法需要维护一个查找有序（地址按从小到大排列）空闲块（以页为最小单位的连续地址空间）的数据结构，而双向链表是一个很好的选择。

libs/list.h 定义了可挂接任意元素的通用双向链表结构和对应的操作，所以需要了解如何使用这个文件提供的各种函数，从而可以完成对双向链表的初始化/插入/删除等。

kern/mm/memlayout.h 中定义了一个 free_area_t 数据结构，包含成员结构

```c
  list_entry_t free_list;         // the list header   空闲块双向链表的头
  unsigned int nr_free;           // # of free pages in this free list  空闲块的总数（以页为单位）
```

显然，我们可以通过此数据结构来完成对空闲块的管理。而 default_pmm.c 中定义的 free_area 变量就是干这个事情的。

kern/mm/pmm.h 中定义了一个通用的分配算法的函数列表，用 pmm_manager
表示。其中 init 函数就是用来初始化 free_area 变量的,
first_fit 分配算法可直接重用 default_init 函数的实现。init_memmap 函数需要根据现有的内存情况构建空闲块列表的初始状态。何时应该执行这个函数呢？

通过分析代码，可以知道：

```
kern_init --> pmm_init-->page_init-->init_memmap--> pmm_manager->init_memmap
```

所以，default_init_memmap 需要根据 page_init 函数中传递过来的参数（某个连续地址的空闲块的起始页，页个数）来建立一个连续内存空闲块的双向链表。这里有一个假定 page_init 函数是按地址从小到大的顺序传来的连续内存空闲块的。链表头是 free_area.free_list，链表项是 Page 数据结构的 base-\>page_link。这样我们就依靠 Page 数据结构中的成员变量 page_link 形成了连续内存空闲块列表。

**设计实现**

default_init_memmap 函数将根据每个物理页帧的情况来建立空闲页链表，且空闲页块应该是根据地址高低形成一个有序链表。根据上述变量的定义，default_init_memmap 可大致实现如下：

```c
default_init_memmap(struct Page *base, size_t n) {
    struct Page *p = base;
    for (; p != base + n; p ++) {
        p->flags = p->property = 0;
        set_page_ref(p, 0);
    }
    base->property = n;
    SetPageProperty(base);
    nr_free += n;
    list_add(&free_list, &(base->page_link));
}
```

如果要分配一个页，那要考虑哪些呢？这里就需要考虑实现 default_alloc_pages 函数，注意参数 n 表示要分配 n 个页。另外，需要注意实现时尽量多考虑一些边界情况，这样确保软件的鲁棒性。比如

```c
if (n > nr_free) {
return NULL;
}
```

这样可以确保分配不会超出范围。也可加一些
assert 函数，在有错误出现时，能够迅速发现。比如 n 应该大于 0，我们就可以加上

```c
assert(n \> 0);
```

这样在 n<=0 的情况下，ucore 会迅速报错。firstfit 需要从空闲链表头开始查找最小的地址，通过 list_next 找到下一个空闲块元素，通过 le2page 宏可以由链表元素获得对应的 Page 指针 p。通过 p-\>property 可以了解此空闲块的大小。如果\>=n，这就找到了！如果<n，则 list_next，继续查找。直到 list_next==
&free_list，这表示找完了一遍了。找到后，就要从新组织空闲块，然后把找到的 page 返回。所以 default_alloc_pages 可大致实现如下：

```c
static struct Page *
default_alloc_pages(size_t n) {
    if (n > nr_free) {
        return NULL;
    }
    struct Page *page = NULL;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        if (p->property >= n) {
            page = p;
            break;
        }
    }
    if (page != NULL) {
        list_del(&(page->page_link));
        if (page->property > n) {
            struct Page *p = page + n;
            p->property = page->property - n;
            list_add(&free_list, &(p->page_link));
        }
        nr_free -= n;
        ClearPageProperty(page);
    }
    return page;
}
```

default_free_pages 函数的实现其实是 default_alloc_pages 的逆过程，不过需要考虑空闲块的合并问题。这里就不再细讲了。注意，上诉代码只是参考设计，不是完整的正确设计。更详细的说明位于 lab2/kernel/mm/default_pmm.c 的注释中。希望同学能够顺利完成本实验的第一部分。
