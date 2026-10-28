# Junta los addons de la colección de EFG, el gamemode y Helix en un único
# addon de carpeta para uso propio (servidor y pruebas). No se publica.
# Uso: python repack.py   (rehace D:\GMOD\EFG_PACK\efg_pack desde cero)
import os, struct, shutil, time, json

WS = r"C:\Program Files (x86)\Steam\steamapps\workshop\content\4000"
GM = r"C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod\gamemodes"
OUT = r"D:\GMOD\EFG_PACK\efg_pack"
LOG = r"D:\GMOD\EFG_PACK\repack_log.txt"

# Orden de la colección 3224545557: los últimos pisan a los primeros
IDS = """2828830531,2910505837,2838301678,2962214657,2962331253,2962353031,2888386851,2828829604,3001247817,2964982792,
2886973051,2838300952,2988439306,2988310573,2908595400,2636534237,2646150977,2804625575,2230307188,2661001153,2401302833,
2405571926,2401315707,2568311977,2773945064,2221101820,2654914995,2771924539,2578541471,2791757272,2853397949,2827400035,
2813956565,2634728857,2847673946,239531104,2870524642,2858144529,1970593283,2846867031,1952504766,2049452093,2962829818,
3010049092,2950907061,3012983285,2976665920,2965318829,2919110631,2922999549,2924902340,2925285789,2917344450,3432143677,
2917343547,2910537020,2954197681,2951064927,3653148203,2641653126,1985020945""".replace("\n", "").split(",")

SKIP_DIRS = (".git", ".claude", ".github", ".vscode", "_retirados", "__pycache__")

log = open(LOG, "w", encoding="utf-8")
def say(*a):
    msg = " ".join(str(x) for x in a)
    print(msg, flush=True)
    log.write(msg + "\n"); log.flush()

def cstr(f):
    b = bytearray()
    while True:
        c = f.read(1)
        if not c or c == b"\0": return b.decode("utf-8", "replace")
        b += c

owner = {}  # ruta -> addon que la puso
clashes = 0

def extract(gma, wsid):
    global clashes
    with open(gma, "rb") as f:
        if f.read(4) != b"GMAD": raise ValueError("no es un GMA")
        ver = f.read(1)[0]
        f.read(16)  # steamid + timestamp
        if ver > 1:
            while cstr(f): pass
        name = cstr(f); cstr(f); cstr(f); f.read(4)
        entries = []
        while True:
            num = struct.unpack("<I", f.read(4))[0]
            if num == 0: break
            path = cstr(f).replace("\\", "/").lower()
            size = struct.unpack("<q", f.read(8))[0]
            f.read(4)
            entries.append((path, size))
        n = 0
        for path, size in entries:
            if ".." in path or path.startswith("/") or ":" in path:
                f.seek(size, 1); continue
            if path in owner and owner[path] != wsid:
                say("  CHOQUE", path, owner[path], "->", wsid)
                clashes += 1
            owner[path] = wsid
            dest = os.path.join(OUT, path)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            left = size
            with open(dest, "wb") as o:
                while left > 0:
                    chunk = f.read(min(left, 8 << 20))
                    if not chunk: raise IOError("GMA cortado")
                    o.write(chunk); left -= len(chunk)
            n += 1
        return name, n

def copytree(src, dst):
    n = 0
    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fn in files:
            s = os.path.join(root, fn)
            d = os.path.join(dst, os.path.relpath(s, src))
            os.makedirs(os.path.dirname(d), exist_ok=True)
            shutil.copy2(s, d)
            n += 1
    return n

t0 = time.time()
if os.path.isdir(OUT):
    say("Borrando el paquete anterior...")
    shutil.rmtree(OUT)
os.makedirs(OUT)

for i, wsid in enumerate(IDS, 1):
    folder = os.path.join(WS, wsid)
    gmas = [os.path.join(folder, x) for x in os.listdir(folder) if x.lower().endswith(".gma")] if os.path.isdir(folder) else []
    if not gmas:
        say(f"[{i}/61] {wsid}: FALTA")
        continue
    for g in gmas:
        try:
            name, n = extract(g, wsid)
            say(f"[{i}/61] {wsid} {name}: {n} archivos")
        except Exception as e:
            say(f"[{i}/61] {wsid}: ERROR {e}")

# El modo: gamemodes/helix y gamemodes/metrorp (EFG). El contenido del schema
# se copia también a la raíz del addon para que se monte siempre.
for gm in ("helix", "metrorp"):
    say("Copiando gamemode", gm, copytree(os.path.join(GM, gm), os.path.join(OUT, "gamemodes", gm)))
say("Copiando contenido de EFG a la raíz", copytree(os.path.join(GM, "metrorp", "content"), OUT))

with open(os.path.join(OUT, "addon.json"), "w", encoding="utf-8") as f:
    json.dump({"title": "EFG - paquete completo (uso propio)", "type": "gamemode",
               "tags": ["roleplay", "realism"], "ignore": ["*.psd", "*.vcproj", "*.svn*"]}, f, indent=1)

total = sum(os.path.getsize(os.path.join(r, x)) for r, _, fs in os.walk(OUT) for x in fs)
say(f"HECHO en {int(time.time() - t0)} s: {len(owner)} archivos de Workshop, {clashes} choques, {total / 1e9:.1f} GB en {OUT}")
