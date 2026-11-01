# Pasa los tonos sepia/ámbar antiguos a los grises verdosos de EFT
import re, sys, colorsys
PAT = re.compile(r'Color\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(,\s*[^)]+)?\)')
def conv(m):
    r, g, b = (int(m.group(i)) for i in (1, 2, 3))
    if max(r, g, b) > 255: return m.group(0)
    h, l, s = colorsys.rgb_to_hls(r/255, g/255, b/255)
    hd = h * 360
    # solo marrones / ámbar / dorados poco saturados (lo típico del schema anterior)
    if not (15 <= hd <= 55) or s < 0.08: return m.group(0)
    if s > 0.6 and l > 0.35: return m.group(0)  # acentos vivos (naranja EFT, etc.)
    ns = min(s, 0.10 if l < 0.4 else 0.16)
    nr, ng, nb = colorsys.hls_to_rgb(65/360, l, ns)
    out = "Color(%d, %d, %d%s)" % (round(nr*255), round(ng*255), round(nb*255), m.group(4) or "")
    return out
total = 0
for f in sys.argv[2:]:
    src = open(f, encoding="utf-8").read()
    new, n = PAT.subn(lambda m: conv(m), src)
    changed = sum(1 for a, b in zip(PAT.findall(src), PAT.findall(new)) if a != b)
    if changed:
        total += changed
        print(f, changed)
        if sys.argv[1] == "apply": open(f, "w", encoding="utf-8").write(new)
print("total", total)
