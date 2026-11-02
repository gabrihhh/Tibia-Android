#!/system/bin/sh
# Cliente do Tibia (x86_64) via box64, sem proot. Ver PLANO-APK.md para o porquê
# de cada variável.
. $TIBIA_HOME/bin/env.sh
T=$B/Tibia

export DISPLAY=:0 QT_QPA_PLATFORM=xcb TIBIA_X11_DIR=$TMPDIR
export BOX64_LOG=1
export BOX64_LD_LIBRARY_PATH=$T/bin/lib:$R/usr/lib/x86_64-linux-gnu:$R/lib/x86_64-linux-gnu
export BOX64_PATH=$T/bin
export BOX64_LD_PRELOAD=$B/libqtthreadfix.so
export LIBGL_DRIVERS_PATH=$R/usr/lib/aarch64-linux-gnu/dri
export __EGL_VENDOR_LIBRARY_DIRS=$R/usr/share/glvnd/egl_vendor.d
# Força o GLX por software (drisw) que leva ao virpipe. Sem isso, dentro do app o
# servidor X entrega a GPU real via DRI3 (driver "sgpu", desconhecido pelo Mesa)
# e a criação da tela GL trava.
export LIBGL_ALWAYS_SOFTWARE=1 LIBGL_DRI3_DISABLE=1
export GALLIUM_DRIVER=virpipe VTEST_SOCKET_NAME=@tibia-virgl
export QTWEBENGINE_CHROMIUM_FLAGS="--single-process --no-zygote --no-sandbox --disable-gpu --in-process-gpu"
export QTWEBENGINE_DISABLE_SANDBOX=1

# servidores DNS para a libc do glibc-fix (lê /proc/self/cwd/r)
[ -f $T/bin/r ] || printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > $T/bin/r

# janela do tamanho da tela X (1600x1000), sem borda; o arquivo é criado pelo
# próprio cliente na primeira vez que ele fecha
C=$T/conf/clientoptions.json
if [ -f $C ]; then
  sed -i 's/"clientWindowWidth": [0-9]*/"clientWindowWidth": 1600/; s/"clientWindowHeight": [0-9]*/"clientWindowHeight": 1000/;
          s/"clientWindowIsBorderless": [a-z]*/"clientWindowIsBorderless": true/;
          s/"clientWindowPositionX": [-0-9]*/"clientWindowPositionX": 0/; s/"clientWindowPositionY": [-0-9]*/"clientWindowPositionY": 0/' $C
fi

cd $T/bin
exec $R/lib/ld-linux-aarch64.so.1 --preload "$B/libseccompfix.so $V/libabstractsock-glibc.so" $R/usr/bin/box64 ./client --package-is-up-to-date
