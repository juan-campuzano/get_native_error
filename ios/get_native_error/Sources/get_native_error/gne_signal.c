#include "gne_signal.h"

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#ifdef __ANDROID__
#include <sys/syscall.h>
#endif

#if defined(__APPLE__)
#include <pthread.h>
#endif

#define GNE_ALT_STACK_SIZE (64 * 1024)
#define GNE_PATH_MAX 1024
#define GNE_JSON_MAX 4096
#define GNE_MAX_FRAMES 32
#define GNE_SIGNAL_COUNT 6

static char g_altstack[GNE_ALT_STACK_SIZE];
static char g_crash_path[GNE_PATH_MAX];
static char g_platform[32];
static char g_arch[32];
static volatile sig_atomic_t g_handling = 0;

static struct sigaction g_previous[GNE_SIGNAL_COUNT];
static const int k_signals[GNE_SIGNAL_COUNT] = {
    SIGSEGV, SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGTRAP,
};

static const char *gne_arch_name(void) {
#if defined(__aarch64__)
  return "arm64";
#elif defined(__arm__)
  return "arm";
#elif defined(__x86_64__)
  return "x86_64";
#elif defined(__i386__)
  return "x86";
#else
  return "unknown";
#endif
}

static const char *gne_signal_name(int signo) {
  switch (signo) {
    case SIGSEGV:
      return "SIGSEGV";
    case SIGABRT:
      return "SIGABRT";
    case SIGBUS:
      return "SIGBUS";
    case SIGFPE:
      return "SIGFPE";
    case SIGILL:
      return "SIGILL";
    case SIGTRAP:
      return "SIGTRAP";
    default:
      return "UNKNOWN";
  }
}

static int gne_signal_index(int signo) {
  for (int i = 0; i < GNE_SIGNAL_COUNT; ++i) {
    if (k_signals[i] == signo) {
      return i;
    }
  }
  return -1;
}

static size_t gne_append_str(char *buf, size_t off, size_t cap, const char *s) {
  if (s == NULL || off >= cap) {
    return off;
  }
  while (*s && off + 1 < cap) {
    buf[off++] = *s++;
  }
  buf[off] = '\0';
  return off;
}

static size_t gne_append_uint(char *buf, size_t off, size_t cap, unsigned long v) {
  char tmp[32];
  int n = 0;
  if (v == 0) {
    tmp[n++] = '0';
  } else {
    while (v > 0 && n < (int)sizeof(tmp)) {
      tmp[n++] = (char)('0' + (v % 10));
      v /= 10;
    }
  }
  while (n > 0 && off + 1 < cap) {
    buf[off++] = tmp[--n];
  }
  buf[off] = '\0';
  return off;
}

static size_t gne_append_hex(char *buf, size_t off, size_t cap, unsigned long v) {
  static const char k_digits[] = "0123456789abcdef";
  char tmp[2 + sizeof(unsigned long) * 2];
  int n = 0;
  off = gne_append_str(buf, off, cap, "0x");
  if (v == 0) {
    return gne_append_str(buf, off, cap, "0");
  }
  while (v > 0 && n < (int)sizeof(tmp)) {
    tmp[n++] = k_digits[v & 0xf];
    v >>= 4;
  }
  while (n > 0 && off + 1 < cap) {
    buf[off++] = tmp[--n];
  }
  buf[off] = '\0';
  return off;
}

static long gne_tid(void) {
#ifdef __ANDROID__
  return (long)syscall(__NR_gettid);
#elif defined(__APPLE__)
  uint64_t tid = 0;
  pthread_threadid_np(NULL, &tid);
  return (long)tid;
#else
  return (long)getpid();
#endif
}

static int gne_fp_sane(uintptr_t fp, uintptr_t prev) {
  if (fp == 0 || fp == (uintptr_t)-1) {
    return 0;
  }
  if ((fp & 0x7u) != 0) {
    return 0;
  }
  if (prev != 0 && fp <= prev) {
    return 0;
  }
  return 1;
}

static size_t gne_append_stack(char *buf, size_t off, size_t cap) {
  uintptr_t fp = (uintptr_t)__builtin_frame_address(0);
  uintptr_t prev = 0;
  int frames = 0;
  while (frames < GNE_MAX_FRAMES && gne_fp_sane(fp, prev)) {
    uintptr_t *frame = (uintptr_t *)fp;
    uintptr_t lr = frame[1];
    if (frames > 0) {
      off = gne_append_str(buf, off, cap, "\\n");
    }
    off = gne_append_hex(buf, off, cap, (unsigned long)lr);
    prev = fp;
    fp = frame[0];
    frames++;
  }
  return off;
}

