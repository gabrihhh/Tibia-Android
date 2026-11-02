#!/bin/sh
# Roda dentro do rootfs: Xvfb + cliente do Tibia via box64.
# Variáveis extras podem vir de /share/env (uma por linha, formato VAR=valor).
export DISPLAY=:1
[ -e /tmp/.X1-lock ] || (Xvfb :1 -screen 0 1600x1000x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &)
sleep 2
cd /opt/Tibia/bin
export BOX64_LOG=1
export QT_QPA_PLATFORM=xcb
export QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu"
export QTWEBENGINE_DISABLE_SANDBOX=1
[ -f /share/env ] && set -a && . /share/env && set +a
exec box64 ./client "$@"
