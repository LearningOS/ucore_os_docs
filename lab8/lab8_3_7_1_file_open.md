#### 打开文件

有了上述分析后，我们可以看看如果一个用户进程打开文件会做哪些事情？首先假定用户进程需要打开的文件已经存在在硬盘上。以 user/sfs_filetest1.c 为例，首先用户进程会调用在 main 函数中的如下语句：

```
int fd1 = safe_open("sfs\_filetest1", O_RDONLY);
```

从字面上可以看出，如果 ucore 能够正常查找到这个文件，就会返回一个代表文件的文件描述符 fd1，这样在接下来的读写文件过程中，就直接用这样 fd1 来代表就可以了。那这个打开文件的过程是如何一步一步实现的呢？

**通用文件访问接口层的处理流程**

首先进入通用文件访问接口层的处理流程，即进一步调用如下用户态函数： open-\>sys_open-\>syscall，从而引起系统调用进入到内核态。到了内核态后，通过中断处理例程，会调用到 sys_open 内核函数，并进一步调用 sysfile_open 内核函数。到了这里，需要把位于用户空间的字符串"sfs_filetest1"拷贝到内核空间中的字符串 path 中，并进入到文件系统抽象层的处理流程完成进一步的打开文件操作中。

**文件系统抽象层的处理流程**

1. 分配一个空闲的 file 数据结构变量 file 在文件系统抽象层的处理中，首先调用的是 file_open 函数，它要给这个即将打开的文件分配一个 file 数据结构的变量，这个变量其实是当前进程的打开文件数组 current-\>fs_struct-\>filemap[]中的一个空闲元素（即还没用于一个打开的文件），而这个元素的索引值就是最终要返回到用户进程并赋值给变量 fd1。到了这一步还仅仅是给当前用户进程分配了一个 file 数据结构的变量，还没有找到对应的文件索引节点。

为此需要进一步调用 vfs_open 函数来找到 path 指出的文件所对应的基于 inode 数据结构的 VFS 索引节点 node。vfs_open 函数需要完成两件事情：通过 vfs_lookup 找到 path 对应文件的 inode；调用 vop_open 函数打开文件。

2. 找到文件设备的根目录“/”的索引节点需要注意，这里的 vfs_lookup 函数是一个针对目录的操作函数，它会调用 vop_lookup 函数来找到 SFS 文件系统中的“/”目录下的“sfs_filetest1”文件。为此，vfs_lookup 函数首先调用 get_device 函数，并进一步调用 vfs_get_bootfs 函数（其实调用了）来找到根目录“/”对应的 inode。这个 inode 就是位于 vfs.c 中的 inode 变量 bootfs_node。这个变量在 init_main 函数（位于 kern/process/proc.c）执行时获得了赋值。

3. 通过调用 vop_lookup 函数来查找到根目录“/”下对应文件 sfs_filetest1 的索引节点，，如果找到就返回此索引节点。

4. 把 file 和 node 建立联系。完成第 3 步后，将返回到 file_open 函数中，通过执行语句“file-\>node=node;”，就把当前进程的 current-\>fs_struct-\>filemap[fd]（即 file 所指变量）的成员变量 node 指针指向了代表 sfs_filetest1 文件的索引节点 inode。这时返回 fd。经过重重回退，通过系统调用返回，用户态的 syscall-\>sys_open-\>open-\>safe_open 等用户函数的层层函数返回，最终把把 fd 赋值给 fd1。自此完成了打开文件操作。但这里我们还没有分析第 2 和第 3 步是如何进一步调用 SFS 文件系统提供的函数找位于 SFS 文件系统上的 sfs_filetest1 文件所对应的 sfs 磁盘 inode 的过程。下面需要进一步对此进行分析。

**SFS 文件系统层的处理流程**

这里需要分析文件系统抽象层中没有彻底分析的 vop_lookup 函数到底做了啥。下面我们来看看。在 sfs_inode.c 中的 sfs_node_dirops 变量定义了“.vop_lookup = sfs_lookup”，所以我们重点分析 sfs_lookup 的实现。注意：在 lab8 中，为简化代码，sfs_lookup 函数中并没有实现能够对多级目录进行查找的控制逻辑（在 ucore_plus 中有实现）。

sfs_lookup 有三个参数：node，path，node_store。其中 node 是根目录“/”所对应的 inode 节点；path 是文件 sfs_filetest1 的绝对路径/sfs_filetest1，而 node_store 是经过查找获得的 sfs_filetest1 所对应的 inode 节点。

sfs_lookup 函数以“/”为分割符，从左至右逐一分解 path 获得各个子目录和最终文件对应的 inode 节点。在本例中是调用 sfs_lookup_once 查找以根目录下的文件 sfs_filetest1 所对应的 inode 节点。当无法分解 path 后，就意味着找到了 sfs_filetest1 对应的 inode 节点，就可顺利返回了。

当然这里讲得还比较简单，sfs_lookup_once 将调用 sfs_dirent_search_nolock 函数来查找与路径名匹配的目录项，如果找到目录项，则根据目录项中记录的 inode 所处的数据块索引值找到路径名对应的 SFS 磁盘 inode，并读入 SFS 磁盘 inode 对的内容，创建 SFS 内存 inode。
