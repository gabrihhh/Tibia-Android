#!/usr/bin/env python3
"""Procura no heap um ponteiro (QWaitCondition::d) e mostra a memória ao redor.
Uso: memscan.py <pid> <valor-hex>"""
import re, struct, sys
pid, val = int(sys.argv[1]), int(sys.argv[2], 16)
cands = {struct.pack('<Q', val - d): val - d for d in range(0, int(sys.argv[3]) if len(sys.argv) > 3 else 0x80, 8)}
mem = open(f'/proc/{pid}/mem', 'rb', 0)
for line in open(f'/proc/{pid}/maps'):
    m = re.match(r'([0-9a-f]+)-([0-9a-f]+) (r)w', line)
    if not m: continue
    a, b = int(m[1], 16), int(m[2], 16)
    if b - a > 512 << 20: continue
    try:
        mem.seek(a); data = mem.read(b - a)
    except OSError: continue
    for needle, target in cands.items():
      for off in [i.start() for i in re.finditer(re.escape(needle), data)]:
        if off % 8: continue
        print(f'target {target:#x}')
        addr = a + off
        if True:
         lo = max(0, off - 0xa0)
        print(f'hit @ {addr:#x} ({line.split()[-1] if len(line.split())>5 else "anon"})')
        for o in range(lo, off + 0x10, 8):
            q = struct.unpack('<Q', data[o:o+8])[0]
            print(f'  {a+o:#x} [{o-off:+#05x}]: {q:#018x}  bytes={data[o:o+8].hex()}')
