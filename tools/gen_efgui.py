"""Genera el kit de texturas efgui (identidad Pizarra) para EFG.

Uso: python3 gen_efgui.py <ruta repo>
Escribe en <repo>/content/materials/efgui/...
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(sys.argv[1], "content", "materials", "efgui")
FONT = os.path.join(sys.argv[1], "content", "resource", "fonts", "efgx_display.ttf")

# paleta Pizarra (efg_ui/cl_plugin.lua). KHAKI y TAN se mantienen como nombres
# de rol: texto principal y acento.
BG0 = (14, 18, 22)
BG1 = (22, 28, 34)
BG2 = (31, 39, 48)
LINE = (46, 58, 70)
KHAKI = (230, 226, 216)
TAN = (232, 131, 58)
WHITE = (255, 255, 255)


def out(rel, img, quality=None):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if p.endswith(".jpg"):
        img.convert("RGB").save(p, quality=quality or 88, optimize=True)
    else:
        img.save(p, optimize=True)
    return p


def font(size):
    return ImageFont.truetype(FONT, size)


# ---------------------------------------------------------------- ruido
def smooth_noise(w, h, seed, octaves=((6, 1.0), (14, 0.5), (32, 0.25), (80, 0.12))):
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), np.float32)
    for cells, amp in octaves:
        cw = max(2, int(cells * w / max(w, h)) + 2)
        chh = max(2, int(cells * h / max(w, h)) + 2)
        small = (rng.random((chh, cw)) * 255).astype(np.uint8)
        big = Image.fromarray(small, "L").resize((w, h), Image.BICUBIC)
        acc += np.asarray(big, np.float32) / 255.0 * amp
    acc -= acc.min()
    acc /= max(acc.max(), 1e-6)
    return acc


def grain(w, h, seed, strength=10):
    rng = np.random.default_rng(seed)
    return (rng.standard_normal((h, w)) * strength).astype(np.float32)


def vignette(w, h, power=1.6):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (x / w - 0.5) * 2
    ny = (y / h - 0.5) * 2
    d = np.sqrt(nx * nx * 0.8 + ny * ny)
    return np.clip(1 - (d / 1.45) ** power, 0, 1)


def to_img(rgb):
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def grid_mask(w, h, step, width=1, offset=0):
    m = np.zeros((h, w), np.float32)
    for x in range(offset, w, step):
        m[:, x:x + width] = 1
    for y in range(offset, h, step):
        m[y:y + width, :] = 1
    return m


def contour_mask(field, levels=18, thick=0.06):
    f = field * levels
    frac = f - np.floor(f)
    d = np.minimum(frac, 1 - frac)
    return np.clip(1 - d / thick, 0, 1)


# ---------------------------------------------------------------- fondos
def tactical_bg(w, h, seed, tint=(0.92, 1.0, 1.08), contour=0.10, gridstep=64, text=None):
    field = smooth_noise(w, h, seed, ((3, 1.0), (7, 0.35), (13, 0.1)))
    base = np.full((h, w, 3), BG1, np.float32)
    cl = contour_mask(field, 26, 0.045)
    major = contour_mask(field, 26 / 5, 0.012)
    g = grid_mask(w, h, gridstep)
    g2 = grid_mask(w, h, gridstep * 4, 2)
    lum = (field - 0.5) * 18 + cl * 255 * contour + major * 255 * contour * 0.8
    lum += g * 10 + g2 * 8 + grain(w, h, seed + 1, 5)
    rgb = base + lum[..., None] * np.array(tint, np.float32)[None, None, :]
    rgb *= (0.35 + 0.65 * vignette(w, h))[..., None]
    img = to_img(rgb)
    if text:
        d = ImageDraw.Draw(img)
        f = font(int(h * 0.018))
        for i, t in enumerate(text):
            d.text((int(w * 0.03), int(h * 0.04) + i * int(h * 0.024)), t, font=f, fill=(86, 98, 110))
    return img


def panel_bg(w, h, seed, alpha=235, gridstep=48):
    noise = smooth_noise(w, h, seed, ((4, 1.0), (20, 0.4))) * 10
    rgb = np.full((h, w, 3), BG1, np.float32) + noise[..., None]
    g = grid_mask(w, h, gridstep)
    rgb += g[..., None] * 7
    a = np.full((h, w), alpha, np.float32)
    img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    # chaflán arriba a la derecha (rasgo de Pizarra)
    cut = max(8, min(w, h) // 12)
    d.polygon([(w - cut, 0), (w, 0), (w, cut)], fill=(0, 0, 0, 0))
    d.line([(0, 0), (w - cut, 0), (w - 1, cut), (w - 1, h - 1), (0, h - 1), (0, 0)], fill=LINE + (255,), width=2)
    return img


# ---------------------------------------------------------------- piezas tintables (blancas)
def card(w=886, h=85):
    """Cabecera de pestaña: barra blanca con rayado diagonal y muesca izquierda."""
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, h], fill=(255, 255, 255, 215))
    for x in range(-h, w, 14):
        d.line([(x, h), (x + h, 0)], fill=(255, 255, 255, 255), width=4)
    d.rectangle([0, 0, 10, h], fill=(255, 255, 255, 255))
    d.rectangle([0, h - 4, w, h], fill=(255, 255, 255, 255))
    # sombreado hacia la derecha para que no se vea plano
    a = np.asarray(img).astype(np.float32)
    ramp = np.linspace(1.0, 0.55, w)[None, :]
    a[..., :3] *= ramp[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def smoke(size=512, seed=7):
    f = smooth_noise(size, size, seed, ((3, 1.0), (8, 0.6), (20, 0.3), (50, 0.15)))
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    r = np.sqrt((x / size - 0.5) ** 2 + (y / size - 0.5) ** 2) * 2
    falloff = np.clip(1 - r, 0, 1) ** 1.5
    a = np.clip((f - 0.35) * 2.2, 0, 1) * falloff * 200
    return Image.fromarray(np.dstack([np.full((size, size, 3), 255, np.float32), a]).astype(np.uint8), "RGBA")


def header_strip(w=1046, h=39):
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    a = np.zeros((h, w), np.float32)
    a[:, :] = np.linspace(110, 0, w)[None, :]
    a[h - 2:, :] = np.linspace(255, 40, w)[None, :]
    a[:, :6] = 255
    return Image.fromarray(np.dstack([np.full((h, w, 3), 255, np.float32), a]).astype(np.uint8), "RGBA")


def side_shade(w=1098, h=936):
    a = np.zeros((h, w), np.float32)
    a[:, :] = (np.linspace(1, 0, w) ** 1.4 * 230)[None, :]
    return Image.fromarray(np.dstack([np.full((h, w, 3), 12, np.float32), a]).astype(np.uint8), "RGBA")


def fullscreen_frame(w=1600, h=900, seed=3):
    """Fondo de menú a pantalla completa: carbón + rejilla + viñeta."""
    rgb = np.full((h, w, 3), BG1, np.float32)
    rgb += smooth_noise(w, h, seed, ((5, 1.0), (16, 0.4)))[..., None] * 14
    rgb += grid_mask(w, h, 40)[..., None] * 6 + grid_mask(w, h, 160, 2)[..., None] * 6
    rgb *= (0.5 + 0.5 * vignette(w, h))[..., None]
    a = np.full((h, w), 255, np.float32)
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a]).astype(np.uint8), "RGBA")


def overlay_vignette(w=1600, h=900, horizontal=False):
    if horizontal:
        a = np.tile((np.linspace(1, 0, w) ** 1.2 * 235)[None, :], (h, 1))
    else:
        a = (1 - vignette(w, h, 2.2)) * 240
    scan = np.zeros((h, w), np.float32)
    scan[::3, :] = 10
    a = np.clip(a + scan, 0, 255)
    return Image.fromarray(np.dstack([np.full((h, w, 3), 6, np.float32), a]).astype(np.uint8), "RGBA")


def corners(size=128, arm=34, th=6):
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    s = size - 1
    for x0, x1 in ((0, arm), (s - arm, s)):
        for y0, y1 in ((0, th), (s - th, s)):
            d.rectangle([x0, y0, x1, y1], fill=WHITE + (255,))
    for x0, x1 in ((0, th), (s - th, s)):
        for y0, y1 in ((0, arm), (s - arm, s)):
            d.rectangle([x0, y0, x1, y1], fill=WHITE + (255,))
    return img


# ---------------------------------------------------------------- iconos (blancos, 128px, trazo grueso)
S = 256  # se dibuja a 256 y se reduce a 128 para suavizar


def icon_canvas():
    return Image.new("RGBA", (S, S), (255, 255, 255, 0))


def finish(img, size=128):
    return img.resize((size, size), Image.LANCZOS)


W = (255, 255, 255, 255)


def ic_gun():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.polygon([(20, 100), (200, 100), (236, 92), (236, 118), (200, 122), (150, 122), (140, 150), (118, 150), (122, 122), (96, 122), (84, 176), (58, 176), (66, 122), (20, 122)], fill=W)
    d.rectangle([24, 112, 70, 160], fill=W)
    d.rectangle([150, 86, 186, 100], fill=W)
    return finish(im)


def ic_ammo():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    for i, x in enumerate((70, 128, 186)):
        d.rectangle([x - 18, 110, x + 18, 220], fill=W)
        d.ellipse([x - 18, 40, x + 18, 140], fill=W)
        d.rectangle([x - 22, 200, x + 22, 214], fill=(0, 0, 0, 0))
        d.rectangle([x - 20, 214, x + 20, 228], fill=W)
    return finish(im)


def ic_med():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([28, 60, 228, 210], 18, outline=W, width=16)
    d.rectangle([108, 90, 148, 180], fill=W)
    d.rectangle([83, 115, 173, 155], fill=W)
    d.rectangle([96, 36, 160, 62], outline=W, width=12)
    return finish(im)


def ic_armor():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.polygon([(60, 30), (100, 30), (128, 60), (156, 30), (196, 30), (226, 70), (210, 120), (210, 228), (46, 228), (46, 120), (30, 70)], fill=W)
    d.polygon([(100, 30), (128, 60), (156, 30), (146, 30), (128, 48), (110, 30)], fill=(0, 0, 0, 0))
    for y in (140, 176):
        d.rectangle([70, y, 186, y + 14], fill=(0, 0, 0, 0))
    return finish(im)


def ic_bread():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([30, 90, 226, 210], 50, fill=W)
    for x in (80, 128, 176):
        d.line([(x - 14, 110), (x + 14, 150)], fill=(0, 0, 0, 0), width=12)
    return finish(im)


def ic_flask():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rectangle([104, 30, 152, 100], outline=W, width=14)
    d.polygon([(104, 100), (152, 100), (226, 220), (30, 220)], outline=W, fill=None, width=14)
    d.polygon([(80, 160), (176, 160), (210, 210), (46, 210)], fill=W)
    return finish(im)


def ic_star():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    pts = []
    for i in range(10):
        r = 110 if i % 2 == 0 else 46
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((128 + r * math.cos(a), 132 + r * math.sin(a)))
    d.polygon(pts, fill=W)
    return finish(im)


def ic_group():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    for cx, cy, r in ((128, 80, 38), (60, 110, 28), (196, 110, 28)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=W)
    d.pieslice([58, 120, 198, 260], 180, 360, fill=W)
    d.pieslice([10, 140, 110, 240], 180, 360, fill=W)
    d.pieslice([146, 140, 246, 240], 180, 360, fill=W)
    return finish(im)


def ic_backpack():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([50, 60, 206, 230], 24, outline=W, width=14)
    d.arc([88, 20, 168, 100], 180, 360, fill=W, width=14)
    d.rectangle([80, 130, 176, 190], outline=W, width=12)
    return finish(im)


def ic_fragments():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.polygon([(40, 60), (120, 30), (110, 120), (30, 140)], fill=W)
    d.polygon([(140, 40), (220, 70), (200, 140), (130, 120)], fill=W)
    d.polygon([(60, 170), (130, 140), (190, 170), (150, 230), (70, 220)], fill=W)
    return finish(im)


def ic_box():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rectangle([36, 70, 220, 220], outline=W, width=14)
    d.rectangle([36, 70, 220, 110], fill=W)
    d.rectangle([108, 120, 148, 140], fill=W)
    return finish(im)


def ic_gear():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    for i in range(8):
        a = i * math.pi / 4
        cx, cy = 128 + 92 * math.cos(a), 128 + 92 * math.sin(a)
        d.regular_polygon((cx, cy, 24), 4, rotation=math.degrees(a), fill=W)
    d.ellipse([46, 46, 210, 210], fill=W)
    d.ellipse([96, 96, 160, 160], fill=(0, 0, 0, 0))
    return finish(im)


def ic_quest():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rectangle([50, 40, 206, 230], outline=W, width=14)
    d.rectangle([96, 24, 160, 56], fill=W)
    for y in (100, 140, 180):
        d.rectangle([76, y, 96, y + 16], fill=W)
        d.rectangle([110, y, 180, y + 16], fill=W)
    return finish(im)


def ic_key():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.ellipse([20, 80, 116, 176], outline=W, width=18)
    d.rectangle([110, 118, 236, 138], fill=W)
    d.rectangle([190, 138, 206, 176], fill=W)
    d.rectangle([218, 138, 234, 166], fill=W)
    return finish(im)


def ic_wrench():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.line([(70, 186), (180, 76)], fill=W, width=34)
    d.ellipse([150, 26, 236, 112], fill=W)
    d.polygon([(200, 30), (236, 30), (236, 66), (196, 70)], fill=(0, 0, 0, 0))
    d.ellipse([30, 150, 100, 220], fill=W)
    return finish(im)


def ic_chevron():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    for y in (60, 120):
        d.polygon([(30, y + 40), (128, y), (226, y + 40), (226, y + 76), (128, y + 36), (30, y + 76)], fill=W)
    return finish(im)


def ic_heart():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.ellipse([30, 50, 134, 154], fill=W)
    d.ellipse([122, 50, 226, 154], fill=W)
    d.polygon([(36, 120), (220, 120), (128, 226)], fill=W)
    return finish(im)


def ic_drop():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.polygon([(128, 24), (196, 140), (60, 140)], fill=W)
    d.ellipse([58, 96, 198, 236], fill=W)
    return finish(im)


def ic_food():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rectangle([60, 80, 196, 230], fill=W)
    d.ellipse([60, 56, 196, 104], fill=W)
    d.rectangle([60, 130, 196, 170], fill=(0, 0, 0, 0))
    d.rectangle([60, 138, 196, 162], fill=W)
    return finish(im)


def ic_run():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.ellipse([140, 20, 184, 64], fill=W)
    d.line([(150, 76), (118, 150)], fill=W, width=26)
    d.line([(118, 150), (160, 186), (150, 236)], fill=W, width=22, joint="curve")
    d.line([(118, 150), (80, 190), (36, 186)], fill=W, width=22, joint="curve")
    d.line([(150, 86), (196, 120)], fill=W, width=18)
    d.line([(140, 90), (88, 100), (66, 130)], fill=W, width=18, joint="curve")
    return finish(im)


def ic_nvg():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([20, 90, 236, 170], 20, fill=W)
    for cx in (76, 180):
        d.ellipse([cx - 40, 92, cx + 40, 172], fill=(0, 0, 0, 0))
        d.ellipse([cx - 26, 106, cx + 26, 158], fill=W)
    d.rectangle([110, 60, 146, 92], fill=W)
    return finish(im)


def ic_filter():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.ellipse([40, 40, 216, 216], outline=W, width=18)
    for i in range(6):
        a = i * math.pi / 3
        d.line([(128, 128), (128 + 70 * math.cos(a), 128 + 70 * math.sin(a))], fill=W, width=10)
    return finish(im)


def ic_nofilter():
    im = ic_filter().resize((S, S))
    d = ImageDraw.Draw(im)
    d.line([(30, 226), (226, 30)], fill=W, width=22)
    return finish(im)


def ic_voice(level):
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([96, 30, 160, 150], 32, fill=W)
    d.arc([66, 80, 190, 190], 0, 180, fill=W, width=14)
    d.rectangle([120, 190, 136, 226], fill=W)
    for i in range(level):
        r = 100 + i * 26
        d.arc([128 - r, 90 - r, 128 + r, 90 + r], -40, 40, fill=W, width=10)
    return finish(im)


def ic_bullet(kind):
    im = icon_canvas(); d = ImageDraw.Draw(im)
    if kind == "shell":
        d.rectangle([92, 70, 164, 200], fill=W)
        d.rectangle([84, 200, 172, 230], fill=W)
        d.rectangle([92, 120, 164, 128], fill=(0, 0, 0, 0))
    elif kind == "flame":
        d.rectangle([92, 70, 164, 200], fill=W)
        d.rectangle([84, 200, 172, 230], fill=W)
        d.polygon([(128, 86), (150, 130), (128, 176), (106, 130)], fill=(0, 0, 0, 0))
    elif kind == "long":
        d.rectangle([112, 90, 144, 230], fill=W)
        d.polygon([(112, 92), (144, 92), (128, 20)], fill=W)
    elif kind == "dart":
        d.line([(40, 216), (216, 40)], fill=W, width=16)
        d.polygon([(216, 40), (170, 56), (200, 86)], fill=W)
        d.polygon([(40, 216), (40, 170), (70, 200)], fill=W)
    elif kind == "belt":
        for x in (64, 112, 160, 208):
            d.rectangle([x - 16, 100, x + 16, 200], fill=W)
            d.ellipse([x - 16, 60, x + 16, 120], fill=W)
        d.rectangle([40, 160, 232, 172], fill=(0, 0, 0, 0))
    elif kind == "pistol":
        d.rectangle([96, 120, 160, 220], fill=W)
        d.ellipse([96, 70, 160, 160], fill=W)
    elif kind == "rocket":
        d.polygon([(128, 20), (156, 70), (156, 190), (100, 190), (100, 70)], fill=W)
        d.polygon([(100, 170), (70, 230), (100, 210)], fill=W)
        d.polygon([(156, 170), (186, 230), (156, 210)], fill=W)
    else:  # rifle
        d.rectangle([104, 110, 152, 220], fill=W)
        d.polygon([(104, 112), (152, 112), (140, 60), (128, 34), (116, 60)], fill=W)
        d.rectangle([98, 214, 158, 232], fill=W)
    return finish(im)


def ic_ruble():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rectangle([84, 36, 112, 226], fill=W)
    d.arc([40, 36, 190, 144], -90, 90, fill=W, width=28)
    d.rectangle([84, 36, 116, 64], fill=W)
    d.rectangle([84, 116, 116, 144], fill=W)
    d.rectangle([56, 166, 160, 190], fill=W)
    return finish(im)


def ic_default():
    im = icon_canvas(); d = ImageDraw.Draw(im)
    d.rectangle([40, 40, 216, 216], outline=W, width=12)
    f = font(150)
    d.text((128, 132), "?", font=f, fill=W, anchor="mm")
    return finish(im)


# ---------------------------------------------------------------- emblemas (coloreados)
def emblem(label, sub=None, color=TAN, size=256, shape="hex"):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = size / 2
    if shape == "hex":
        d.regular_polygon((c, c, c - 6), 6, rotation=30, fill=BG1 + (240,), outline=color + (255,), width=8)
    elif shape == "circle":
        d.ellipse([6, 6, size - 6, size - 6], fill=BG1 + (240,), outline=color + (255,), width=8)
    else:
        d.rectangle([6, 6, size - 6, size - 6], fill=BG1 + (240,), outline=color + (255,), width=8)
    f = font(int(size * (0.42 if len(label) <= 2 else 0.26)))
    d.text((c, c - (size * 0.05 if sub else 0)), label, font=f, fill=KHAKI + (255,), anchor="mm")
    if sub:
        d.text((c, c + size * 0.24), sub, font=font(int(size * 0.1)), fill=color + (255,), anchor="mm")
    return im


def faction_icon(label, glyph, color, size=256):
    """Insignia de facción: marco metálico como el icono de EFG, glifo y placa con el nombre."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size / 256
    d.rounded_rectangle([8 * s, 8 * s, 248 * s, 248 * s], radius=34 * s, fill=(110, 116, 120, 255))
    d.rounded_rectangle([16 * s, 16 * s, 240 * s, 240 * s], radius=28 * s, fill=(34, 40, 46, 255))
    d.rounded_rectangle([24 * s, 24 * s, 232 * s, 232 * s], radius=22 * s, fill=BG0 + (255,), outline=LINE + (255,), width=max(1, int(3 * s)))
    c = (128 * s, 108 * s)
    col = color + (255,)
    if glyph == "crosshair":
        r = 46 * s
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=col, width=int(8 * s))
        d.ellipse([c[0] - 8 * s, c[1] - 8 * s, c[0] + 8 * s, c[1] + 8 * s], fill=col)
        for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            d.line([c[0] + dx * (r + 6 * s), c[1] + dy * (r + 6 * s), c[0] + dx * (r + 24 * s), c[1] + dy * (r + 24 * s)], fill=col, width=int(7 * s))
    elif glyph == "shield":
        pts = [(c[0], c[1] - 52 * s), (c[0] + 44 * s, c[1] - 36 * s), (c[0] + 40 * s, c[1] + 12 * s), (c[0], c[1] + 52 * s), (c[0] - 40 * s, c[1] + 12 * s), (c[0] - 44 * s, c[1] - 36 * s)]
        d.polygon(pts, fill=col)
        d.polygon([(c[0], c[1] - 34 * s), (c[0] + 24 * s, c[1] - 24 * s), (c[0] + 22 * s, c[1] + 6 * s), (c[0], c[1] + 32 * s), (c[0] - 22 * s, c[1] + 6 * s), (c[0] - 24 * s, c[1] - 24 * s)], fill=BG0 + (255,))
    elif glyph == "pack":
        d.rounded_rectangle([c[0] - 40 * s, c[1] - 36 * s, c[0] + 40 * s, c[1] + 44 * s], radius=10 * s, fill=col)
        d.rounded_rectangle([c[0] - 26 * s, c[1] - 58 * s, c[0] + 26 * s, c[1] - 30 * s], radius=8 * s, outline=col, width=int(8 * s))
        d.rectangle([c[0] - 40 * s, c[1] - 4 * s, c[0] + 40 * s, c[1] + 6 * s], fill=BG0 + (255,))
    elif glyph == "star":
        pts = []
        for i in range(10):
            a = -math.pi / 2 + math.pi * i / 5
            rr = 56 * s if i % 2 == 0 else 24 * s
            pts.append((c[0] + rr * math.cos(a), c[1] + rr * math.sin(a)))
        d.polygon(pts, fill=col)
    elif glyph == "lock":
        d.arc([c[0] - 26 * s, c[1] - 58 * s, c[0] + 26 * s, c[1] - 6 * s], 180, 360, fill=col, width=int(10 * s))
        d.rounded_rectangle([c[0] - 40 * s, c[1] - 14 * s, c[0] + 40 * s, c[1] + 50 * s], radius=10 * s, fill=col)
        d.ellipse([c[0] - 9 * s, c[1] + 6 * s, c[0] + 9 * s, c[1] + 24 * s], fill=BG0 + (255,))
    elif glyph == "gear":
        teeth = 8
        outer, inner = 52 * s, 40 * s
        pts = []
        for i in range(teeth * 2):
            a = math.pi * i / teeth
            rr = outer if i % 2 == 0 else inner
            pts.append((c[0] + rr * math.cos(a), c[1] + rr * math.sin(a)))
        d.polygon(pts, fill=col)
        r = 16 * s
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=BG0 + (255,))
    d.rectangle([34 * s, 176 * s, 222 * s, 220 * s], fill=color + (255,))
    d.text((c[0], 198 * s), label, font=font(int(30 * s)), fill=BG0 + (255,), anchor="mm")
    return im


