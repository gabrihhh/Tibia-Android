#!/system/bin/sh
# Abre o Tibia na tela do tablet (Termux:X11), fechando uma instância anterior.
# Uso (do PC): adb shell /data/local/tmp/tibia/start-tibia.sh
B=/data/local/tmp/tibia

# fecha o cliente anterior (roda como ld-linux-aarch64.so.1)
for p in $(ps -A -o PID,NAME | grep ld-linux | awk '{print $1}'); do kill -9 $p; done

# sobe o servidor X do Termux:X11 se ainda não estiver rodando
if ! grep -qa "@/tmp/.X11-unix/X0" /proc/net/unix; then
  (cd $B && XKB_CONFIG_ROOT=$B/rootfs/usr/share/X11/xkb TMPDIR=/tmp CLASSPATH=$B/x11-loader.apk \
    setsid /system/bin/app_process -Xnoimage-dex2oat / --nice-name=termux-x11 com.termux.x11.Loader :0 -ac \
    > $B/x11.log 2>&1 < /dev/null &)
  sleep 3
fi
am start -n com.termux.x11/.MainActivity > /dev/null 2>&1

# sobe o servidor de GPU (virgl → ANGLE → Vulkan da Samsung) se ainda não estiver rodando
V=$B/virgl
if ! grep -qa "@tibia-virgl" /proc/net/unix; then
  (cd $V && LD_LIBRARY_PATH=$V LD_PRELOAD=$V/libabstractsock-bionic.so \
    setsid ./virgl_server --angle-vulkan --multi-clients --socket-path @tibia-virgl \
    > $B/virgl.log 2>&1 < /dev/null &)
  sleep 2
fi

cat > $B/share/env <<EOF
DISPLAY=:0
LC_ALL=C.UTF-8
LOCPATH=$B/rootfs/usr/lib/locale
VK_ICD_FILENAMES=$B/icd/lvp.json
BOX64_LD_PRELOAD=$B/libqtthreadfix.so
TIBIA_CA_BUNDLE=$B/certs/tibia-ca.pem
TZ=$(getprop persist.sys.timezone)
TZDIR=$B/rootfs/usr/share/zoneinfo
GALLIUM_DRIVER=virpipe
VTEST_SOCKET_NAME=@tibia-virgl
NATIVE_PRELOAD=$V/libabstractsock-glibc.so
QTWEBENGINE_CHROMIUM_FLAGS="--single-process --no-zygote --no-sandbox --disable-gpu --in-process-gpu"
EOF

cd $B && nohup sh -c './run-direct.sh --package-is-up-to-date > direct.log 2>&1; echo exit=$? >> direct.log' > /dev/null 2>&1 < /dev/null &
echo "Tibia iniciando (leva ~1 min para aparecer)"
