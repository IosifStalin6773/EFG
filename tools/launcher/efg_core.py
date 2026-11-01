"""Lógica del launcher de EFG sin interfaz: Steam, colección, parche y arranque.

Se puede usar sola desde consola:
	python tools/launcher/efg_core.py estado
	python tools/launcher/efg_core.py parche | quitar | jugar | web
"""
import base64, json, os, re, shutil, socket, struct, subprocess, sys, urllib.parse, urllib.request

AQUI = os.path.dirname(os.path.abspath(__file__))
API = "https://api.steampowered.com/ISteamRemoteStorage/"
APP_GMOD = "4000"


def Recursos():
	# Con PyInstaller los datos van en sys._MEIPASS; en el repo, junto al script.
	return getattr(sys, "_MEIPASS", AQUI)


def CargaConfig():
	config = {}
	rutas = [os.path.join(Recursos(), "launcher.json")]
	# Un launcher.json junto al .exe manda sobre el empaquetado.
	if (getattr(sys, "frozen", False)):
		rutas.append(os.path.join(os.path.dirname(sys.executable), "launcher.json"))
	else:
		rutas.append(os.path.join(AQUI, "launcher.local.json"))
	for ruta in rutas:
		if (os.path.exists(ruta)):
			with open(ruta, encoding="utf-8") as f:
				config.update(json.load(f))
	return config


def GuardaLocal(config, claves):
	ruta = os.path.join(os.path.dirname(sys.executable), "launcher.json") if getattr(sys, "frozen", False) else os.path.join(AQUI, "launcher.local.json")
	datos = {}
	if (os.path.exists(ruta)):
		with open(ruta, encoding="utf-8") as f:
			datos = json.load(f)
	for clave in claves:
		datos[clave] = config.get(clave)
	with open(ruta, "w", encoding="utf-8") as f:
		json.dump(datos, f, indent="\t", ensure_ascii=False)


# --- Steam -------------------------------------------------------------------

def RutaSteam():
	if (sys.platform == "win32"):
		import winreg
		for raiz, clave, valor in (
			(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam", "SteamPath"),
			(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath"),
			(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Valve\Steam", "InstallPath"),
		):
			try:
				with winreg.OpenKey(raiz, clave) as k:
					ruta = winreg.QueryValueEx(k, valor)[0]
					if (os.path.isdir(ruta)):
						return os.path.normpath(ruta)
			except OSError:
				pass
		return None

	for ruta in ("~/.steam/steam", "~/.local/share/Steam", "~/Library/Application Support/Steam"):
		ruta = os.path.expanduser(ruta)
		if (os.path.isdir(ruta)):
			return ruta
	return None


def SteamAbierto():
	"""True si Steam está en marcha (Windows: pid de ActiveProcess distinto de 0)."""
	if (sys.platform == "win32"):
		import winreg
		try:
			with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam\ActiveProcess") as k:
				return int(winreg.QueryValueEx(k, "pid")[0]) != 0
		except OSError:
			return False
	try:
		return subprocess.run(["pgrep", "-x", "steam"], capture_output=True).returncode == 0
	except OSError:
		return False


def SteamUsuario(steam):
	"""Cuenta de Steam con la que se entró por última vez: {nombre, avatar (data URL o ""), enlinea}."""
	usuario = {"nombre": "", "avatar": "", "enlinea": SteamAbierto()}
	if (not steam):
		return usuario
	vdf = os.path.join(steam, "config", "loginusers.vdf")
	if (not os.path.exists(vdf)):
		return usuario
	with open(vdf, encoding="utf-8", errors="replace") as f:
		cuentas = LeeVDF(f.read()).get("users", {})
	elegido = None
	for sid, datos in cuentas.items():
		if (isinstance(datos, dict) and (elegido is None or datos.get("MostRecent") == "1")):
			elegido = (sid, datos)
	if (not elegido):
		return usuario
	sid, datos = elegido
	usuario["nombre"] = datos.get("PersonaName") or datos.get("AccountName") or ""
	avatar = os.path.join(steam, "config", "avatarcache", sid + ".png")
	if (os.path.exists(avatar)):
		with open(avatar, "rb") as f:
			usuario["avatar"] = "data:image/png;base64," + base64.b64encode(f.read()).decode()
	return usuario


def LeeVDF(texto):
	"""Parser mínimo de KeyValues de Valve (libraryfolders.vdf, appworkshop_*.acf)."""
	fichas = re.findall(r'"((?:[^"\\]|\\.)*)"|([{}])', texto)
	pila = [{}]
	clave = None
	for cadena, llave in fichas:
		if (llave == "{"):
			nuevo = {}
			pila[-1][clave] = nuevo
			pila.append(nuevo)
			clave = None
		elif (llave == "}"):
			if (len(pila) > 1):
				pila.pop()
		elif (clave is None):
			clave = cadena.replace("\\\\", "\\")
		else:
			pila[-1][clave] = cadena.replace("\\\\", "\\")
			clave = None
	return pila[0]


def Bibliotecas(steam):
	libs = [steam]
	vdf = os.path.join(steam, "steamapps", "libraryfolders.vdf")
	if (os.path.exists(vdf)):
		with open(vdf, encoding="utf-8", errors="replace") as f:
			datos = LeeVDF(f.read())
		for valor in datos.get("libraryfolders", {}).values():
			ruta = valor.get("path") if isinstance(valor, dict) else valor
			if (ruta and os.path.isdir(ruta) and os.path.normcase(ruta) not in map(os.path.normcase, libs)):
				libs.append(os.path.normpath(ruta))
	return libs


def BuscaGMod(steam):
	"""Devuelve (biblioteca, carpeta garrysmod) o (None, None)."""
	if (not steam):
		return None, None
	for lib in Bibliotecas(steam):
		gmod = os.path.join(lib, "steamapps", "common", "GarrysMod", "garrysmod")
		if (os.path.isdir(gmod)):
			return lib, gmod
	return None, None


def BibliotecaDe(gmod):
	# <lib>/steamapps/common/GarrysMod/garrysmod
	return os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.normpath(gmod)))))


