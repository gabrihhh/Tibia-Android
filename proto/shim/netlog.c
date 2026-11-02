// Diagnóstico: registra em $TIBIA_NETLOG os corpos JSON que o cliente envia
// (QNetworkAccessManager::post) e lê (QIODevice::readAll) da rede.
// Mascara os valores de "password", "sessionkey", "email" e "token" antes de gravar.
// Uso só para depuração: BOX64_LD_PRELOAD=.../libnetlog.so
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Layout do QByteArray no Qt 6 (x86_64): ponteiro de dados, ponteiro, tamanho
struct QByteArray {
    void *d;
    char *ptr;
    long size;
};

static void mask_field(char *s, const char *key)
{
    for (char *p = strstr(s, key); p; p = strstr(p + 1, key)) {
        char *q = strchr(p + strlen(key), '"');  // aspa de abertura do valor
        if (!q)
            return;
        for (q++; *q && *q != '"'; q++)
            *q = '*';
    }
}

static void log_body(const char *tag, const char *data, long size)
{
    const char *path = getenv("TIBIA_NETLOG");
    if (!path || !data || size <= 0 || data[0] != '{')
        return;  // só JSON
    long n = size < 4000 ? size : 4000;
    char *copy = malloc(n + 1);
    if (!copy)
        return;
    memcpy(copy, data, n);
    copy[n] = '\0';
    mask_field(copy, "\"password\"");
    mask_field(copy, "\"sessionkey\"");
    mask_field(copy, "\"email\"");
    mask_field(copy, "\"token\"");
    FILE *f = fopen(path, "a");
    if (f) {
        fprintf(f, "== %s (%ld bytes)\n%s\n", tag, size, copy);
        fclose(f);
    }
    free(copy);
}

// QByteArray QIODevice::readAll() — retorno via ponteiro oculto (sret)
struct QByteArray *_ZN9QIODevice7readAllEv(struct QByteArray *ret, void *self)
{
    static struct QByteArray *(*real)(struct QByteArray *, void *);
    if (!real)
        real = dlvsym(RTLD_NEXT, "_ZN9QIODevice7readAllEv", "Qt_6");
    real(ret, self);
    log_body("resposta", ret->ptr, ret->size);
    return ret;
}

// QNetworkReply *QNetworkAccessManager::post(const QNetworkRequest &, const QByteArray &)
void *_ZN21QNetworkAccessManager4postERK15QNetworkRequestRK10QByteArray(void *self, void *req,
                                                                          const struct QByteArray *data)
{
    static void *(*real)(void *, void *, const struct QByteArray *);
    if (!real)
        real = dlvsym(RTLD_NEXT, "_ZN21QNetworkAccessManager4postERK15QNetworkRequestRK10QByteArray", "Qt_6");
    log_body("envio", data->ptr, data->size);
    return real(self, req, data);
}
