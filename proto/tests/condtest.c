// Reproduz o padrão do QWaitCondition do Qt6: cond com CLOCK_MONOTONIC,
// thread principal espera a thread filha sinalizar que iniciou.
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef struct { pthread_mutex_t m; pthread_cond_t c; int waiters, wakeups; } wc_t;
static wc_t *wc;
static volatile int started;

static void wc_init(wc_t *w) {
    pthread_condattr_t a;
    pthread_mutex_init(&w->m, NULL);
    pthread_condattr_init(&a);
    pthread_condattr_setclock(&a, CLOCK_MONOTONIC);
    pthread_cond_init(&w->c, &a);
    pthread_condattr_destroy(&a);
    w->waiters = w->wakeups = 0;
}
static void wc_wait(wc_t *w) {
    pthread_mutex_lock(&w->m);
    w->waiters++;
    while (w->wakeups == 0) pthread_cond_wait(&w->c, &w->m);
    w->waiters--; w->wakeups--;
    pthread_mutex_unlock(&w->m);
}
static void wc_wake(wc_t *w) {
    pthread_mutex_lock(&w->m);
    w->wakeups = w->wakeups + 1 < w->waiters ? w->wakeups + 1 : w->waiters;
    pthread_cond_signal(&w->c);
    pthread_mutex_unlock(&w->m);
}
static void *child(void *arg) {
    struct timespec ts = {0, 50 * 1000 * 1000};
    nanosleep(&ts, NULL);
    started = 1;
    wc_wake(wc);
    return NULL;
}
int main(void) {
    for (int i = 0; i < 200; i++) {
        wc = malloc(sizeof(wc_t));  // malloc como o Qt (alinhamento de heap)
        wc_init(wc);
        started = 0;
        pthread_t t;
        pthread_create(&t, NULL, child, NULL);
        wc_wait(wc);
        pthread_join(t, NULL);
        free(wc);
        if (i % 50 == 0) printf("iter %d ok\n", i), fflush(stdout);
    }
    printf("PASS\n");
    return 0;
}
