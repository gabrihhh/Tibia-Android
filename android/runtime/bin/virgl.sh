#!/system/bin/sh
# Servidor de GPU: virgl -> ANGLE -> Vulkan do Android. Socket abstrato @tibia-virgl
# (libabstractsock converte o caminho "@nome").
. $TIBIA_HOME/bin/env.sh
cd $V
exec env LD_LIBRARY_PATH=$V LD_PRELOAD=$V/libabstractsock-bionic.so \
  ./virgl_server --angle-vulkan --multi-clients --socket-path @tibia-virgl
