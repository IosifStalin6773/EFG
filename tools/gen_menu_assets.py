"""Genera la portada y los logotipos del menú principal de GMod para EFG.

Uso: python3 gen_menu_assets.py <ruta repo>
GMod los lee de la raíz de la carpeta del gamemode (gamemodes/metrorp/):
  logo.png        288x128, arriba a la izquierda del menú
  icon24.png      24x24, selector de gamemode abajo a la derecha
  backgrounds/    fondos del menú (elige uno al azar)
Parte del logo y los fondos de content/materials/efgui (tools/gen_efgui.py).
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

REPO = sys.argv[1]
EFGUI = os.path.join(REPO, "content", "materials", "efgui")
FONT = os.path.join(REPO, "content", "resource", "fonts", "efgx_display.ttf")
BG0 = (14, 18, 22)
LINE = (46, 58, 70)
TAN = (232, 131, 58)


def logo(w=288, h=128):
	src = Image.open(os.path.join(EFGUI, "logo32028.png")).convert("RGBA")
	src = src.crop(src.getbbox())
	src.thumbnail((w - 8, h - 8), Image.LANCZOS)
	im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	im.alpha_composite(src, (0, (h - src.height) // 2))
	return im


def icon(size=24, scale=8):
	s = size * scale
	im = Image.new("RGBA", (s, s), BG0 + (255,))
	d = ImageDraw.Draw(im)
	d.rectangle([0, 0, s - 1, s - 1], outline=LINE, width=scale)
	fs = s
	while ImageDraw.Draw(im).textlength("EFG", font=ImageFont.truetype(FONT, fs)) > s * 0.86:
		fs -= 2
	d.text((s // 2, s // 2), "EFG", font=ImageFont.truetype(FONT, fs), fill=TAN + (255,), anchor="mm")
	return im.resize((size, size), Image.LANCZOS)


def main():
	logo().save(os.path.join(REPO, "logo.png"), optimize=True)
	icon().save(os.path.join(REPO, "icon24.png"), optimize=True)
	bgdir = os.path.join(REPO, "backgrounds")
	os.makedirs(bgdir, exist_ok=True)
	for name in ("mainmenu", "creation", "load"):
		img = Image.open(os.path.join(EFGUI, "backgrounds", name + ".jpg")).convert("RGB")
		img.save(os.path.join(bgdir, "efg_" + name + ".jpg"), quality=88, optimize=True)


if __name__ == "__main__":
	main()
