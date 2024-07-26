---
title: 进程间通信(IPC)
author: Leager
mathjax: true
date: 2023-10-11 11:46:29
summary:
categories: operating system
tags:
img:
---

为了保护操作系统中进程互不干扰，需要使用进程隔离技术，以防不同进程能够修改其他进程数据。但进程之间又不能完全隔离，需要一定的通信手段，于是开发出了**进程间通信(IPC, InterProcess Communication)**技术。

<!--more-->

## 管道(Pipe)

管道是最基本的通信机制，实质是一个半双工的通信方式，即数据只能单向流通，每次从头读取，向尾写入，并且遵循 **FIFO(First In First Out)** 原则，以**字节流**的方式进行传输，就仿佛一个单向队列。并且管道双方必须均处于“在线”状态，一旦一方退出，另一方也自动断开。

> 如果双方相互通信时，则需要建立两个管道。

根据**是否存在于文件系统**中，又可将管道分为**匿名管道**和**命名管道**两种。

> “**名**”指的就是路径名啦。

### 匿名管道

Linux 中可以通过函数 `int pipe(int fd[2])` 建立匿名管道，其中 `fd[0]` 为读取端，`fd[1]` 为写入端，两个都是**文件描述符**，从而可以用 `read()/write()` 系统调用进行数据传输。比如下面这段代码：

```C
#include<stdio.h>
#include<unistd.h>
#include<string.h>

int main() {
  int fd[2];
  int ret = pipe(fd); // ret>=0 for success, ret<0 for fail
  if (ret < 0) {
    printf("Pipe Create Failed!\n");
  }

  pid_t id = fork();
  if (id < 0) {
    printf("Fork Failed\n");
  } else if(id == 0) {
    close(fd[0]); // 关闭读取才能写入
    int i = 0;
    char* msg = "I'm child";
    while(i++ < 100) {
      write(fd[1], msg, strlen(msg));
      sleep(1);
    }
  } else {
    close(fd[1]); // 关闭写入才能读取
    int i = 0;
    char msg[100];
    while(i++ < 100) {
      memset(msg, '\0', sizeof(msg));
      read(fd[0], msg, sizeof(msg));
      printf("%s\n", msg);
    }
  }

  return 0;
}
```

事实上，匿名管道并**不**位于文件系统中，它本质上是一个位于**内核空间**中的缓冲区，只不过将两端以“文件”的形式提供了数据读写的渠道。如果缓冲区已满，则阻塞写入；如果缓冲区为空，则阻塞读取。

<img src="1.png"/>

同时，读写端的文件描述符仅仅位于通信双方公共祖先进程的地址空间内部，也是因为如此，匿名管道仅适用于**父子进程**这种有“亲缘关系”（或称相关）的进程之间的通信，而无法跨进程通信。

> 毕竟调用 `fork()` 会进行一次完整的拷贝操作，也就会复制该 `fd[]`。

同样，一旦进程销毁，该管道也随之被销毁。也就是说，匿名管道的**生命周期完全由进程决定**。

### 命名管道

那么为了实现跨进程通信，不如就把上文中的缓冲区改为实际的文件，令其位于文件系统中，这样一来只要知道该**管道文件**的路径，就可以在任何进程之间进行通信了。

Linux 中可以通过函数 `int mkfifo(const char *path, mode_t mode)` 建立命名管道，其中 `path` 指明文件路径，`mode` 指明管道文件的存取权限。比如下面这段代码：

```C
/* server.c */
#include<stdio.h>
#include<unistd.h>
#include<string.h>
#define _PATH_NAME_ "/tmp/file.tmp"
#define _SIZE_  100

int main() {
  int ret = mkfifo(_PATH_NAME_, S_IFIFO | 0666);
  if (ret == -1) {
    printf("Make File Error\n");
    return -1;
  }

  char buf[_SIZE_] = {0};
  int fd = open(_PATH_NAME_, O_WRONLY);
  while (true) {
    fget(buf, sizeof(buf)-1, stdin);
    int ret = write(fd, buf, strlen(buf)+1);
    if (ret < 0) {
      printf("Write Error\n");
      break;
    }
  }
  close(fd);

  return 0;
}
```

