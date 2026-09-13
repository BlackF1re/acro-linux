// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Minimal ARM EABI launcher for the disposable ttyGS0 diagnostic shell.
 *
 * PID 1's ash ignores interactive signals.  POSIX shells preserve inherited
 * SIG_IGN dispositions, so an ash/setsid wrapper cannot restore Ctrl-C.  Keep
 * this freestanding to avoid adding a complete second static libc to the
 * tightly constrained Sony ELF memory layout.
 */

typedef unsigned int u32;
typedef unsigned char u8;

enum {
	NR_exit = 1,
	NR_open = 5,
	NR_close = 6,
	NR_execve = 11,
	NR_ioctl = 54,
	NR_dup2 = 63,
	NR_getpgrp = 65,
	NR_setsid = 66,
	NR_rt_sigaction = 174,
	NR_rt_sigprocmask = 175,
};

enum {
	O_RDWR = 2,
	O_NOCTTY = 0400,
	SIG_SETMASK = 2,
	SIGKILL = 9,
	SIGSTOP = 19,
	NSIG = 65,
	TCGETS = 0x5401,
	TCSETS = 0x5402,
	TIOCSPGRP = 0x5410,
	TIOCSCTTY = 0x540e,
};

enum {
	IGNBRK = 0000001,
	BRKINT = 0000002,
	INLCR = 0000100,
	IGNCR = 0000200,
	ICRNL = 0000400,
	IXON = 0002000,
	IXOFF = 0010000,
	OPOST = 0000001,
	ONLCR = 0000004,
	ISIG = 0000001,
	ICANON = 0000002,
	ECHO = 0000010,
	ECHOE = 0000020,
	ECHOK = 0000040,
	ECHOCTL = 0001000,
	ECHOKE = 0004000,
	IEXTEN = 0100000,
};

enum {
	VINTR = 0,
	VQUIT = 1,
	VERASE = 2,
	VKILL = 3,
	VEOF = 4,
	VSTART = 8,
	VSTOP = 9,
	VSUSP = 10,
	NCCS = 19,
};

struct kernel_sigaction {
	u32 handler;
	u32 flags;
	u32 restorer;
	u32 mask[2];
};

struct kernel_termios {
	u32 iflag;
	u32 oflag;
	u32 cflag;
	u32 lflag;
	u8 line;
	u8 cc[NCCS];
};

static inline long syscall4(long number, long arg0, long arg1, long arg2,
			    long arg3)
{
	register long r0 __asm__("r0") = arg0;
	register long r1 __asm__("r1") = arg1;
	register long r2 __asm__("r2") = arg2;
	register long r3 __asm__("r3") = arg3;
	register long r7 __asm__("r7") = number;

	__asm__ volatile("svc 0"
		: "+r" (r0)
		: "r" (r1), "r" (r2), "r" (r3), "r" (r7)
		: "memory");
	return r0;
}

static inline long syscall3(long number, long arg0, long arg1, long arg2)
{
	return syscall4(number, arg0, arg1, arg2, 0);
}

static inline long syscall2(long number, long arg0, long arg1)
{
	return syscall4(number, arg0, arg1, 0, 0);
}

static inline long syscall1(long number, long arg0)
{
	return syscall4(number, arg0, 0, 0, 0);
}

static inline long syscall0(long number)
{
	return syscall4(number, 0, 0, 0, 0);
}

static __attribute__((noreturn)) void fail(int status)
{
	syscall1(NR_exit, status);
	__builtin_unreachable();
}

void __attribute__((noreturn)) _start(void)
{
	static const char tty[] = "/dev/ttyGS0";
	static const char shell[] = "/bin/sh";
	static char *const argv[] = { (char *)shell, (char *)"-i", 0 };
	static char *const envp[] = {
		(char *)"PATH=/bin:/sbin:/usr/bin:/usr/sbin",
		(char *)"HOME=/",
		(char *)"TERM=linux",
		0,
	};
	struct kernel_sigaction action;
	struct kernel_termios termios;
	u32 empty_mask[2];
	int pgrp;
	int signo;
	int fd;

	fd = syscall3(NR_open, (long)tty, O_RDWR | O_NOCTTY, 0);
	if (fd < 0)
		fail(101);
	if (syscall0(NR_setsid) < 0)
		fail(102);
	if (syscall3(NR_ioctl, fd, TIOCSCTTY, 1) < 0)
		fail(103);
	pgrp = syscall0(NR_getpgrp);
	if (pgrp < 0 || syscall3(NR_ioctl, fd, TIOCSPGRP, (long)&pgrp) < 0)
		fail(104);

	if (syscall3(NR_ioctl, fd, TCGETS, (long)&termios) < 0)
		fail(105);
	termios.iflag &= ~(IGNBRK | INLCR | IGNCR | IXOFF);
	termios.iflag |= BRKINT | ICRNL | IXON;
	termios.oflag |= OPOST | ONLCR;
	termios.lflag |= ISIG | ICANON | IEXTEN | ECHO | ECHOE | ECHOK |
			  ECHOCTL | ECHOKE;
	termios.cc[VINTR] = 3;
	termios.cc[VQUIT] = 28;
	termios.cc[VERASE] = 127;
	termios.cc[VKILL] = 21;
	termios.cc[VEOF] = 4;
	termios.cc[VSTART] = 17;
	termios.cc[VSTOP] = 19;
	termios.cc[VSUSP] = 26;
	if (syscall3(NR_ioctl, fd, TCSETS, (long)&termios) < 0)
		fail(106);

	if (syscall2(NR_dup2, fd, 0) < 0 || syscall2(NR_dup2, fd, 1) < 0 ||
	    syscall2(NR_dup2, fd, 2) < 0)
		fail(107);
	if (fd > 2)
		syscall1(NR_close, fd);

	action.handler = 0;
	action.flags = 0;
	action.restorer = 0;
	action.mask[0] = 0;
	action.mask[1] = 0;
	for (signo = 1; signo < NSIG; signo++) {
		if (signo != SIGKILL && signo != SIGSTOP)
			syscall4(NR_rt_sigaction, signo, (long)&action, 0, 8);
	}
	empty_mask[0] = 0;
	empty_mask[1] = 0;
	if (syscall4(NR_rt_sigprocmask, SIG_SETMASK, (long)empty_mask, 0, 8) < 0)
		fail(108);

	syscall3(NR_execve, (long)shell, (long)argv, (long)envp);
	fail(109);
}
