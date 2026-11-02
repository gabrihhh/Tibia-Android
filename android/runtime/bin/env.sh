# Ambiente comum do runtime. Incluído (".") pelos outros scripts.
# TIBIA_HOME é definido pelo app (pasta files/rt do pacote).
B=$TIBIA_HOME
R=$B/rootfs
V=$B/virgl
export HOME=$B/home TMPDIR=$B/tmp XDG_RUNTIME_DIR=$B/tmp
mkdir -p $HOME $TMPDIR $B/logs

# glibc ARM64 do rootfs; glibc-fix tem a libc com /etc/resolv.conf -> /proc/self/cwd/r
export LD_LIBRARY_PATH=$B/glibc-fix:$R/usr/lib/aarch64-linux-gnu:$R/lib/aarch64-linux-gnu
# libseccompfix: transforma em ENOSYS as syscalls que o seccomp do Android proíbe
LOADER="$R/lib/ld-linux-aarch64.so.1 --preload $B/libseccompfix.so"
export SECCOMPFIX_LOG=1  # registra no log cada syscall bloqueada

# O Android não tem /etc/ssl, /usr/share/zoneinfo nem /etc/fonts
export SSL_CERT_FILE=$B/certs/ca-bundle.pem SSL_CERT_DIR=$B/certs
export TIBIA_CA_BUNDLE=$B/certs/tibia-ca.pem
export TZ=$(getprop persist.sys.timezone) TZDIR=$R/usr/share/zoneinfo
export LC_ALL=C.UTF-8 LOCPATH=$R/usr/lib/locale
export FONTCONFIG_FILE=$B/fonts/fonts.conf
if [ ! -f $FONTCONFIG_FILE ]; then
  mkdir -p $B/fonts $TMPDIR/fontcache
  # printf em vez de heredoc: o sh do Android cria o temporário do heredoc em
  # /data/local, que um app não pode escrever
  printf '%s\n' '<?xml version="1.0"?>' '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">' '<fontconfig>' \
    "  <dir>$R/usr/share/fonts</dir>" '  <dir>/system/fonts</dir>' "  <cachedir>$TMPDIR/fontcache</cachedir>" \
    "  <include ignore_missing=\"yes\">$R/etc/fonts/conf.d</include>" '</fontconfig>' > $FONTCONFIG_FILE
fi
