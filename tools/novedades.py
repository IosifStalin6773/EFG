"""Genera la imagen de novedades de un commit (tarjetas al estilo del roadmap de EFT).

Uso:
	python tools/novedades.py cambios.json [--salida docs/novedades] [--sin-indice]

cambios.json:
	{
		"titulo": "Registro del ciclo de raid",          (opcional, sale grande arriba)
		"fecha": "2026-10-30",                          (opcional, por defecto hoy)
		"tarjetas": [
			{
				"area": "efg_testcycle",                 cabecera de la tarjeta
				"relevancia": "alta",                    critica | alta | media | baja
				"cambios": ["Texto corto;", "..."],      viñetas
				"nota": "Texto tras el separador"        (opcional)
			}
		]
	}

Escribe <salida>/<fecha>-<slug>.png y añade la entrada al principio de
<salida>/README.md (índice con todas las imágenes). Imprime la ruta del PNG.
"""
import argparse, datetime, json, os, re, subprocess, sys, unicodedata
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(REPO, "content", "resource", "fonts", "mbender.ttf")

W = 1920
BG_TOP = (34, 36, 38)
BG_BOT = (14, 15, 16)
CARD = (27, 28, 29, 236)
CARD_HEAD = (22, 23, 24, 250)
CARD_LINE = (70, 70, 66)
TEXT = (205, 204, 196)
TEXT_DIM = (140, 140, 134)
TITLE = (226, 225, 216)
DIVIDER = (60, 60, 56)

RELEVANCIA = {
	"critica": ("CRÍTICA", (176, 58, 46), (240, 230, 224)),
	"alta": ("ALTA", (196, 128, 52), (24, 22, 20)),
	"media": ("MEDIA", (154, 151, 120), (30, 30, 26)),
	"baja": ("BAJA", (96, 98, 96), (220, 220, 212)),
}
ORDEN = ["critica", "alta", "media", "baja"]


def font(size):
	return ImageFont.truetype(FONT, size)


def norm(s):
	s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
	return s.lower().strip()


def git(*args):
	try:
		return subprocess.check_output(["git", "-C", REPO] + list(args), stderr=subprocess.DEVNULL).decode().strip()
	except Exception:
		return ""


def wrap(draw, text, fnt, width):
	lines, cur = [], ""
	for word in text.split():
		test = word if not cur else cur + " " + word
		if draw.textlength(test, font=fnt) <= width or not cur:
			cur = test
		else:
			lines.append(cur)
			cur = word
	if cur:
		lines.append(cur)
	return lines


def background(h):
	rng = np.random.default_rng(2033)
	y = np.linspace(0, 1, h)[:, None]
	base = np.array(BG_TOP)[None, None, :] * (1 - y[..., None]) + np.array(BG_BOT)[None, None, :] * y[..., None]
	base = np.repeat(base, W, axis=1)

	# manchas suaves y grano
	small = rng.random((h // 60 + 2, W // 60 + 2))
	blot = np.array(Image.fromarray((small * 255).astype(np.uint8)).resize((W, h), Image.BICUBIC)) / 255.0
	base += (blot[..., None] - 0.5) * 14
	base += rng.normal(0, 3.2, (h, W, 1))

	# viñeta
	yy, xx = np.mgrid[0:h, 0:W]
	d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - h * 0.4) / (h * 0.75)) ** 2)
	base *= np.clip(1.08 - d * 0.32, 0.55, 1)[..., None]

	img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")

	# retícula técnica muy tenue (mapa) y líneas de escaneo
	over = Image.new("RGBA", (W, h), (0, 0, 0, 0))
	od = ImageDraw.Draw(over)
	for x in range(0, W, 64):
		od.line([(x, 0), (x, h)], fill=(255, 255, 255, 6))
	for yv in range(0, h, 64):
		od.line([(0, yv), (W, yv)], fill=(255, 255, 255, 6))
	for i in range(14):
		cx, cy, r = rng.integers(0, W), rng.integers(0, h), rng.integers(40, 260)
		od.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 7), width=1)
	for yv in range(0, h, 3):
		od.line([(0, yv), (W, yv)], fill=(0, 0, 0, 10))
	return Image.alpha_composite(img, over)


def icon_head(d, x, y, color):
	# rombo con muesca: insignia de EFG (sin logos de terceros)
	d.polygon([(x + 11, y), (x + 22, y + 11), (x + 11, y + 22), (x, y + 11)], outline=color, width=2)
	d.polygon([(x + 11, y + 6), (x + 16, y + 11), (x + 11, y + 16), (x + 6, y + 11)], fill=color)


def icon_arrow(d, x, y, color):
	for i in range(3):
		d.rectangle([x + i * 4, y + 7, x + i * 4 + 1, y + 13], fill=color)
	d.rectangle([x + 12, y + 8, x + 18, y + 12], fill=color)
	d.polygon([(x + 18, y + 3), (x + 26, y + 10), (x + 18, y + 17)], fill=color)