```C
/* client.c */
#include<stdio.h>
#include<unistd.h>
#include<string.h>
#define _PATH_NAME_ "/tmp/file.tmp"
#define _SIZE_  100

int main() {
  int fd = open(_PATH_NAME_, O_RDONLY);
  if (fd < 0) {
    printf("Open File Error\n");
    return 1;
  }

  char buf[_SIZE_] = {0};
  while (true) {
    int ret = read(fd, buf, sizeof(buf));
    if (ret < 0) {
      printf("Read Error\n");
      break;
    }
    printf("%s\n", buf);
  }
  close(fd);

  return 0;
}
```

服务端利用系统函数 `mkfifo()` 创建一个名为 `file.tmp` 的文件作为管道并写入。客户端同样也能打开该文件进行读取。而它们却是无关进程。

## 信号(Signal)

信号是一种软中断，采用异步通信方式，内核可以利用信号来通知用户进程发生了哪些系统事件，一般源于**硬件方式**（用户按下 `Ctrl+C` 键）或**软件方式**（系统调用产生信号）

Linux 中共定义了 64 种信号，分为以下两种：

1. **不可靠信号**：不支持排队，信号可能会丢失，发送多次相同的信号，进程只能收到一次. 信号值取值区间为 1~31；
2. **可靠信号**：支持排队，信号不会丢失，发多少次，就可以收到多少次，信号值取值区间为 32~64；

### 常见信号

|         信号         |                                           描述                                           |
| :------------------: | :--------------------------------------------------------------------------------------: |
|      **SIGHUP**      |   用户从终端注销，所有已启动进程都将收到该进程。系统缺省状态下对该信号的处理是终止进程   |
|      **SIGINT**      |                 程序终止信号。程序运行过程中，按 `Ctrl+C` 键将产生该信号                 |
|     **SIGQUIT**      |                 程序退出信号。程序运行过程中，按 `Ctrl+\` 键将产生该信号                 |
| **SIGBUS / SIGSEGV** |                                     进程访问非法地址                                     |
|      **SIGFPE**      |                        运算中出现致命错误，如除零操作、数据溢出等                        |
|     **SIGKILL**      |                     用户终止进程执行信号。执行 `kill -9` 发送该信号                      |
|     **SIGTERM**      |                         结束进程信号。执行 `kill pid` 发送该信号                         |
|     **SIGALRM**      |                                        定时器信号                                        |
|     **SIGCHLD**      | 子进程退出信号。如果其父进程没有忽略该信号也没有处理该信号，则子进程退出后将形成僵尸进程 |

### Linux 信号相关数据结构

Linux 在进程管理结构 `task_struct` 中定义了信号相关的变量。

```C
struct task_struct {
  ...
  int sigpending; // 是否有待处理信号
  ...
  struct signal_struct *sig; // 定义了信号值对应的处理方法
  sigset_t blocked;          // 被屏蔽的信息，以 bit 表示
  struct sigpending pending; // 待处理信号队列
  ...
}
```

```C
#define  _NSIG  64

struct signal_struct {
  atomic_t count;
  struct k_sigaction action[_NSIG]; // 信号处理函数表
  spinlock_t siglock;
};

typedef void (*__sighandler_t)(int);

struct sigaction {
  __sighandler_t sa_handler; // 处理函数
  unsigned long sa_flags;
  void (*sa_restorer)(void);
  sigset_t sa_mask;
};

struct k_sigaction {
  struct sigaction sa;
};

struct sigqueue {
  struct sigqueue *next;
  siginfo_t info;
};

struct sigpending {
  struct sigqueue *head, **tail;
  sigset_t signal;
};
```

### 信号发送流程

以 `kill()` 为例，其函数原型为 `int kill(pid_t pid, int sig)`。

当源进程(src)调用 `kill()` 打算将目标进程(dst)给杀掉时，该系统调用会进一步调用内核函数 `sys_kill()`：

```C
asmlinkage long
sys_kill(int pid, int sig)
{
  struct siginfo info;

  info.si_signo = sig;
  info.si_errno = 0;
  info.si_code = SI_USER;
  info.si_pid = current->pid;
  info.si_uid = current->uid;

  return kill_something_info(sig, &info, pid);
}

