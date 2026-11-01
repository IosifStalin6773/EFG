"""Le pone el estilo de EFG al menú principal de GMod.

El menú de GMod (portada, Extensiones, servidores, Empezar nueva, Copias...)
sale de garrysmod/html y garrysmod/resource, que ningún addon ni gamemode puede
cambiar. Este parche:

  1. Copia tools/menu_gmod/efg_menu.css, la fuente Bender, el logo y la
     ilustración de portada en garrysmod/html/efg/.
  2. Añade ese CSS al final del <head> de garrysmod/html/menu.html.
  3. Cambia garrysmod/html/template/main.html por tools/menu_gmod/main.html
     (portada al estilo de EFT: botón grande central y barra inferior).
  4. Recolorea garrysmod/resource/SourceScheme.res con la paleta de EFG
     (ventana de Opciones y demás ventanas VGUI del motor).

Uso:
	python tools/parche_menu_gmod.py "C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod"
	python tools/parche_menu_gmod.py <garrysmod> --quitar

Cada archivo tocado se guarda antes como <archivo>.orig. Una actualización de
GMod quita el parche: basta con volver a ejecutarlo. Hay que reiniciar GMod
para ver los cambios.
"""
import os, re, shutil, sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MENU = os.path.join(RAIZ, "tools", "menu_gmod")

MARCA_HTML = "<!-- EFG: menu -->"
ENLACE = MARCA_HTML + "\n\t<link rel=\"stylesheet\" type=\"text/css\" href=\"efg/efg_menu.css\" />\n"
MARCA_MAIN = "efg-main"
MARCA_SCHEME = "// EFG: paleta"

RECURSOS = {
	"efg_menu.css": os.path.join(MENU, "efg_menu.css"),
	"mbender.ttf": os.path.join(RAIZ, "content", "resource", "fonts", "mbender.ttf"),
	"logo.png": os.path.join(RAIZ, "content", "materials", "efgui", "logo32028.png"),
	"main_art.jpg": os.path.join(RAIZ, "content", "materials", "efg", "menu", "main_art.jpg"),
}

# Colores de SourceScheme.res (RGBA). Paleta de efg_ui/cl_css.lua.
FONDO = "28 30 27"
TEXTO = "200 198 180 255"
TEXTO2 = "154 152 136 255"
TEXTO_HI = "232 230 214 255"
NEGRO = "14 15 13 255"
CELDA = "18 19 17 255"
BOTON = "44 47 41 255"
LINEA = "58 61 54 255"
LINEA2 = "86 90 80 255"
NARANJA = "227 114 45 255"
NARANJA_SEL = "227 114 45 204"
NARANJA_OFF = "227 114 45 90"

COLORES = {
	"GMod_BG_Opaque": FONDO + " 250",
	"GMod_BG": FONDO + " 0",
	"Border.Bright": LINEA2,
	"Border.Dark": "0 0 0 200",
	"Border.DarkSolid": NEGRO,
	"Border.Subtle": LINEA,
	"Button.TextColor": TEXTO,
	"Button.BgColor": BOTON,
	"Button.ArmedTextColor": NEGRO,
	"Button.ArmedBgColor": TEXTO,
	"Button.DepressedTextColor": "18 12 6 255",
	"Button.DepressedBgColor": NARANJA,
	"Button.FocusBorderColor": NARANJA,
	"CheckButton.BgColor": CELDA,
	"CheckButton.Check": NARANJA,
	"CheckButton.DisabledBgColor": BOTON,
	"ComboBoxButton.ArrowColor": TEXTO,
	"ComboBoxButton.ArmedArrowColor": NARANJA,
	"Frame.OutOfFocusBgColor": FONDO + " 240",
	"FrameTitleBar.TextColor": TEXTO,
	"FrameTitleButton.FgColor": TEXTO,
	"Label.TextDullColor": TEXTO2,
	"Label.TextColor": TEXTO,
	"Label.TextBrightColor": TEXTO_HI,
	"ListPanel.TextColor": TEXTO,
	"ListPanel.BgColor": CELDA,
	"ListPanel.SelectedBgColor": NARANJA_SEL,
	"ListPanel.OutOfFocusSelectedTextColor": TEXTO,
	"ListPanel.SelectedOutOfFocusBgColor": NARANJA_OFF,
	"ListPanel.EmptyListInfoTextColor": TEXTO2,
	"Menu.TextColor": TEXTO,
	"Menu.BgColor": FONDO + " 255",
	"Menu.ArmedTextColor": NEGRO,
	"Menu.ArmedBgColor": NARANJA,
	"PropertySheet.TextColor": TEXTO2,
	"PropertySheet.SelectedTextColor": TEXTO_HI,
	"PropertySheet.SelectedBgColor": NARANJA,
	"PropertySheet.BgColor": NEGRO,
	"RichText.SelectedBgColor": NARANJA_SEL,
	"ScrollBarButton.FgColor": TEXTO,
	"ScrollBarButton.BgColor": BOTON,
	"ScrollBarButton.ArmedFgColor": NEGRO,
	"ScrollBarButton.ArmedBgColor": TEXTO,
	"ScrollBarButton.DepressedFgColor": "18 12 6 255",
	"ScrollBarButton.DepressedBgColor": NARANJA,
	"ScrollBarSlider.FgColor": LINEA2,
	"ScrollBarSlider.BgColor": "18 19 17 229",
	"SectionedListPanel.HeaderTextColor": NARANJA,
	"SectionedListPanel.DividerColor": LINEA,
	"SectionedListPanel.TextColor": TEXTO,
	"SectionedListPanel.BrightTextColor": TEXTO_HI,
	"SectionedListPanel.BgColor": CELDA,
	"SectionedListPanel.SelectedBgColor": NARANJA_SEL,
	"SectionedListPanel.OutOfFocusSelectedTextColor": TEXTO,
	"SectionedListPanel.OutOfFocusSelectedBgColor": NARANJA_OFF,
	"Slider.NobColor": TEXTO,
	"Slider.TextColor": TEXTO2,
	"Slider.TrackColor": "58 61 54 229",
	"TextEntry.TextColor": TEXTO,
	"TextEntry.BgColor": CELDA,
	"TextEntry.CursorColor": NARANJA,
	"TextEntry.DisabledTextColor": "104 106 94 255",
	"TextEntry.DisabledBgColor": "37 39 35 255",
	"TextEntry.SelectedTextColor": NEGRO,
	"TextEntry.SelectedBgColor": NARANJA_SEL,
	"TextEntry.OutOfFocusSelectedBgColor": NARANJA_OFF,
	"TextEntry.FocusEdgeColor": "227 114 45 196",
	"Tooltip.TextColor": TEXTO,
	"Tooltip.BgColor": NEGRO,
}


