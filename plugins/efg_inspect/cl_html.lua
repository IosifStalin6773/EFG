-- Página de la ventana de inspección/modding. 3 columnas: imagen + ranuras
-- de accesorios | stats | descripción + acciones. Drag & drop hecho a mano
-- (mousedown/mousemove/mouseup) porque el HTML5 DnD no es fiable en el CEF
-- de GMod. Lua manda los datos con render(json); la página llama a
-- efg.install(modID), efg.remove(slot), efg.action(key), efg.close(), efg.click().

local PLUGIN = PLUGIN

PLUGIN.inspectHTML = [==[
<!doctype html>
<html><head><meta charset="utf-8">
<style>
/*EFG_BASE*/
html, body { background: transparent; }
body { display: flex; align-items: center; justify-content: center; }

#win { width: 100%; height: 100%; display: flex; flex-direction: column;
	background: var(--efg-bg1) var(--efg-grunge); border: 1px solid #0a0b09;
	box-shadow: 0 0 0 1px var(--efg-line), 0 20px 60px rgba(0,0,0,.9); }
#top { display: flex; align-items: center; height: 30px; background: #000; padding: 0 0 0 12px; flex: 0 0 auto; }
#top .t { flex: 1; font-family: var(--efg-font-stencil); font-size: 15px; letter-spacing: 2px; text-transform: uppercase; color: var(--efg-text); }
#top .t small { margin-left: 10px; font-family: var(--efg-font-type); font-size: 11px; letter-spacing: 0; text-transform: none; color: var(--efg-dim); }
#top .x { width: 34px; height: 30px; border: 0; background: none; color: var(--efg-text2); font-size: 16px; cursor: pointer; font-family: var(--efg-font); }
#top .x:hover { background: var(--efg-red); color: #fff; }

#cols { flex: 1; min-height: 0; display: grid; grid-template-columns: 1.25fr 1fr .9fr; gap: 6px; padding: 6px; }
.col { display: flex; flex-direction: column; min-height: 0; background: rgba(0,0,0,.28); border: 1px solid #0a0b09;
	box-shadow: inset 0 1px 0 rgba(255,255,255,.03); }
.col .body { flex: 1; min-height: 0; overflow-y: auto; padding: 8px; }

/* ── izquierda: imagen y ranuras ── */
#pic { position: relative; height: 210px; margin-bottom: 8px; display: flex; align-items: center; justify-content: center;
	background: radial-gradient(ellipse at center, rgba(200,198,180,.07), transparent 70%), var(--efg-slot);
	box-shadow: var(--efg-shadow-in); border: 1px solid #0a0b09; }
#pic img { max-width: 92%; max-height: 190px; filter: drop-shadow(0 6px 8px rgba(0,0,0,.9)); }
#pic .rar { position: absolute; left: 0; bottom: 0; height: 3px; right: 0; }
#pic .none { font-family: var(--efg-font-stencil); font-size: 26px; letter-spacing: 3px; color: var(--efg-dim); }
.sub { display: flex; align-items: center; height: 22px; margin: 6px 0 6px; padding: 0 8px; background: #000;
	font-size: 12px; letter-spacing: 1.5px; text-transform: uppercase; color: var(--efg-text); }
.sub span { margin-left: auto; font-family: var(--efg-font-type); font-size: 10px; letter-spacing: 0; text-transform: none; color: var(--efg-dim); }
#slots { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4px; }
.slot { position: relative; height: 74px; background: var(--efg-slot); border: 1px solid #0a0b09;
	box-shadow: inset 1px 1px 0 rgba(0,0,0,.8), inset -1px -1px 0 rgba(255,255,255,.04), inset 0 0 12px rgba(0,0,0,.6);
	display: flex; align-items: center; justify-content: center; }
.slot .lb { position: absolute; left: 0; top: 0; padding: 1px 6px; background: #000; font-size: 10px; letter-spacing: 1px;
	text-transform: uppercase; color: var(--efg-dim); z-index: 1; }
.slot .mod { position: absolute; left: 2px; top: 2px; right: 2px; bottom: 2px; display: flex; align-items: center; justify-content: center;
	background: rgba(60,62,58,.55); box-shadow: inset 1px 1px 0 rgba(255,255,255,.08), inset -1px -1px 0 rgba(0,0,0,.6); cursor: grab; }
.slot .mod img { max-width: 80%; max-height: 70%; filter: drop-shadow(0 2px 2px #000); pointer-events: none; }
.slot .mod .nm { position: absolute; right: 3px; bottom: 1px; max-width: 95%; font-size: 11px; color: #cdcbbe;
	white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.slot .mod:hover { box-shadow: inset 0 0 0 1px var(--efg-text2); }
.slot.empty::after { content: "+"; font-size: 22px; color: rgba(200,198,180,.12); }
.slot.drop-ok { background: rgba(143,179,74,.20); box-shadow: inset 0 0 0 1px var(--efg-ok); }
.slot.drop-bad { background: rgba(184,50,42,.22); box-shadow: inset 0 0 0 1px var(--efg-red-hi); }
.slot.hint { box-shadow: inset 0 0 0 1px rgba(143,179,74,.45); }

#parts { display: grid; grid-template-columns: repeat(auto-fill, 64px); grid-auto-rows: 64px; gap: 3px; min-height: 70px;
	padding: 3px; background: #0a0b09; box-shadow: var(--efg-shadow-in); }
#parts.drop-ok { box-shadow: inset 0 0 0 1px var(--efg-ok); background: rgba(143,179,74,.12); }
.part { position: relative; display: flex; align-items: center; justify-content: center; background: rgba(60,62,58,.55);
	box-shadow: inset 1px 1px 0 rgba(255,255,255,.08), inset -1px -1px 0 rgba(0,0,0,.6); cursor: grab; }
.part img { max-width: 80%; max-height: 70%; pointer-events: none; filter: drop-shadow(0 2px 2px #000); }
.part .nm { position: absolute; right: 2px; top: 1px; max-width: 95%; font-size: 10px; color: #cdcbbe; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.part:hover { box-shadow: inset 0 0 0 1px var(--efg-text2); }
.part.dragging, .slot .mod.dragging { opacity: .3; }
.empty-msg { grid-column: 1 / -1; padding: 8px; font-family: var(--efg-font-type); font-size: 11px; color: var(--efg-dim); }

#ghost { position: fixed; width: 64px; height: 64px; pointer-events: none; z-index: 99; display: none; align-items: center; justify-content: center;
	background: rgba(60,62,58,.85); box-shadow: 0 0 0 1px var(--efg-orange), 0 8px 20px rgba(0,0,0,.85); }
#ghost img { max-width: 80%; max-height: 70%; }

/* ── centro: stats ── */
.stat { padding: 7px 8px 6px; border-bottom: 1px solid rgba(0,0,0,.55); box-shadow: inset 0 1px 0 rgba(255,255,255,.02); }
.stat:nth-child(odd) { background: rgba(255,255,255,.015); }
.stat .row { display: flex; align-items: baseline; }
.stat .k { flex: 1; font-size: 12px; letter-spacing: 1.5px; text-transform: uppercase; color: var(--efg-text2); }
.stat .v { font-size: 17px; color: var(--efg-text); }
.stat .d { width: 58px; text-align: right; font-size: 13px; }
.d.up { color: var(--efg-ok); } .d.down { color: var(--efg-red-hi); }
.bar { position: relative; height: 5px; margin-top: 5px; background: #0a0b09; box-shadow: var(--efg-shadow-in); }
.bar i { position: absolute; left: 0; top: 0; bottom: 0; background: var(--efg-text2); }
.bar b { position: absolute; top: 0; bottom: 0; }
.bar b.up { background: var(--efg-ok); } .bar b.down { background: var(--efg-red-hi); }
.ammo-h { margin: 2px 0 8px; padding: 6px 8px; background: rgba(227,114,45,.08); border-left: 2px solid var(--efg-orange);
	font-size: 14px; color: var(--efg-text); }
.ammo-h small { display: block; font-family: var(--efg-font-type); font-size: 11px; color: var(--efg-dim); }
.pen-scale { display: grid; grid-template-columns: repeat(6, 1fr); gap: 2px; margin-top: 6px; }
.pen-scale div { height: 18px; display: flex; align-items: center; justify-content: center; font-size: 11px; color: #111; }

/* ── derecha: descripción y acciones ── */
.desc { font-family: var(--efg-font-type); font-size: 12.5px; line-height: 1.55; color: var(--efg-text2); white-space: pre-wrap; }
.info { margin-top: 10px; }
.info div { display: flex; justify-content: space-between; padding: 4px 2px; border-bottom: 1px solid rgba(0,0,0,.45); font-size: 13px; }
.info div span:first-child { color: var(--efg-dim); text-transform: uppercase; letter-spacing: 1px; font-size: 11px; }
#acts { flex: 0 0 auto; display: flex; flex-direction: column; gap: 4px; padding: 8px; border-top: 1px solid #0a0b09; background: rgba(0,0,0,.3); }
#acts .btn { width: 100%; padding: 9px; font-size: 14px; letter-spacing: 2px; }
#note { font-family: var(--efg-font-type); font-size: 11px; color: var(--efg-red-hi); padding: 0 2px 4px; }
</style></head>
<body>
<div id="win">
	<div id="top"><div class="t" id="title">—</div><button class="x" onclick="closeWin()">✕</button></div>
	<div id="cols">
		<div class="col"><div class="body" id="left"></div></div>
		<div class="col"><div class="sub" style="margin:0">Características</div><div class="body" id="mid"></div></div>
		<div class="col"><div class="sub" style="margin:0">Descripción</div><div class="body" id="right"></div><div id="acts"></div></div>
	</div>
</div>
<div id="ghost"><img></div>
<script>
var D = null, preview = null, drag = null;
var RARC = {common: "#8a8f86", uncommon: "#8fb34a", rare: "#4f8fb0", epic: "#a77bd6", legendary: "#dcc060"};

function el(t, c, x) { var e = document.createElement(t); if (c) e.className = c; if (x !== undefined && x !== null) e.textContent = x; return e; }
function call(fn) { if (window.efg && efg[fn]) efg[fn].apply(efg, [].slice.call(arguments, 1)); }
function click() { call("click"); }
function closeWin() { click(); call("close"); }
function img(src) { var i = el("img"); if (src) i.src = src; i.onerror = function () { i.style.display = "none"; }; return i; }
function fmt(v, s) { if (s.unit === "kg") return v.toFixed(3) + " kg"; if (s.unit === "moa") return v.toFixed(2) + " MOA"; if (s.unit === "%") return v + "%"; if (s.unit === "ms") return v + " m/s"; return String(v); }

// ── izquierda ──
function drawLeft() {
	var L = document.getElementById("left"); L.innerHTML = "";
	var pic = el("div"); pic.id = "pic";
	if (D.item.icon) pic.appendChild(img(D.item.icon)); else pic.appendChild(el("div", "none", D.item.name));
	var r = el("div", "rar"); r.style.background = RARC[D.item.rarity] || "transparent"; pic.appendChild(r);
	L.appendChild(pic);

	if (D.item.kind !== "weapon") return;

	var h = el("div", "sub", "Accesorios"); h.appendChild(el("span", null, "Arrastra para montar o desmontar")); L.appendChild(h);
	var g = el("div"); g.id = "slots";
	D.slots.forEach(function (s) {
		var b = el("div", "slot" + (s.mod ? "" : " empty")); b.dataset.slot = s.slot;
		b.appendChild(el("div", "lb", s.label));
		if (s.mod) {
			var m = el("div", "mod"); m.appendChild(img(s.mod.icon)); m.appendChild(el("span", "nm", s.mod.name));
			m.onmouseenter = function () { if (!drag) setPreview(s.previewRemove); };
			m.onmouseleave = function () { if (!drag) setPreview(null); };
			m.onmousedown = function (ev) { startDrag(ev, {from: "slot", slot: s.slot, icon: s.mod.icon, el: m, preview: s.previewRemove}); };
			b.appendChild(m);
		}
		g.appendChild(b);
	});
	L.appendChild(g);

	var h2 = el("div", "sub", "Accesorios en tu inventario"); h2.appendChild(el("span", null, D.parts.length + " compatibles")); L.appendChild(h2);
	var p = el("div"); p.id = "parts";
	if (!D.parts.length) p.appendChild(el("div", "empty-msg", "No llevas accesorios compatibles. Suelta aquí uno montado para desmontarlo."));
	D.parts.forEach(function (it) {
		var c = el("div", "part"); c.appendChild(img(it.icon)); c.appendChild(el("span", "nm", it.name));
		c.title = it.name + " (" + it.slotLabel + ")";
		c.onmouseenter = function () { if (!drag) { setPreview(it.preview); hintSlot(it.slot, true); } };
		c.onmouseleave = function () { if (!drag) { setPreview(null); hintSlot(it.slot, false); } };
		c.onmousedown = function (ev) { startDrag(ev, {from: "inv", id: it.id, slot: it.slot, icon: it.icon, el: c, preview: it.preview}); };
		p.appendChild(c);
	});
	L.appendChild(p);
}
function hintSlot(slot, on) {
	document.querySelectorAll(".slot").forEach(function (s) { if (s.dataset.slot === slot) s.classList.toggle("hint", on); });
}

// ── centro ──
function drawMid() {
	var M = document.getElementById("mid"); M.innerHTML = "";
	if (D.ammo) {
		var h = el("div", "ammo-h", D.ammo.name); h.appendChild(el("small", null, D.item.kind === "ammo" ? "Balística" : "Munición del calibre del arma")); M.appendChild(h);
	}
	D.stats.forEach(function (s) {
		var v = s.value, pv = preview && preview[s.key] !== undefined ? preview[s.key] : v;
		var row = el("div", "stat"), top = el("div", "row");
		top.appendChild(el("div", "k", s.label));
		top.appendChild(el("div", "v", fmt(pv, s)));
		var diff = Math.round((pv - v) * 1000) / 1000, good = s.better === "low" ? diff < 0 : diff > 0;
		var d = el("div", "d" + (diff ? (good ? " up" : " down") : ""), diff ? ((diff > 0 ? "+" : "") + (s.unit === "kg" ? diff.toFixed(3) : (s.unit === "moa" ? diff.toFixed(2) : diff))) : "");
		top.appendChild(d); row.appendChild(top);
		if (s.max) {
			var bar = el("div", "bar"), a = Math.min(v, pv) / s.max * 100, b = Math.max(v, pv) / s.max * 100;
			var base = el("i"); base.style.width = Math.max(0, Math.min(100, a)) + "%"; bar.appendChild(base);
			if (diff) { var x = el("b", good ? "up" : "down"); x.style.left = a + "%"; x.style.width = Math.max(0, Math.min(100, b) - a) + "%"; bar.appendChild(x); }
			row.appendChild(bar);
		}
		M.appendChild(row);
	});
	if (D.ammo) {
		// clases de blindaje que atraviesa (6 casillas, como la tabla de EFT)
		var sc = el("div", "pen-scale");
		[15, 25, 35, 45, 55, 65].forEach(function (th, i) {
			var pen = D.ammo.pen, cell = el("div", null, String(i + 1));
			cell.style.background = pen > th * 1.6 ? "#6f9a3a" : (pen > th ? "#c9a43a" : (pen > th * 0.7 ? "#b56a2a" : "#7a1414"));
			sc.appendChild(cell);
		});
		var t = el("div", "sub", "Eficacia por clase de blindaje"); M.appendChild(t); M.appendChild(sc);
	}
}

// ── derecha ──
function drawRight() {
	var R = document.getElementById("right"); R.innerHTML = "";
	R.appendChild(el("div", "desc", D.item.desc || ""));
	var info = el("div", "info");
	(D.info || []).forEach(function (r) { var d = el("div"); d.appendChild(el("span", null, r[0])); d.appendChild(el("span", null, r[1])); info.appendChild(d); });
	R.appendChild(info);

	var A = document.getElementById("acts"); A.innerHTML = "";
	if (D.note) A.appendChild(el("div", null, D.note)).id = "note";
	D.actions.forEach(function (a) {
		var b = el("button", "btn" + (a.style ? " " + a.style : ""), a.name);
		b.onclick = function () { click(); call("action", a.key); };
		A.appendChild(b);
	});
	var c = el("button", "btn", "Cerrar"); c.onclick = closeWin; A.appendChild(c);
}

function setPreview(p) { preview = p || null; drawMid(); }

// ── drag & drop a mano ──
function startDrag(ev, info) {
	if (ev.button !== 0 || !D.canMod) return;
	ev.preventDefault();
	drag = info; drag.x = ev.clientX; drag.y = ev.clientY; drag.moved = false;
}
document.addEventListener("mousemove", function (ev) {
	if (!drag) return;
	var gh = document.getElementById("ghost");
	if (!drag.moved && Math.abs(ev.clientX - drag.x) + Math.abs(ev.clientY - drag.y) > 4) {
		drag.moved = true; drag.el.classList.add("dragging");
		gh.querySelector("img").src = drag.icon || ""; gh.style.display = "flex";
		setPreview(drag.preview); if (drag.from === "inv") hintSlot(drag.slot, true);
	}
	if (!drag.moved) return;
	gh.style.left = (ev.clientX - 32) + "px"; gh.style.top = (ev.clientY - 32) + "px";
	clearDrop();
	var t = target(ev);
	if (t) t.node.classList.add(t.ok ? "drop-ok" : "drop-bad");
});
document.addEventListener("mouseup", function (ev) {
	if (!drag) return;
	var d = drag, t = d.moved ? target(ev) : null;
	drag = null; clearDrop();
	document.getElementById("ghost").style.display = "none";
	if (d.el) d.el.classList.remove("dragging");
	hintSlot(d.slot, false); setPreview(null);
	if (!t || !t.ok) return;
	click();
	if (t.kind === "slot") call("install", String(d.id));
	else if (t.kind === "parts") call("remove", d.slot);
});
function clearDrop() { document.querySelectorAll(".drop-ok, .drop-bad").forEach(function (n) { n.classList.remove("drop-ok", "drop-bad"); }); }
function target(ev) {
	var n = document.elementFromPoint(ev.clientX, ev.clientY);
	while (n && n !== document.body) {
		if (n.classList && n.classList.contains("slot")) {
			return {node: n, kind: "slot", ok: drag.from === "inv" && n.dataset.slot === drag.slot};
		}
		if (n.id === "parts") return {node: n, kind: "parts", ok: drag.from === "slot"};
		n = n.parentNode;
	}
	return null;
}

function arr(x) { return Array.isArray(x) ? x : []; }
// util.TableToJSON deja {} en las listas vacías: se normalizan
function render(data) {
	D = data; D.stats = arr(D.stats); D.slots = arr(D.slots); D.parts = arr(D.parts); D.actions = arr(D.actions); D.info = arr(D.info);
	D.slots.forEach(function (s) { if (s.mod && !s.mod.name) s.mod = null; });
	var t = document.getElementById("title"); t.textContent = D.item.name;
	if (D.item.kindLabel) t.appendChild(el("small", null, D.item.kindLabel));
	preview = null; drawLeft(); drawMid(); drawRight();
}
document.addEventListener("keydown", function (ev) { if (ev.keyCode === 27) closeWin(); });
</script>
</body></html>
]==]
