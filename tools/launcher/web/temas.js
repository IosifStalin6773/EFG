// Temas del launcher: solo los tres de temas.css. El elegido se guarda en
// launcher.local.json (Api.GuardaTema) y en localStorage para pintarlo al instante.
window.EFGTemas = (function () {
	"use strict";

	// Las muestras son los colores del propio tema (fondo, panel, acento, segundo acento).
	var LISTA = [
		{ id: "tactico", nombre: "Táctico Oscuro", texto: "Oliva y naranja, como el juego", muestras: ["#0b0c0b", "#252723", "#e3722d", "#8fb34a"] },
		{ id: "nightops", nombre: "Night Ops", texto: "Azul noche con verde y cian neón", muestras: ["#05080b", "#15212b", "#39ff88", "#00d4ff"] },
		{ id: "contraste", nombre: "Alto Contraste", texto: "Blanco y gris con rojo, máxima legibilidad", muestras: ["#ffffff", "#9a9a96", "#d0021b", "#000000"] }
	];
	var POR_DEFECTO = "tactico";
	var api = null, actual = POR_DEFECTO, temporizador = 0;

	function Valido(id) {
		return LISTA.some(function (t) { return t.id === id; }) ? id : POR_DEFECTO;
	}

	function Aplica(id, guardar) {
		id = Valido(id);
		var raiz = document.documentElement;
		if (id !== actual) {
			raiz.classList.add("cambiando-tema");
			clearTimeout(temporizador);
			temporizador = setTimeout(function () { raiz.classList.remove("cambiando-tema"); }, 350);
		}
		actual = id;
		raiz.setAttribute("data-tema", id);
		try { localStorage.setItem("efg-tema", id); } catch (e) {}
		if (guardar && api && api.GuardaTema) api.GuardaTema(id);
		Pinta();
	}

	function Pinta() {
		var menu = document.getElementById("menu-tema");
		if (!menu) return;
		menu.innerHTML = "<h4>TEMA VISUAL</h4>" + LISTA.map(function (t) {
			return "<div class=\"opcion-tema" + (t.id === actual ? " activa" : "") + "\" data-tema=\"" + t.id + "\">" +
				"<span class=\"muestras\">" + t.muestras.map(function (c) { return "<i style=\"background:" + c + "\"></i>"; }).join("") + "</span>" +
				"<span><b>" + t.nombre + "</b><small>" + t.texto + "</small></span><span class=\"marca-tema\">&#10003;</span></div>";
		}).join("");
	}

	function Alterna(abrir) {
		var menu = document.getElementById("menu-tema"), boton = document.getElementById("b-tema");
		var si = typeof abrir === "boolean" ? abrir : menu.hidden;
		menu.hidden = !si;
		boton.classList.toggle("abierto", si);
	}

	function Inicia(apiPython, inicial) {
		api = apiPython;
		var guardado = null;
		try { guardado = localStorage.getItem("efg-tema"); } catch (e) {}
		// launcher.local.json manda: es lo que se conserva si se borra la caché de WebView2.
		Aplica(inicial || guardado || POR_DEFECTO, false);
		document.getElementById("b-tema").addEventListener("click", function (e) { e.stopPropagation(); Alterna(); });
		document.getElementById("menu-tema").addEventListener("click", function (e) {
			e.stopPropagation();
			var op = e.target.closest(".opcion-tema");
			if (op) { Aplica(op.getAttribute("data-tema"), true); Alterna(false); }
		});
		document.addEventListener("click", function () { Alterna(false); });
	}

	return { lista: LISTA, Aplica: Aplica, Inicia: Inicia, Cierra: function () { Alterna(false); }, Actual: function () { return actual; } };
})();