static int kill_something_info(int sig, struct siginfo *info, int pid)
{
  if (!pid) {
    return kill_pg_info(sig, info, current->pgrp);
  } else if (pid == -1) {
    int retval = 0, count = 0;
    struct task_struct * p;
    read_lock(&tasklist_lock);
    for_each_task(p) {
      if (p->pid > 1 && p != current) {
        int err = send_sig_info(sig, info, p);
        ++count;
        if (err != -EPERM)
          retval = err;
      }
    }
    read_unlock(&tasklist_lock);
    return count ? retval : -ESRCH;
  } else if (pid < 0) {
    return kill_pg_info(sig, info, -pid);
  } else {
    return kill_proc_info(sig, info, pid);
  }
}
```

从函数 `kill_something_info()` 可以得知，信号发送后具体的处理流程与 dst 的 `pid` 有很大关系，具体为：

1. `pid > 0` 时：直接发送给 `pid` 对应的进程；
2. `pid = 0` 时：发送给所有与 src 属同一个使用组的进程；
3. `pid = -1` 时：发送给 src 有权给其发送信号的所有进程，除了进程 1(init);
4. `pid < -1` 时：发送给 -pid 为组标识的进程；

这里只讨论第一种情况。当 pid>0 时，调用 `kill_proc_info()` 函数，通过 `send_sig_info()` 发送信号。

```C
inline int
kill_proc_info(int sig, struct siginfo *info, pid_t pid)
{
  int error;
  struct task_struct *p;

  read_lock(&tasklist_lock);
  p = find_task_by_pid(pid); // 获得 pid 对应的 task_struct
  error = -ESRCH;
  if (p) {
    error = send_sig_info(sig, info, p);
  }
  read_unlock(&tasklist_lock);
  return error;
}

