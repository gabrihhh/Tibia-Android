// Testa as interceptações de stat64/lstat64/statx/open64 da shim sob o box64.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
int main(void) {
    printf("dlvsym statx=%p lstat64=%p stat64=%p\n", dlvsym(RTLD_NEXT, "statx", "GLIBC_2.28"),
           dlvsym(RTLD_NEXT, "lstat64", "GLIBC_2.33"), dlvsym(RTLD_NEXT, "stat64", "GLIBC_2.33"));
    struct stat64 st; struct statx sx;
    printf("stat64 bundle: %d\n", stat64("/etc/pki/tls/certs/ca-bundle.crt", &st));
    printf("lstat64 bundle: %d\n", lstat64("/etc/pki/tls/certs/ca-bundle.crt", &st));
    printf("statx bundle: %d size=%llu\n", statx(AT_FDCWD, "/etc/pki/tls/certs/ca-bundle.crt", 0, STATX_SIZE, &sx), (unsigned long long)sx.stx_size);
    int fd = open("/etc/pki/tls/certs/ca-bundle.crt", O_RDONLY);
    printf("open bundle fd=%d\n", fd);
    return 0;
}
