#### make 和 Makefile

GNU make(简称 make)是一种代码维护工具，在大中型项目中，它将根据程序各个模块的更新情况，自动的维护和生成目标代码。

make 命令执行时，需要一个 makefile （或 Makefile）文件，以告诉 make 命令需要怎么样的去编译和链接程序。首先，我们用一个示例来说明 makefile 的书写规则。以便给大家一个感兴认识。这个示例来源于 gnu 的 make 使用手册，在这个示例中，我们的工程有 8 个 c 文件，和 3 个头文件，我们要写一个 makefile 来告诉 make 命令如何编译和链接这几个文件。我们的规则是：

- 如果这个工程没有编译过，那么我们的所有 c 文件都要编译并被链接。
- 如果这个工程的某几个 c 文件被修改，那么我们只编译被修改的 c 文件，并链接目标程序。
- 如果这个工程的头文件被改变了，那么我们需要编译引用了这几个头文件的 c 文件，并链接目标程序。

只要我们的 makefile 写得够好，所有的这一切，我们只用一个 make 命令就可以完成，make 命令会自动智能地根据当前的文件修改的情况来确定哪些文件需要重编译，从而自己编译所需要的文件和链接目标程序。

##### 2.3.2.1.1 makefile 的规则

在讲述这个 makefile 之前，还是让我们先来粗略地看一看 makefile 的规则。

```
target ... : prerequisites ...
	command
	...
	...
```

target 也就是一个目标文件，可以是 object file，也可以是执行文件。还可以是一个标签（label）。prerequisites 就是，要生成那个 target 所需要的文件或是目标。command 也就是 make 需要执行的命令（任意的 shell 命令）。 这是一个文件的依赖关系，也就是说，target 这一个或多个的目标文件依赖于 prerequisites 中的文件，其生成规则定义在 command 中。如果 prerequisites 中有一个以上的文件比 target 文件要新，那么 command 所定义的命令就会被执行。这就是 makefile 的规则。也就是 makefile 中最核心的内容。
