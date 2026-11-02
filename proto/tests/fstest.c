// Verifica se %fs:0 (ponteiro "self" do TCB, usado pelo Qt em currentThreadId)
// é único por thread e igual a pthread_self() sob o box64.
#include <pthread.h>
#include <stdio.h>

static void *fs0(void) { void *p; __asm__ volatile("mov %%fs:0x10, %0" : "=r"(p)); return p; }
static void *child(void *arg) {
    printf("child: fs:0x10=%p pthread_self=%p\n", fs0(), (void *)pthread_self());
    return NULL;
}
int main(void) {
    printf("main : fs:0x10=%p pthread_self=%p\n", fs0(), (void *)pthread_self());
    pthread_t t[2];
    for (int i = 0; i < 2; i++) pthread_create(&t[i], NULL, child, NULL);
    for (int i = 0; i < 2; i++) pthread_join(t[i], NULL);
    return 0;
}
