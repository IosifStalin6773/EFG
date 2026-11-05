"""Lógica del launcher de EFG sin interfaz: Steam, colección, parche y arranque.

Se puede usar sola desde consola:
	python tools/launcher/efg_core.py estado
	python tools/launcher/efg_core.py parche | quitar | jugar | web
"""
import base64, json, os, re, shutil, socket, string, struct, subprocess, sys, threading, time, urllib.parse, urllib.request

AQUI = os.path.dirname(os.path.abspath(__file__))
API = "https://api.steampowered.com/ISteamRemoteStorage/"
APP_GMOD = "4000"

# Los únicos temas que el jugador puede elegir (web/temas.css y PALETAS de efg_launcher_tk.py).
TEMAS = ("tactico", "nightops", "contraste")
TEMA_DEFECTO = "tactico"


def TemaValido(tema):
	return tema if tema in TEMAS else TEMA_DEFECTO


def Recursos():
	# Con PyInstaller los datos van en sys._MEIPASS; en el repo, junto al script.
	return getattr(sys, "_MEIPASS", AQUI)


def _RutaCacheRemota():
	base = os.path.dirname(sys.executable) if getattr(sys, "frozen", False) else AQUI
	return os.path.join(base, "launcher.remoto.json")


def ConfigRemota(url):
	"""launcher.json publicado en GitHub (config_url). Si no hay red, la última copia buena."""
	if (url and url.split(":", 1)[0] in ("http", "https")):
		try:
			req = urllib.request.Request(url, headers={"User-Agent": "EFG-Launcher", "Cache-Control": "no-cache"})
			with urllib.request.urlopen(req, timeout=4) as r:
				datos = json.load(r)
			if (isinstance(datos, dict)):
				try:
					with open(_RutaCacheRemota(), "w", encoding="utf-8") as f:
						json.dump(datos, f, ensure_ascii=False, indent="\t")
				except OSError:
					pass
				return datos
		except Exception:
			pass
	try:
		with open(_RutaCacheRemota(), encoding="utf-8") as f:
			datos = json.load(f)
		return datos if isinstance(datos, dict) else None
	except (OSError, ValueError):
		return None


def CargaConfig():
	config = {}
	bundled = os.path.join(Recursos(), "launcher.json")
	if (os.path.exists(bundled)):
		with open(bundled, encoding="utf-8") as f:
			config.update(json.load(f))
	# Lo publicado en GitHub manda sobre lo empaquetado; lo local (abajo) manda sobre todo.
	remoto = ConfigRemota(config.get("config_url"))
	if (remoto):
		config.update(remoto)
	# Un launcher.json junto al .exe manda sobre el empaquetado.
	if (getattr(sys, "frozen", False)):
		local = os.path.join(os.path.dirname(sys.executable), "launcher.json")
	else:
		local = os.path.join(AQUI, "launcher.local.json")
	if (os.path.exists(local)):
		with open(local, encoding="utf-8") as f:
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

def _EsSteam(ruta):
	"""Una carpeta es Steam si tiene el ejecutable o steamapps/."""
	if (not ruta or not os.path.isdir(ruta)):
		return False
	exe = "steam.exe" if sys.platform == "win32" else "steam.sh"
	return os.path.exists(os.path.join(ruta, exe)) or os.path.isdir(os.path.join(ruta, "steamapps"))


