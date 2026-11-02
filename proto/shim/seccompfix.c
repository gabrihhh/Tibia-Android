// Sobrevive ao filtro seccomp que o Android aplica aos processos de app.
//
// Chamadas de sistema fora da lista do Android geram SIGSYS (SECCOMP_RET_TRAP) e
// matam o processo. O glibc moderno usa algumas delas (e tem alternativa quando
// a chamada devolve ENOSYS). Aqui tratamos o SIGSYS: devolvemos -ENOSYS no
// registrador de retorno e o programa segue. Com SECCOMPFIX_LOG=1 registra o
// número de cada chamada bloqueada no stderr.
//
// Carregado com: ld-linux-aarch64.so.1 --preload libseccompfix.so <programa>
#define _GNU_SOURCE
#include <errno.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <ucontext.h>
#include <unistd.h>

static int log_enabled;

static void put_num(char *buf, int *len, long v)
{
    char tmp[24];
    int n = 0;
    if (v < 0) {
        buf[(*len)++] = '-';
        v = -v;
    }
    do {
        tmp[n++] = '0' + v % 10;
        v /= 10;
    } while (v);
    while (n) buf[(*len)++] = tmp[--n];
}

static void on_sigsys(int sig, siginfo_t *info, void *ctx)
{
    ucontext_t *uc = ctx;
    uc->uc_mcontext.regs[0] = (unsigned long)-ENOSYS;  // retorno da syscall (x0)
    if (log_enabled) {
        char buf[64] = "[seccompfix] syscall bloqueada: ";
        int len = strlen(buf);
        put_num(buf, &len, info->si_syscall);
        buf[len++] = '\n';
        write(2, buf, len);
    }
}

__attribute__((constructor)) static void install(void)
{
    log_enabled = getenv("SECCOMPFIX_LOG") != NULL;
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = on_sigsys;
    sa.sa_flags = SA_SIGINFO | SA_NODEFER;
    sigaction(SIGSYS, &sa, NULL);
}
