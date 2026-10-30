-- Página de la pantalla de modding de armas de ARC9 (como el modding de EFT).
-- Izquierda: árbol de ranuras del arma (las ranuras hijas cuelgan de la pieza
-- montada). Al elegir una ranura se abre al lado la lista de piezas
-- compatibles. Centro: transparente, se ve el arma real de ARC9 en modo
-- personalizar, con marcadores sobre cada ranura (arrastrar = girar, rueda =
-- zoom). Derecha: stats en vivo con la diferencia de la pieza bajo el ratón.
-- Lua manda render(json), parts(json) y markers(json); la página llama a
-- efg.select(slot), efg.install(slot, att), efg.remove(slot), efg.rotate(dx, dy),
-- efg.zoom(d), efg.close(), efg.click().

local PLUGIN = PLUGIN

PLUGIN.modHTML = [==[
<!doctype html>
<html><head><meta charset="utf-8">
<style>
/*EFG_BASE*/
html, body { background: transparent; }

#top { position: absolute; left: 0; right: 0; top: 0; height: 34px; display: flex; align-items: center;
	background: linear-gradient(#000, rgba(0,0,0,.85)); border-bottom: 1px solid var(--efg-line); padding-left: 14px; z-index: 5; }
#top .t { font-family: var(--efg-font-stencil); font-size: 16px; letter-spacing: 3px; text-transform: uppercase; color: var(--efg-text); }
#top .w { margin-left: 14px; padding-left: 14px; border-left: 1px solid var(--efg-line); font-size: 15px; letter-spacing: 1px; color: var(--efg-orange); }
#top .sp { flex: 1; }
#top .k { font-size: 11px; letter-spacing: 1px; color: var(--efg-dim); margin-right: 10px; text-transform: uppercase; }
#top .x { width: 40px; height: 34px; border: 0; background: none; color: var(--efg-text2); font-size: 17px; cursor: pointer; font-family: var(--efg-font); }
#top .x:hover { background: var(--efg-red); color: #fff; }

.col { position: absolute; top: 44px; bottom: 12px; display: flex; flex-direction: column; z-index: 3;
	background: rgba(20,21,19,.93) var(--efg-grunge); border: 1px solid #0a0b09;
	box-shadow: 0 0 0 1px var(--efg-line), 0 10px 40px rgba(0,0,0,.8); }
.col .body { flex: 1; min-height: 0; overflow-y: auto; }
#left { left: 12px; width: 340px; }
#right { right: 12px; width: 350px; }

/* ── árbol de ranuras ── */
.node { position: relative; display: flex; align-items: stretch; height: 58px; margin: 3px 6px 3px 0; cursor: pointer; }
.node .ind { flex: 0 0 auto; position: relative; }
.node .ind i { position: absolute; top: -4px; bottom: 50%; width: 10px; border-left: 1px solid var(--efg-line2); border-bottom: 1px solid var(--efg-line2); }
.node .ic { flex: 0 0 58px; position: relative; display: flex; align-items: center; justify-content: center; background: var(--efg-slot);
	box-shadow: inset 1px 1px 0 rgba(0,0,0,.8), inset -1px -1px 0 rgba(255,255,255,.04), inset 0 0 12px rgba(0,0,0,.6); border: 1px solid #0a0b09; }
.node .ic img { max-width: 86%; max-height: 80%; filter: drop-shadow(0 2px 2px #000); }
.node.full .ic { background: var(--efg-r-common); box-shadow: var(--efg-shadow-out); }
.node.empty .ic::after { content: ""; position: absolute; left: 50%; top: 50%; width: 18px; height: 18px; margin: -9px 0 0 -9px;
	border: 1px dashed rgba(200,198,180,.18); }
.node .tx { flex: 1; min-width: 0; display: flex; flex-direction: column; justify-content: center; padding: 0 8px; margin-left: 2px;
	background: rgba(0,0,0,.35); border: 1px solid #0a0b09; }
.node .sl { font-size: 10px; letter-spacing: 1.5px; text-transform: uppercase; color: var(--efg-dim); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.node .nm { font-size: 14px; color: var(--efg-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.node.empty .nm { color: var(--efg-dim); font-size: 12px; letter-spacing: 1px; text-transform: uppercase; }
.node .rm { position: absolute; right: 0; top: 0; width: 22px; height: 22px; display: none; align-items: center; justify-content: center;
	background: #000; color: var(--efg-text2); font-size: 12px; }
.node.full:hover .rm { display: flex; }
.node .rm:hover { background: var(--efg-red); color: #fff; }
.node:hover .tx { background: rgba(255,255,255,.04); }
.node.sel .tx { background: rgba(227,114,45,.12); border-color: var(--efg-orange); }
.node.sel .ic { outline: 1px solid var(--efg-orange); outline-offset: -1px; }
.node.blocked { opacity: .45; }
.node.blocked .nm { color: var(--efg-red-hi); }
.node.flash .ic { animation: flash .5s; }
@keyframes flash { 0% { box-shadow: inset 0 0 0 2px var(--efg-ok); } 100% { box-shadow: inset 0 0 0 0 transparent; } }
.legend { padding: 6px 10px 8px; font-family: var(--efg-font); font-size: 11px; color: var(--efg-dim); border-top: 1px solid #0a0b09; background: rgba(0,0,0,.3); }

/* ── lista de piezas compatibles ── */
#parts { position: absolute; top: 44px; left: 360px; width: 380px; bottom: 12px; display: none; flex-direction: column; z-index: 4;
	background: rgba(16,17,15,.96) var(--efg-grunge); border: 1px solid #0a0b09;
	box-shadow: 0 0 0 1px var(--efg-orange), 0 10px 40px rgba(0,0,0,.9); }
#parts.open { display: flex; }
#parts .hdr span { margin-left: auto; font-family: var(--efg-font); font-size: 11px; letter-spacing: 0; text-transform: none; color: var(--efg-dim); }
#parts .hdr .x { margin-left: 8px; cursor: pointer; color: var(--efg-text2); padding: 0 4px; }
#parts .hdr .x:hover { color: #fff; background: var(--efg-red); }
#search { margin: 6px; padding: 5px 8px; background: #0a0b09; border: 1px solid var(--efg-line); color: var(--efg-text);
	font-family: var(--efg-font); font-size: 13px; outline: none; user-select: text; }
#search:focus { border-color: var(--efg-text2); }
#filters { display: flex; gap: 4px; padding: 0 6px 6px; }
#filters .btn { flex: 1; padding: 4px; font-size: 11px; }
#plist { flex: 1; min-height: 0; overflow-y: auto; padding: 0 6px 6px; }
.part { display: flex; align-items: stretch; height: 56px; margin-bottom: 3px; cursor: pointer; background: rgba(0,0,0,.35); border: 1px solid #0a0b09; }
.part .ic { flex: 0 0 64px; display: flex; align-items: center; justify-content: center; background: var(--efg-r-common); box-shadow: var(--efg-shadow-out); }
.part .ic img { max-width: 86%; max-height: 80%; filter: drop-shadow(0 2px 2px #000); }
.part .tx { flex: 1; min-width: 0; display: flex; flex-direction: column; justify-content: center; padding: 0 8px; }
.part .nm { font-size: 14px; color: var(--efg-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.part .dl { display: flex; gap: 8px; margin-top: 2px; font-size: 11px; }
.part .dl b { font-weight: normal; }
.part .st { flex: 0 0 auto; display: flex; align-items: center; padding: 0 8px; font-size: 11px; letter-spacing: 1px; text-transform: uppercase; }
.part.have .st { color: var(--efg-ok); }
.part.on { border-color: var(--efg-orange); }
.part.on .st { color: var(--efg-orange); }
.part.na { cursor: default; }
.part.na .ic, .part.na .tx { opacity: .4; }
.part.na .st { color: var(--efg-dim); }
.part.none .ic { background: var(--efg-slot); }
.part:not(.na):hover { background: rgba(255,255,255,.05); border-color: var(--efg-text2); }
.up { color: var(--efg-ok); } .down { color: var(--efg-red-hi); }
.msg { padding: 14px 8px; font-family: var(--efg-font); font-size: 12px; color: var(--efg-dim); }

/* ── vista del arma ── */
#view { position: absolute; left: 0; right: 0; top: 34px; bottom: 0; z-index: 1; cursor: grab; }
#view.rot { cursor: grabbing; }
#lines { position: absolute; left: 0; top: 0; width: 100%; height: 100%; pointer-events: none; z-index: 2; }
#lines line { stroke: var(--efg-orange); stroke-width: 1; stroke-dasharray: 4 3; }
.mk { position: absolute; width: 14px; height: 14px; margin: -7px 0 0 -7px; z-index: 2; cursor: pointer;
	background: rgba(0,0,0,.6); border: 1px solid var(--efg-text2); transform: rotate(45deg); }
.mk.full { background: rgba(200,198,180,.55); }
.mk:hover, .mk.sel { border-color: var(--efg-orange); background: var(--efg-orange); }
.mk .lb { position: absolute; left: 14px; top: -14px; transform: rotate(-45deg); transform-origin: 0 100%; white-space: nowrap; display: none;
	padding: 1px 6px; background: #000; font-size: 11px; letter-spacing: 1px; text-transform: uppercase; color: var(--efg-text); }
.mk:hover .lb, .mk.sel .lb { display: block; }
#hint { position: absolute; left: 50%; bottom: 18px; transform: translateX(-50%); z-index: 2; pointer-events: none;
	font-size: 11px; letter-spacing: 1.5px; text-transform: uppercase; color: rgba(200,198,180,.45); }

/* ── stats ── */
#wname { padding: 10px 12px 2px; font-size: 20px; color: var(--efg-text); }
#wsub { padding: 0 12px 8px; font-family: var(--efg-font); font-size: 11px; color: var(--efg-dim); border-bottom: 1px solid #0a0b09; }
#pv { display: none; margin: 6px 8px 0; padding: 5px 8px; background: rgba(227,114,45,.10); border-left: 2px solid var(--efg-orange); font-size: 12px; color: var(--efg-text); }
#pv.on { display: block; }
.stat { padding: 7px 12px 6px; border-bottom: 1px solid rgba(0,0,0,.55); }
.stat:nth-child(odd) { background: rgba(255,255,255,.015); }
.stat .row { display: flex; align-items: baseline; }
.stat .k { flex: 1; font-size: 12px; letter-spacing: 1.5px; text-transform: uppercase; color: var(--efg-text2); }
.stat .v { font-size: 17px; color: var(--efg-text); }
.stat .d { width: 64px; text-align: right; font-size: 13px; }
.bar { position: relative; height: 5px; margin-top: 5px; background: #0a0b09; box-shadow: var(--efg-shadow-in); }
.bar i { position: absolute; left: 0; top: 0; bottom: 0; background: var(--efg-text2); }
.bar b { position: absolute; top: 0; bottom: 0; }
.bar b.up { background: var(--efg-ok); } .bar b.down { background: var(--efg-red-hi); }
.info { padding: 8px 12px; }
.info div { display: flex; justify-content: space-between; padding: 5px 0; border-bottom: 1px solid rgba(0,0,0,.45); font-size: 13px; }
.info div span:first-child { color: var(--efg-dim); text-transform: uppercase; letter-spacing: 1px; font-size: 11px; }
#acts { flex: 0 0 auto; padding: 8px; border-top: 1px solid #0a0b09; background: rgba(0,0,0,.3); }
#acts .btn { width: 100%; padding: 9px; font-size: 14px; letter-spacing: 2px; }
#note { font-family: var(--efg-font); font-size: 11px; color: var(--efg-red-hi); padding: 0 2px 6px; }
</style></head>
<body>
<div id="view"><svg id="lines"></svg><div id="hint">Arrastra para girar · Rueda para acercar</div></div>
<div id="top"><div class="t">Modificación de arma</div><div class="w" id="title">—</div><div class="sp"></div>
	<div class="k">Esc · cerrar</div><button class="x" onclick="closeWin()">✕</button></div>
<div class="col" id="left"><div class="hdr efg-hdr">Módulos del arma</div><div class="body" id="tree"></div>
	<div class="legend">Clic en una ranura para ver las piezas compatibles. Clic derecho o ✕ para desmontar.</div></div>
<div id="parts"><div class="hdr efg-hdr"><b id="ptitle">—</b><span id="pcount"></span><b class="x" onclick="closeParts()">✕</b></div>
	<input id="search" placeholder="BUSCAR PIEZA" oninput="drawParts()">
	<div id="filters"><button class="btn on" data-f="all">Todas</button><button class="btn" data-f="have">Disponibles</button></div>
	<div id="plist"></div></div>
<div class="col" id="right"><div class="hdr efg-hdr">Características</div>
	<div id="wname">—</div><div id="wsub"></div><div id="pv"></div>
	<div class="body"><div id="stats"></div><div class="info" id="info"></div></div>
	<div id="acts"><div id="note"></div><button class="btn" onclick="closeWin()">Cerrar</button></div></div>
<script>
var D = null, P = null, sel = null, hov = null, preview = null, filter = "all", MK = [];

function el(t, c, x) { var e = document.createElement(t); if (c) e.className = c; if (x !== undefined && x !== null) e.textContent = x; return e; }
function call(fn) { if (window.efg && efg[fn]) efg[fn].apply(efg, [].slice.call(arguments, 1)); }
function click() { call("click"); }
function closeWin() { click(); call("close"); }
function arr(x) { return Array.isArray(x) ? x : []; }
function img(src) { var i = el("img"); if (src) i.src = src; else i.style.display = "none"; i.onerror = function () { i.style.display = "none"; }; return i; }
function fmt(v, s) { if (s.unit === "kg") return v.toFixed(3) + " kg"; if (s.unit === "moa") return v.toFixed(2) + " MOA"; return String(v); }
function slotOf(k) { for (var i = 0; i < D.slots.length; i++) if (D.slots[i].k === k) return D.slots[i]; return null; }

// ── árbol ──
function drawTree() {
	var T = document.getElementById("tree"); T.innerHTML = "";
	if (!D.slots.length) { T.appendChild(el("div", "msg", "Este arma no tiene ranuras de accesorios.")); return; }
	D.slots.forEach(function (s) {
		var n = el("div", "node " + (s.att ? "full" : "empty") + (s.blocked ? " blocked" : "") + (sel === s.k ? " sel" : ""));
		n.dataset.k = s.k;
		var ind = el("div", "ind"); ind.style.width = (s.depth * 16) + "px";
		if (s.depth > 0) { var i = el("i"); i.style.left = ((s.depth - 1) * 16 + 6) + "px"; ind.appendChild(i); }
		n.appendChild(ind);
		var ic = el("div", "ic"); if (s.att) ic.appendChild(img(s.icon)); n.appendChild(ic);
		var tx = el("div", "tx"); tx.appendChild(el("div", "sl", s.label));
		tx.appendChild(el("div", "nm", s.att ? s.name : (s.blocked ? "Bloqueada" : "Vacía"))); n.appendChild(tx);
		if (s.att && !s.integral) {
			var rm = el("div", "rm", "✕"); rm.title = "Desmontar";
			rm.onclick = function (ev) { ev.stopPropagation(); click(); call("remove", s.k); };
			n.appendChild(rm);
		}
		n.onclick = function () { click(); select(s.k); };
		n.oncontextmenu = function (ev) { ev.preventDefault(); if (s.att && !s.integral) { click(); call("remove", s.k); } };
		n.onmouseenter = function () { hov = s.k; drawMarkers(); };
		n.onmouseleave = function () { hov = null; drawMarkers(); };
		T.appendChild(n);
	});
}
function select(k) {
	sel = k; P = null;
	document.querySelectorAll(".node").forEach(function (n) { n.classList.toggle("sel", n.dataset.k === k); });
	var s = slotOf(k);
	document.getElementById("ptitle").textContent = s ? s.label : "—";
	document.getElementById("pcount").textContent = "";
	document.getElementById("plist").innerHTML = "";
	document.getElementById("plist").appendChild(el("div", "msg", "Buscando piezas..."));
	document.getElementById("parts").classList.add("open");
	call("select", k); drawMarkers();
}
function closeParts() { sel = null; P = null; document.getElementById("parts").classList.remove("open"); setPreview(null, null);
	document.querySelectorAll(".node.sel").forEach(function (n) { n.classList.remove("sel"); }); drawMarkers(); }

// ── piezas ──
function parts(data) {
	if (!data || data.k !== sel) return;
	P = data; P.list = arr(P.list); drawParts();
}
function delta(key, base, pv, better, unit) {
	var d = Math.round((pv[key] - base[key]) * 1000) / 1000;
	if (!d) return null;
	var good = better === "low" ? d < 0 : d > 0;
	return el("b", good ? "up" : "down", (d > 0 ? "+" : "") + (unit === "kg" ? d.toFixed(3) : d));
}
function drawParts() {
	var L = document.getElementById("plist"); L.innerHTML = "";
	if (!P) return;
	var q = document.getElementById("search").value.toLowerCase(), shown = 0, have = 0;
	if (P.installed && !P.integral) {
		var e = el("div", "part none"), ic = el("div", "ic"), tx = el("div", "tx");
		e.appendChild(ic); tx.appendChild(el("div", "nm", "Vacío")); tx.appendChild(el("div", "dl", "Desmontar la pieza actual")); e.appendChild(tx);
		e.appendChild(el("div", "st", ""));
		e.onmouseenter = function () { setPreview(P.removePreview, "Sin pieza en " + P.label); };
		e.onmouseleave = function () { setPreview(null, null); };
		e.onclick = function () { click(); call("remove", P.k); };
		L.appendChild(e);
	}
	P.list.forEach(function (it) {
		if (it.have || it.on) have++;
		if (filter === "have" && !it.have && !it.on) return;
		if (q && it.name.toLowerCase().indexOf(q) < 0) return;
		shown++;
		var cls = it.on ? "on" : (it.have ? "have" : "na");
		var e = el("div", "part " + cls), ic = el("div", "ic"), tx = el("div", "tx");
		ic.appendChild(img(it.icon)); e.appendChild(ic);
		tx.appendChild(el("div", "nm", it.name));
		var dl = el("div", "dl");
		[["ergo", "high", "Ergo "], ["recoilV", "low", "Retr. "], ["accuracy", "low", "MOA "], ["weight", "low", "kg "]].forEach(function (s) {
			var b = delta(s[0], D.stats, it.preview, s[1], s[0] === "weight" ? "kg" : null);
			if (b) { b.textContent = s[2] + b.textContent; dl.appendChild(b); }
		});
		tx.appendChild(dl); e.appendChild(tx);
		e.appendChild(el("div", "st", it.on ? "Montada" : (it.free ? "Libre" : (it.have ? "x" + it.count : "No disponible"))));
		e.title = it.name;
		e.onmouseenter = function () { setPreview(it.preview, it.name); };
		e.onmouseleave = function () { setPreview(null, null); };
		if (!it.on && it.have) e.onclick = function () { click(); call("install", P.k, it.att); };
		L.appendChild(e);
	});
	if (!shown) L.appendChild(el("div", "msg", P.list.length ? "Ninguna pieza coincide." : "No hay piezas compatibles con esta ranura."));
	document.getElementById("pcount").textContent = have + " disponibles / " + P.list.length;
}
document.querySelectorAll("#filters .btn").forEach(function (b) {
	b.onclick = function () { click(); filter = b.dataset.f;
		document.querySelectorAll("#filters .btn").forEach(function (x) { x.classList.toggle("on", x === b); }); drawParts(); };
});

// ── stats ──
function setPreview(p, name) {
	preview = p || null;
	var pv = document.getElementById("pv");
	pv.classList.toggle("on", !!(p && name)); pv.textContent = name ? "Vista previa: " + name : "";
	drawStats();
}
function drawStats() {
	var M = document.getElementById("stats"); M.innerHTML = "";
	D.statRows.forEach(function (s) {
		var v = D.stats[s.key], pv = preview && preview[s.key] !== undefined ? preview[s.key] : v;
		var row = el("div", "stat"), top = el("div", "row");
		top.appendChild(el("div", "k", s.label));
		top.appendChild(el("div", "v", fmt(pv, s)));
		var diff = Math.round((pv - v) * 1000) / 1000, good = s.better === "low" ? diff < 0 : diff > 0;
		top.appendChild(el("div", "d" + (diff ? (good ? " up" : " down") : ""), diff ? ((diff > 0 ? "+" : "") + (s.unit === "kg" ? diff.toFixed(3) : (s.unit === "moa" ? diff.toFixed(2) : diff))) : ""));
		row.appendChild(top);
		var bar = el("div", "bar"), a = Math.min(v, pv) / s.max * 100, b = Math.max(v, pv) / s.max * 100;
		var base = el("i"); base.style.width = Math.max(0, Math.min(100, a)) + "%"; bar.appendChild(base);
		if (diff) { var x = el("b", good ? "up" : "down"); x.style.left = a + "%"; x.style.width = Math.max(0, Math.min(100, b) - a) + "%"; bar.appendChild(x); }
		row.appendChild(bar); M.appendChild(row);
	});
	var I = document.getElementById("info"); I.innerHTML = "";
	D.info.forEach(function (r) { var d = el("div"); d.appendChild(el("span", null, r[0])); d.appendChild(el("span", null, r[1])); I.appendChild(d); });
}

// ── marcadores sobre el arma 3D ──
function markers(list) { MK = arr(list); drawMarkers(); }
function drawMarkers() {
	var V = document.getElementById("view");
	V.querySelectorAll(".mk").forEach(function (m) { m.remove(); });
	var svg = document.getElementById("lines"); svg.innerHTML = "";
	var top = V.getBoundingClientRect().top;
	MK.forEach(function (m) {
		var s = slotOf(m.k); if (!s) return;
		var d = el("div", "mk" + (s.att ? " full" : "") + ((sel === m.k || hov === m.k) ? " sel" : ""));
		d.style.left = m.x + "px"; d.style.top = (m.y - top) + "px";
		d.appendChild(el("div", "lb", s.att ? s.name : s.label));
		d.onmousedown = function (ev) { ev.stopPropagation(); };
		d.onclick = function (ev) { ev.stopPropagation(); click(); select(m.k); };
		V.appendChild(d);
		if (sel === m.k || hov === m.k) {
			var n = document.querySelector('.node[data-k="' + m.k + '"]');
			if (n) {
				var r = n.getBoundingClientRect(), ln = document.createElementNS("http://www.w3.org/2000/svg", "line");
				var px = document.getElementById("parts").classList.contains("open") ? document.getElementById("parts").getBoundingClientRect().right : r.right;
				ln.setAttribute("x1", px); ln.setAttribute("y1", r.top + r.height / 2 - top);
				ln.setAttribute("x2", m.x); ln.setAttribute("y2", m.y - top);
				svg.appendChild(ln);
			}
		}
	});
}

// girar y acercar el arma
(function () {
	var V = document.getElementById("view"), rot = null;
	V.addEventListener("mousedown", function (ev) { if (ev.button !== 0) return; rot = {x: ev.clientX, y: ev.clientY}; V.classList.add("rot"); });
	document.addEventListener("mousemove", function (ev) {
		if (!rot) return;
		var dx = ev.clientX - rot.x, dy = ev.clientY - rot.y;
		if (dx || dy) { call("rotate", dx, dy); rot.x = ev.clientX; rot.y = ev.clientY; }
	});
	document.addEventListener("mouseup", function () { rot = null; V.classList.remove("rot"); });
	V.addEventListener("wheel", function (ev) { ev.preventDefault(); call("zoom", ev.deltaY > 0 ? 1 : -1); });
	V.addEventListener("dblclick", function () { call("rotate", 0, 0, true); });
})();

function render(data) {
	D = data; D.slots = arr(D.slots); D.statRows = arr(D.statRows); D.info = arr(D.info);
	document.getElementById("title").textContent = D.name;
	document.getElementById("wname").textContent = D.name;
	document.getElementById("wsub").textContent = D.sub || "";
	var note = document.getElementById("note"); note.textContent = D.note || ""; note.style.display = D.note ? "block" : "none";
	drawTree(); drawStats(); drawMarkers();
	if (D.flash) { var f = document.querySelector('.node[data-k="' + D.flash + '"]'); if (f) f.classList.add("flash"); }
	if (sel !== null && !slotOf(sel)) closeParts();
	else if (sel !== null) call("select", sel);
	preview = null; document.getElementById("pv").classList.remove("on");
}
document.addEventListener("keydown", function (ev) {
	if (ev.keyCode === 27) { if (document.activeElement && document.activeElement.id === "search" && P) { document.activeElement.blur(); return; } closeWin(); }
});
</script>
</body></html>
]==]
