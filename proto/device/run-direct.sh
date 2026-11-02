#!/system/bin/sh
# Roda o cliente SEM proot: box64 chamado pelo loader glibc do rootfs.
# O Xvfb (:1) deve estar rodando (dentro do proot); conexão via socket abstrato.
B=/data/local/tmp/tibia
R=$B/rootfs
export HOME=$B/home TMPDIR=$B/tmp XDG_RUNTIME_DIR=$B/tmp
mkdir -p $HOME
export DISPLAY=:1
export LD_LIBRARY_PATH=$B/glibc-fix:$R/usr/lib/aarch64-linux-gnu:$R/lib/aarch64-linux-gnu
export BOX64_LD_LIBRARY_PATH=$R/opt/Tibia/bin/lib:$R/usr/lib/x86_64-linux-gnu:$R/lib/x86_64-linux-gnu
export BOX64_PATH=$R/opt/Tibia/bin
export BOX64_LOG=1
export FONTCONFIG_FILE=$B/fonts/fonts.conf
# Certificados raiz para o OpenSSL (o Android não tem /etc/ssl)
export SSL_CERT_FILE=$B/certs/ca-bundle.pem SSL_CERT_DIR=$B/certs
export LIBGL_DRIVERS_PATH=$R/usr/lib/aarch64-linux-gnu/dri
export __EGL_VENDOR_LIBRARY_DIRS=$R/usr/share/glvnd/egl_vendor.d
export QT_QPA_PLATFORM=xcb
export QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu"
export QTWEBENGINE_DISABLE_SANDBOX=1
[ -f $B/share/env ] && set -a && . $B/share/env && set +a
cd $R/opt/Tibia/bin
# NATIVE_PRELOAD: libs glibc ARM64 carregadas no processo do box64 (ex.: socket abstrato do virgl)
exec $R/lib/ld-linux-aarch64.so.1 ${NATIVE_PRELOAD:+--preload $NATIVE_PRELOAD} $R/usr/bin/box64 ./client "$@"
