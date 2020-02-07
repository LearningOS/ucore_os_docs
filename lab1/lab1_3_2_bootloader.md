### bootloader 启动过程

BIOS 将通过读取硬盘主引导扇区到内存，并转跳到对应内存中的位置执行 bootloader。bootloader 完成的工作包括：

- 切换到保护模式，启用分段机制
- 读磁盘中 ELF 执行文件格式的 ucore 操作系统到内存
- 显示字符串信息
- 把控制权交给 ucore 操作系统

对应其工作的实现文件在 lab1 中的 boot 目录下的三个文件 asm.h、bootasm.S 和 bootmain.c。下面从原理上介绍完成上述工作的计算机系统硬件和软件背景知识。
