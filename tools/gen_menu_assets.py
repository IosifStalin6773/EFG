"""Genera la portada y los logotipos del menú principal de GMod para EFG.

Uso: python3 gen_menu_assets.py <ruta repo>
GMod los lee de la raíz de la carpeta del gamemode (gamemodes/metrorp/):
  logo.png        288x128, arriba a la izquierda del menú
  icon24.png      24x24, selector de gamemode abajo a la derecha
  backgrounds/    fondos del menú (elige uno al azar)
El logo es propio de EFG (fuente efgx_display, sin marca de terceros); los
fondos salen de content/materials/efgui (tools/gen_efgui.py).
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

REPO = sys.argv[1]
EFGUI = os.path.join(REPO, "content", "materials", "efgui")
FONT = os.path.join(REPO, "content", "resource", "fonts", "efgx_display.ttf")
BG0 = (14, 18, 22)
LINE = (46, 58, 70)
KHAKI = (230, 226, 216)
TAN = (232, 131, 58)


def font(size):
	return ImageFont.truetype(FONT, size)


def logo(w=288, h=128, scale=4):
	W, H = w * scale, h * scale
	im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)

	# "ESCAPE FROM" pequeño y espaciado arriba
	small = font(11 * scale)
	txt = "ESCAPE FROM"
	gap = 3 * scale
	tw = sum(d.textlength(c, font=small) for c in txt) + gap * (len(txt) - 1)
	x = (W - tw) / 2
	for c in txt:
		d.text((x, 5 * scale), c, font=small, fill=KHAKI + (255,))
		x += d.textlength(c, font=small) + gap

	# "EFG" grande a ancho completo, con desgaste en la textura
	size = 75 * scale
	while True:
		big = font(size)
		bb = d.textbbox((0, 0), "EFG", font=big)
		if bb[2] - bb[0] <= W * 0.92:
			break
		size -= 4 * scale
	mask = Image.new("L", (W, H), 0)
	ImageDraw.Draw(mask).text(((W - (bb[2] - bb[0])) / 2 - bb[0], 17 * scale - bb[1]), "EFG", font=big, fill=255)
	rng = np.random.default_rng(7)
	noise = rng.random((H // (8 * scale // 4), W // (8 * scale // 4))).astype(np.float32)
	noise = np.asarray(Image.fromarray((noise * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32) / 255
	holes = (noise > 0.80).astype(np.uint8) * 255
	holes = np.asarray(Image.fromarray(holes).filter(ImageFilter.GaussianBlur(scale / 2)), np.float32) / 255
	worn = Image.fromarray((np.asarray(mask, np.float32) * (1 - holes)).astype(np.uint8))
	im.paste(Image.new("RGBA", (W, H), TAN + (255,)), (0, 0), worn)

	# filete naranja bajo EFG
	ly = 17 * scale + (bb[3] - bb[1]) + 6 * scale
	ImageDraw.Draw(im).rectangle([W * 0.2, ly, W * 0.8, ly + 2.5 * scale], fill=TAN + (255,))
	return im.resize((w, h), Image.LANCZOS)


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
