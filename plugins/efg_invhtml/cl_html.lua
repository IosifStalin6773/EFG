-- Página del inventario. Rejillas con CSS Grid (cada objeto con grid-column /
-- grid-row) y arrastre hecho a mano con el ratón: el DnD de HTML5 no es fiable
-- en el CEF de GMod.

local PLUGIN = PLUGIN

PLUGIN.invHTML = [==[
<!doctype html>
<html><head><meta charset="utf-8">
<style>
/*EFG_BASE*/
html, body { margin: 0; height: 100%; overflow: hidden; background: transparent; user-select: none; }
body { font-family: var(--efg-font); color: var(--efg-text); font-size: 12px; }
:root { --cell: 48px; }

#app { position: absolute; inset: 0; display: flex; flex-direction: column; }
#bar { flex: 0 0 34px; display: flex; align-items: stretch; background: #000; border-bottom: 1px solid var(--efg-line); }
#bar .tab { padding: 0 22px; display: flex; align-items: center; font-size: 13px; letter-spacing: 2px; text-transform: uppercase; color: var(--efg-text2); border-right: 1px solid #1a1b18; }
#bar .tab.on { color: #fff; background: linear-gradient(#2a2c27, #151613); box-shadow: inset 0 -2px 0 var(--efg-text); }
#bar .sp { flex: 1; }
#bar .who { display: flex; align-items: center; padding: 0 14px; color: var(--efg-text2); letter-spacing: 1px; text-transform: uppercase; }
#bar .x { width: 42px; border: 0; background: none; color: var(--efg-text2); font: 16px var(--efg-font); cursor: pointer; }
#bar .x:hover { background: var(--efg-red); color: #fff; }

#cols { flex: 1; min-height: 0; display: grid; grid-template-columns: minmax(0, 27fr) minmax(0, 34fr) minmax(0, 39fr); gap: 10px; padding: 10px; }
.col { min-height: 0; display: flex; flex-direction: column; background: rgba(10,11,9,.72); border: 1px solid #0a0b09; box-shadow: 0 0 0 1px var(--efg-line); }
.col > .body { flex: 1; min-height: 0; overflow-y: auto; overflow-x: hidden; padding: 8px; }
.hdr { flex: 0 0 auto; display: flex; align-items: center; gap: 8px; height: 24px; padding: 0 8px; background: #000; text-transform: uppercase; letter-spacing: 1.5px; font-size: 12px; color: var(--efg-text); }
.hdr .r { margin-left: auto; color: var(--efg-dim); letter-spacing: .5px; }

/* ── equipo ── */
#equip { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; }
.slot, .wslot { position: relative; background: var(--efg-slot); border: 1px solid var(--efg-line); box-shadow: var(--efg-shadow-in); overflow: hidden; }
.slot { aspect-ratio: 1 / 1; }
.slot .lbl, .wslot .lbl { position: absolute; left: 0; right: 0; top: 0; height: 15px; padding: 0 4px; background: rgba(0,0,0,.75); font-size: 10px; letter-spacing: 1px; text-transform: uppercase; color: var(--efg-text2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; z-index: 2; }
.slot.empty .lbl, .wslot.empty .lbl { background: none; color: var(--efg-dim); top: auto; bottom: 0; text-align: center; }
.slot .it, .wslot .it { position: absolute; inset: 15px 0 0 0; }
.slot.nolbl .it { inset: 0; }
#silo { position: relative; margin: 6px 0; height: 0; }
#weps { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-top: 8px; }
.wslot { height: calc(var(--cell) * 1.6); }
.wslot.long { grid-column: 1 / span 2; }
#stats { margin-top: 10px; display: grid; grid-template-columns: repeat(3, 1fr); border: 1px solid var(--efg-line); background: #000; }
#stats div { padding: 6px 8px; border-right: 1px solid #1a1b18; }
#stats div:last-child { border-right: 0; }
#stats b { display: block; font-size: 15px; font-weight: normal; color: #fff; }
#stats span { font-size: 10px; letter-spacing: 1px; text-transform: uppercase; color: var(--efg-dim); }
#stats .bad b { color: var(--efg-red-hi); }

/* ── rejillas ── */
.sect { margin-bottom: 10px; }
.sect .hdr { margin-bottom: 4px; }
.row { display: flex; gap: 6px; align-items: flex-start; }
.row > .slot { flex: 0 0 calc(var(--cell) * 1.5); width: calc(var(--cell) * 1.5); }
.grid { position: relative; display: grid; grid-template-columns: repeat(var(--gw), var(--cell)); grid-template-rows: repeat(var(--gh), var(--cell));
	width: calc(var(--gw) * var(--cell)); background-color: var(--efg-slot);
	background-image: linear-gradient(to right, rgba(255,255,255,.07) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,.07) 1px, transparent 1px);
	background-size: var(--cell) var(--cell); border: 1px solid var(--efg-line); box-shadow: inset 0 0 14px rgba(0,0,0,.7); }
.none { padding: 10px; border: 1px dashed var(--efg-line); color: var(--efg-dim); text-transform: uppercase; letter-spacing: 1px; font-size: 10px; flex: 1; }

/* ── objetos ── */
.it { position: relative; box-sizing: border-box; border: 1px solid rgba(255,255,255,.12); background: rgba(60,62,58,.55); overflow: hidden; cursor: pointer; }
.grid > .it { margin: 0 1px 1px 0; }
.it img { position: absolute; inset: 3px; width: calc(100% - 6px); height: calc(100% - 6px); object-fit: contain; pointer-events: none; filter: drop-shadow(0 1px 1px #000); }
.it .n { position: absolute; top: 1px; right: 3px; left: 3px; text-align: right; font-size: 10px; color: var(--efg-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-shadow: 0 1px 1px #000; pointer-events: none; }
.it .c { position: absolute; right: 3px; bottom: 1px; font-size: 10px; color: #fff; text-shadow: 0 1px 1px #000; pointer-events: none; }
.it .e { position: absolute; left: 3px; bottom: 1px; font-size: 9px; color: var(--efg-ok); letter-spacing: 1px; pointer-events: none; }
.it.noicon .n { top: 50%; transform: translateY(-50%); text-align: center; white-space: normal; font-size: 10px; }
.it:hover { border-color: var(--efg-text); box-shadow: inset 0 0 0 1px rgba(255,255,255,.18), 0 0 8px rgba(255,255,255,.18); z-index: 3; }
.it.sel { border-color: var(--efg-orange); box-shadow: inset 0 0 0 1px var(--efg-orange); }
.it.dim { opacity: .18; }
.it.drag { opacity: .3; }
.c-weapon { background: rgba(38,44,48,.7); } .c-mag, .c-ammo { background: rgba(58,52,30,.6); } .c-mod { background: rgba(34,48,40,.6); }
.c-gear { background: rgba(44,46,40,.7); } .c-med { background: rgba(70,30,30,.55); } .c-food { background: rgba(40,56,40,.55); } .c-key { background: rgba(72,62,20,.55); }

/* ── alijo ── */
#stashTools { display: flex; align-items: center; gap: 8px; padding: 6px 8px; background: rgba(0,0,0,.5); border-bottom: 1px solid #0a0b09; }
#search { flex: 1; height: 22px; padding: 0 8px; background: var(--efg-slot); border: 1px solid var(--efg-line); color: var(--efg-text); font: 12px var(--efg-font); outline: none; }
#search:focus { border-color: var(--efg-text2); }
.money { color: var(--efg-text); white-space: nowrap; } .money b { color: #fff; font-weight: normal; }
#stashMsg { padding: 20px; text-align: center; color: var(--efg-dim); text-transform: uppercase; letter-spacing: 1px; }

/* ── arrastre y tooltip ── */
#ghost { position: fixed; pointer-events: none; z-index: 50; display: none; opacity: .85; box-shadow: 0 0 0 1px var(--efg-orange), 0 6px 18px rgba(0,0,0,.8); }
.prev { position: absolute; pointer-events: none; z-index: 4; }
.prev.ok { background: rgba(143,179,74,.28); outline: 1px solid var(--efg-ok); }
.prev.bad { background: rgba(184,50,42,.3); outline: 1px solid var(--efg-red-hi); }
.slot.ok, .wslot.ok { box-shadow: inset 0 0 0 1px var(--efg-ok), inset 0 0 14px rgba(143,179,74,.35); }
.slot.bad, .wslot.bad { box-shadow: inset 0 0 0 1px var(--efg-red-hi); }
#tip { position: fixed; z-index: 60; display: none; max-width: 300px; padding: 8px 10px; background: rgba(8,9,7,.96); border: 1px solid var(--efg-line2); box-shadow: 0 6px 20px rgba(0,0,0,.8); pointer-events: none; }
#tip .t { font-size: 13px; color: #fff; margin-bottom: 4px; }
#tip .k { display: flex; gap: 14px; color: var(--efg-text2); font-size: 11px; margin-bottom: 4px; }
#tip .k b { color: var(--efg-text); font-weight: normal; }
#tip .d { color: var(--efg-dim); font-size: 11px; line-height: 1.35; white-space: pre-line; }
</style></head>
<body>
<div id="app">
	<div id="bar">
		<div class="tab on">Equipo</div>
		<div class="sp"></div>
		<div class="who" id="who"></div>
		<button class="x" onclick="efg.close()">✕</button>
	</div>
	<div id="cols">
		<div class="col"><div class="hdr">Equipamiento</div><div class="body">
			<div id="equip"></div>
			<div id="weps"></div>
			<div id="stats"></div>
		</div></div>
		<div class="col"><div class="hdr">Táctico</div><div class="body" id="tact"></div></div>
		<div class="col" id="stashCol">
			<div class="hdr">Alijo <span class="r" id="stashSize"></span></div>
			<div id="stashTools">
				<input id="search" placeholder="BUSCAR" spellcheck="false">
				<span class="money"><b id="money">0</b> RUB</span>
			</div>
			<div class="body" id="stash"></div>
		</div>
	</div>
</div>
<div id="ghost"></div>
<div id="tip"></div>

<script>
var S = null, items = {}, sel = null, drag = null, tipTimer = null, query = "";
var $ = function (id) { return document.getElementById(id); };

var EQUIP = [["headset", "Auriculares"], ["helmet", "Casco"], ["facecover", "Cubrecaras"],
	["armband", "Brazalete"], ["armor", "Chaleco"], ["eyewear", "Gafas"]];
var WEPS = [["primary", "En bandolera", "long", ["primary"]], ["primary2", "A la espalda", "long", ["primary"]],
	["secondary", "Funda", "", ["secondary"]], ["melee", "Vaina", "", ["melee"]]];
var GRIDKIND = {rig: "rig", backpack: "backpack", secure: "secure"};

function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[c]; }); }
function fmt(n) { return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, " "); }
function cell() { return parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--cell")) || 48; }

function fitCell() {
	var body = $("stash"), w = body.clientWidth - 20, gw = (S && S.stash) ? S.stash.w : 10;
	var c = Math.floor(w / Math.max(gw, 1));
	c = Math.max(30, Math.min(64, c || 48));
	document.documentElement.style.setProperty("--cell", c + "px");
}

function itemEl(it, origin, inv) {
	items[it.id] = it;
	var d = document.createElement("div");
	d.className = "it c-" + it.cat + (it.icon ? "" : " noicon") + (sel == it.id ? " sel" : "");
	d.dataset.id = it.id; d.dataset.origin = origin; if (inv) d.dataset.inv = inv;
	d.innerHTML = (it.icon ? '<img src="' + esc(it.icon) + '" onerror="this.parentNode.classList.add(\'noicon\'); this.remove()">' : "") +
		'<div class="n">' + esc(it.short) + "</div>" + (it.count ? '<div class="c">' + esc(it.count) + "</div>" : "") +
		(it.eq && origin == "grid" && it.wcat ? '<div class="e">EQ</div>' : "");
	if (query && it.name.toLowerCase().indexOf(query) < 0) d.classList.add("dim");
	return d;
}

function slotEl(kind, label, it, cls, weapon) {
	var s = document.createElement("div");
	s.className = (weapon ? "wslot " : "slot ") + (cls || "") + (it ? "" : " empty");
	s.dataset[weapon ? "wslot" : "kind"] = kind;
	if (label) s.innerHTML = '<div class="lbl">' + esc(label) + "</div>"; else s.classList.add("nolbl");
	if (it) s.appendChild(itemEl(it, weapon ? "weapon" : "equip"));
	return s;
}

function gridEl(g) {
	var el = document.createElement("div");
	el.className = "grid"; el.dataset.inv = g.inv;
	el.style.setProperty("--gw", g.w); el.style.setProperty("--gh", g.h);
	g.items.forEach(function (it) {
		var d = itemEl(it, "grid", g.inv);
		d.style.gridColumn = it.x + " / span " + it.w;
		d.style.gridRow = it.y + " / span " + it.h;
		el.appendChild(d);
	});
	return el;
}

function render(data) {
	S = data; items = {};
	$("who").textContent = data.name;
	$("money").textContent = fmt(data.money);
	fitCell();

	var eq = $("equip"); eq.innerHTML = "";
	EQUIP.forEach(function (e) { eq.appendChild(slotEl(e[0], e[1], data.equip[e[0]])); });

	var wp = $("weps"); wp.innerHTML = "";
	WEPS.forEach(function (w) { wp.appendChild(slotEl(w[0], w[1], data.weapons[w[0]], w[2], true)); });

	var over = data.weight[0] > data.weight[1];
	var hpLow = data.hp[0] < data.hp[1] * 0.35;
	$("stats").innerHTML =
		'<div class="' + (hpLow ? "bad" : "") + '"><b>' + data.hp[0] + " / " + data.hp[1] + "</b><span>Salud</span></div>" +
		'<div class="' + (over ? "bad" : "") + '"><b>' + data.weight[0].toFixed(1) + " / " + data.weight[1] + "</b><span>Peso (kg)</span></div>" +
		"<div><b>" + fmt(data.money) + "</b><span>RUB</span></div>";

	var t = $("tact"); t.innerHTML = "";
	data.grids.forEach(function (g) {
		var sec = document.createElement("div"); sec.className = "sect";
		var size = g.empty ? "" : g.w + "x" + g.h;
		var name = g.holder ? " · " + esc(g.holder.name) : "";
		sec.innerHTML = '<div class="hdr">' + esc(g.title) + name + '<span class="r">' + size + "</span></div>";
		var row = document.createElement("div"); row.className = "row";
		if (GRIDKIND[g.key]) row.appendChild(slotEl(GRIDKIND[g.key], "", g.holder || null));
		if (g.empty) {
			var n = document.createElement("div"); n.className = "none"; n.textContent = "Arrastra aquí un objeto de este tipo";
			row.appendChild(n);
		} else {
			row.appendChild(gridEl(g));
		}
		sec.appendChild(row); t.appendChild(sec);
	});

	var st = $("stash"); st.innerHTML = "";
	if (data.stash) {
		$("stashSize").textContent = data.stash.w + "x" + data.stash.h;
		st.appendChild(gridEl(data.stash));
	} else {
		$("stashSize").textContent = "";
		st.innerHTML = '<div id="stashMsg">' + esc(data.stashMsg || "") + "</div>";
	}
}

/* ── ocupación de una rejilla sin el objeto que se arrastra ── */
function gridData(invID) {
	if (!S) return null;
	if (S.stash && S.stash.inv == invID) return S.stash;
	for (var i = 0; i < S.grids.length; i++) if (S.grids[i].inv == invID) return S.grids[i];
	return null;
}

function fits(g, it, x, y) {
	if (x < 1 || y < 1 || x + it.w - 1 > g.w || y + it.h - 1 > g.h) return false;
	for (var i = 0; i < g.items.length; i++) {
		var o = g.items[i];
		if (o.id == it.id) continue;
		if (x < o.x + o.w && x + it.w > o.x && y < o.y + o.h && y + it.h > o.y) return false;
	}
	return true;
}

function slotAccepts(el, it) {
	if (el.dataset.kind) return it.kind == el.dataset.kind;
	var w = WEPS.filter(function (x) { return x[0] == el.dataset.wslot; })[0];
	return !!(w && it.wcat && w[3].indexOf(it.wcat) >= 0);
}

/* ── arrastre ── */
var prev = document.createElement("div"); prev.className = "prev";

function clearHL() {
	if (prev.parentNode) prev.parentNode.removeChild(prev);
	document.querySelectorAll(".ok,.bad").forEach(function (e) { e.classList.remove("ok", "bad"); });
}

function target(ev) {
	var c = cell(), it = drag.it;
	var under = document.elementFromPoint(ev.clientX, ev.clientY);
	if (!under) return null;
	var slot = under.closest(".slot,.wslot");
	if (slot) return {slot: slot, ok: slotAccepts(slot, it)};
	var grid = under.closest(".grid");
	if (!grid) return null;
	var r = grid.getBoundingClientRect();
	var x = Math.round((ev.clientX - drag.ox - r.left - 1) / c) + 1;
	var y = Math.round((ev.clientY - drag.oy - r.top - 1) / c) + 1;
	var g = gridData(+grid.dataset.inv);
	return {grid: grid, inv: +grid.dataset.inv, x: x, y: y, ok: !!g && fits(g, it, x, y)};
}

document.addEventListener("mousedown", function (ev) {
	hideTip();
	var d = ev.target.closest(".it");
	if (ev.target.id != "search" && document.activeElement == $("search")) $("search").blur();
	if (!d) return;
	var it = items[d.dataset.id];
	if (ev.button == 2) { ev.preventDefault(); efg.menu(it.id); return; }
	if (ev.button != 0) return;
	var r = d.getBoundingClientRect();
	drag = {el: d, it: it, origin: d.dataset.origin, sx: ev.clientX, sy: ev.clientY, ox: ev.clientX - r.left, oy: ev.clientY - r.top, on: false, w: r.width, h: r.height};
	ev.preventDefault();
});

document.addEventListener("mousemove", function (ev) {
	if (!drag) { moveTip(ev); return; }
	if (!drag.on) {
		if (Math.abs(ev.clientX - drag.sx) + Math.abs(ev.clientY - drag.sy) < 5) return;
		drag.on = true;
		var c = cell(), g = $("ghost");
		g.innerHTML = ""; g.appendChild(drag.el.cloneNode(true));
		g.firstChild.style.width = (drag.it.w * c) + "px"; g.firstChild.style.height = (drag.it.h * c) + "px";
		g.firstChild.style.position = "relative"; g.firstChild.style.inset = "auto";
		if (drag.origin != "grid") { drag.ox = Math.min(drag.ox, c / 2); drag.oy = Math.min(drag.oy, c / 2); }
		g.style.display = "block";
		drag.el.classList.add("drag");
		efg.click();
	}
	var gh = $("ghost");
	gh.style.left = (ev.clientX - drag.ox) + "px"; gh.style.top = (ev.clientY - drag.oy) + "px";

	clearHL();
	var t = target(ev);
	if (!t) return;
	if (t.slot) { t.slot.classList.add(t.ok ? "ok" : "bad"); return; }
	var c = cell();
	prev.className = "prev " + (t.ok ? "ok" : "bad");
	prev.style.left = ((t.x - 1) * c) + "px"; prev.style.top = ((t.y - 1) * c) + "px";
	prev.style.width = (drag.it.w * c) + "px"; prev.style.height = (drag.it.h * c) + "px";
	t.grid.appendChild(prev);
});

document.addEventListener("mouseup", function (ev) {
	if (!drag || ev.button != 0) return;
	var d = drag;
	var t = d.on ? target(ev) : null;
	drag = null;
	$("ghost").style.display = "none";
	d.el.classList.remove("drag");
	clearHL();

	if (!d.on) { select(d.it.id); return; }

	if (!t || !t.ok) return;
	var it = d.it;

	if (t.slot) {
		if (d.origin != "grid") return;
		if (t.slot.dataset.kind) efg.equip(it.id); else efg.wequip(it.id);
		return;
	}

	if (d.origin == "equip") efg.unequip(it.id, t.inv, t.x, t.y);
	else if (d.origin == "weapon") efg.wunequip(it.id, t.inv, t.x, t.y);
	else if (t.inv != it_inv(d.el) || t.x != it.x || t.y != it.y) {
		/* respuesta inmediata: se recoloca ya y Lua confirma con el siguiente render */
		if (t.inv == it_inv(d.el)) { d.el.style.gridColumn = t.x + " / span " + it.w; d.el.style.gridRow = t.y + " / span " + it.h; it.x = t.x; it.y = t.y; }
		efg.move(it.id, t.inv, t.x, t.y);
	}
});

function it_inv(el) { return +el.dataset.inv; }

document.addEventListener("dblclick", function (ev) {
	var d = ev.target.closest(".it");
	if (d) efg.inspect(+d.dataset.id);
});

document.addEventListener("contextmenu", function (ev) { ev.preventDefault(); });
document.addEventListener("keydown", function (ev) {
	if (ev.keyCode == 27) { ev.preventDefault(); efg.close(); }
});

function select(id) {
	sel = (sel == id) ? null : id;
	document.querySelectorAll(".it").forEach(function (e) { e.classList.toggle("sel", e.dataset.id == sel); });
}

/* ── tooltip ── */
var tipFor = null;
function hideTip() { clearTimeout(tipTimer); tipFor = null; $("tip").style.display = "none"; }
function moveTip(ev) {
	var d = ev.target.closest && ev.target.closest(".it");
	var tip = $("tip");
	if (!d) { hideTip(); return; }
	if (tipFor != d.dataset.id) {
		hideTip(); tipFor = d.dataset.id;
		var it = items[tipFor];
		tipTimer = setTimeout(function () {
			tip.innerHTML = '<div class="t">' + esc(it.name) + '</div><div class="k"><span>Peso <b>' + (+it.weight).toFixed(2) + " kg</b></span>" +
				"<span>Venta <b>" + fmt(it.price) + " RUB</b></span>" + (it.count ? "<span>Cant. <b>" + esc(it.count) + "</b></span>" : "") + "</div>" +
				(it.desc ? '<div class="d">' + esc(it.desc) + "</div>" : "");
			tip.style.display = "block";
		}, 280);
	}
	var x = ev.clientX + 16, y = ev.clientY + 16;
	if (x + tip.offsetWidth > innerWidth - 4) x = ev.clientX - tip.offsetWidth - 12;
	if (y + tip.offsetHeight > innerHeight - 4) y = ev.clientY - tip.offsetHeight - 12;
	tip.style.left = x + "px"; tip.style.top = y + "px";
}

/* ── búsqueda en el alijo ── */
$("search").addEventListener("input", function () {
	query = this.value.trim().toLowerCase();
	document.querySelectorAll("#stash .it").forEach(function (e) {
		var it = items[e.dataset.id];
		e.classList.toggle("dim", !!query && it.name.toLowerCase().indexOf(query) < 0);
	});
});

window.addEventListener("resize", function () { if (S) render(S); });
</script>
</body></html>
]==]
