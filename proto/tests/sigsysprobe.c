// Diagnóstico: roda um programa sob ptrace e, a cada SIGSYS (chamada bloqueada
// pelo seccomp do Android), imprime o número da syscall (registrador x8).
// Uso: sigsysprobe <programa> [args...]
#include <elf.h>
#include <signal.h>
#include <stdio.h>
#include <sys/ptrace.h>
#include <sys/uio.h>
#include <sys/wait.h>
#include <unistd.h>

struct regs {
    unsigned long x[31], sp, pc, pstate;
};

int main(int argc, char **argv)
{
    pid_t pid = fork();
    if (pid == 0) {
        ptrace(PTRACE_TRACEME, 0, 0, 0);
        execv(argv[1], argv + 1);
        perror("execv");
        _exit(127);
    }
    int status, reported = 0;
    while (waitpid(pid, &status, 0) == pid) {
        if (WIFEXITED(status) || WIFSIGNALED(status)) break;
        int sig = WSTOPSIG(status);
        if (sig == SIGTRAP) sig = 0;  // parada do execve
        if (sig == SIGSYS) {
            struct regs r;
            struct iovec iov = {&r, sizeof(r)};
            ptrace(PTRACE_GETREGSET, pid, (void *)NT_PRSTATUS, &iov);
            fprintf(stderr, "[sigsysprobe] syscall bloqueada: %lu (pc=%#lx)\n", r.x[8], r.pc);
            if (++reported > 20) sig = SIGKILL;
        }
        ptrace(PTRACE_CONT, pid, 0, (void *)(long)sig);
    }
    return 0;
}