int
send_sig_info(int sig, struct siginfo *info, struct task_struct *t)
{
  unsigned long flags;
  int ret;

  ret = -EINVAL;
  if (sig < 0 || sig > _NSIG)
    goto out_nolock;

  ret = -EPERM;
  if (bad_signal(sig, info, t)) // 检查是否有权限发送，没有就直接返回
    goto out_nolock;

  ret = 0;
  if (!sig || !t->sig)
    goto out_nolock;

  spin_lock_irqsave(&t->sigmask_lock, flags);
  handle_stop_signal(sig, t)

  if (ignored_signal(sig, t)) // 是否忽略该信号，是就不发送
    goto out;

  if (sig < SIGRTMIN && sigismember(&t->pending.signal, sig)) // 不可靠信号如果已经在等待队列中，就不会再次入队
    goto out;

  ret = deliver_signal(sig, info, t); // 发送信号，并将 task_struct.pending 置为 1
out:
  spin_unlock_irqrestore(&t->sigmask_lock, flags);
  if ((t->state & TASK_INTERRUPTIBLE)&& signal_pending(t)) // 如果处于睡眠可中断状态且有信号待处理，将其唤醒
    wake_up_process(t);

out_nolock:
  return ret;
}
```

至此，发送信号的流程已完成。

### 信号处理流程

此时此刻信号已经发送给目标进程，为了尽快让信号得到处理，Linux 把信号处理过程放置在进程**从内核态返回到用户态前**，也就是操作系统决定调度目标进程的时候，然后检查 `sigpending` 是否为 1，若是，就调用 `do_signal()` 函数进行处理。

```C
int do_signal(struct pt_regs *regs, sigset_t *oldset)
{
  siginfo_t info;
  struct k_sigaction *ka;

  if ((regs->xcs & 3)!= 3)
    return 1;

  if (!oldset)
    oldset = &current->blocked;

  for (;;) {
    unsigned long signr;

    // 不断对信号队列进行 dequeue 取出头部，如果没有可取的就直接退出
    spin_lock_irq(&current->sigmask_lock);
    signr = dequeue_signal(&current->blocked, &info);
    spin_unlock_irq(&current->sigmask_lock);
    if (!signr)
      break;

    ka = &current->sig->action[signr-1];
    if (ka->sa.sa_handler == SIG_IGN) { // ignore. 即如果忽视就直接跳过
      if (signr != SIGCHLD)
        continue;

      /* Check for SIGCHLD: it's special.  */
      while (sys_wait4(-1, NULL, WNOHANG, NULL)> 0)
        /* nothing */;

      continue;
    }

    if (ka->sa.sa_handler == SIG_DFL) { // default. 即指定为默认就用系统的默认处理方法
      int exit_code = signr;

      /* Init gets no signals it doesn't want.  */
      if (current->pid == 1)
        continue;

      switch (signr) {
      case SIGCONT: case SIGCHLD: case SIGWINCH:
        continue;

      case SIGTSTP: case SIGTTIN: case SIGTTOU:
        if (is_orphaned_pgrp(current->pgrp))
          continue;
        /* FALLTHRU */

      case SIGSTOP:
        current->state = TASK_STOPPED;
        current->exit_code = signr;
        if (!(current->p_pptr->sig->action[SIGCHLD-1].sa.sa_flags & SA_NOCLDSTOP))
          notify_parent(current, SIGCHLD);
        schedule();
        continue;

      case SIGQUIT: case SIGILL: case SIGTRAP:
      case SIGABRT: case SIGFPE: case SIGSEGV:
      case SIGBUS: case SIGSYS: case SIGXCPU: case SIGXFSZ:
        if (do_coredump(signr, regs))
          exit_code |= 0x80;
        /* FALLTHRU */

      default:
        sigaddset(&current->pending.signal, signr);
        recalc_sigpending(current);
        current->flags |= PF_SIGNALED;
        do_exit(exit_code);
        /* NOTREACHED */
      }
    }
    ...
    handle_signal(signr, ka, &info, oldset, regs); // 如果通过 signal() 注册了自定义处理方法，就用 handle_signal() 去处理
    return 1;
  }
  ...
  return 0;
}
```

> 值得注意的是，用户定义的处理方法代码位于用户态，而在运行这段系统函数期间 CPU 还处于内核态，只能先返回用户态执行用户态代码，再回到内核态做后续工作。所以信号处理的开销还是蛮大的。

### 总结

发送进程通过 `sys_*()` 系统调用，将信号信息打包放到目标进程的 `task_struct` 中，下次操作系统调度进程时，检查这个进程是否有待处理的信号，如果有则先进行信号处理，之后在回到用户态继续执行之前的指令。

## 消息队列(Msg Queue)

管道的一个劣势在于，数据都是以字节流进行传输，没有格式一说，这就要求管道的读取方和写入方必须事先约定好数据的格式与长度，比如多少字节算作一个消息/命令/记录等等。

为了打破这一限制，诞生了消息队列。其本质上是内核中的链表，每个节点是一个具有**特定格式**的消息，和 C++ 中的 `std::list<Message>` 很像。不同的队列以不同的**队列标识符(qid)**来区分，只有内核重启或显式删除后相关队列才会被移除。

和管道相同之处在于，如果管道/队列存放的数据/消息满了，写会被阻塞，读同理。

不同之处在于，虽然写都是写到末尾，但是消息队列可以根据消息字段**随机读取**，而不一定要从队首。并且，消息队列允许多个进程对其读写。

### 消息队列使用

```C
/* writer.c */
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/msg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

struct msgbuf { // 待写入消息节点数据结构，必须以 long 类型变量开始
	long mtype;
	char mtext[255];
};

int main() {
	int mq_id = msgget(123, IPC_CREAT | 0666); // 创建一个消息队列
	if (mq_id != -1) {
		// 初始化要发生的消息
		struct msgbuf mybuf;
		mybuf.mtype = 1;
		strcpy(mybuf.mtext, "I'm send process.\n");

		// 发送消息
		if (msgsnd(mq_id, &mybuf, sizeof(mybuf.mtext), 0)) {
			printf("success\n");
    }
		else {
      printf("msgsnd Fail\n");
    }
	} else {
		printf("msgget Fail\n");
	}

	return 0;
}
```

```C
/* reader.c */
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/msg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

