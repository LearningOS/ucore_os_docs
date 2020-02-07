### 练习

对实验报告的要求：

- 基于 markdown 格式来完成，以文本方式为主
- 填写各个基本练习中要求完成的报告内容
- 完成实验后，请分析 ucore_lab 中提供的参考答案，并请在实验报告中说明你的实现与参考答案的区别
- 列出你认为本实验中重要的知识点，以及与对应的 OS 原理中的知识点，并简要说明你对二者的含义，关系，差异等方面的理解（也可能出现实验中的知识点没有对应的原理知识点）
- 列出你认为 OS 原理中很重要，但在实验中没有对应上的知识点

#### 练习 0：填写已有实验

本实验依赖实验 1/2/3/4/5。请把你做的实验 2/3/4/5 的代码填入本实验中代码中有“LAB1”/“LAB2”/“LAB3”/“LAB4”“LAB5”的注释相应部分。并确保编译通过。注意：为了能够正确执行 lab6 的测试应用程序，可能需对已完成的实验 1/2/3/4/5 的代码进行进一步改进。

#### 练习 1: 使用 Round Robin 调度算法（不需要编码）

完成练习 0 后，建议大家比较一下（可用 kdiff3 等文件比较软件）个人完成的 lab5 和练习 0 完成后的刚修改的 lab6 之间的区别，分析了解 lab6 采用 RR 调度算法后的执行过程。执行 make grade，大部分测试用例应该通过。但执行 priority.c 应该过不去。

请在实验报告中完成：

- 请理解并分析 sched_class 中各个函数指针的用法，并结合 Round Robin 调度算法描 ucore 的调度执行过程
- 请在实验报告中简要说明如何设计实现”多级反馈队列调度算法“，给出概要设计，鼓励给出详细设计

#### 练习 2: 实现 Stride Scheduling 调度算法（需要编码）

首先需要换掉 RR 调度器的实现，即用 default_sched_stride_c 覆盖 default_sched.c。然后根据此文件和后续文档对 Stride 度器的相关描述，完成 Stride 调度算法的实现。

后面的实验文档部分给出了 Stride 调度算法的大体描述。这里给出 Stride 调度算法的一些相关的资料（目前网上中文的资料比较欠缺）。

- [strid-shed paper location1](http://wwwagss.informatik.uni-kl.de/Projekte/Squirrel/stride/node3.html)
- [strid-shed paper location2](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.138.3502&rank=1)
- 也可 GOOGLE “Stride Scheduling” 来查找相关资料

执行：make grade。如果所显示的应用程序检测都输出 ok，则基本正确。如果只是 priority.c 过不去，可执行 make run-priority 命令来单独调试它。大致执行结果可看附录。（ 使用的是 qemu-1.0.1 ）。

请在实验报告中简要说明你的设计实现过程。

#### 扩展练习 Challenge 1 ：实现 Linux 的 CFS 调度算法

在 ucore 的调度器框架下实现下 Linux 的 CFS 调度算法。可阅读相关 Linux 内核书籍或查询网上资料，可了解 CFS 的细节，然后大致实现在 ucore 中。

#### 扩展练习 Challenge 2 ：在 ucore 上实现尽可能多的各种基本调度算法(FIFO, SJF,...)，并设计各种测试用例，能够定量地分析出各种调度算法在各种指标上的差异，说明调度算法的适用范围。
