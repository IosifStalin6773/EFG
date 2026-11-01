"""Launcher de EFG (Escape from Gmod).

Interfaz web (web/index.html) con la distribución del launcher de BSG y la marca de
EFG, servida con pywebview (WebView2 en Windows). La lógica está en efg_core.py:
  - Busca Steam y Garry's Mod (todas las bibliotecas) y la cuenta de Steam.
  - Compara la colección de Workshop y los addons extra de launcher.json con lo
    descargado y abre en Steam la página de lo que falte (panel Descargas).
  - Aplica o quita el parche del menú principal (tools/parche_menu_gmod.py) y lo
    vuelve a aplicar si una actualización de GMod lo ha quitado.
  - JUGAR lanza GMod con +gamemode y, si hay servidor, +connect. El estado del
    servidor se consulta con A2S_INFO.
Si no hay pywebview o WebView2, abre la interfaz Tkinter de efg_launcher_tk.py.

Ejecutar desde el repo: python tools/launcher/efg_launcher.py  (pip install pywebview)
Generar el .exe: tools/launcher/build_launcher.bat
"""
import contextlib, io, os, sys, threading

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import efg_core as core


class Api:
	"""Métodos que la interfaz llama con window.pywebview.api.<Método>()."""

	def __init__(self):
		self._ventana = None
		self._cerrojo = threading.Lock()
		self.config = core.CargaConfig()
		self.steam = core.RutaSteam()
		_, self.gmod = core.BuscaGMod(self.steam)
		if (self.config.get("garrysmod") and os.path.isdir(self.config["garrysmod"])):
			self.gmod = self.config["garrysmod"]

	def _Base(self):
		aplicado = False
		if (self.gmod):
			try:
				aplicado = core.Parche().EstaAplicado(self.gmod)
			except Exception:
				pass
		return {"steam": self.steam or "", "gmod": self.gmod or "", "parche": aplicado}

	def _Parchea(self, aplicar):
		salida = io.StringIO()
		try:
			with contextlib.redirect_stdout(salida):
				p = core.Parche()
				codigo = p.Aplica(self.gmod) if aplicar else p.Quita(self.gmod)
		except PermissionError as e:
			codigo = 1
			salida.write("Sin permiso para escribir en GMod (" + str(e) + "). Ejecuta el launcher como administrador.\n")
		lineas = salida.getvalue().splitlines()
		if (codigo):
			lineas.append("El parche ha fallado.")
		return lineas

	# --- datos ---------------------------------------------------------------

	def Inicio(self):
		claves = ("titulo", "version", "edicion", "servidor", "servidores", "enlaces", "coleccion")
		datos = self._Base()
		datos["config"] = {k: self.config.get(k) for k in claves}
		try:
			datos["usuario"] = core.SteamUsuario(self.steam)
		except Exception:
			datos["usuario"] = {"nombre": "", "avatar": "", "enlinea": False}
		return datos

	def Noticias(self):
		return core.Noticias(self.config)

	def Comprueba(self):
		with self._cerrojo:
			log = []
			if (not self.gmod):
				log.append("No encuentro Garry's Mod. Ajustes del juego > Elegir carpeta de GMod.")
				datos = self._Base()
				datos.update({"log": log, "faltan": [], "total": 0, "error": ""})
				return datos
			if (self.config.get("parche_auto") and not core.Parche().EstaAplicado(self.gmod)):
				log.append("El menú EFG no está aplicado (¿actualización de GMod?). Lo aplico.")
				log += self._Parchea(True)
			error = ""
			try:
				req = core.Requeridos(self.config)
				inst = core.Instalados(self.gmod)
			except Exception as e:
				req, inst, error = [], set(), str(e)
				log.append("Error al consultar la Workshop: " + error)
			faltan = [r for r in req if r["id"] not in inst]

			nombre = self.config.get("gamemode", "escapefromgmod")
			local = core.GamemodeLocal(self.gmod, nombre)
			pendientes = [e for e in self.config.get("extra", []) if not str(e.get("id") or "").strip()]
			if (local):
				gm = ("Instalado en gamemodes/" + nombre, "ok")
			elif (pendientes):
				gm = ("Sin ID de Workshop en launcher.json", "aviso")
			else:
				gm = ("Por Workshop (ver lista)", "ok" if not faltan else "aviso")

			datos = self._Base()
			datos.update({"log": log, "faltan": faltan, "total": len(req), "error": error,
				"gm_local": local, "gm_texto": gm[0], "gm_clase": gm[1]})
			return datos

	def Servidor(self, direccion):
		return core.ConsultaServidor(direccion)

	# --- acciones ----------------------------------------------------------------

	def GuardaServidor(self, direccion):
		self.config["servidor"] = (direccion or "").strip()
		core.GuardaLocal(self.config, ["servidor"])

	def Juega(self, direccion):
		if (not self.steam):
			return ["No encuentro Steam."]
		self.GuardaServidor(direccion)
		return ["Lanzando GMod: " + " ".join(core.Juega(self.steam, self.config))]

	def CambiaParche(self):
		log = ["Elige la carpeta de GMod primero."]
		if (self.gmod):
			log = self._Parchea(not core.Parche().EstaAplicado(self.gmod))
		datos = self._Base()
		datos["log"] = log
		return datos

	def EligeGMod(self):
		import webview
		datos = self._Base()
		datos.update({"log": [], "cambiado": False})
		r = self._ventana.create_file_dialog(webview.FOLDER_DIALOG, directory=self.gmod or "")
		if (not r):
			return datos
		ruta = r[0] if isinstance(r, (list, tuple)) else r
		if (os.path.isdir(os.path.join(ruta, "garrysmod"))):
			ruta = os.path.join(ruta, "garrysmod")
		if (not os.path.isdir(os.path.join(ruta, "html"))):
			datos["log"].append("Esa carpeta no parece garrysmod: " + ruta)
			return datos
		self.gmod = os.path.normpath(ruta)
		self.config["garrysmod"] = self.gmod
		core.GuardaLocal(self.config, ["garrysmod"])
		datos = self._Base()
		datos.update({"log": ["Carpeta de GMod: " + self.gmod], "cambiado": True})
		return datos

	def AbreColeccion(self):
		if (not self.config.get("coleccion")):
			return []
		core.Abre(core.UrlTaller(self.config["coleccion"]))
		return ["Abierta la colección en Steam: pulsa \"Suscribirse a todo\" y vuelve a Comprobar."]

	def AbreTaller(self, ident):
		core.Abre(core.UrlTaller(ident))

	def AbreUrl(self, url):
		if (isinstance(url, str) and url.split(":", 1)[0] in ("http", "https", "steam")):
			core.Abre(url)

	def AbreCarpeta(self):
		if (not self.gmod):
			return ["No hay carpeta de GMod."]
		core.Abre(self.gmod)
		return []

	def Minimiza(self):
		self._ventana.minimize()

	def Cierra(self):
		self._ventana.destroy()


def Web():
	"""Abre la interfaz web. Devuelve False si no se puede (sin pywebview o sin WebView2)."""
	try:
		import webview
	except ImportError:
		return False
	if (not getattr(sys, "frozen", False)):
		core.PreparaWeb()
	indice = os.path.join(core.Recursos(), "web", "index.html")
	api = Api()
	api._ventana = webview.create_window("EFG Launcher", indice, js_api=api, width=1240, height=740,
		min_size=(1060, 640), frameless=True, easy_drag=False, background_color="#0b0c0b")
	try:
		webview.start(gui="edgechromium" if sys.platform == "win32" else None, private_mode=False)
	except Exception as e:
		print("No se pudo abrir la interfaz web:", e)
		return False
	return True


def main():
	if ("--tk" in sys.argv or not Web()):
		from efg_launcher_tk import Launcher
		Launcher().mainloop()


if (__name__ == "__main__"):
	main()