def _SteamRegistro():
	import winreg
	for raiz, clave, valor in (
		(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam", "SteamPath"),
		(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath"),
		(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Valve\Steam", "InstallPath"),
	):
		try:
			with winreg.OpenKey(raiz, clave) as k:
				# SteamPath viene con barras "/" y en minúsculas: normpath lo deja en formato Windows.
				ruta = os.path.normpath(winreg.QueryValueEx(k, valor)[0])
				if (_EsSteam(ruta)):
					return ruta
		except OSError:
			pass
	# El protocolo steam:// guarda la ruta del ejecutable aunque falte la clave anterior.
	try:
		with winreg.OpenKey(winreg.HKEY_CLASSES_ROOT, r"steam\Shell\Open\Command") as k:
			orden = winreg.QueryValueEx(k, "")[0]
			m = re.match(r'\s*"([^"]+)"', orden) or re.match(r"\s*(\S+)", orden)
			if (m and _EsSteam(os.path.dirname(m.group(1)))):
				return os.path.normpath(os.path.dirname(m.group(1)))
	except OSError:
		pass
	return None


def _SteamProceso():
	"""Ruta de steam.exe si Steam está abierto (por si el registro está roto)."""
	try:
		r = subprocess.run(["powershell", "-NoProfile", "-Command", "(Get-Process steam -ErrorAction SilentlyContinue | Select-Object -First 1).Path"],
			capture_output=True, text=True, timeout=5, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
		ruta = r.stdout.strip()
		if (ruta and _EsSteam(os.path.dirname(ruta))):
			return os.path.normpath(os.path.dirname(ruta))
	except (OSError, subprocess.SubprocessError):
		pass
	return None


def _SteamRutasHabituales():
	if (sys.platform == "win32"):
		for letra in string.ascii_uppercase:
			unidad = letra + ":\\"
			if (not os.path.exists(unidad)):
				continue
			for sub in (r"Program Files (x86)\Steam", r"Program Files\Steam", "Steam", r"Games\Steam"):
				yield os.path.join(unidad, sub)
	else:
		for ruta in ("~/.steam/steam", "~/.local/share/Steam", "~/.var/app/com.valvesoftware.Steam/.local/share/Steam", "~/Library/Application Support/Steam"):
			yield os.path.expanduser(ruta)


def DetectaSteam():
	"""Busca Steam sin dar nada por supuesto. Devuelve (ruta, origen) o (None, motivo).

	Orden: registro de Windows (HKCU SteamPath, HKLM InstallPath, protocolo steam://),
	proceso steam.exe en marcha y, por último, rutas habituales en todas las unidades.
	"""
	if (sys.platform == "win32"):
		try:
			ruta = _SteamRegistro()
			if (ruta):
				return ruta, "registro de Windows"
		except ImportError:
			pass
		ruta = _SteamProceso()
		if (ruta):
			return ruta, "proceso de Steam"
	for ruta in _SteamRutasHabituales():
		if (_EsSteam(ruta)):
			return os.path.normpath(ruta), "ruta habitual"
	return None, "no está en el registro, no está abierto y no aparece en las rutas habituales"


def RutaSteam():
	return DetectaSteam()[0]


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


def GModInstalado(steam):
	"""True si Steam tiene GMod instalado (appmanifest_4000.acf en alguna biblioteca)."""
	if (not steam):
		return False
	for lib in Bibliotecas(steam):
		if (os.path.exists(os.path.join(lib, "steamapps", "appmanifest_" + APP_GMOD + ".acf"))):
			return True
	return BuscaGMod(steam)[1] is not None


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


def VersionesLocales(gmod):
	"""{id: timeupdated} de lo descargado según appworkshop_4000.acf (0 si no consta)."""
	acf = os.path.join(BibliotecaDe(gmod), "steamapps", "workshop", "appworkshop_" + APP_GMOD + ".acf")
	if (not os.path.exists(acf)):
		return {}
	with open(acf, encoding="utf-8", errors="replace") as f:
		datos = LeeVDF(f.read()).get("AppWorkshop", {})
	salida = {}
	for seccion in ("WorkshopItemDetails", "WorkshopItemsInstalled"):
		for k, v in datos.get(seccion, {}).items():
			if (k.isdigit() and isinstance(v, dict)):
				try:
					salida[k] = max(salida.get(k, 0), int(v.get("timeupdated") or 0))
				except ValueError:
					pass
	return salida


def Desfasados(gmod, requeridos, instalados):
	"""Addons descargados cuya versión en la Workshop es más nueva que la local."""
	local = VersionesLocales(gmod)
	return [r for r in requeridos if r["id"] in instalados and r.get("act") and local.get(r["id"]) and r["act"] > local[r["id"]]]


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
		salida[d["publishedfileid"]] = {"titulo": d.get("title") or d["publishedfileid"], "tam": int(d.get("file_size") or 0), "ok": d.get("result") == 1,
			"act": int(d.get("time_updated") or 0)}
	return salida


def IdsLauncher(config):
	"""[(id, motivo)] de launcher.json sin red: "addons" (IDs sueltos o {id, motivo}) y "extra"."""
	salida, vistos = [], set()
	for entrada in list(config.get("addons", [])) + list(config.get("extra", [])):
		if (isinstance(entrada, dict)):
			x, motivo = str(entrada.get("id") or "").strip(), entrada.get("motivo") or "extra"
		else:
			x, motivo = str(entrada).strip(), "launcher.json"
		if (x.isdigit() and x not in vistos):
			vistos.add(x)
			salida.append((x, motivo))
	return salida


def RequeridosSinRed(config):
	"""Lo que se puede saber sin la API de Steam: los IDs escritos en launcher.json."""
	return [{"id": x, "titulo": "Addon " + x, "tam": 0, "act": 0, "origen": motivo} for x, motivo in IdsLauncher(config)]


def EstadoAddons(requeridos, instalados, viejos):
	"""Copia de requeridos con estado: "ok", "falta" (no está en content/4000) o "viejo"."""
	viejos = {v["id"] for v in viejos}
	return [dict(r, estado="falta" if r["id"] not in instalados else "viejo" if r["id"] in viejos else "ok") for r in requeridos]


def Requeridos(config):
	"""Lista de dicts {id, titulo, tam, origen} con todo lo necesario."""
	ids, origen = [], {}
	if (config.get("coleccion")):
		for x in Hijos(config["coleccion"]):
			ids.append(x)
			origen[x] = "colección"
	for x, motivo in IdsLauncher(config):
		if (x not in origen):
			ids.append(x)
			origen[x] = motivo
	det = Detalles(ids)
	return [{"id": x, "titulo": det.get(x, {}).get("titulo", x), "tam": det.get(x, {}).get("tam", 0),
		"act": det.get(x, {}).get("act", 0), "origen": origen[x]} for x in ids]


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


def _RutaCacheNoticias():
	base = os.path.dirname(sys.executable) if getattr(sys, "frozen", False) else AQUI
	return os.path.join(base, "noticias.cache.json")


def LimpiaNoticias(datos):
	"""Acepta una lista o {"noticias": [...]} y deja solo entradas válidas.

	Cada noticia: titulo (obligatorio), texto, fecha, etiqueta, tipo ("destacada"),
	imagen (ruta de web/ o https://) y url (http, https o steam). Lo demás se ignora.
	"""
	if (isinstance(datos, dict)):
		datos = datos.get("noticias")
	if (not isinstance(datos, list)):
		return []
	salida = []
	for n in datos:
		if (not isinstance(n, dict) or not str(n.get("titulo") or "").strip()):
			continue
		limpia = {k: str(n[k]) for k in ("titulo", "texto", "fecha", "etiqueta", "tipo", "imagen", "url") if n.get(k) is not None}
		if (limpia.get("url") and limpia["url"].split(":", 1)[0] not in ("http", "https", "steam")):
			del limpia["url"]
		salida.append(limpia)
	return salida[:30]


def NoticiasConOrigen(config):
	"""(lista, origen): "remoto" (noticias_url), "cache" (última que respondió) o "local" (empaquetadas)."""
	url = config.get("noticias_url")
	if (url):
		try:
			req = urllib.request.Request(url, headers={"User-Agent": "EFG-Launcher", "Cache-Control": "no-cache"})
			with urllib.request.urlopen(req, timeout=6) as r:
				lista = LimpiaNoticias(json.load(r))
			if (lista):
				try:
					with open(_RutaCacheNoticias(), "w", encoding="utf-8") as f:
						json.dump(lista, f, ensure_ascii=False, indent="\t")
				except OSError:
					pass
				return lista, "remoto"
		except Exception:
			pass
	for ruta, origen in ((_RutaCacheNoticias(), "cache"), (os.path.join(Recursos(), "noticias.json"), "local")):
		try:
			with open(ruta, encoding="utf-8") as f:
				lista = LimpiaNoticias(json.load(f))
			if (lista):
				return lista, origen
		except (OSError, ValueError):
			pass
	return [], ""


def Noticias(config):
	return NoticiasConOrigen(config)[0]


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


def SuscribeTodo(config, faltan, espera=1.5, maximo=15):
	"""Abre en Steam lo necesario para suscribirse a todo lo que falta.

	Steam no deja suscribirse desde fuera sin que el jugador pulse el botón, así que:
	  - si hay colección, abre solo su página (tiene el botón "Suscribirse a todo");
	    lo que falta fuera de ella se avisa, no se abre uno a uno;
	  - sin colección, los addons que faltan se abren uno a uno, con una pausa entre
	    páginas para que Steam no se atasque, como mucho `maximo`.
	Devuelve las líneas para el registro.
	"""
	log = []
	if (config.get("coleccion")):
		# Con colección, una sola página: todo lo que falta debe estar dentro de ella.
		Abre(UrlTaller(config["coleccion"]))
		log.append("Abierta la colección en Steam: pulsa \"Suscribirse a todo\" y vuelve a Comprobar.")
		fuera = [f["id"] for f in faltan if f.get("origen") != "colección"]
		if (fuera):
			log.append("%d addons no están en la colección y no se abren uno a uno: añádelos a la colección." % len(fuera))
		return log
	sueltos = [f["id"] for f in faltan]
	if (sueltos):
		def Abre_():
			for x in sueltos[:maximo]:
				Abre(UrlTaller(x))
				time.sleep(espera)
		threading.Thread(target=Abre_, daemon=True).start()
		log.append("Abriendo %d páginas de addons sueltos: pulsa Suscribirse en cada una." % min(len(sueltos), maximo))
		if (len(sueltos) > maximo):
			log.append("Hay %d más: ábrelos desde la lista de Descargas." % (len(sueltos) - maximo))
	if (not log):
		log.append("No falta nada por suscribir.")
	return log


class ErrorLanzamiento(Exception):
	"""Fallo que el jugador puede arreglar; el texto se le enseña tal cual."""


DIRECCION = re.compile(r"^[A-Za-z0-9.\-]+(:\d{1,5})?$")


def ArgumentosJuego(config):
	args = ["-applaunch", APP_GMOD]
	if (config.get("gamemode")):
		args += ["+gamemode", config["gamemode"]]
	if (config.get("servidor")):
		args += ["+connect", config["servidor"]]
	return args + [str(a) for a in config.get("argumentos", [])]


def Lanza(steam, config):
	"""Arranca GMod hacia config["servidor"] (o al menú si está vacío).

	launcher.json "lanzamiento":
	  "argumentos" (por defecto): steam.exe -applaunch 4000 +gamemode ... +connect IP.
	    Pasa también el gamemode y los argumentos extra.
	  "protocolo": steam://connect/IP. Sin argumentos extra; útil si steam.exe no se
	    puede ejecutar (permisos, Steam en otra cuenta de Windows).
	Devuelve {"ok", "mensaje", "comando"}; nunca lanza excepciones hacia la interfaz.
	"""
	try:
		if (not steam):
			raise ErrorLanzamiento("No encuentro Steam. Instálalo o ábrelo una vez y vuelve a probar.")
		if (not GModInstalado(steam)):
			Abre("steam://install/" + APP_GMOD)
			raise ErrorLanzamiento("Garry's Mod no está instalado. Te abro la instalación en Steam.")
		servidor = (config.get("servidor") or "").strip()
		if (servidor and not DIRECCION.match(servidor)):
			raise ErrorLanzamiento("La dirección del servidor no es válida: " + servidor)

		if (config.get("lanzamiento") == "protocolo" and servidor):
			url = "steam://connect/" + servidor
			Abre(url)
			return {"ok": True, "mensaje": "Conectando a " + servidor, "comando": url}

		args = ArgumentosJuego(config)
		exe = os.path.join(steam, "steam.exe" if sys.platform == "win32" else "steam")
		if (os.path.exists(exe)):
			subprocess.Popen([exe] + args)
			comando = "steam " + " ".join(args)
		else:
			comando = "steam://rungameid/" + APP_GMOD + "//" + " ".join(args[2:])
			Abre(comando)
		return {"ok": True, "mensaje": "Lanzando GMod" + (" hacia " + servidor if servidor else ""), "comando": comando}
	except ErrorLanzamiento as e:
		return {"ok": False, "mensaje": str(e), "comando": ""}
	except OSError as e:
		# Steam movido o sin permiso de ejecución: el protocolo es el último recurso.
		try:
			Abre("steam://rungameid/" + APP_GMOD)
			return {"ok": True, "mensaje": "steam.exe no respondió (" + str(e) + "); abierto GMod por steam://", "comando": "steam://rungameid/" + APP_GMOD}
		except OSError:
			return {"ok": False, "mensaje": "No se pudo abrir Steam: " + str(e), "comando": ""}


def Juega(steam, config):
	"""Versión simple para la interfaz Tk y la consola: devuelve los argumentos usados."""
	args = ArgumentosJuego(config)
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
	print("Steam:", steam, "(" + DetectaSteam()[1] + ")")
	print("garrysmod:", gmod)
	if (not gmod):
		return 1
	if (orden == "parche"):
		return Parche().Aplica(gmod)
	if (orden == "quitar"):
		return Parche().Quita(gmod)
	if (orden == "jugar"):
		r = Lanza(steam, config)
		print(r["mensaje"], "|", r["comando"])
		return 0 if r["ok"] else 1
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
