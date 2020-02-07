#### 通过虚拟机使用 Linux 实验环境（推荐：最容易的实验环境安装方法）

这是最简单的一种通过虚拟机方式使用 Linux 并完成 OS 各个实验的方法，不需要安装 Linux 操作系统和各种实验所需开发软件。首先安装 VirtualBox 虚拟机软件（有 windows 版本和其他 OS 版本，可到 http://www.virtualbox.org/wiki/Downloads 下载），然后在[百度云盘上](http://pan.baidu.com/s/11zjRK)下载一个已经安装好各种所需编辑/开发/调试/运行软件的 Linux 实验环境的 VirtualBox 虚拟硬盘文件(mooc-os-2015.vdi.xz，包含一个虚拟磁盘镜像文件和两个配置描述文件，下载此文件的网址址见https://github.com/chyyuu/ucore_lab下的README中的描述)。用 2345 好压软件(有 windows 版本，可到http://www.haozip.com 下载。一般软件解压不了 xz 格式的压缩文件）先解压到 C 盘的 vms 目录下即：
C:\vms\mooc-os-2015.vdi

解压后这个文件所占用的硬盘空间为 6GB 左右。在 VirtualBox 中创建新虚拟机（设置 64 位 Linux 系统，指定配置刚解压的这个虚拟硬盘 mooc-os-2015.vdi），就可以启动并运行已经配置好相关工具的 Linux 实验环境了。

如果提示用户“moocos”输入口令时，只需简单敲一个空格键和回车键即可。然后就进入到开发环境中了。实验内容位于 ucore_lab 目录下。可以通过如下命令获得整个实验的代码和文档：
\$ git clone https://github.com/chyyuu/ucore_lab.git

并可通过如下命令获得以后更新后的代码和文档：
\$ git pull
当然，你需要了解一下 git 的基本使用方法，这可以通过网络获得很多这方面的信息。
