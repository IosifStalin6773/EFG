"""Launcher de EFG (Escape from Gmod).

Comprueba que el jugador tiene todo lo necesario para jugar EFG y arranca GMod:
  - Busca Steam y Garry's Mod (todas las bibliotecas).
  - Compara la colección de Workshop y los addons extra de launcher.json con lo
    descargado y abre en Steam la página de lo que falte.
  - Aplica o quita el parche del menú principal (tools/parche_menu_gmod.py) y lo
    vuelve a aplicar si una actualización de GMod lo ha quitado.
  - JUGAR lanza GMod con +gamemode y, si hay servidor, +connect.

Ejecutar desde el repo: python tools/launcher/efg_launcher.py
Generar el .exe: tools/launcher/build_launcher.bat
"""
import contextlib, io, os, sys, threading
import tkinter as tk
from tkinter import filedialog, font as tkfont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import efg_core as core

# Paleta de efg_ui (ix.efgui.color / --efg-*).
FONDO = "#1c1e1b"
PANEL = "#121311"
BOTON = "#2c2f29"
LINEA = "#3a3d36"
TEXTO = "#c8c6b4"
TEXTO2 = "#9a9888"
NARANJA = "#e3722d"
VERDE = "#7fa35a"
ROJO = "#b03a2e"


def CargaFuente():
	ruta = os.path.join(core.Recursos(), "menu_gmod", "mbender.ttf")
	if (not os.path.exists(ruta)):
		ruta = os.path.join(os.path.dirname(os.path.dirname(core.AQUI)), "content", "resource", "fonts", "mbender.ttf")
	if (sys.platform == "win32" and os.path.exists(ruta)):
		try:
			import ctypes
			ctypes.windll.gdi32.AddFontResourceExW(ruta, 0x10, 0)  # FR_PRIVATE
		except Exception:
			pass


