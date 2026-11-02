// Converte sockets Unix "@nome" em sockets abstratos (Linux).
//
// O SELinux do Android não deixa o usuário shell criar sockets em arquivo, e o
// virglrenderer (servidor) e o Mesa vtest (cliente) só aceitam caminhos. Com
// LD_PRELOAD desta lib, um caminho que começa com '@' vira o socket abstrato de
// mesmo nome. Compilada duas vezes: bionic (servidor) e glibc ARM64 (cliente,
// com -DCLIENT_ONLY, que só intercepta connect).
//
// No cliente também redireciona o X: o libxcb sempre procura o socket abstrato
// "/tmp/.X11-unix/X<n>", mas dentro de um app o servidor X precisa de um TMPDIR
// gravável (arquivo de trava), então o socket real fica em $TIBIA_X11_DIR.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>

static socklen_t to_abstract(const struct sockaddr *addr, socklen_t len, struct sockaddr_un *out)
{
    const struct sockaddr_un *un = (const struct sockaddr_un *)addr;
    if (!addr || addr->sa_family != AF_UNIX || un->sun_path[0] != '@')
        return 0;
    memset(out, 0, sizeof(*out));
    out->sun_family = AF_UNIX;
    size_t n = strnlen(un->sun_path + 1, sizeof(out->sun_path) - 1);
    memcpy(out->sun_path + 1, un->sun_path + 1, n);  // sun_path[0] fica '\0'
    return offsetof(struct sockaddr_un, sun_path) + 1 + n;
}

#ifndef CLIENT_ONLY
int bind(int fd, const struct sockaddr *addr, socklen_t len)
{
    static int (*real)(int, const struct sockaddr *, socklen_t);
    if (!real)
        real = dlsym(RTLD_NEXT, "bind");
    struct sockaddr_un abs;
    socklen_t n = to_abstract(addr, len, &abs);
    return n ? real(fd, (struct sockaddr *)&abs, n) : real(fd, addr, len);
}
#endif

// "\0/tmp/.X11-unix/X<n>" -> "\0$TIBIA_X11_DIR/.X11-unix/X<n>"
static socklen_t redirect_x11(const struct sockaddr *addr, socklen_t len, struct sockaddr_un *out)
{
    static const char x11[] = "/tmp/.X11-unix/X";
    const struct sockaddr_un *un = (const struct sockaddr_un *)addr;
    const char *dir = getenv("TIBIA_X11_DIR");
    if (!dir || !addr || addr->sa_family != AF_UNIX || un->sun_path[0] != '\0' ||
        strncmp(un->sun_path + 1, x11, sizeof(x11) - 1) != 0)
        return 0;
    memset(out, 0, sizeof(*out));
    out->sun_family = AF_UNIX;
    int n = snprintf(out->sun_path + 1, sizeof(out->sun_path) - 1, "%s/.X11-unix/X%s", dir,
                     un->sun_path + sizeof(x11));
    return offsetof(struct sockaddr_un, sun_path) + 1 + n;
}

int connect(int fd, const struct sockaddr *addr, socklen_t len)
{
    static int (*real)(int, const struct sockaddr *, socklen_t);
    if (!real)
        real = dlsym(RTLD_NEXT, "connect");
    struct sockaddr_un abs;
    socklen_t n = to_abstract(addr, len, &abs);
#ifdef CLIENT_ONLY
    if (!n)
        n = redirect_x11(addr, len, &abs);
#endif
    return n ? real(fd, (struct sockaddr *)&abs, n) : real(fd, addr, len);
}
