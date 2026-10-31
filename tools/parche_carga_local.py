"""Hace que la pantalla de carga de GMod abra la de EFG en partidas locales.

GMod no usa sv_loadingurl para el jugador que crea la partida: le enseña
garrysmod/html/loading.html. Este parche cambia, al principio de GameDetails,
la página por una pantalla de arranque al estilo de EFT (arte, logo de EFG,
barra y estado) cuando el gamemode es
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
				if ( gamemode == "metrorp" && !window.efgCarga ) {
					window.efgCarga = true;
					var efgAsset = "asset://garrysmod/materials/";
					var efgCss = document.createElement( "style" );
					efgCss.textContent =
						"@font-face { font-family: Bender; src: url('asset://garrysmod/resource/fonts/mbender.ttf'); }" +
						"#background, #container, .server_info, #spambox { display: none !important; }" +
						"#efg { position: fixed; left: 0; top: 0; right: 0; bottom: 0; background: #0e0f0d url('" + efgAsset + "efg/menu/main_art.jpg') center / cover no-repeat; font-family: Bender, sans-serif; color: #c8c6b4; text-transform: uppercase; overflow: hidden; }" +
						"#efg-shade { position: absolute; left: 0; top: 0; right: 0; bottom: 0; background: radial-gradient(ellipse at center, rgba(14,15,13,.35) 0%, rgba(14,15,13,.85) 70%, #0e0f0d 100%); }" +
						"#efg-logo { position: absolute; left: 50%; top: 44%; width: 36vw; transform: translate(-50%, -50%); opacity: 0; animation: efgIn 1.2s ease-out .2s forwards; }" +
						"#efg-load { position: absolute; left: 50%; top: 58%; width: 36vw; transform: translateX(-50%); opacity: 0; animation: efgIn 1s ease-out .8s forwards; }" +
						"#efg-bar { position: relative; height: 2px; background: rgba(200,198,180,.15); overflow: hidden; }" +
						"#efg-fill { position: absolute; left: 0; top: 0; bottom: 0; width: 0; background: #e3722d; transition: width .4s; }" +
						"#efg-run { position: absolute; top: 0; bottom: 0; width: 25%; background: linear-gradient(90deg, transparent, #e3722d, transparent); animation: efgRun 1.6s linear infinite; }" +
						"#efg-status { margin-top: 1.2vh; font-size: 1.5vh; letter-spacing: .15em; color: #9a9888; text-align: center; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }" +
						"#efg-info { position: absolute; left: 3vw; bottom: 3vh; font-size: 1.4vh; letter-spacing: .12em; color: #686a5e; line-height: 1.6; }" +
						"#efg-info b { color: #9a9888; font-weight: normal; }" +
						"#efg-spin { position: absolute; right: 3vw; bottom: 3vh; width: 2.6vh; height: 2.6vh; border: 2px solid rgba(200,198,180,.15); border-top-color: #e3722d; border-radius: 50%; animation: efgSpin 1s linear infinite; }" +
						"@keyframes efgIn { from { opacity: 0; } to { opacity: 1; } }" +
						"@keyframes efgRun { from { left: -25%; } to { left: 100%; } }" +
						"@keyframes efgSpin { to { transform: rotate(360deg); } }";
					document.head.appendChild( efgCss );

					var efg = document.createElement( "div" );
					efg.id = "efg";
					efg.innerHTML = "<div id='efg-shade'></div>" +
						"<img id='efg-logo' src='" + efgAsset + "efgui/logo32028.png'>" +
						"<div id='efg-load'><div id='efg-bar'><div id='efg-fill'></div><div id='efg-run'></div></div><div id='efg-status'>Cargando...</div></div>" +
						"<div id='efg-info'><b id='efg-server'></b><br><span id='efg-map'></span></div>" +
						"<div id='efg-spin'></div>";
					document.body.appendChild( efg );
					document.getElementById( "efg-server" ).innerText = servername;
					document.getElementById( "efg-map" ).innerText = mapname;

					var efgTotal = 0, efgNeeded = 0;
					var efgBar = function() {
						if ( efgTotal <= 0 ) return;
						document.getElementById( "efg-run" ).style.display = "none";
						document.getElementById( "efg-fill" ).style.width = Math.min( ( efgTotal - efgNeeded ) / efgTotal * 100, 100 ) + "%";
					};
					window.SetFilesTotal = function( n ) { efgTotal = n; efgBar(); };
					window.SetFilesNeeded = function( n ) { efgNeeded = n; efgBar(); };
					window.SetStatusChanged = function( text ) { document.getElementById( "efg-status" ).innerText = text; };
					window.DownloadingFile = function( file ) { document.getElementById( "efg-status" ).innerText = "Descargando " + file; };
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
