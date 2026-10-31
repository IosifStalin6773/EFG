"""Hace que la pantalla de carga de GMod abra la de EFG en partidas locales.

GMod no usa sv_loadingurl para el jugador que crea la partida: le enseña
garrysmod/html/loading.html. Este parche cambia, al principio de GameDetails,
el fondo y el logo de esa misma página por los de EFG cuando el gamemode es
metrorp (sin salir de la página: saltar a otra dejaba la pantalla en gris). Con otros gamemodes la pantalla no cambia.

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
					var efgLogo = document.querySelector( "#logo" );
					efgLogo.onerror = function() { efgLogo.onerror = null; efgLogo.src = "img/gmod_logo_brave.png"; };
					efgLogo.src = "asset://garrysmod/materials/efgui/logo32028.png";
					efgLogo.style.width = "300px";
					document.querySelector( ".walk" ).style.display = "none";
					document.querySelector( "#serverName" ).innerText = servername;
					document.querySelector( "#serverMap" ).innerText = mapname;
					document.querySelector( "#serverGamemode" ).innerText = gamemodeNice;
					document.querySelector( "#mapimg" ).setAttribute( "src", "asset://mapimage/" + mapname );
					document.querySelector( ".server_info" ).classList.add( "visible" );
					document.body.style.backgroundColor = "#0e0f0d";
					document.body.style.backgroundImage = "url('asset://garrysmod/materials/efgui/backgrounds/load.jpg'), url('asset://mapimage/" + mapname + "')";
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