def Instalados(gmod):
	"""IDs de Workshop de GMod descargados en la biblioteca de GMod."""
	lib = BibliotecaDe(gmod)
	ids = set()
	carpeta = os.path.join(lib, "steamapps", "workshop", "content", APP_GMOD)
	if (os.path.isdir(carpeta)):
		for nombre in os.listdir(carpeta):
			ruta = os.path.join(carpeta, nombre)
			if (nombre.isdigit() and os.path.isdir(ruta) and os.listdir(ruta)):
				ids.add(nombre)
	acf = os.path.join(lib, "steamapps", "workshop", "appworkshop_" + APP_GMOD + ".acf")
	if (os.path.exists(acf)):
		with open(acf, encoding="utf-8", errors="replace") as f:
			datos = LeeVDF(f.read())
		ids.update(k for k in datos.get("AppWorkshop", {}).get("WorkshopItemsInstalled", {}) if k.isdigit())
	return ids


# --- API pública de Steam (sin clave) ------------------------------------------

def _Post(metodo, campos):
	datos = urllib.parse.urlencode(campos).encode()
	req = urllib.request.Request(API + metodo + "/v1/", data=datos, headers={"User-Agent": "EFG-Launcher"})
	with urllib.request.urlopen(req, timeout=20) as r:
		return json.load(r)["response"]


def Hijos(coleccion):
	"""IDs de una colección; abre las colecciones anidadas."""
	vistos, pendientes, objetos = set(), [str(coleccion)], []
	while (pendientes):
		actual = pendientes.pop()
		if (actual in vistos):
			continue
		vistos.add(actual)
		r = _Post("GetCollectionDetails", {"collectioncount": 1, "publishedfileids[0]": actual})
		for det in r.get("collectiondetails", []):
			for hijo in det.get("children", []):
				if (hijo.get("filetype") == 2):
					pendientes.append(hijo["publishedfileid"])
				elif (hijo["publishedfileid"] not in objetos):
					objetos.append(hijo["publishedfileid"])
	return objetos


def Detalles(ids):
	if (not ids):
		return {}
	campos = {"itemcount": len(ids)}
	for i, x in enumerate(ids):
		campos["publishedfileids[%d]" % i] = x
	r = _Post("GetPublishedFileDetails", campos)
	salida = {}
	for d in r.get("publishedfiledetails", []):
		salida[d["publishedfileid"]] = {"titulo": d.get("title") or d["publishedfileid"], "tam": int(d.get("file_size") or 0), "ok": d.get("result") == 1}
	return salida


def Requeridos(config):
	"""Lista de dicts {id, titulo, tam, origen} con todo lo necesario."""
	ids, origen = [], {}
	if (config.get("coleccion")):
		for x in Hijos(config["coleccion"]):
			ids.append(x)
			origen[x] = "colección"
	for extra in config.get("extra", []):
		x = str(extra.get("id") or "").strip()
		if (x and x not in origen):
			ids.append(x)
			origen[x] = extra.get("motivo") or "extra"
	det = Detalles(ids)
	return [{"id": x, "titulo": det.get(x, {}).get("titulo", x), "tam": det.get(x, {}).get("tam", 0), "origen": origen[x]} for x in ids]


# --- Servidor (A2S_INFO) y noticias ------------------------------------------

def _Cadena(datos, i):
	fin = datos.index(b"\x00", i)
	return datos[i:fin].decode("utf-8", "replace"), fin + 1