class Card:
	PAD = 26
	HEAD = 58
	BAR = 30
	LINE_H = 27

	def __init__(self, data, width, draw):
		self.data = data
		self.width = width
		rel = norm(data.get("relevancia", "media"))
		self.rel = rel if rel in RELEVANCIA else "media"
		self.f_head = font(28)
		self.f_bar = font(18)
		self.f_body = font(19)
		inner = width - self.PAD * 2 - 20
		self.items = [wrap(draw, t, self.f_body, inner) for t in data.get("cambios", [])]
		self.nota = wrap(draw, data["nota"], self.f_body, inner) if data.get("nota") else None
		self.area = data.get("area", "General")

	def height(self):
		h = self.HEAD + self.BAR + 22
		for lines in self.items:
			h += len(lines) * self.LINE_H + 8
		if self.nota:
			h += 30 + len(self.nota) * self.LINE_H + 8
		return h + 18

	def draw(self, img, x, y, h=None):
		h = h or self.height()
		layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
		d = ImageDraw.Draw(layer)
		label, bar_col, bar_txt = RELEVANCIA[self.rel]

		d.rectangle([x, y, x + self.width, y + h], fill=CARD, outline=CARD_LINE, width=1)
		d.rectangle([x + 1, y + 1, x + self.width - 1, y + self.HEAD], fill=CARD_HEAD)
		icon_head(d, x + 18, y + 18, TITLE)
		title = self.area
		while d.textlength(title, font=self.f_head) > self.width - 124 and len(title) > 4:
			title = title[:-2]
		if title != self.area:
			title = title.rstrip() + "…"
		d.text((x + 52, y + self.HEAD / 2), title, font=self.f_head, fill=TITLE, anchor="lm")
		icon_arrow(d, x + self.width - 46, y + 19, TITLE)

		by = y + self.HEAD
		d.rectangle([x + 1, by, x + self.width - 1, by + self.BAR], fill=bar_col)
		d.text((x + self.width / 2, by + self.BAR / 2), "Relevancia: " + label, font=self.f_bar, fill=bar_txt, anchor="mm")

		cy = by + self.BAR + 22
		for lines in self.items:
			d.ellipse([x + self.PAD + 2, cy + 9, x + self.PAD + 7, cy + 14], fill=TEXT)
			for ln in lines:
				d.text((x + self.PAD + 20, cy), ln, font=self.f_body, fill=TEXT)
				cy += self.LINE_H
			cy += 8
		if self.nota:
			cy += 6
			for dx in range(x + 8, x + self.width - 8, 6):
				d.line([(dx, cy), (dx + 2, cy)], fill=DIVIDER)
			cy += 24
			d.ellipse([x + self.PAD + 2, cy + 9, x + self.PAD + 7, cy + 14], fill=TEXT_DIM)
			for ln in self.nota:
				d.text((x + self.PAD + 20, cy), ln, font=self.f_body, fill=TEXT_DIM)
				cy += self.LINE_H

		shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
		ImageDraw.Draw(shadow).rectangle([x + 6, y + 8, x + self.width + 6, y + h + 8], fill=(0, 0, 0, 120))
		shadow = shadow.filter(ImageFilter.GaussianBlur(10))
		img.alpha_composite(shadow)
		img.alpha_composite(layer)


def brand_panel(img, x, y, w, h, info):
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	d = ImageDraw.Draw(layer)
	# degradado frío de arriba (humo) a abajo (azul acero), como la tarjeta de lanzamiento
	for i in range(h):
		t = i / max(h - 1, 1)
		c = (int(52 - 22 * t), int(46 - 8 * t + 10 * t * t), int(42 + 18 * t * t), 245)
		d.line([(x, y + i), (x + w, y + i)], fill=c)
	d.rectangle([x, y, x + w, y + h], outline=CARD_LINE, width=1)
	for k in range(0, h, 4):
		d.line([(x, y + k), (x + w, y + k)], fill=(0, 0, 0, 22))

	cx = x + w / 2
	my = y + h * 0.42
	d.text((cx, my - 74), "ESCAPER  FROM  GMOD", font=font(24), fill=(200, 198, 190), anchor="mm")
	d.text((cx + 3, my + 4), "EFG", font=font(120), fill=(0, 0, 0, 160), anchor="mm")
	d.text((cx, my), "EFG", font=font(120), fill=(232, 231, 224), anchor="mm")
	d.text((cx, my + 72), "NOVEDADES", font=font(40), fill=(88, 160, 168), anchor="mm")
	d.text((cx, my + 108), info["ver"], font=font(18), fill=(190, 190, 184), anchor="mm")

	by = y + h - 120
	icon_head(d, int(cx - 11), by - 20, (150, 150, 144))
	d.text((cx, by + 40), info["anio"], font=font(34), fill=(170, 170, 164), anchor="mm")
	img.alpha_composite(layer)


