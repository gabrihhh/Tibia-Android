#!/system/bin/sh
# Servidor X do Termux:X11 (app instalado à parte). O socket abstrato fica em
# @$TMPDIR/.X11-unix/X0; o cliente é redirecionado para ele (libabstractsock).
. $TIBIA_HOME/bin/env.sh
LOADER_APK=$B/x11-loader.apk

# preferências: 1600x1000 ampliado para a tela inteira. Em segundo plano: chamado
# de dentro de um app, o broadcast não recebe resposta e o comando fica preso ~20 s.
(LD_LIBRARY_PATH= CLASSPATH=$LOADER_APK TERMUX_X11_LOADER_OVERRIDE_CMDENTRYPOINT_CLASS='com.termux.x11.LoriePreferences$Receiver' \
  /system/bin/app_process -Xnoimage-dex2oat / com.termux.x11.Loader \
  displayResolutionMode:custom displayResolutionCustom:1600x1000 fullscreen:true hideCutout:true \
  > /dev/null 2>&1 &)

# sem o LD_LIBRARY_PATH do env.sh: as libs glibc do rootfs quebram o GLX do
# servidor (bionic), que acaba carregando EGL/GL errados
unset LD_LIBRARY_PATH
exec env XKB_CONFIG_ROOT=$R/usr/share/X11/xkb CLASSPATH=$LOADER_APK \
  /system/bin/app_process -Xnoimage-dex2oat / --nice-name=tibia-x11 com.termux.x11.Loader :0 -ac
