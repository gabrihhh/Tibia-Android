#!/system/bin/sh
# Baixa/atualiza o cliente oficial na CDN da CipSoft (tibia-fetch.py com o Python
# do rootfs). Imprime o progresso; o app mostra as linhas na tela.
. $TIBIA_HOME/bin/env.sh
mkdir -p $B/Tibia/bin
printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > $B/Tibia/bin/r
cd $B/Tibia/bin   # a libc do glibc-fix lê o DNS de /proc/self/cwd/r
exec env PYTHONHOME=$R/usr PYTHONUNBUFFERED=1 $LOADER $R/usr/bin/python3 -I $B/bin/tibia-fetch.py $B/Tibia
