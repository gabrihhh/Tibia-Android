#!/usr/bin/env python3
"""Converte um dump xwd (ZPixmap, 24 ou 32 bpp, little-endian) em PNG sem dependências."""
import struct, sys, zlib
d = open(sys.argv[1], 'rb').read()
h = struct.unpack('>25I', d[:100])
hs, w, hh, bpp, bpl, nc = h[0], h[4], h[5], h[11], h[12], h[19]
step = bpl // w  # o campo bpp do Xvfb diz 24, mas cada pixel ocupa 4 bytes
off = hs + nc * 12
rows = []
for y in range(hh):
    r = d[off + y * bpl: off + y * bpl + w * step]
    px = bytearray(w * 3)
    px[0::3], px[1::3], px[2::3] = r[2::step], r[1::step], r[0::step]
    rows.append(b'\x00' + bytes(px))
def chunk(t, c): return struct.pack('>I', len(c)) + t + c + struct.pack('>I', zlib.crc32(t + c) & 0xffffffff)
open(sys.argv[2], 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, hh, 8, 2, 0, 0, 0))
                              + chunk(b'IDAT', zlib.compress(b''.join(rows), 6)) + chunk(b'IEND', b''))
