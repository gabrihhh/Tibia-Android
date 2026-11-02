// Correções de compatibilidade para o cliente do Tibia (Qt6 + QtWebEngine) sob o box64.
//
// 1) Identificação de threads do Qt6.
//
// O Qt (x86_64/glibc) obtém o ID da thread atual lendo %fs:0x10 (o campo
// "self" do TCB), que no glibc nativo é igual a pthread_self(). O QThread
// guarda como ID o pthread_t devolvido por pthread_create(). Sob o box64 esses
// dois valores são diferentes, então QThread::isCurrentThread() sempre falha:
// a QQmlThread acha que é outra thread, manda mensagem para si mesma e trava.
//
// Aqui gravamos pthread_self() em %fs:0x10 na thread principal (ao carregar)
// e em toda thread criada via pthread_create(), antes de rodar o código dela.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>

typedef int (*create_fn)(pthread_t *, const pthread_attr_t *, void *(*)(void *), void *);

struct start_arg {
    void *(*fn)(void *);
    void *arg;
};

static void fix_current_thread(void)
{
    pthread_t self = pthread_self();
    __asm__ volatile("mov %0, %%fs:0x10" : : "r"(self) : "memory");
}

static void *start_wrapper(void *p)
{
    struct start_arg a = *(struct start_arg *)p;
    free(p);
    fix_current_thread();
    return a.fn(a.arg);
}

static void init_shm_dir(void);

__attribute__((constructor)) static void init(void)
{
    fix_current_thread();
    init_shm_dir();
}

static int create_common(create_fn real, pthread_t *t, const pthread_attr_t *attr,
                         void *(*fn)(void *), void *arg)
{
    struct start_arg *a = malloc(sizeof(*a));
    if (!a)
        return real(t, attr, fn, arg);
    a->fn = fn;
    a->arg = arg;
    int r = real(t, attr, start_wrapper, a);
    if (r)
        free(a);
    return r;
}

// O Qt importa pthread_create@GLIBC_2.34; binários mais antigos usam @GLIBC_2.2.5.
int pthread_create_234(pthread_t *t, const pthread_attr_t *attr, void *(*fn)(void *), void *arg)
{
    static create_fn real;
    if (!real)
        real = (create_fn)dlvsym(RTLD_NEXT, "pthread_create", "GLIBC_2.34");
    return create_common(real, t, attr, fn, arg);
}

int pthread_create_225(pthread_t *t, const pthread_attr_t *attr, void *(*fn)(void *), void *arg)
{
    static create_fn real;
    if (!real)
        real = (create_fn)dlvsym(RTLD_NEXT, "pthread_create", "GLIBC_2.2.5");
    return create_common(real, t, attr, fn, arg);
}

__asm__(".symver pthread_create_234, pthread_create@@GLIBC_2.34");
__asm__(".symver pthread_create_225, pthread_create@GLIBC_2.2.5");

// O box64 repassa o sysconf() do glibc ARM64, onde _SC_THREAD_STACK_MIN vale
// 128 KiB; no x86_64 vale 16 KiB, e o Chromium (QtWebEngine) faz CHECK disso.
typedef long (*sysconf_fn)(int);

static long fixed_sysconf(const char *sym, sysconf_fn *real, int name)
{
    if (name == _SC_THREAD_STACK_MIN)
        return 16384;
    if (!*real)
        *real = (sysconf_fn)dlvsym(RTLD_NEXT, sym, "GLIBC_2.2.5");
    return (*real)(name);
}

long sysconf(int name)
{
    static sysconf_fn real;
    return fixed_sysconf("sysconf", &real, name);
}

// O Chromium chama a variante interna __sysconf.
long __sysconf(int name)
{
    static sysconf_fn real;
    return fixed_sysconf("__sysconf", &real, name);
}

// 3) Caminhos de sistema que não existem no Android.
//
// - O Chromium cria memória compartilhada com mkstemp() em /dev/shm, que não
//   existe no Android (mas o box64 responde que existe): /dev/shm/... vira
//   $TMPDIR/shm/...
// - O Qt procura os certificados raiz em caminhos fixos; um deles é o arquivo
//   /etc/pki/tls/certs/ca-bundle.crt, que redirecionamos para $TIBIA_CA_BUNDLE.
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

