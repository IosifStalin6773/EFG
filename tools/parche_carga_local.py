"""Hace que la pantalla de carga de GMod abra la de EFG en partidas locales.

GMod no usa sv_loadingurl para el jugador que crea la partida: le enseña
garrysmod/html/loading.html. Este parche añade al principio de GameDetails un
salto a efg_loading.html (content/html del gamemode) cuando el gamemode es
metrorp. Con otros gamemodes la pantalla no cambia.

Uso:
	python tools/parche_carga_local.py "C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod"
	python tools/parche_carga_local.py <garrysmod> --quitar

Guarda una copia en html/loading.html.orig. Una actualización de GMod quita el
parche: basta con volver a ejecutarlo.
"""
import os, shutil, sys

MARCA = "/* EFG: pantalla de carga */"
PARCHE = MARCA + """
				if ( gamemode == "metrorp" ) {
					window.location.href = "efg_loading.html?server=" + encodeURIComponent( servername ) + "&map=" + encodeURIComponent( mapname );
					return;
				}
"""
ANCLA = "var mapImg = \"asset://mapimage/\" + mapname;"


def main():
	if (len(sys.argv) < 2):
		print(__doc__)
		return 1

	ruta = os.path.join(sys.argv[1], "html", "loading.html")
	copia = ruta + ".orig"

	if ("--quitar" in sys.argv):
		if (os.path.exists(copia)):
			shutil.copyfile(copia, ruta)
			print("Restaurado " + ruta)
		else:
			print("No hay copia en " + copia)
		return 0

	with open(ruta, encoding="utf-8") as f:
		texto = f.read()

	if (MARCA in texto):
		print("Ya estaba parcheado")
		return 0

	if (ANCLA not in texto):
		print("GMod ha cambiado loading.html: no encuentro GameDetails")
		return 1

	shutil.copyfile(ruta, copia)
	texto = texto.replace(ANCLA, PARCHE + "\t\t\t\t" + ANCLA, 1)

	with open(ruta, "w", encoding="utf-8", newline="") as f:
		f.write(texto)

	print("Parcheado " + ruta + " (copia en " + copia + ")")
	return 0


if (__name__ == "__main__"):
	sys.exit(main())
