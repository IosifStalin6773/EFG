"""Genera la portada y los logotipos del menú principal de GMod para EFG.

Uso: python3 gen_menu_assets.py <ruta repo>
GMod los lee de la raíz de la carpeta del gamemode (gamemodes/metrorp/):
  logo.png        288x128, arriba a la izquierda del menú
  icon24.png      24x24, selector de gamemode abajo a la derecha
  backgrounds/    fondos del menú (elige uno al azar)
El logo y el icono salen de content/materials/efg/brand (arte propio de EFG).
Los fondos salen de content/materials/efgui (tools/gen_efgui.py).
"""
import os, sys
from PIL import Image
import numpy as np

REPO = sys.argv[1]
BRAND = os.path.join(REPO, "content", "materials", "efg", "brand")
EFGUI = os.path.join(REPO, "content", "materials", "efgui")


def logo(w=288, h=128, floor=12):
	# el arte viene sobre negro: la luminosidad hace de alfa
	src = np.asarray(Image.open(os.path.join(BRAND, "efg_logo_src.png")).convert("RGB"), np.float32)
	alpha = np.clip((src.max(axis=2) - floor) * 255 / (255 - floor), 0, 255)
	im = Image.fromarray(np.dstack([src, alpha]).astype(np.uint8), "RGBA")
	im = im.crop(im.getbbox())
	im.thumbnail((w, h), Image.LANCZOS)
	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	out.alpha_composite(im, ((w - im.width) // 2, (h - im.height) // 2))
	return out


def icon(size=24, box=(330, 40, 700, 400)):
	im = Image.open(os.path.join(BRAND, "efg_icon_src.png")).convert("RGBA")
	return im.crop(box).resize((size, size), Image.LANCZOS)


def main():
	logo().save(os.path.join(REPO, "logo.png"), optimize=True)
	icon().save(os.path.join(REPO, "icon24.png"), optimize=True)
	# los mismos arte para los menús de schema, sin tocar código: se sustituyen los PNG
	# que ya cargan efg_menus, metroui, efg_pmc y efg_ui
	content = os.path.join(REPO, "content", "materials")
	logo(1024, 435).save(os.path.join(content, "efg", "menu", "logo.png"), optimize=True)
	icon(256).save(os.path.join(content, "efg", "menu", "sb_game_eft.png"), optimize=True)
	for name in ("logo32028.png", "logo3.png"):
		logo(1024, 256).save(os.path.join(content, "efgui", name), optimize=True)
	bgdir = os.path.join(REPO, "backgrounds")
	os.makedirs(bgdir, exist_ok=True)
	for name in ("mainmenu", "creation", "load"):
		img = Image.open(os.path.join(EFGUI, "backgrounds", name + ".jpg")).convert("RGB")
		img.save(os.path.join(bgdir, "efg_" + name + ".jpg"), quality=88, optimize=True)


if __name__ == "__main__":
	main()