struct msgbuf { // 待读取消息节点数据结构，必须与消息队列节点格式一致
	long mtype;
	char mtext[255];
};

int main() {
	int mq_id = msgget(123, IPC_CREAT | 0666); // 获取消息队列
	if (mq_id != -1) {
		struct msgbuf mybuf;
		// 接收第一条消息，存到 mybuf 中
		if (msgrcv(mq_id, &mybuf, sizeof(mybuf.mtext), 0, IPC_NOWAIT) != -1) {
			printf("read success: %s\n", mybuf.mtext);
			// 删除这个消息队列
			if (msgctl(mq_id, IPC_RMID, 0) != -1){
				printf("delete msg success\n");
      }
		} else {
			printf("msgsnd Fail\n");
		}

	} else {
		printf("msgget Fail\n");
	}

	return 0;
}
```

## 共享内存(Shared Memory)

共享内存是指将同一片内存映射到多个进程的虚拟地址空间，进程就可以直接读写这一块内存而不需要进行数据的拷贝，从而大大提高效率。

当然，建立共享内存的过程无需进行数据复制，直接在内存中操作，是最快的可用通信机制。然而还需要一些信号量提供同步/互斥手段，否则会出现一致性的问题。

> 管道、消息队列都需要将进程内部数据复制到内核空间/磁盘

目前 Linux 系统有以下三种共享内存方案：

1. mmap 内存共享映射；
2. XSI 共享内存；
3. POSIX 共享内存；

### mmap 共享内存

mmap 本来的是存储映射功能。它可以将一个文件映射到内存中，在程序里就可以直接使用内存地址对文件内容进行访问，这可以让程序对文件访问更方便。

```C
#include <sys/mman.h>

// 通过设置 fd，就可以映射到文件，返回值是相应的内存地址。
void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);

// 移除地址 addr 上的共享内存
int munmap(void *addr, size_t length);
```

由于这个系统调用的特性可以用在很多场合，所以 Linux 系统用它实现了很多功能，并不仅局限于存储映射，还可以进行共享内存，只需令 `mmap()` 中 `flags = MAP_SHARED|MAP_ANONYMOUS, fd = -1`。这样一来，配合 `fork()`，父子进程都可以获取相同的 `mmap()` 返回的共享内存地址，从而实现通信。样例代码如下：

```C
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/file.h>
#include <wait.h>
#include <sys/mman.h>

#define COUNT 100

int do_child(int *count)
{
	int interval;

	/* critical section */
	interval = *count;
	interval++;
	usleep(1);
	*count = interval;
	/* critical section */

	exit(0);
}

int main()
{
	pid_t pid;
	int count;
	int *shm_p;

	shm_p = (int *)mmap(NULL, sizeof(int), PROT_WRITE|PROT_READ, MAP_SHARED|MAP_ANONYMOUS, -1, 0);
	if (MAP_FAILED == shm_p) {
		perror("mmap()");
		exit(1);
	}
	
	*shm_p = 0;

	for (count = 0; count < COUNT; count++) {
		pid = fork();
		if (pid < 0) {
			perror("fork()");
			exit(1);
		}

		if (pid == 0) {
			do_child(shm_p);
		}
	}

	for (count=0;count<COUNT;count++) {
		wait(NULL);
	}

	printf("shm_p: %d\n", *shm_p);
	munmap(shm_p, sizeof(int));
	exit(0);
}
```

### XSI 共享内存

mmap 实现共享内存的方式需要 `fork()` 配合，只能支持相关进程。XSI 采取更为通用的手段，能够支持无关进程。

```C
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/types.h>
#include <sys/ipc.h>

// 根据指定文件的 inode 编号和文件所在设备的设备编号来生成 key
key_t ftok(const char *pathname, int proj_id);

// 根据 key 生成/获取共享内存标识符 shmid
// Linux 限制了系统最大能创建的共享内存为 128 个
int shmget(key_t key, size_t size, int shmflg);

// 将 {虚拟地址: 物理地址} 的映射绑定到进程内，并令该共享内存的 `shm_nattach` 计数器加一
void *shmat(int shmid, const void *shmaddr, int shmflg);

