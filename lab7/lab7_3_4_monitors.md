### 管程和条件变量

#### 原理回顾

引入了管程是为了将对共享资源的所有访问及其所需要的同步操作集中并封装起来。Hansan 为管程所下的定义：“一个管程定义了一个数据结构和能为并发进程所执行（在该数据结构上）的一组操作，这组操作能同步进程和改变管程中的数据”。有上述定义可知，管程由四部分组成：

- 管程内部的共享变量；
- 管程内部的条件变量；
- 管程内部并发执行的进程；
- 对局部于管程内部的共享数据设置初始值的语句。

局限在管程中的数据结构，只能被局限在管程的操作过程所访问，任何管程之外的操作过程都不能访问它；另一方面，局限在管程中的操作过程也主要访问管程内的数据结构。由此可见，管程相当于一个隔离区，它把共享变量和对它进行操作的若干个过程围了起来，所有进程要访问临界资源时，都必须经过管程才能进入，而管程每次只允许一个进程进入管程，从而需要确保进程之间互斥。

但在管程中仅仅有互斥操作是不够用的。进程可能需要等待某个条件 Cond 为真才能继续执行。如果采用[忙等](http://zh.wikipedia.org/w/index.php?title=%E5%BF%99%E7%AD%89%E5%BE%85&action=edit&redlink=1 "忙等待（页面不存在）")(busy
waiting)方式：

```
while not( Cond ) do {}
```

