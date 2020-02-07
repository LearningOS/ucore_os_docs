#### file & dir 接口

file&dir 接口层定义了进程在内核中直接访问的文件相关信息，这定义在 file 数据结构中，具体描述如下：

```
struct file {
    enum {
        FD_NONE, FD_INIT, FD_OPENED, FD_CLOSED,
    } status;                         //访问文件的执行状态
    bool readable;                    //文件是否可读
    bool writable;                    //文件是否可写
    int fd;                           //文件在filemap中的索引值
    off_t pos;                        //访问文件的当前位置
    struct inode *node;               //该文件对应的内存inode指针
    int open_count;                   //打开此文件的次数
};
```

而在 kern/process/proc.h 中的 proc_struct 结构中描述了进程访问文件的数据接口 files_struct，其数据结构定义如下：

```
struct files_struct {
    struct inode *pwd;                //进程当前执行目录的内存inode指针
    struct file *fd_array;            //进程打开文件的数组
    atomic_t files_count;             //访问此文件的线程个数
    semaphore_t files_sem;            //确保对进程控制块中fs_struct的互斥访问
};
```

当创建一个进程后，该进程的 files_struct 将会被初始化或复制父进程的 files_struct。当用户进程打开一个文件时，将从 fd_array 数组中取得一个空闲 file 项，然后会把此 file 的成员变量 node 指针指向一个代表此文件的 inode 的起始地址。
