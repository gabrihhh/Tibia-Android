#!/usr/bin/env bash
# Testa uma configuração no tablet: ./try.sh <segundos> [VAR=valor ...]
# Inicia o cliente, espera, tira screenshot (shot.png no scratchpad) e encerra.
set -u
WAIT=$1; shift
D=/data/local/tmp/tibia
OUT=${SHOT_DIR:-/tmp}
adb shell "kill -9 \$(pidof client proot Xvfb) 2>/dev/null; chmod 755 $D/rootfs/root/*.sh; rm -f $D/rootfs/tmp/.X1-lock $D/share/shot.xwd" 2>/dev/null
printf '%s\n' "$@" | adb shell "cat > $D/share/env"
adb shell "cd $D && (setsid ./enter.sh /root/run-xvfb.sh > run.log 2>&1 < /dev/null &)"
sleep "$WAIT"
timeout 60 adb shell "timeout 40 $D/enter.sh /root/shot.sh" 
adb pull $D/share/shot.xwd "$OUT/shot.xwd" >/dev/null 2>&1 && python3 "$(dirname "$0")/xwd2png.py" "$OUT/shot.xwd" "$OUT/shot.png"
adb shell "P=\$(pidof client); echo pid=\$P; [ -n \"\$P\" ] && top -b -n1 -p \$P | tail -1; grep -viE 'Using (native|emulated)' $D/run.log | tail -15"