在单处理器情况下，将会导致所有其它进程都无法进入[临界区](http://zh.wikipedia.org/wiki/%E4%B8%B4%E7%95%8C%E5%8C%BA "临界区")使得该条件 Cond 为真，该管程的执行将会发生[死锁](http://zh.wikipedia.org/wiki/%E6%AD%BB%E9%94%81 "死锁")。为此，可引入条件变量（Condition
Variables，简称 CV）。一个条件变量 CV 可理解为一个进程的等待队列，队列中的进程正等待某个条件 Cond 变为真。每个条件变量关联着一个条件，如果条件 Cond 不为真，则进程需要等待，如果条件 Cond 为真，则进程可以进一步在管程中执行。需要注意当一个进程等待一个条件变量 CV（即等待 Cond 为真），该进程需要退出管程，这样才能让其它进程可以进入该管程执行，并进行相关操作，比如设置条件 Cond 为真，改变条件变量的状态，并唤醒等待在此条件变量 CV 上的进程。因此对条件变量 CV 有两种主要操作：

- wait_cv： 被一个进程调用，以等待断言 Pc 被满足后该进程可恢复执行.
  进程挂在该条件变量上等待时，不被认为是占用了管程。
- signal_cv：被一个进程调用，以指出断言 Pc 现在为真，从而可以唤醒等待断言 Pc 被满足的进程继续执行。

#### "哲学家就餐"实例

有了互斥和信号量支持的管程就可用用了解决各种同步互斥问题。比如参考《OS
Concept》一书中的 6.7.2 小节“用管程解决哲学家就餐问题”就给出了这样的事例：

```c
monitor dp
{
	enum {THINKING, HUNGRY, EATING} state[5];
	condition self[5];

	void pickup(int i) {
		state[i] = HUNGRY;
		test(i);
		if (state[i] != EATING)
			self[i].wait_cv();
	}

	void putdown(int i) {
		state[i] = THINKING;
		test((i + 4) % 5);
		test((i + 1) % 5);
	}

	void test(int i) {
		if ((state[(i + 4) % 5] != EATING) &&
		   (state[i] == HUNGRY) &&
		   (state[(i + 1) % 5] != EATING)) {
			  state[i] = EATING;
			  self[i].signal_cv();
        }
    }

	initialization code() {
		for (int i = 0; i < 5; i++)
		state[i] = THINKING;
		}
}
```

#### 关键数据结构

虽然大部分教科书上说明管程适合在语言级实现比如 java 等高级语言，没有提及在采用 C 语言的 OS 中如何实现。下面我们将要尝试在 ucore 中用 C 语言实现采用基于互斥和条件变量机制的管程基本原理。

ucore 中的管程机制是基于信号量和条件变量来实现的。ucore 中的管程的数据结构 monitor_t 定义如下：

```c
typedef struct monitor{
    semaphore_t mutex;      // the mutex lock for going into the routines in monitor, should be initialized to 1
    // the next semaphore is used to
    //    (1) procs which call cond_signal funciton should DOWN next sema after UP cv.sema
    // OR (2) procs which call cond_wait funciton should UP next sema before DOWN cv.sema
    semaphore_t next;
    int next_count;         // the number of of sleeped procs which cond_signal funciton
    condvar_t *cv;          // the condvars in monitor
} monitor_t;
```

管程中的成员变量 mutex 是一个二值信号量，是实现每次只允许一个进程进入管程的关键元素，确保了[互斥](http://zh.wikipedia.org/wiki/%E4%BA%92%E6%96%A5 "互斥")访问性质。管程中的条件变量 cv 通过执行`wait_cv`，会使得等待某个条件 Cond 为真的进程能够离开管程并睡眠，且让其他进程进入管程继续执行；而进入管程的某进程设置条件 Cond 为真并执行`signal_cv`时，能够让等待某个条件 Cond 为真的睡眠进程被唤醒，从而继续进入管程中执行。

注意：管程中的成员变量信号量 next 和整型变量 next_count 是配合进程对条件变量 cv 的操作而设置的，这是由于发出`signal_cv`的进程 A 会唤醒由于`wait_cv`而睡眠的进程 B，由于管程中只允许一个进程运行，所以进程 B 执行会导致唤醒进程 B 的进程 A 睡眠，直到进程 B 离开管程，进程 A 才能继续执行，这个同步过程是通过信号量 next 完成的；而 next_count 表示了由于发出`singal_cv`而睡眠的进程个数。

管程中的条件变量的数据结构 condvar_t 定义如下：

```c
typedef struct condvar{
    semaphore_t sem; 	// the sem semaphore is used to down the waiting proc, and the signaling proc should up the waiting proc
    int count;       　	// the number of waiters on condvar
    monitor_t * owner; 	// the owner(monitor) of this condvar
} condvar_t;
```

条件变量的定义中也包含了一系列的成员变量，信号量 sem 用于让发出`wait_cv`操作的等待某个条件 Cond 为真的进程睡眠，而让发出`signal_cv`操作的进程通过这个 sem 来唤醒睡眠的进程。count 表示等在这个条件变量上的睡眠进程的个数。owner 表示此条件变量的宿主是哪个管程。

#### 条件变量的 signal 和 wait 的设计

理解了数据结构的含义后，我们就可以开始管程的设计实现了。ucore 设计实现了条件变量`wait_cv`操作和`signal_cv`操作对应的具体函数，即`cond_wait`函数和`cond_signal`函数，此外还有`cond_init`初始化函数（可直接看源码）。函数`cond_wait(condvar_t *cvp, semaphore_t *mp)`和`cond_signal (condvar_t *cvp)`的实现原理参考了《OS Concept》一书中的 6.7.3 小节“用信号量实现管程”的内容。首先来看`wait_cv`的原理实现：

** wait_cv 的原理描述 **

```c
cv.count++;
if(monitor.next_count > 0)
   sem_signal(monitor.next);
else
   sem_signal(monitor.mutex);
sem_wait(cv.sem);
cv.count -- ;
```

对照着可分析出`cond_wait`函数的具体执行过程。可以看出如果进程 A 执行了`cond_wait`函数，表示此进程等待某个条件 Cond 不为真，需要睡眠。因此表示等待此条件的睡眠进程个数 cv.count 要加一。接下来会出现两种情况。

情况一：如果 monitor.next_count 如果大于 0，表示有大于等于 1 个进程执行 cond_signal 函数且睡了，就睡在了 monitor.next 信号量上（假定这些进程挂在 monitor.next 信号量相关的等待队列Ｓ上），因此需要唤醒等待队列Ｓ中的一个进程 B；然后进程 A 睡在 cv.sem 上。如果进程 A 醒了，则让 cv.count 减一，表示等待此条件变量的睡眠进程个数少了一个，可继续执行了！

> 这里隐含这一个现象，即某进程 A 在时间顺序上先执行了`cond_signal`，而另一个进程 B 后执行了`cond_wait`，这会导致进程 A 没有起到唤醒进程 B 的作用。

> 问题: 在 cond_wait 有 sem_signal(mutex)，但没有看到哪里有 sem_wait(mutex)，这好像没有成对出现，是否是错误的？
> 答案：其实在管程中的每一个函数的入口处会有 wait(mutex)，这样二者就配好对了。

情况二：如果 monitor.next_count 如果小于等于 0，表示目前没有进程执行 cond_signal 函数且睡着了，那需要唤醒的是由于互斥条件限制而无法进入管程的进程，所以要唤醒睡在 monitor.mutex 上的进程。然后进程 A 睡在 cv.sem 上，如果睡醒了，则让 cv.count 减一，表示等待此条件的睡眠进程个数少了一个，可继续执行了！

然后来看`signal_cv`的原理实现：

** signal_cv 的原理描述 **

```c
if( cv.count > 0) {
   monitor.next_count ++;
   sem_signal(cv.sem);
   sem_wait(monitor.next);
   monitor.next_count -- ;
}
```

对照着可分析出`cond_signal`函数的具体执行过程。首先进程 B 判断 cv.count，如果不大于 0，则表示当前没有执行 cond_wait 而睡眠的进程，因此就没有被唤醒的对象了，直接函数返回即可；如果大于 0，这表示当前有执行 cond_wait 而睡眠的进程 A，因此需要唤醒等待在 cv.sem 上睡眠的进程 A。由于只允许一个进程在管程中执行，所以一旦进程 B 唤醒了别人（进程 A），那么自己就需要睡眠。故让 monitor.next_count 加一，且让自己（进程 B）睡在信号量 monitor.next 上。如果睡醒了，这让 monitor.next_count 减一。

#### 管程中函数的入口出口设计

为了让整个管程正常运行，还需在管程中的每个函数的入口和出口增加相关操作，即：

```
function_in_monitor （…）
{
  sem.wait(monitor.mutex);
//-----------------------------
  the real body of function;
//-----------------------------
  if(monitor.next_count > 0)
     sem_signal(monitor.next);
  else
     sem_signal(monitor.mutex);
}
```

这样带来的作用有两个，（1）只有一个进程在执行管程中的函数。（2）避免由于执行了 cond_signal 函数而睡眠的进程无法被唤醒。对于第二点，如果进程 A 由于执行了 cond_signal 函数而睡眠（这会让 monitor.next_count 大于 0，且执行 sem_wait(monitor.next)），则其他进程在执行管程中的函数的出口，会判断 monitor.next_count 是否大于 0，如果大于 0，则执行 sem_signal(monitor.next)，从而执行了 cond_signal 函数而睡眠的进程被唤醒。上诉措施将使得管程正常执行。

需要注意的是，上述只是原理描述，与具体描述相比，还有一定的差距。需要大家在完成练习时仔细设计和实现。