class Launcher(tk.Tk):
	def __init__(self):
		super().__init__()
		self.config_efg = core.CargaConfig()
		self.steam = core.RutaSteam()
		_, self.gmod = core.BuscaGMod(self.steam)
		if (self.config_efg.get("garrysmod") and os.path.isdir(self.config_efg["garrysmod"])):
			self.gmod = self.config_efg["garrysmod"]
		self.faltan = []

		CargaFuente()
		familias = tkfont.families(self)
		fam = "Bender" if "Bender" in familias else ("MBender" if "MBender" in familias else "Segoe UI")
		self.f_titulo = tkfont.Font(family=fam, size=26, weight="bold")
		self.f_normal = tkfont.Font(family=fam, size=11)
		self.f_boton = tkfont.Font(family=fam, size=12, weight="bold")
		self.f_log = tkfont.Font(family="Consolas", size=9)

		self.title("EFG Launcher")
		self.configure(bg=FONDO)
		self.geometry("940x600")
		self.minsize(820, 520)
		icono = os.path.join(core.Recursos(), "efg.ico")
		if (sys.platform == "win32" and os.path.exists(icono)):
			self.iconbitmap(icono)

		self.Construye()
		self.Refresca()
		self.after(200, self.Comprueba)

	# --- interfaz ---------------------------------------------------------

	def Boton(self, padre, texto, orden, principal=False):
		b = tk.Label(padre, text=texto, font=self.f_boton, bg=NARANJA if principal else BOTON,
			fg="#120c06" if principal else TEXTO, padx=18, pady=8, cursor="hand2")
		normal = b["bg"]
		b.bind("<Enter>", lambda e: b.configure(bg="#f08a48" if principal else LINEA))
		b.bind("<Leave>", lambda e: b.configure(bg=normal))
		b.bind("<Button-1>", lambda e: orden())
		return b

	def Construye(self):
		cab = tk.Frame(self, bg=PANEL)
		cab.pack(fill="x")
		tk.Label(cab, text=self.config_efg.get("titulo", "ESCAPE FROM GMOD"), font=self.f_titulo, bg=PANEL, fg=TEXTO, padx=20, pady=12).pack(side="left")
		tk.Frame(self, bg=NARANJA, height=2).pack(fill="x")

		cuerpo = tk.Frame(self, bg=FONDO, padx=20, pady=14)
		cuerpo.pack(fill="both", expand=True)

		izq = tk.Frame(cuerpo, bg=FONDO)
		izq.pack(side="left", fill="y")
		self.estados = {}
		for clave, nombre in (("steam", "Steam"), ("gmod", "Garry's Mod"), ("addons", "Addons"), ("gm", "Gamemode EFG"), ("parche", "Menú EFG")):
			fila = tk.Frame(izq, bg=PANEL, padx=10, pady=6, highlightbackground=LINEA, highlightthickness=1)
			fila.pack(fill="x", pady=3)
			tk.Label(fila, text=nombre.upper(), font=self.f_normal, bg=PANEL, fg=TEXTO2, width=14, anchor="w").pack(side="left")
			lab = tk.Label(fila, text="...", font=self.f_normal, bg=PANEL, fg=TEXTO, anchor="w", width=34)
			lab.pack(side="left")
			self.estados[clave] = lab

		srv = tk.Frame(izq, bg=FONDO, pady=10)
		srv.pack(fill="x")
		tk.Label(srv, text="SERVIDOR (IP:PUERTO, VACÍO = MENÚ)", font=self.f_normal, bg=FONDO, fg=TEXTO2).pack(anchor="w")
		self.servidor = tk.StringVar(value=self.config_efg.get("servidor", ""))
		tk.Entry(srv, textvariable=self.servidor, font=self.f_normal, bg=PANEL, fg=TEXTO, insertbackground=NARANJA, relief="flat",
			highlightbackground=LINEA, highlightcolor=NARANJA, highlightthickness=1).pack(fill="x", ipady=4)

		botones = tk.Frame(izq, bg=FONDO)
		botones.pack(fill="x", pady=6)
		self.Boton(botones, "SUSCRIBIRSE A LA COLECCIÓN", self.AbreColeccion).pack(fill="x", pady=3)
		self.Boton(botones, "COMPROBAR DE NUEVO", self.Comprueba).pack(fill="x", pady=3)
		self.b_parche = self.Boton(botones, "APLICAR MENÚ EFG", self.CambiaParche)
		self.b_parche.pack(fill="x", pady=3)
		self.Boton(botones, "ELEGIR CARPETA DE GMOD", self.EligeGMod).pack(fill="x", pady=3)
		self.Boton(izq, "JUGAR", self.Juega, principal=True).pack(fill="x", side="bottom", pady=(10, 0))

		der = tk.Frame(cuerpo, bg=FONDO, padx=16)
		der.pack(side="left", fill="both", expand=True)
		tk.Label(der, text="FALTAN (DOBLE CLIC PARA ABRIR EN STEAM)", font=self.f_normal, bg=FONDO, fg=TEXTO2).pack(anchor="w")
		self.lista = tk.Listbox(der, font=self.f_normal, bg=PANEL, fg=TEXTO, selectbackground=NARANJA, selectforeground="#120c06",
			relief="flat", highlightbackground=LINEA, highlightthickness=1, activestyle="none")
		self.lista.pack(fill="both", expand=True)
		self.lista.bind("<Double-Button-1>", self.AbreSeleccion)
		tk.Label(der, text="REGISTRO", font=self.f_normal, bg=FONDO, fg=TEXTO2).pack(anchor="w", pady=(8, 0))
		self.log = tk.Text(der, height=8, font=self.f_log, bg=PANEL, fg=TEXTO2, relief="flat", highlightbackground=LINEA, highlightthickness=1, state="disabled")
		self.log.pack(fill="x")

	def Estado(self, clave, texto, color=TEXTO):
		self.estados[clave].configure(text=texto, fg=color)

	def Log(self, texto):
		self.log.configure(state="normal")
		self.log.insert("end", texto.rstrip() + "\n")
		self.log.see("end")
		self.log.configure(state="disabled")

	# --- estado -------------------------------------------------------------

	def Refresca(self):
		self.Estado("steam", self.steam or "No encontrado", VERDE if self.steam else ROJO)
		self.Estado("gmod", self.gmod or "No encontrado: elige la carpeta", VERDE if self.gmod else ROJO)
		if (not self.gmod):
			self.Estado("parche", "-", TEXTO2)
			self.Estado("gm", "-", TEXTO2)
			return
		aplicado = core.Parche().EstaAplicado(self.gmod)
		self.Estado("parche", "Aplicado" if aplicado else "Sin aplicar", VERDE if aplicado else NARANJA)
		self.b_parche.configure(text="QUITAR MENÚ EFG" if aplicado else "APLICAR MENÚ EFG")

	def Comprueba(self):
		if (not self.gmod):
			self.Log("No encuentro Garry's Mod. Pulsa ELEGIR CARPETA DE GMOD.")
			return
		if (self.config_efg.get("parche_auto") and not core.Parche().EstaAplicado(self.gmod)):
			self.Log("El menú EFG no está aplicado (¿actualización de GMod?). Lo aplico.")
			self.Parchea(True)
		self.Estado("addons", "Consultando Steam...", TEXTO2)
		threading.Thread(target=self._Comprueba, daemon=True).start()

	def _Comprueba(self):
		try:
			req = core.Requeridos(self.config_efg)
			inst = core.Instalados(self.gmod)
			error = None
		except Exception as e:
			req, inst, error = [], set(), e
		self.after(0, lambda: self._Muestra(req, inst, error))

	def _Muestra(self, req, inst, error):
		gmname = self.config_efg.get("gamemode", "escapefromgmod")
		self.faltan = [r for r in req if r["id"] not in inst]
		self.lista.delete(0, "end")
		for r in self.faltan:
			mb = (" · %d MB" % (r["tam"] // 1048576)) if r["tam"] else ""
			self.lista.insert("end", "%s  (%s%s)" % (r["titulo"], r["origen"], mb))
		if (error):
			self.Estado("addons", "No se pudo consultar Steam", ROJO)
			self.Log("Error al consultar la Workshop: " + str(error))
		elif (self.faltan):
			self.Estado("addons", "Faltan %d de %d" % (len(self.faltan), len(req)), NARANJA)
		else:
			self.Estado("addons", "Todo descargado (%d)" % len(req), VERDE)

		pendientes = [e for e in self.config_efg.get("extra", []) if not str(e.get("id") or "").strip()]
		local = core.GamemodeLocal(self.gmod, gmname)
		if (local):
			self.Estado("gm", "Instalado en gamemodes/" + gmname, VERDE)
		elif (pendientes):
			self.Estado("gm", "Sin ID de Workshop en launcher.json", NARANJA)
		else:
			self.Estado("gm", "Por Workshop (ver lista)", VERDE if not self.faltan else NARANJA)
		self.Refresca()

	# --- acciones -----------------------------------------------------------

	def AbreColeccion(self):
		if (self.config_efg.get("coleccion")):
			core.Abre(core.UrlTaller(self.config_efg["coleccion"]))
			self.Log("Abierta la colección en Steam: pulsa \"Suscribirse a todo\" y vuelve a COMPROBAR.")

	def AbreSeleccion(self, _evento=None):
		for i in self.lista.curselection():
			core.Abre(core.UrlTaller(self.faltan[i]["id"]))

	def Parchea(self, aplicar):
		salida = io.StringIO()
		try:
			with contextlib.redirect_stdout(salida):
				p = core.Parche()
				codigo = p.Aplica(self.gmod) if aplicar else p.Quita(self.gmod)
		except PermissionError as e:
			codigo = 1
			salida.write("Sin permiso para escribir en GMod (" + str(e) + "). Ejecuta el launcher como administrador.\n")
		self.Log(salida.getvalue())
		if (codigo):
			self.Log("El parche ha fallado.")
		self.Refresca()

	def CambiaParche(self):
		if (self.gmod):
			self.Parchea(not core.Parche().EstaAplicado(self.gmod))

	def EligeGMod(self):
		ruta = filedialog.askdirectory(title="Carpeta garrysmod (dentro de GarrysMod)")
		if (not ruta):
			return
		if (os.path.isdir(os.path.join(ruta, "garrysmod"))):
			ruta = os.path.join(ruta, "garrysmod")
		if (not os.path.isdir(os.path.join(ruta, "html"))):
			self.Log("Esa carpeta no parece garrysmod: " + ruta)
			return
		self.gmod = os.path.normpath(ruta)
		self.config_efg["garrysmod"] = self.gmod
		core.GuardaLocal(self.config_efg, ["garrysmod"])
		self.Refresca()
		self.Comprueba()

	def Juega(self):
		if (not self.steam):
			self.Log("No encuentro Steam.")
			return
		if (self.faltan):
			self.Log("Aviso: faltan %d addons; puede que falten modelos o armas." % len(self.faltan))
		self.config_efg["servidor"] = self.servidor.get().strip()
		core.GuardaLocal(self.config_efg, ["servidor"])
		args = core.Juega(self.steam, self.config_efg)
		self.Log("Lanzando GMod: " + " ".join(args))


if (__name__ == "__main__"):
	Launcher().mainloop()
