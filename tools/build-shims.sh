#!/usr/bin/env bash
# Compila as libs de compatibilidade em proto/shim/:
#   libqtthreadfix.so          x86_64 glibc  (carregada pelo box64 no cliente)
#   libseccompfix.so           arm64  glibc  (loader --preload)
#   libabstractsock-glibc.so   arm64  glibc  (loader --preload, lado cliente)
#   libabstractsock-bionic.so  arm64  bionic (LD_PRELOAD do virgl_server)
# Requer: gcc (x86_64), Docker (cross-compiler arm64 do Debian) e o Android NDK.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM="$ROOT/proto/shim"
NDK="${ANDROID_NDK_HOME:-$(ls -d "$HOME"/Android/Sdk/ndk/* | sort -V | tail -1)}"
cd "$SHIM"

gcc -O2 -Wall -shared -fPIC -Wl,--version-script=glibc.map -o libqtthreadfix.so qtthreadfix.c -ldl

"$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang" \
  -O2 -shared -fPIC -o libabstractsock-bionic.so abstractsock.c

docker run --rm -v "$SHIM":/src -w /src debian:trixie sh -c '
  apt-get update >/dev/null && apt-get install -y --no-install-recommends gcc-aarch64-linux-gnu libc6-dev-arm64-cross >/dev/null 2>&1
  aarch64-linux-gnu-gcc -O2 -Wall -DCLIENT_ONLY -shared -fPIC -o libabstractsock-glibc.so abstractsock.c
  aarch64-linux-gnu-gcc -O2 -Wall -shared -fPIC -o libseccompfix.so seccompfix.c
  chown '"$(id -u):$(id -g)"' libabstractsock-glibc.so libseccompfix.so'

ls -l "$SHIM"/*.so
