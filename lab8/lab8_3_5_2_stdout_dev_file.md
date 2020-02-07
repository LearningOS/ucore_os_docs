#### stdout 设备文件

**初始化**

既然 stdout 设备是设备文件系统的文件，自然有自己的 inode 结构。在系统初始化时，即只需如下处理过程

```
kern_init-->fs_init-->dev_init-->dev_init_stdout --> dev_create_inode
                 --> stdout_device_init
                 --> vfs_add_dev
```

在 dev_init_stdout 中完成了对 stdout 设备文件的初始化。即首先创建了一个 inode，然后通过 stdout_device_init 完成对 inode 中的成员变量 inode-\>\_\_device_info 进行初始：

这里的 stdout 设备文件实际上就是指的 console 外设（它其实是串口、并口和 CGA 的组合型外设）。这个设备文件是一个只写设备，如果读这个设备，就会出错。接下来我们看看 stdout 设备的相关处理过程。

**初始化**

stdout 设备文件的初始化过程主要由 stdout_device_init 完成，其具体实现如下：

```
static void
stdout_device_init(struct device *dev) {
    dev->d_blocks = 0;
    dev->d_blocksize = 1;
    dev->d_open = stdout_open;
    dev->d_close = stdout_close;
    dev->d_io = stdout_io;
    dev->d_ioctl = stdout_ioctl;
}
```

可以看到，stdout_open 函数完成设备文件打开工作，如果发现用户进程调用 open 函数的参数 flags 不是只写（O_WRONLY），则会报错。

**访问操作实现**

stdout_io 函数完成设备的写操作工作，具体实现如下：

```
static int
stdout_io(struct device *dev, struct iobuf *iob, bool write) {
    if (write) {
        char *data = iob->io_base;
        for (; iob->io_resid != 0; iob->io_resid --) {
            cputchar(*data ++);
        }
        return 0;
    }
    return -E_INVAL;
}
```

可以看到，要写的数据放在 iob-\>io_base 所指的内存区域，一直写到 iob-\>io_resid 的值为 0 为止。每次写操作都是通过 cputchar 来完成的，此函数最终将通过 console 外设驱动来完成把数据输出到串口、并口和 CGA 显示器上过程。另外，也可以注意到，如果用户想执行读操作，则 stdout_io 函数直接返回错误值**-**E_INVAL。