def ConsultaServidor(direccion, espera=2.0):
	"""Pregunta A2S_INFO a un servidor de Source. Devuelve {nombre, mapa, jugadores, max} o None."""
	if (not direccion):
		return None
	host, _, puerto = direccion.partition(":")
	puerto = int(puerto or 27015)
	consulta = b"\xFF\xFF\xFF\xFFTSource Engine Query\x00"
	s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	s.settimeout(espera)
	try:
		s.sendto(consulta, (host, puerto))
		datos = s.recv(1400)
		if (datos[4:5] == b"A"):
			# Desafío anti-amplificación: se repite la consulta con los 4 bytes recibidos.
			s.sendto(consulta + datos[5:9], (host, puerto))
			datos = s.recv(1400)
		if (datos[4:5] != b"I"):
			return None
		i = 6
		nombre, i = _Cadena(datos, i)
		mapa, i = _Cadena(datos, i)
		_, i = _Cadena(datos, i)
		_, i = _Cadena(datos, i)
		jugadores, maximo = datos[i + 2], datos[i + 3]
		return {"nombre": nombre, "mapa": mapa, "jugadores": jugadores, "max": maximo}
	except (OSError, ValueError, IndexError, struct.error):
		return None
	finally:
		s.close()


def Noticias(config):
	"""Noticias de noticias_url (si responde) o las de noticias.json empaquetadas."""
	url = config.get("noticias_url")
	if (url):
		try:
			req = urllib.request.Request(url, headers={"User-Agent": "EFG-Launcher"})
			with urllib.request.urlopen(req, timeout=6) as r:
				datos = json.load(r)
			if (isinstance(datos, list) and datos):
				return datos
		except Exception:
			pass
	ruta = os.path.join(Recursos(), "noticias.json")
	if (os.path.exists(ruta)):
		with open(ruta, encoding="utf-8") as f:
			return json.load(f)
	return []


# Imágenes del repo que usa la interfaz web: se copian a web/img (build y modo repo).
IMAGENES = {
	"fondo.jpg": "content/materials/efg/menu/main_art.jpg",
	"trailer.jpg": "content/materials/efg/menu/bg3.jpg",
	"mapa.png": "content/materials/efg/menu/topo_map.png",
	"usec.png": "content/materials/efgui/factions/usec.png",
	"juego.png": "content/materials/efg/menu/sb_game_eft.png",
	"logo.png": "content/materials/efg/menu/logo.png",
	"mbender.ttf": "content/resource/fonts/mbender.ttf",
}


def PreparaWeb(destino=None):
	"""Copia las imágenes y la fuente a web/img. Sin efecto si ya están al día."""
	raiz = os.path.dirname(os.path.dirname(AQUI))
	destino = destino or os.path.join(AQUI, "web", "img")
	os.makedirs(destino, exist_ok=True)
	for nombre, origen in IMAGENES.items():
		origen = os.path.join(raiz, origen)
		final = os.path.join(destino, nombre)
		if (os.path.exists(origen) and (not os.path.exists(final) or os.path.getmtime(final) < os.path.getmtime(origen))):
			shutil.copy2(origen, final)
	return destino


# --- Gamemode, parche y arranque ---------------------------------------------

def GamemodeLocal(gmod, nombre):
	return os.path.exists(os.path.join(gmod, "gamemodes", nombre, nombre + ".txt"))


def Parche():
	sys.path.insert(0, Recursos())
	sys.path.insert(0, os.path.dirname(AQUI))
	import parche_menu_gmod as p
	if (getattr(sys, "frozen", False)):
		p.UsaRecursos(os.path.join(Recursos(), "menu_gmod"))
	return p


def UrlTaller(x):
	return "steam://url/CommunityFilePage/" + str(x)


def Abre(url):
	if (sys.platform == "win32"):
		os.startfile(url)
	else:
		subprocess.Popen(["xdg-open", url])


def Juega(steam, config):
	args = ["-applaunch", APP_GMOD]
	if (config.get("gamemode")):
		args += ["+gamemode", config["gamemode"]]
	if (config.get("servidor")):
		args += ["+connect", config["servidor"]]
	args += config.get("argumentos", [])
	exe = os.path.join(steam, "steam.exe" if sys.platform == "win32" else "steam")
	if (os.path.exists(exe)):
		subprocess.Popen([exe] + args)
	else:
		Abre("steam://rungameid/" + APP_GMOD + "//" + " ".join(args[2:]))
	return args


def main():
	orden = sys.argv[1] if len(sys.argv) > 1 else "estado"
	if (orden == "web"):
		print("Imágenes en", PreparaWeb())
		return 0
	config = CargaConfig()
	steam = RutaSteam()
	_, gmod = BuscaGMod(steam)
	if (config.get("garrysmod")):
		gmod = config["garrysmod"]
	print("Steam:", steam)
	print("garrysmod:", gmod)
	if (not gmod):
		return 1
	if (orden == "parche"):
		return Parche().Aplica(gmod)
	if (orden == "quitar"):
		return Parche().Quita(gmod)
	if (orden == "jugar"):
		print("Steam", " ".join(Juega(steam, config)))
		return 0
	inst = Instalados(gmod)
	faltan = [r for r in Requeridos(config) if r["id"] not in inst]
	print("Parche del menú:", "aplicado" if Parche().EstaAplicado(gmod) else "no")
	print("Gamemode en gamemodes/:", GamemodeLocal(gmod, config.get("gamemode", "")))
	print("Faltan", len(faltan), "addons")
	for r in faltan:
		print("  ", r["id"], r["titulo"], "(" + r["origen"] + ")")
	return 0


if (__name__ == "__main__"):
	sys.exit(main())