static char shm_dir[512];

static void init_shm_dir(void)
{
    const char *tmp = getenv("TMPDIR");
    snprintf(shm_dir, sizeof(shm_dir), "%s/shm", tmp && *tmp ? tmp : "/tmp");
    mkdir(shm_dir, 0700);
}

// Devolve o caminho a usar (redirecionado em buf, ou o próprio path).
static const char *shm_path(const char *path, char *buf, size_t n)
{
    if (!path)
        return path;
    if (strncmp(path, "/dev/shm", 8) == 0 && (path[8] == '\0' || path[8] == '/')) {
        snprintf(buf, n, "%s%s", shm_dir, path + 8);
        return buf;
    }
    if (strcmp(path, "/etc/pki/tls/certs/ca-bundle.crt") == 0) {
        const char *bundle = getenv("TIBIA_CA_BUNDLE");
        if (bundle && *bundle)
            return bundle;
    }
    return path;
}

#define REAL(name, ver) \
    static __typeof__(name) *real_##name; \
    if (!real_##name) real_##name = (__typeof__(name) *)dlvsym(RTLD_NEXT, #name, ver)

int mkstemp64(char *tmpl)
{
    REAL(mkstemp64, "GLIBC_2.2.5");
    char buf[1024];
    const char *p = shm_path(tmpl, buf, sizeof(buf));
    if (p == tmpl)
        return real_mkstemp64(tmpl);
    int fd = real_mkstemp64(buf);
    if (fd >= 0) {
        // devolve ao chamador o sufixo gerado (os "XXXXXX" do template)
        size_t tl = strlen(tmpl), bl = strlen(buf);
        memcpy(tmpl + tl - 6, buf + bl - 6, 6);
    }
    return fd;
}

int open64(const char *path, int flags, ...)
{
    REAL(open64, "GLIBC_2.2.5");
    mode_t mode = 0;
    if (flags & (O_CREAT | O_TMPFILE)) {
        va_list ap;
        va_start(ap, flags);
        mode = va_arg(ap, mode_t);
        va_end(ap);
    }
    char buf[1024];
    return real_open64(shm_path(path, buf, sizeof(buf)), flags, mode);
}

int __open64_2(const char *path, int flags)
{
    REAL(__open64_2, "GLIBC_2.7");
    char buf[1024];
    return real___open64_2(shm_path(path, buf, sizeof(buf)), flags);
}

int openat64(int dirfd, const char *path, int flags, ...)
{
    REAL(openat64, "GLIBC_2.4");
    mode_t mode = 0;
    if (flags & (O_CREAT | O_TMPFILE)) {
        va_list ap;
        va_start(ap, flags);
        mode = va_arg(ap, mode_t);
        va_end(ap);
    }
    char buf[1024];
    return real_openat64(dirfd, shm_path(path, buf, sizeof(buf)), flags, mode);
}

int unlink(const char *path)
{
    REAL(unlink, "GLIBC_2.2.5");
    char buf[1024];
    return real_unlink(shm_path(path, buf, sizeof(buf)));
}

int unlinkat(int dirfd, const char *path, int flag)
{
    REAL(unlinkat, "GLIBC_2.4");
    char buf[1024];
    return real_unlinkat(dirfd, shm_path(path, buf, sizeof(buf)), flag);
}

int access(const char *path, int mode)
{
    REAL(access, "GLIBC_2.2.5");
    char buf[1024];
    return real_access(shm_path(path, buf, sizeof(buf)), mode);
}

int stat64(const char *path, struct stat64 *st)
{
    REAL(stat64, "GLIBC_2.33");
    char buf[1024];
    return real_stat64(shm_path(path, buf, sizeof(buf)), st);
}

int lstat64(const char *path, struct stat64 *st)
{
    REAL(lstat64, "GLIBC_2.33");
    char buf[1024];
    return real_lstat64(shm_path(path, buf, sizeof(buf)), st);
}

int statx(int dirfd, const char *path, int flags, unsigned int mask, struct statx *st)
{
    REAL(statx, "GLIBC_2.28");
    char buf[1024];
    return real_statx(dirfd, shm_path(path, buf, sizeof(buf)), flags, mask, st);
}