def slugify(s):
	s = norm(s)
	s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
	return s[:48] or "cambios"


def render(data, out_dir):
	fecha = data.get("fecha") or datetime.date.today().isoformat()
	tarjetas = sorted(data.get("tarjetas", []), key=lambda c: ORDEN.index(norm(c.get("relevancia", "media"))) if norm(c.get("relevancia", "media")) in ORDEN else 2)
	if not tarjetas:
		sys.exit("cambios.json sin tarjetas")
	titulo = data.get("titulo") or "Novedades de EFG"
	base = git("rev-parse", "--short", "HEAD") or "?"

	margin, gap, panel_w = 150, 46, 330
	ncols = min(3, len(tarjetas))
	avail = W - margin * 2 - panel_w - gap
	cw = int((avail - gap * (ncols - 1)) / ncols)

	tmp = ImageDraw.Draw(Image.new("RGB", (8, 8)))
	cards = [Card(c, cw, tmp) for c in tarjetas]
	cols = [[] for _ in range(ncols)]
	col_h = [0] * ncols
	for c in cards:
		i = col_h.index(min(col_h))
		cols[i].append(c)
		col_h[i] += c.height() + gap
	content_h = max(max(col_h) - gap, 560)

	top = 220
	H = max(1080, top + content_h + 190)
	img = background(H)
	d = ImageDraw.Draw(img)

	f_title = font(60)
	while d.textlength(titulo, font=f_title) > W - 300 and f_title.size > 34:
		f_title = font(f_title.size - 2)
	d.text((W / 2 + 2, 112 + 3), titulo, font=f_title, fill=(0, 0, 0), anchor="mm")
	d.text((W / 2, 112), titulo, font=f_title, fill=TITLE, anchor="mm")
	resumen = "  ·  ".join(
		"%d %s" % (sum(1 for c in cards if c.rel == r), RELEVANCIA[r][0].lower()) for r in ORDEN if any(c.rel == r for c in cards)
	)
	d.text((W / 2, 166), resumen, font=font(22), fill=TEXT_DIM, anchor="mm")

	for i, col in enumerate(cols):
		x = margin + i * (cw + gap)
		y = top
		for j, c in enumerate(col):
			last = j == len(col) - 1
			c.draw(img, x, y, (top + content_h - y) if last else None)
			y += c.height() + gap

	px = W - margin - panel_w
	brand_panel(img, px, top, panel_w, content_h, {"ver": "SOBRE " + base.upper(), "anio": fecha[:4]})

	d = ImageDraw.Draw(img)
	fy = H - 70
	d.text((70, fy), "EFG", font=font(46), fill=(190, 190, 184), anchor="lm")
	d.text((W / 2, fy), "Metro RP By Cono y Manperra  ·  %s  ·  sobre %s" % (fecha, base), font=font(22), fill=TEXT_DIM, anchor="mm")
	d.text((W - 70, fy), "Escaper from Gmod", font=font(22), fill=TEXT_DIM, anchor="rm")

	os.makedirs(out_dir, exist_ok=True)
	name = "%s-%s.png" % (fecha, slugify(titulo))
	path = os.path.join(out_dir, name)
	n = 2
	while os.path.exists(path):
		path = os.path.join(out_dir, "%s-%s-%d.png" % (fecha, slugify(titulo), n))
		n += 1
	img.convert("RGB").save(path, optimize=True)
	return path, fecha, titulo, cards


def update_index(out_dir, path, fecha, titulo, cards):
	idx = os.path.join(out_dir, "README.md")
	head = "# Novedades de EFG\n\nUna imagen por commit, la más reciente arriba. Se generan con `python tools/novedades.py cambios.json`.\n\n"
	body = ""
	if os.path.exists(idx):
		with open(idx, encoding="utf-8") as f:
			old = f.read()
		body = old[len(head):] if old.startswith(head) else old
	rel = ", ".join("%s (%s)" % (c.area, RELEVANCIA[c.rel][0].lower()) for c in cards)
	entry = "## %s · %s\n\n%s\n\n![%s](%s)\n\n" % (fecha, titulo, rel, titulo, os.path.basename(path))
	with open(idx, "w", encoding="utf-8") as f:
		f.write(head + entry + body)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("json")
	ap.add_argument("--salida", default=os.path.join(REPO, "docs", "novedades"))
	ap.add_argument("--sin-indice", action="store_true")
	a = ap.parse_args()
	with open(a.json, encoding="utf-8") as f:
		data = json.load(f)
	path, fecha, titulo, cards = render(data, a.salida)
	if not a.sin_indice:
		update_index(a.salida, path, fecha, titulo, cards)
	print(os.path.relpath(path, REPO).replace(os.sep, "/"))


if __name__ == "__main__":
	main()
