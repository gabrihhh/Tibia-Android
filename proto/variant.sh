#!/usr/bin/env bash
# Roda o cliente (sem proot) com variáveis extras e relata se abriu janela.
# Uso: ./variant.sh <segundos> VAR=valor ...
WAIT=$1; shift
B=/data/local/tmp/tibia
{ echo "LC_ALL=C.UTF-8"; echo "LOCPATH=$B/rootfs/usr/lib/locale"; echo "VK_ICD_FILENAMES=$B/icd/lvp.json"; printf '%s\n' "$@"; } | adb shell "cat > $B/share/env"
adb shell "for p in \$(ps -A -o PID,NAME | grep ld-linux | awk '{print \$1}'); do kill -9 \$p; done; pidof Xvfb >/dev/null || (cd $B; setsid ./enter.sh /bin/sh -c 'rm -f /tmp/.X1-lock; Xvfb :1 -screen 0 1600x1000x24 -nolisten tcp' > xvfb.log 2>&1 < /dev/null &); sleep 2
chmod 755 $B/run-direct.sh; cd $B; nohup sh -c './run-direct.sh > direct.log 2>&1; echo exit=\$? >> direct.log' > /dev/null 2>&1 < /dev/null &
sleep $WAIT
ps -A -o PID,TIME,RSS,NAME | grep ld-linux
grep -viE 'Using (native|emulated)|locale|UTF-8|BOX64\]' direct.log | tail -6"
timeout 40 adb shell "timeout 30 $B/enter.sh /bin/sh -c 'DISPLAY=:1 xwininfo -root -tree' | grep -E '^ +0x' | grep -v 'Selection Owner' | head -5"
