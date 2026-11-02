#!/bin/sh
# Captura a tela do Xvfb :1 em /share/shot.xwd
DISPLAY=:1 xwd -root -silent > /share/shot.xwd