def map_card(w, h, seed, title=None):
    img = tactical_bg(w, h, seed, contour=0.16, gridstep=32)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=LINE, width=3)
    if title:
        d.rectangle([0, h - int(h * 0.16), w, h], fill=BG0)
        d.text((int(w * 0.05), h - int(h * 0.08)), title, font=font(int(h * 0.09)), fill=KHAKI, anchor="lm")
    return img.convert("RGBA")


def logo(w=1024, h=256):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    size = int(h * 0.56)
    while ImageDraw.Draw(im).textlength("ESCAPE FROM GMOD", font=font(size)) > w * 0.9:
        size -= 2
    big = font(size)
    d.text((w // 2, int(h * 0.42)), "ESCAPE FROM GMOD", font=big, fill=KHAKI + (255,), anchor="mm",
           stroke_width=3, stroke_fill=KHAKI + (255,))
    tw = d.textlength("ESCAPE FROM GMOD", font=big) + 6
    y = int(h * 0.80)
    d.rectangle([w // 2 - tw / 2, y - 3, w // 2 - 70, y + 3], fill=TAN + (255,))
    d.rectangle([w // 2 + 70, y - 3, w // 2 + tw / 2, y + 3], fill=TAN + (255,))
    d.text((w // 2, y), "EFG", font=font(int(h * 0.2)), fill=TAN + (255,), anchor="mm")
    return im


def main():
    random.seed(1)
    # fondos
    out("backgrounds/mainmenu.jpg", tactical_bg(1920, 1080, 11, text=["EFG / ZONA DE EXTRACCIÓN", "CUADRÍCULA 07-14"]))
    out("backgrounds/creation.jpg", tactical_bg(1920, 1080, 23, tint=(0.95, 1.0, 1.05)))
    out("backgrounds/load.jpg", tactical_bg(1920, 1080, 37, tint=(1.05, 1.0, 0.92)))
    out("spawnmenu/Menu/3.jpg", fullscreen_frame().convert("RGB"))
    out("spawnmenu/Menu/1.png", header_strip())
    out("spawnmenu/Menu/2.png", side_shade())
    out("mainmenu.png", overlay_vignette())
    out("mainmenu2.png", panel_bg(348, 512, 5))
    out("creation/ui_pausemenu_back_002.png", panel_bg(512, 384, 9))
    out("mainmenu_card.png", card())
    out("smoke2.png", smoke())
    out("panel.png", panel_bg(256, 256, 13))
    out("cell.png", cell_tex())
    out("icons/corner.png", corners())
    out("logo32028.png", logo())
    out("logo3.png", logo())

    icons = {
        "icons/craft/guns.png": ic_gun, "icons/craft/ammo.png": ic_ammo,
        "icons/craft/medicaments.png": ic_med, "icons/craft/armor.png": ic_armor,
        "icons/cooking/bread.png": ic_bread, "icons/clay.png": ic_flask,
        "icons/skills_icon.png": ic_star, "icons/icon_org64.png": ic_group,
        "icons/icon_inventory64.png": ic_backpack, "icons/fragments_icon.png": ic_fragments,
        "icons/default.png": ic_default, "icons/settings.png": ic_gear,
        "icons/icon_quest64.png": ic_quest, "icons/key.png": ic_key,
        "bonuses/medic.png": ic_med, "bonuses/mechanic.png": ic_wrench, "bonuses/conscript.png": ic_chevron,
        "hud/hp.png": ic_heart, "hud/food.png": ic_food, "hud/thirst.png": ic_drop,
        "hud/stamina.png": ic_run, "hud/armor.png": ic_armor, "hud/pnv.png": ic_nvg,
        "hud/filter.png": ic_filter, "hud/no_filter.png": ic_nofilter,
        "icons/money.png": ic_ruble,
    }
    for rel, fn in icons.items():
        out(rel, fn())
    for i in (1, 2, 3):
        out("icons/hud_voice%d.png" % i, ic_voice(i))
    ammo = {"ak_ammo": "rifle", "revolver_ammo": "pistol", "shotgun_ammo": "shell",
            "shotgun_flame_ammo": "flame", "sniper_ammo": "long", "gatling_ammo": "belt",
            "tikhar_ammo": "dart", "money_ammo": "pistol", "rozok": "rocket"}
    for name, kind in ammo.items():
        out("icons/%s.png" % name, ic_bullet(kind))

    # bandos y traders
    out("factions/usec.png", faction_icon("USEC", "lock", (90, 120, 150)))
    out("factions/bear.png", faction_icon("BEAR", "star", (150, 70, 60)))
    out("factions/scav.png", faction_icon("SCAV", "pack", (120, 130, 80)))
    out("factions/staff.png", faction_icon("STAFF", "gear", TAN))
    # las claves (nombre de archivo) siguen siendo las internas de traders/
    traders = [("prapor", "I", "INTENDENTE"), ("therapist", "D", "DOCTORA"), ("fence", "CH", "CHATARRERO"),
               ("skier", "C", "CONTRABANDISTA"), ("peacekeeper", "AG", "AGREGADO"), ("mechanic", "A", "ARMERO"),
               ("ragman", "CO", "COSTURERA"), ("jaeger", "M", "MONTERO"), ("staff", "ST", "STAFF")]
    for key, initial, name in traders:
        out("traders/%s.png" % key, emblem(initial, name, TAN, shape="square"))

    # tarjetas del menú de aparición (antes facciones de Metro)
    cards = ["void", "ui_spawn", "ui_astra_ex1", "reich", "redline", "rangers", "hanza", "bandit",
             "RedLine/latest", "RedLine/RedLine", "Rangers/latest", "Rangers/Ranger", "Hanza/latest",
             "Hanza/Hanza", "Bandit/bandit", "4Reich/latest", "4Reich/4Reich"]
    for i, c in enumerate(cards):
        out("spawnmenu/%s.jpg" % c, map_card(384, 384, 100 + i))


def cell_tex(size=64):
    """Celda de inventario Pizarra: fondo pizarra, borde fino y degradado sutil."""
    im = Image.new("RGBA", (size, size), BG1 + (230,))
    d = ImageDraw.Draw(im)
    for y in range(size):
        v = int(6 * (1 - y / size))
        d.line([(0, y), (size, y)], fill=(BG1[0] + v, BG1[1] + v, BG1[2] + v, 230))
    d.rectangle([0, 0, size - 1, size - 1], outline=LINE + (255,), width=1)
    return im


if __name__ == "__main__":
    main()
    n = sum(len(f) for _, _, f in os.walk(ROOT))
    print("ok", n, "archivos en", ROOT)
