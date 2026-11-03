// Panel DESCARGAS en tarjetas: resumen (¿puedo jugar?), requisitos y addons con
// filtros. Recibe el resultado de Api.Comprueba y no habla con Python salvo para
// abrir la página de un addon en Steam.
window.EFGDescargas = (function () {
	"use strict";

	var ICONO = { ok: "✅", aviso: "⚠️", mal: "❌", espera: "⌛" };
	var CHIP = { ok: "LISTO", falta: "FALTA", viejo: "ACTUALIZAR" };
	var api = null, addons = [], filtro = "todos";

	function $(id) { return document.getElementById(id); }
	function esc(t) { return String(t == null ? "" : t).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;" }[c]; }); }
	function MB(b) { return b ? (b >= 1073741824 ? (b / 1073741824).toFixed(1) + " GB" : Math.max(1, Math.round(b / 1048576)) + " MB") : ""; }

	function Req(titulo, texto, estado, boton, ancha) {
		var b = boton ? "<button data-orden=\"" + boton.orden + "\"" + (boton.url ? " data-url=\"" + esc(boton.url) + "\"" : "") + ">" + esc(boton.texto) + "</button>" : "";
		return "<div class=\"req" + (ancha ? " ancha" : "") + "\" data-estado=\"" + estado + "\"><span class=\"icono\">" + ICONO[estado] + "</span>" +
			"<div><b>" + esc(titulo) + "</b><span title=\"" + esc(texto) + "\">" + esc(texto) + "</span></div>" + b + "</div>";
	}

	function Resumen(estado, titulo, texto, pct) {
		$("resumen").setAttribute("data-estado", estado);
		$("resumen-icono").textContent = ICONO[estado];
		$("resumen-titulo").textContent = titulo;
		$("resumen-texto").textContent = texto;
		$("resumen-pct").textContent = pct == null ? "" : pct + "%";
		$("progreso").style.width = (pct || 0) + "%";
	}

	function Comprobando() {
		Resumen("espera", "Comprobando", "Leyendo Steam, Garry's Mod y la Workshop...", null);
		$("progreso").style.width = "30%";
	}

	function PintaLista() {
		var cuenta = { todos: addons.length, falta: 0, viejo: 0, ok: 0 };
		addons.forEach(function (a) { cuenta[a.estado]++; });
		[].forEach.call(document.querySelectorAll("#filtros a"), function (a) {
			var f = a.getAttribute("data-filtro");
			a.classList.toggle("activo", f === filtro);
			a.querySelector("em").textContent = cuenta[f];
		});
		// Primero lo que pide acción: faltan, luego por actualizar, luego listos.
		var orden = { falta: 0, viejo: 1, ok: 2 };
		var lista = addons.filter(function (a) { return filtro === "todos" || a.estado === filtro; })
			.sort(function (x, y) { return orden[x.estado] - orden[y.estado]; });
		if (!lista.length) {
			$("lista-addons").innerHTML = "<div class=\"vacio\">" + (addons.length ? "Nada en este filtro." : "Sin datos de addons.") + "</div>";
			return;
		}
		$("lista-addons").innerHTML = lista.map(function (a, i) {
			var icono = a.estado === "ok" ? ICONO.ok : ICONO.aviso;
			var detalle = [a.origen, MB(a.tam), "ID " + a.id].filter(Boolean).join(" · ");
			// El retraso escalonado hace que la lista entre en cascada, sin pasar de 0,3 s.
			return "<div class=\"addon\" data-estado=\"" + a.estado + "\" data-id=\"" + esc(a.id) + "\" style=\"animation-delay:" + Math.min(i * 15, 300) + "ms\">" +
				"<span class=\"icono\">" + icono + "</span><div class=\"cuerpo\"><b>" + esc(a.titulo) + "</b><small>" + esc(detalle) + "</small></div>" +
				"<span class=\"chip\">" + CHIP[a.estado] + "</span><svg class=\"ir\"><use href=\"#i-fuera\"/></svg></div>";
		}).join("");
	}

	function Pinta(r) {
		var faltan = (r.faltan || []).length, viejos = (r.viejos || []).length, total = r.total || 0;
		addons = r.addons || [];

		var html = "";
		html += Req("Steam", r.steam || "No encontrado", r.steam ? "ok" : "mal",
			r.steam ? null : { orden: "url", url: "https://store.steampowered.com/about/", texto: "Instalar" });
		html += Req("Garry's Mod", r.gmod || "No instalado", r.gmod ? "ok" : "mal",
			r.gmod ? null : (r.steam ? { orden: "url", url: "steam://install/4000", texto: "Instalar" } : { orden: "elegir", texto: "Elegir carpeta" }));
		html += Req("Gamemode EFG", r.gm_texto || "-", r.gm_clase === "ok" ? "ok" : (r.gmod ? "aviso" : "mal"));
		html += Req("Menú EFG", !r.gmod ? "-" : (r.parche ? "Aplicado" : "Sin aplicar"), r.parche ? "ok" : (r.gmod ? "aviso" : "mal"),
			r.gmod ? { orden: "parche", texto: r.parche ? "Quitar" : "Aplicar" } : null);
		var tAddons = !r.gmod ? "-" : r.error && !total ? "No se pudo consultar Steam" : faltan ? "Faltan " + faltan + " de " + total
			: viejos ? viejos + " por actualizar (Steam los baja al abrir GMod)" : "Todo descargado y al día (" + total + ")";
		html += Req("Addons de Workshop" + (r.sin_red ? " · sin conexión" : ""), tAddons, !r.gmod || (r.error && !total) ? "mal" : (faltan || viejos || r.sin_red) ? "aviso" : "ok", null, true);
		$("requisitos").innerHTML = html;

		var pct = total ? Math.round(100 * (total - faltan) / total) : (r.gmod ? 100 : 0);
		if (!r.steam) Resumen("mal", "Steam no encontrado", "Instala Steam o ábrelo una vez para que se registre.", 0);
		else if (!r.gmod) Resumen("mal", "Garry's Mod no está instalado", "Instálalo desde Steam o elige su carpeta a mano.", 0);
		else if (r.error && !total) Resumen("mal", "Sin conexión con la Workshop", r.error, null);
		else if (faltan) Resumen("aviso", "Faltan " + faltan + " addons", "Pulsa Suscribirse a todo y espera a que Steam los descargue.", pct);
		else Resumen("ok", "Listo para jugar", total + " addons descargados" + (viejos ? " · " + viejos + " con actualización pendiente" : "") + (r.sin_red ? " · lista sin conexión" : ""), pct);
		PintaLista();
	}

	function Inicia(apiPython) {
		api = apiPython;
		$("filtros").addEventListener("click", function (e) {
			var a = e.target.closest("a[data-filtro]");
			if (a) { filtro = a.getAttribute("data-filtro"); PintaLista(); }
		});
		$("lista-addons").addEventListener("click", function (e) {
			var el = e.target.closest(".addon");
			if (el) api.AbreTaller(el.getAttribute("data-id"));
		});
	}

	return { Inicia: Inicia, Pinta: Pinta, Comprobando: Comprobando, Faltan: function () { return addons.filter(function (a) { return a.estado === "falta"; }); } };
})();
