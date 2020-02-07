## 实验目的：

操作系统是一个软件，也需要通过某种机制加载并运行它。在这里我们将通过另外一个更加简单的软件-bootloader 来完成这些工作。为此，我们需要完成一个能够切换到 x86 的保护模式并显示字符的 bootloader，为启动操作系统 ucore 做准备。lab1 提供了一个非常小的 bootloader 和 ucore OS，整个 bootloader 执行代码小于 512 个字节，这样才能放到硬盘的主引导扇区中。通过分析和实现这个 bootloader 和 ucore OS，读者可以了解到：

- 计算机原理

  - CPU 的编址与寻址: 基于分段机制的内存管理
  - CPU 的中断机制
  - 外设：串口/并口/CGA，时钟，硬盘

- Bootloader 软件

  - 编译运行 bootloader 的过程
  - 调试 bootloader 的方法
  - PC 启动 bootloader 的过程
  - ELF 执行文件的格式和加载
  - 外设访问：读硬盘，在 CGA 上显示字符串

- ucore OS 软件
  - 编译运行 ucore OS 的过程
  - ucore OS 的启动过程
  - 调试 ucore OS 的方法
  - 函数调用关系：在汇编级了解函数调用栈的结构和处理过程
  - 中断管理：与软件相关的中断处理
  - 外设管理：时钟