def UsaRecursos(carpeta):
	# El launcher empaquetado lleva todos los recursos juntos en una carpeta.
	global MENU
	MENU = carpeta
	for nombre, origen in RECURSOS.items():
		RECURSOS[nombre] = os.path.join(carpeta, os.path.basename(origen))


def EstaAplicado(gmod):
	menu = os.path.join(gmod, "html", "menu.html")
	main = os.path.join(gmod, "html", "template", "main.html")
	if (not os.path.exists(menu) or not os.path.exists(main)):
		return False
	return MARCA_HTML in Lee(menu) and MARCA_MAIN in Lee(main)


def Copia(ruta):
	# Solo se llama con el archivo sin parchear: tras una actualización de GMod
	# la copia vieja se sustituye por la nueva.
	shutil.copyfile(ruta, ruta + ".orig")


def Restaura(ruta):
	if (os.path.exists(ruta + ".orig")):
		shutil.copyfile(ruta + ".orig", ruta)
		os.remove(ruta + ".orig")
		print("Restaurado " + ruta)


def Lee(ruta):
	with open(ruta, encoding="utf-8", errors="surrogateescape") as f:
		return f.read()


def Escribe(ruta, texto):
	with open(ruta, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
		f.write(texto)


def ParcheaScheme(ruta):
	texto = Lee(ruta)
	if (MARCA_SCHEME in texto):
		print("SourceScheme.res ya estaba parcheado")
		return

	cambiados = set()

	def Cambia(m):
		clave = m.group(2)
		if (clave not in COLORES or "X360" in m.group(5)):
			return m.group(0)
		cambiados.add(clave)
		return m.group(1) + m.group(2) + m.group(3) + m.group(4) + "\"" + COLORES[clave] + "\"" + m.group(5)

	patron = re.compile(r'^(\s*"?)([\w.]+)("?)(\s+)"[^"]*"([^\r\n]*)$', re.M)
	texto = patron.sub(Cambia, texto)
	faltan = sorted(set(COLORES) - cambiados)
	if (faltan):
		print("Aviso: no encuentro en SourceScheme.res " + ", ".join(faltan))

	Copia(ruta)
	Escribe(ruta, MARCA_SCHEME + "\n" + texto)
	print("Parcheado " + ruta + " (" + str(len(cambiados)) + " colores)")


def Aplica(gmod):
	html = os.path.join(gmod, "html")
	menu = os.path.join(html, "menu.html")
	main = os.path.join(html, "template", "main.html")
	scheme = os.path.join(gmod, "resource", "SourceScheme.res")

	for ruta in (menu, main):
		if (not os.path.exists(ruta)):
			print("No encuentro " + ruta + ": ¿es la carpeta garrysmod?")
			return 1

	destino = os.path.join(html, "efg")
	os.makedirs(destino, exist_ok=True)
	for nombre, origen in RECURSOS.items():
		shutil.copyfile(origen, os.path.join(destino, nombre))
	print("Copiados " + str(len(RECURSOS)) + " archivos en " + destino)

	texto = Lee(menu)
	if (MARCA_HTML in texto):
		print("menu.html ya estaba parcheado")
	elif ("</head>" not in texto):
		print("GMod ha cambiado menu.html: no encuentro </head>")
		return 1
	else:
		Copia(menu)
		Escribe(menu, texto.replace("</head>", ENLACE + "\n</head>", 1))
		print("Parcheado " + menu)

	if (MARCA_MAIN not in Lee(main)):
		Copia(main)
	shutil.copyfile(os.path.join(MENU, "main.html"), main)
	print("Cambiado " + main)

	if (os.path.exists(scheme)):
		ParcheaScheme(scheme)
	else:
		print("No encuentro " + scheme + ": la ventana de Opciones se queda como estaba")

	print("Listo. Reinicia GMod para ver el menú nuevo.")
	return 0


def Quita(gmod):
	html = os.path.join(gmod, "html")
	Restaura(os.path.join(html, "menu.html"))
	Restaura(os.path.join(html, "template", "main.html"))
	Restaura(os.path.join(gmod, "resource", "SourceScheme.res"))
	destino = os.path.join(html, "efg")
	if (os.path.isdir(destino)):
		shutil.rmtree(destino)
		print("Borrado " + destino)
	return 0


def main():
	if (len(sys.argv) < 2):
		print(__doc__)
		return 1

	if ("--quitar" in sys.argv):
		return Quita(sys.argv[1])

	return Aplica(sys.argv[1])


if (__name__ == "__main__"):
	sys.exit(main())
