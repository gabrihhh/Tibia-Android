#!/bin/sh
# Roda dentro de um container Debian amd64: Xvfb + cliente nativo x86, captura tela.
apt-get update >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb x11-utils x11-apps libgl1 libopengl0 libegl1 libgl1-mesa-dri libvulkan1 mesa-vulkan-drivers libxkbcommon0 libxkbcommon-x11-0 libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 libxcb-xkb1 libxcb-xinput0 libfontconfig1 libfreetype6 fonts-dejavu-core libdbus-1-3 libnss3 libasound2t64 libpulse0 libglib2.0-0t64 libwebp7 libwebpdemux2 libwebpmux3 libxdamage1 libxkbfile1 libgbm1 ca-certificates >/dev/null 2>&1
Xvfb :1 -screen 0 1600x1000x24 -nolisten tcp >/dev/null 2>&1 &
sleep 2
export DISPLAY=:1 LC_ALL=C.UTF-8 QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu" QTWEBENGINE_DISABLE_SANDBOX=1
cd /opt/Tibia/bin && (timeout 60 ./client > /out/pc-client.log 2>&1 &)
sleep 45
xwininfo -root -tree | grep -E '^ +0x' | head -8
xwd -root -silent > /out/pc-shot.xwd