// 移除映射，并令该共享内存的 `shm_nattach` 计数器减一
int shmdt(const void *shmaddr);

// 执行控制命令，如进行删除
int shmctl(int shmid, int cmd, struct shmid_ds *buf);
```

但根据管道的经验，无关进程之间的通信能且仅能通过文件来实现，每次根据 `path` 打开一个文件，进程内部都有一个文件描述符 `fd` 来指向该文件，从而进行操作。XSI 就是根据这个思路来设计的，`key` 对应了 `path`，`shmid` 对应了 `fd`。之所以说**对应**，是因为并不是真正的文件描述符，无法使用 `open()/write()` 这样的系统调用对其执行操作。事实上，内核里有一张名为 `shm_segs[]` 的表来存放共享内存相关信息，并根据 `shmid` 来索引。只要 `ftok` 的参数是一样的，那么生成的 `key` 也必然是一样且唯一的，根据 `shmget()` 得到的 `shmid` 也是唯一的，这就实现了任意进程能够对共享内存进行访问。样例代码如下：

```C
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/file.h>
#include <wait.h>
#include <sys/mman.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/types.h>

#define COUNT 100
#define PATHNAME "/etc/passwd"

int do_child(int proj_id)
{
	int interval;
	int *shm_p, shm_id;
	key_t shm_key;
	// 使用 ftok() 产生shmkey
	if ((shm_key = ftok(PATHNAME, proj_id)) == -1) {
		perror("ftok()");
		exit(1);
	}

	// 在子进程中获取到已经在父进程中创建好的 shmid
	shm_id = shmget(shm_key, sizeof(int), 0);
	if (shm_id < 0) {
		perror("shmget()");
		exit(1);
	}
	
	// 将相关共享内存段映射到本进程的内存地址
	shm_p = (int *)shmat(shm_id, NULL, 0);
	if ((void *)shm_p == (void *)-1) {
		perror("shmat()");
		exit(1);
	}

	/* critical section */
	interval = *shm_p;
	interval++;
	usleep(1);
	*shm_p = interval;
	/* critical section */

	// 解除本进程内对共享内存的地址映射
	if (shmdt(shm_p) < 0) {
		perror("shmdt()");
		exit(1);
	}

	exit(0);
}

int main()
{
	pid_t pid;
	int count;
	int *shm_p;
	int shm_id, proj_id;
	key_t shm_key;

	proj_id = 1234;
	
	// 使用约定好的文件路径和 proj_id 产生 shm_key
	if ((shm_key = ftok(PATHNAME, proj_id)) == -1) {
		perror("ftok()");
		exit(1);
	}

	// 创建一个共享内存，如果系统中已经存在此共享内存则报错退出，创建出来的共享内存权限为 0600(-rw-------)
	shm_id = shmget(shm_key, sizeof(int), IPC_CREAT|IPC_EXCL|0600);
	if (shm_id < 0) {
		perror("shmget()");
		exit(1);
	}

	// 绑定映射
	shm_p = (int *)shmat(shm_id, NULL, 0);
	if ((void *)shm_p == (void *)-1) {
		perror("shmat()");
		exit(1);
	}


	*shm_p = 0;

	// 并发读写
	for (count = 0; count < COUNT; count++) {
		pid = fork();
		if (pid < 0) {
			perror("fork()");
			exit(1);
		}

		if (pid == 0) {
			do_child(proj_id);
		}
	}
	
	// 等待所有子进程执行完毕
	for (count = 0; count < COUNT; count++) {
		wait(NULL);
	}

	// 解除映射
	if (shmdt(shm_p) < 0) {
		perror("shmdt()");
		exit(1);
	}

	// 删除共享内存
	if (shmctl(shm_id, IPC_RMID, NULL) < 0) {
		perror("shmctl()");
		exit(1);
	}

	exit(0);
}
```

### POSIX 共享内存

POSIX 共享内存本质上就是在 `/dev/shm` 上创建一个文件，并将其 mmap 之后映射其内存地址。

## 套接字(Socket)