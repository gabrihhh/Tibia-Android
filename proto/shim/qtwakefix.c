// Corrige uma corrida do QWaitCondition do Qt6 que aparece sob emulação (box64).
//
// QWaitCondition::wakeOne() só incrementa "wakeups"; quem chegar primeiro em
// wait() consome. No QQmlThread a thread principal acorda a QQmlThread e logo
// volta a esperar na MESMA condição — sob box64 ela chega antes e rouba o
// próprio wakeup, e as duas dormem para sempre.
//
// Aqui interceptamos wakeOne(): chamamos o original e esperamos (no máx. ~5 ms)
// a thread acordada consumir o wakeup antes de devolver o controle.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// Layout do QWaitConditionPrivate (qwaitcondition_unix.cpp, Qt 6, x86_64)
struct QWaitConditionPrivate {
    char mutex[40];  // pthread_mutex_t
    char cond[48];   // pthread_cond_t
    int waiters;
    int wakeups;
};
struct QWaitCondition { struct QWaitConditionPrivate *d; };

typedef void (*wake_fn)(struct QWaitCondition *);

void _ZN14QWaitCondition7wakeOneEv(struct QWaitCondition *self)
{
    static wake_fn orig;
    if (!orig)
        orig = (wake_fn)dlsym(RTLD_NEXT, "_ZN14QWaitCondition7wakeOneEv");
    static int calls;
    if (getenv("QTWAKEFIX_DEBUG") && calls++ < 20)
        fprintf(stderr, "[qtwakefix] wakeOne %p waiters=%d wakeups=%d\n", (void *)self, self->d->waiters, self->d->wakeups);
    orig(self);

    const struct timespec step = {0, 25 * 1000};
    for (int i = 0; i < 200 && __atomic_load_n(&self->d->wakeups, __ATOMIC_ACQUIRE) > 0; i++)
        nanosleep(&step, NULL);
}