static void gne_write_report(int signo, siginfo_t *info) {
  char json[GNE_JSON_MAX];
  size_t off = 0;
  const size_t cap = sizeof(json);
  long timestamp_ms = (long)time(NULL) * 1000L;
  unsigned long fault = 0;
  int code = 0;

  if (g_crash_path[0] == '\0') {
    return;
  }
  if (info != NULL) {
    code = info->si_code;
    fault = (unsigned long)(uintptr_t)info->si_addr;
  }

  off = gne_append_str(json, off, cap, "{\"kind\":\"signal\",\"signal\":\"");
  off = gne_append_str(json, off, cap, gne_signal_name(signo));
  off = gne_append_str(json, off, cap, "\",\"signalNumber\":");
  off = gne_append_uint(json, off, cap, (unsigned long)signo);
  off = gne_append_str(json, off, cap, ",\"code\":");
  off = gne_append_uint(json, off, cap, (unsigned long)(unsigned)code);
  off = gne_append_str(json, off, cap, ",\"faultAddress\":\"");
  off = gne_append_hex(json, off, cap, fault);
  off = gne_append_str(json, off, cap, "\",\"pid\":");
  off = gne_append_uint(json, off, cap, (unsigned long)getpid());
  off = gne_append_str(json, off, cap, ",\"tid\":");
  off = gne_append_uint(json, off, cap, (unsigned long)gne_tid());
  off = gne_append_str(json, off, cap, ",\"platform\":\"");
  off = gne_append_str(json, off, cap, g_platform);
  off = gne_append_str(json, off, cap, "\",\"arch\":\"");
  off = gne_append_str(json, off, cap, g_arch);
  off = gne_append_str(json, off, cap, "\",\"timestampMs\":");
  off = gne_append_uint(json, off, cap, (unsigned long)timestamp_ms);
  off = gne_append_str(json, off, cap, ",\"stackTrace\":\"");
  off = gne_append_stack(json, off, cap);
  off = gne_append_str(json, off, cap, "\"}");

  int fd = open(g_crash_path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
  if (fd < 0) {
    return;
  }
  const char *p = json;
  size_t left = off;
  while (left > 0) {
    ssize_t n = write(fd, p, left);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }
    p += (size_t)n;
    left -= (size_t)n;
  }
  fsync(fd);
  close(fd);
}

static void gne_chain_previous(int signo, siginfo_t *info, void *ucontext) {
  int index = gne_signal_index(signo);
  if (index < 0) {
    signal(signo, SIG_DFL);
    raise(signo);
    return;
  }
  struct sigaction *prev = &g_previous[index];
  if ((prev->sa_flags & SA_SIGINFO) != 0 && prev->sa_sigaction != NULL) {
    prev->sa_sigaction(signo, info, ucontext);
  } else if (prev->sa_handler != NULL && prev->sa_handler != SIG_DFL &&
             prev->sa_handler != SIG_IGN) {
    prev->sa_handler(signo);
  }
  signal(signo, SIG_DFL);
  raise(signo);
}

static void gne_signal_handler(int signo, siginfo_t *info, void *ucontext) {
  if (g_handling) {
    signal(signo, SIG_DFL);
    raise(signo);
    return;
  }
  g_handling = 1;
  gne_write_report(signo, info);
  gne_chain_previous(signo, info, ucontext);
}

void gne_install(const char *crash_file_path, const char *platform) {
  if (crash_file_path == NULL || crash_file_path[0] == '\0') {
    return;
  }
  size_t i = 0;
  while (crash_file_path[i] && i + 1 < sizeof(g_crash_path)) {
    g_crash_path[i] = crash_file_path[i];
    i++;
  }
  g_crash_path[i] = '\0';

  g_platform[0] = '\0';
  if (platform != NULL) {
    i = 0;
    while (platform[i] && i + 1 < sizeof(g_platform)) {
      g_platform[i] = platform[i];
      i++;
    }
    g_platform[i] = '\0';
  }
  i = 0;
  const char *arch = gne_arch_name();
  while (arch[i] && i + 1 < sizeof(g_arch)) {
    g_arch[i] = arch[i];
    i++;
  }
  g_arch[i] = '\0';

  stack_t ss;
  memset(&ss, 0, sizeof(ss));
  ss.ss_sp = g_altstack;
  ss.ss_size = sizeof(g_altstack);
  ss.ss_flags = 0;
  sigaltstack(&ss, NULL);

  struct sigaction action;
  memset(&action, 0, sizeof(action));
  sigfillset(&action.sa_mask);
  action.sa_sigaction = gne_signal_handler;
  action.sa_flags = SA_SIGINFO | SA_ONSTACK;

  for (int s = 0; s < GNE_SIGNAL_COUNT; ++s) {
    struct sigaction old;
    memset(&old, 0, sizeof(old));
    sigaction(k_signals[s], &action, &old);
    int ours = ((old.sa_flags & SA_SIGINFO) != 0 &&
                old.sa_sigaction == gne_signal_handler);
    if (!ours) {
      g_previous[s] = old;
    }
  }
}

void gne_crash_native(void) {
  volatile int *ptr = (volatile int *)NULL;
  *ptr = 0xdead;
}

const char *gne_crash_file_path(void) { return g_crash_path; }
