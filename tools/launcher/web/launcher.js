// Launcher de EFG: interfaz. La lógica (Steam, colección, parche, arranque) está en
// Python (efg_launcher.py, clase Api) y se llama con window.pywebview.api.
// Módulos: temas.js (EFGTemas, los tres temas) y descargas.js (EFGDescargas, tarjetas).
(function () {
	"use strict";

	var api = null;
	var estado = { config: {}, faltan: [], total: 0, gmod: "", servidor: "", comprobando: false, error: false };

	function $(id) { return document.getElementById(id); }
	function esc(t) { return String(t == null ? "" : t).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;" }[c]; }); }

	function Log(lineas) {
		if (!lineas) return;
		if (typeof lineas === "string") lineas = [lineas];
		var r = $("registro");
		lineas.forEach(function (l) { l = String(l).replace(/\s+$/, ""); if (l) r.textContent += l + "\n"; });
		r.scrollTop = r.scrollHeight;
	}

	function Info(id, texto, clase) {
		$(id).textContent = texto;
		$(id).className = clase || "";
	}

	// --- botón grande ------------------------------------------------------------

	function BotonJugar() {
		var b = $("b-jugar"), icono = $("b-jugar-icono"), texto = $("b-jugar-texto");
		b.className = "b-jugar";
		if (estado.comprobando) {
			b.disabled = true; icono.hidden = true; texto.textContent = "Comprobando";
		} else if (!estado.gmod || estado.faltan.length) {
			b.disabled = false; icono.hidden = false; texto.textContent = "Instalar";
			if (estado.faltan.length) { b.className = "b-jugar con-nota"; b.setAttribute("data-nota", "Faltan " + estado.faltan.length + " addons"); }
		} else {
			b.disabled = false; icono.hidden = true; texto.textContent = "JUGAR"; b.className = "b-jugar jugar";
		}
		var n = $("n-faltan");
		n.hidden = !estado.faltan.length;
		n.textContent = estado.faltan.length;
	}

	// --- noticias -------------------------------------------------------------------

	function Abre(url) { if (url) api.AbreUrl(url); }

	var REFRESCO_NOTICIAS = 10 * 60 * 1000;

	function CargaNoticias() {
		api.Noticias().then(function (r) {
			// Api.Noticias devuelve {lista, origen}; una lista sola es el formato antiguo.
			var lista = Array.isArray(r) ? r : (r && r.lista) || [];
			var origen = r && r.origen;
			$("origen-noticias").textContent = origen === "remoto" ? "Al día con el servidor de noticias"
				: origen === "cache" ? "Sin conexión: última copia descargada" : origen === "local" ? "Sin conexión: noticias de esta versión" : "";
			PintaNoticias(lista);
		});
	}

	function PintaNoticias(lista) {
		var html = "", todas = "";
		lista.forEach(function (n, i) {
			var img = "background-image:url('" + esc(n.imagen || "img/fondo.jpg") + "')";
			if (n.tipo === "destacada") {
				html += "<div class=\"tarjeta destacada\" data-i=\"" + i + "\"><div class=\"imagen\" style=\"" + img + "\"></div>" +
					"<svg class=\"play\"><use href=\"#i-play\"/></svg>" +
					"<div class=\"rotulo\"><b>" + esc(n.etiqueta) + "</b><span>" + esc(n.titulo) + "</span><small>" + esc(n.texto) + "</small></div></div>";
			} else if (i < 3) {
				html += "<div class=\"tarjeta\" data-i=\"" + i + "\"><div class=\"imagen\" style=\"" + img + "\"></div>" +
					"<h3>" + esc(n.titulo) + "</h3><p>" + esc(n.texto) + "</p><svg class=\"mas\"><use href=\"#i-mas\"/></svg></div>";
			}
			todas += "<div class=\"noticia\" data-i=\"" + i + "\"><span class=\"imagen\" style=\"" + img + "\"></span>" +
				"<div>" + (n.fecha ? "<time>" + esc(n.fecha) + "</time>" : "") + "<h3>" + esc((n.etiqueta ? n.etiqueta + " · " : "") + n.titulo) + "</h3><p>" + esc(n.texto) + "</p></div></div>";
		});
		$("tarjetas").innerHTML = html;
		$("lista-noticias").innerHTML = todas;
		[].forEach.call(document.querySelectorAll(".tarjeta, .noticia"), function (el) {
			el.addEventListener("click", function () { Abre(lista[+el.getAttribute("data-i")].url); });
		});
	}

	// --- servidor -----------------------------------------------------------------------

	function PintaServidores() {
		var lista = (estado.config.servidores || []).slice();
		if (estado.servidor && !lista.some(function (s) { return s.ip === estado.servidor; }))
			lista.push({ nombre: estado.servidor, ip: estado.servidor });
		var html = "";
		lista.forEach(function (s) {
			html += "<a data-ip=\"" + esc(s.ip) + "\" class=\"" + (s.ip === estado.servidor ? "marcado" : "") + "\">" +
				esc(s.nombre) + (s.ip && s.nombre !== s.ip ? "<small>" + esc(s.ip) + "</small>" : "") + "</a>";
		});
		html += "<div class=\"otro\"><input id=\"otro-ip\" placeholder=\"IP:puerto\" spellcheck=\"false\"><button id=\"otro-ok\">Usar</button></div>";
		var menu = $("menu-servidor");
		menu.innerHTML = html;
		[].forEach.call(menu.querySelectorAll("a"), function (a) {
			a.addEventListener("click", function () { EligeServidor(a.getAttribute("data-ip")); });
		});
		$("otro-ok").addEventListener("click", function () { var v = $("otro-ip").value.trim(); if (v) EligeServidor(v); });
		$("otro-ip").addEventListener("keydown", function (e) { if (e.key === "Enter") $("otro-ok").click(); });
		$("otro-ip").addEventListener("click", function (e) { e.stopPropagation(); });
	}

	function EligeServidor(ip) {
		estado.servidor = ip || "";
		CierraMenus();
		PintaServidores();
		api.GuardaServidor(estado.servidor);
		ConsultaServidor();
	}

	function ConsultaServidor() {
		if (!estado.servidor) { Info("i-servidor", "Menú principal", ""); return; }
		Info("i-servidor", "Consultando " + estado.servidor + "...", "");
		var pedido = estado.servidor;
		api.Servidor(pedido).then(function (r) {
			if (pedido !== estado.servidor) return;
			if (r) Info("i-servidor", "En línea · " + r.jugadores + "/" + r.max + " · " + r.mapa, "ok");
			else Info("i-servidor", "Sin respuesta (" + pedido + ")", "mal");
		});
	}

	// --- comprobación -------------------------------------------------------------------

	function PintaBase(d) {
		estado.gmod = d.gmod || "";
		$("m-parche").textContent = d.parche ? "Quitar menú EFG" : "Aplicar menú EFG";
	}

	function Comprueba() {
		if (estado.comprobando) return;
		estado.comprobando = true;
		BotonJugar();
		EFGDescargas.Comprobando();
		api.Comprueba().then(function (r) {
			estado.comprobando = false;
			Log(r.log);
			PintaBase(r);
			estado.faltan = r.faltan || [];
			estado.total = r.total || 0;
			estado.error = !!r.error;
			EFGDescargas.Pinta(r);

			if (!r.gmod) Info("i-version", "No instalado", "mal");
			else Info("i-version", (estado.config.version || "-") + (r.gm_local ? "" : " · gamemode por Workshop"), "");
			if (r.gmod && !r.error && !estado.faltan.length) Info("i-edicion", estado.config.edicion || "Estándar", "");
			BotonJugar();
		});
	}

	// --- acciones ------------------------------------------------------------------------

	function Juega() {
		if (!estado.gmod || estado.faltan.length) {
			AbreDescargas(true);
			return;
		}
		var b = $("b-jugar");
		b.disabled = true;
		b.classList.add("lanzando");
		$("b-jugar-texto").textContent = "Lanzando";
		api.Juega(estado.servidor).then(function (r) {
			// r = {ok, mensaje, log}. Un fallo (sin Steam, sin GMod, IP mala) abre Descargas con el motivo.
			Log(r.log || r.mensaje);
			b.classList.remove("lanzando");
			if (!r.ok) {
				BotonJugar();
				b.classList.add("con-nota");
				b.setAttribute("data-nota", r.mensaje || "No se pudo lanzar");
				AbreDescargas(true);
				$("descargas").querySelector("details").open = true;
				return;
			}
			setTimeout(BotonJugar, 4000);
		});
	}

	var ordenes = {
		minimizar: function () { api.Minimiza(); },
		cerrar: function () { api.Cierra(); },
		steam: function () { api.AbreUrl("steam://open/main"); },
		carpeta: function () { api.AbreCarpeta().then(Log); },
		parche: function () { api.CambiaParche().then(function (r) { Log(r.log); PintaBase(r); }); },
		comprobar: function () { Comprueba(); },
		coleccion: function () { api.AbreColeccion().then(Log); },
		suscribir: function () { api.SuscribeTodo().then(Log); },
		noticias: function () { CargaNoticias(); },
		url: function (el) { Abre(el.getAttribute("data-url")); },
		elegir: function () { api.EligeGMod().then(function (r) { Log(r.log); if (r.cambiado) { PintaBase(r); Comprueba(); } }); },
		"cerrar-descargas": function () { AbreDescargas(false); }
	};

	function AbreDescargas(si) {
		$("descargas").hidden = !si;
		$("velo").hidden = !si;
	}

	function CierraMenus() {
		[].forEach.call(document.querySelectorAll(".desplegable.abierto"), function (d) { d.classList.remove("abierto"); });
		$("menu-usuario").hidden = true;
		EFGTemas.Cierra();
	}

	function Vista(nombre) {
		[].forEach.call(document.querySelectorAll("#pestanas a[data-vista]"), function (a) {
			a.classList.toggle("activa", a.getAttribute("data-vista") === nombre);
		});
		$("vista-juego").hidden = nombre !== "juego";
		$("vista-noticias").hidden = nombre !== "noticias";
	}

	function Engancha() {
		document.addEventListener("click", function (e) {
			var o = e.target.closest("[data-orden]");
			if (o && ordenes[o.getAttribute("data-orden")]) {
				CierraMenus();
				ordenes[o.getAttribute("data-orden")](o);
				return;
			}
			var disp = e.target.closest(".disparador");
			if (disp) {
				var d = disp.parentNode, abierto = d.classList.contains("abierto");
				CierraMenus();
				if (!abierto) d.classList.add("abierto");
				return;
			}
			if (e.target.closest("#usuario")) {
				var m = $("menu-usuario"), oculto = m.hidden;
				CierraMenus();
				m.hidden = !oculto;
				return;
			}
			if (!e.target.closest(".menu")) CierraMenus();
		});
		[].forEach.call(document.querySelectorAll(".comunidad a"), function (a) {
			a.addEventListener("click", function () { Abre((estado.config.enlaces || {})[a.getAttribute("data-enlace")]); });
		});
		[].forEach.call(document.querySelectorAll("#pestanas a"), function (a) {
			a.addEventListener("click", function () {
				if (a.hasAttribute("data-vista")) Vista(a.getAttribute("data-vista"));
				else Abre((estado.config.enlaces || {})[a.getAttribute("data-enlace")]);
			});
		});
		$("b-descargas").addEventListener("click", function () { AbreDescargas($("descargas").hidden); });
		$("velo").addEventListener("click", function () { AbreDescargas(false); });
		$("b-jugar").addEventListener("click", Juega);
		document.addEventListener("keydown", function (e) { if (e.key === "Escape") { CierraMenus(); AbreDescargas(false); } });
	}

	function Arranca() {
		api = window.pywebview.api;
		Engancha();
		EFGDescargas.Inicia(api);
		api.Inicio().then(function (d) {
			estado.config = d.config || {};
			estado.servidor = estado.config.servidor || "";
			EFGTemas.Inicia(api, estado.config.tema);
			var enlaces = estado.config.enlaces || {};
			[].forEach.call(document.querySelectorAll(".comunidad a"), function (a) {
				var url = enlaces[a.getAttribute("data-enlace")];
				a.classList.toggle("sin-enlace", !url);
				if (!url) a.title = "Falta el enlace en launcher.json (enlaces." + a.getAttribute("data-enlace") + ")";
			});
			document.title = "EFG Launcher";
			var u = d.usuario || {};
			$("u-nombre").textContent = u.nombre || "Jugador";
			if (u.avatar) { $("avatar").src = u.avatar; $("avatar").hidden = false; }
			$("u-estado").classList.toggle("on", !!u.enlinea);
			$("u-estado").querySelector("em").textContent = u.enlinea ? "En línea" : "Steam cerrado";
			Info("i-version", estado.config.version || "-", "");
			Info("i-edicion", estado.config.edicion || "Estándar", "");
			PintaBase(d);
			PintaServidores();
			ConsultaServidor();
			BotonJugar();
			Comprueba();
		});
		CargaNoticias();
		setInterval(CargaNoticias, REFRESCO_NOTICIAS);
	}

	if (window.pywebview && window.pywebview.api && window.pywebview.api.Inicio) Arranca();
	else window.addEventListener("pywebviewready", Arranca);
})();
