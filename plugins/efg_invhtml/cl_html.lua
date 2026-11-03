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

#app { position: absolute; top: 0; left: 0; right: 0; bottom: 0; display: flex; flex-direction: column; }
#bar { flex: 0 0 34px; display: flex; align-items: stretch; background: #000; border-bottom: 1px solid var(--efg-line); }
#bar .tab { padding: 0 22px; display: flex; align-items: center; font-size: 13px; letter-spacing: 2px; text-transform: uppercase; color: var(--efg-text2); border-right: 1px solid #1a1b18; }
#bar .tab.on { color: #fff; background: linear-gradient(#2a2c27, #151613); box-shadow: inset 0 -2px 0 var(--efg-text); }
#bar .sp { flex: 1; }
body.embedded #bar { display: none; }
#bar .who { display: flex; align-items: center; padding: 0 14px; color: var(--efg-text2); letter-spacing: 1px; text-transform: uppercase; }
#bar .x { width: 42px; border: 0; background: none; color: var(--efg-text2); font: 16px var(--efg-font); cursor: pointer; }
#bar .x:hover { background: var(--efg-red); color: #fff; }

/* disposición de EFT: equipo con silueta a la izquierda, táctico en el centro,
   alijo a la derecha y acceso rápido abajo en el centro */
:root { --gs: 120px; }
#cols { flex: 1; min-height: 0; display: grid; grid-template-columns: minmax(0, 33fr) minmax(0, 28fr) minmax(0, 39fr); gap: 16px; padding: 10px 10px 0; }
.col { position: relative; min-height: 0; display: flex; flex-direction: column; }
.col > .body { flex: 1; min-height: 0; overflow-y: auto; overflow-x: hidden; padding: 4px 8px 8px; }
.hdr { flex: 0 0 auto; display: flex; align-items: center; gap: 8px; height: 24px; padding: 0 8px; background: #000; text-transform: uppercase; letter-spacing: 1.5px; font-size: 12px; color: var(--efg-text); }
.hdr .r { margin-left: auto; color: var(--efg-dim); letter-spacing: .5px; }

/* pestaña de título de cada ranura o sección, con la esquina cortada de EFT */
.ttl { display: inline-block; height: 18px; line-height: 18px; padding: 0 22px 0 6px; background: linear-gradient(#22241f, #0c0d0b); font-size: 12px; letter-spacing: 1px; text-transform: uppercase; color: #e4e2d0; -webkit-clip-path: polygon(0 0, calc(100% - 12px) 0, 100% 100%, 0 100%); clip-path: polygon(0 0, calc(100% - 12px) 0, 100% 100%, 0 100%); }

/* ── equipo ── */
#gear { position: relative; flex: 1; min-height: 0; padding: 30px 10px 0; }
#silo { position: absolute; top: 0; bottom: 70px; left: 50%; width: 60%; transform: translateX(-50%); pointer-events: none; opacity: .16; }
#silo img { position: absolute; top: 0; left: 0; width: 100%; height: 100%; object-fit: contain; filter: brightness(.35); }
#equip { position: relative; display: grid; grid-template-columns: repeat(3, var(--gs)); grid-auto-rows: auto; column-gap: calc(var(--gs) * .5); row-gap: 14px; justify-content: center;
	grid-template-areas: "headset helmet facecover" "armband armor eyewear" "primary primary secondary" "primary2 primary2 melee"; }
.gsl { display: flex; flex-direction: column; min-width: 0; }
.gsl.wide .wslot { width: calc(var(--gs) * 2.5); }
.slot, .wslot { position: relative; background: rgba(18,19,17,.78); border: 1px solid var(--efg-line); box-shadow: var(--efg-shadow-in); overflow: hidden; }
.slot { width: var(--gs); height: var(--gs); }
.wslot { width: var(--gs); height: calc(var(--gs) * .95); }
.slot.empty, .wslot.empty { background: repeating-linear-gradient(135deg, rgba(255,255,255,.025) 0 2px, transparent 2px 7px), rgba(18,19,17,.55); }
.slot .it, .wslot .it { position: absolute; top: 0; left: 0; right: 0; bottom: 0; }
#stats { position: absolute; left: 10px; right: 10px; bottom: 8px; display: flex; gap: 22px; align-items: baseline; }
#stats div { white-space: nowrap; }
#stats b { font-size: 26px; font-weight: normal; color: #fff; }
#stats i { font-style: normal; font-size: 13px; color: var(--efg-text2); }
#stats span { display: block; font-size: 10px; letter-spacing: 1px; text-transform: uppercase; color: var(--efg-dim); }
#stats .hp b { color: var(--efg-ok); } #stats .wa b { color: var(--efg-blue); } #stats .en b { color: var(--efg-yellow); }
#stats .bad b { color: var(--efg-red-hi); }

/* ── acceso rápido ── */
#quick { flex: 0 0 auto; display: flex; flex-direction: column; align-items: center; padding: 6px 0 8px; }
#quick .qw { display: flex; flex-direction: column; align-items: flex-start; }
#hot { display: flex; gap: 4px; }
#hot .gap { width: 14px; }
.hslot, .qslot { position: relative; width: 62px; height: 62px; background: rgba(18,19,17,.85); border: 1px solid var(--efg-line); box-shadow: var(--efg-shadow-in); overflow: hidden; }
.hslot .k, .qslot .k { position: absolute; left: 2px; top: 2px; z-index: 2; min-width: 13px; height: 15px; line-height: 15px; text-align: center; font-size: 11px; color: #000; background: var(--efg-text2); pointer-events: none; }
.hslot .it, .qslot .it { position: absolute; top: 0; left: 0; right: 0; bottom: 0; }
.qslot .it .n { display: none; }
.hslot.ok { box-shadow: inset 0 0 0 1px var(--efg-ok), inset 0 0 14px rgba(143,179,74,.35); }
.hslot.bad { box-shadow: inset 0 0 0 1px var(--efg-red-hi); }

/* ── rejillas ── */
.sect { margin-bottom: 14px; }
.row { display: flex; gap: 4px; align-items: flex-start; }
.row > .slot { flex: 0 0 calc(var(--cell) * 2); width: calc(var(--cell) * 2); height: calc(var(--cell) * 2); }
.grid { position: relative; display: grid; grid-template-columns: repeat(var(--gw), var(--cell)); grid-template-rows: repeat(var(--gh), var(--cell));
	width: calc(var(--gw) * var(--cell)); background-color: var(--efg-slot);
	background-image: linear-gradient(to right, rgba(255,255,255,.07) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,.07) 1px, transparent 1px);
	background-size: var(--cell) var(--cell); border: 1px solid var(--efg-line); box-shadow: inset 0 0 14px rgba(0,0,0,.7); }
.none { padding: 10px; border: 1px dashed var(--efg-line); color: var(--efg-dim); text-transform: uppercase; letter-spacing: 1px; font-size: 10px; flex: 1; }

/* ── objetos ── */
.it { position: relative; box-sizing: border-box; border: 1px solid rgba(255,255,255,.12); background: rgba(60,62,58,.55); overflow: hidden; cursor: pointer; }
.grid > .it { margin: 0 1px 1px 0; }
.it img { position: absolute; top: 3px; left: 3px; width: calc(100% - 6px); height: calc(100% - 6px); object-fit: contain; pointer-events: none; filter: drop-shadow(0 1px 1px #000); }
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
#stashCol { background: rgba(10,11,9,.72); border-left: 3px solid #c8c6b4; }
#stashHdr { flex: 0 0 auto; display: flex; align-items: center; gap: 12px; height: 34px; padding: 0 10px 0 14px; }
#stashHdr .big { font-size: 22px; letter-spacing: 1px; text-transform: uppercase; color: #fff; }
#stashHdr .sz { color: var(--efg-dim); font-size: 11px; }
#stashWrap { flex: 1; min-height: 0; display: flex; }
#filt { flex: 0 0 34px; display: flex; flex-direction: column; gap: 2px; padding: 0 2px 0 4px; overflow: hidden; }
#filt div { height: 30px; line-height: 30px; text-align: center; font-size: 10px; letter-spacing: .5px; color: var(--efg-text2); background: #000; border: 1px solid #1a1b18; cursor: pointer; }
#filt div:hover { color: #fff; border-color: var(--efg-line2); }
#filt div.on { color: #000; background: var(--efg-text); }
#stashWrap > .body { flex: 1; min-width: 0; min-height: 0; overflow-y: auto; overflow-x: hidden; padding: 0 8px 8px 2px; }
#search { width: 120px; height: 22px; padding: 0 8px; background: var(--efg-slot); border: 1px solid var(--efg-line); color: var(--efg-text); font: 12px var(--efg-font); outline: none; }
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
		<div class="col"><div id="gear">
			<div id="silo"></div>
			<div id="equip"></div>
			<div id="stats"></div>
		</div></div>
		<div class="col"><div class="body" id="tact"></div></div>
		<div class="col" id="stashCol">
			<div id="stashHdr">
				<span class="big">Alijo</span><span class="sz" id="stashSize"></span>
				<input id="search" placeholder="BUSCAR" spellcheck="false">
				<span class="money" id="money" style="margin-left: auto"></span>
			</div>
			<div id="stashWrap"><div id="filt"></div><div class="body" id="stash"></div></div>
		</div>
	</div>
	<div id="quick"><div class="qw"><div class="ttl">Acceso rápido</div><div id="hot"></div></div></div>
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
/* teclas de las armas en el acceso rápido (efg_quickbar): V vaina, 1 funda, 2 bandolera, 3 espalda */
var QWEPS = [["V", "melee"], ["1", "secondary"], ["2", "primary"], ["3", "primary2"]];
var FILTERS = [["", "TODO"], ["weapon", "ARM"], ["mag", "CAR"], ["ammo", "MUN"], ["mod", "ACC"], ["gear", "EQP"],
	["med", "MED"], ["food", "COM"], ["key", "LLA"], ["other", "OTR"]];
var filter = "";
var SILO = ["head", "thorax", "stomach", "larm", "rarm", "lleg", "rleg"];

function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[c]; }); }
function fmt(n) { return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, " "); }
function cell() { return parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--cell")) || 48; }

/* una sola medida de celda (como en EFT): la que deja caber el alijo y la
   rejilla más ancha de la columna táctica */
function fitCell() {
	var gw = (S && S.stash) ? S.stash.w : 10, tw = 1;
	if (S) S.grids.forEach(function (g) { if (!g.empty) tw = Math.max(tw, g.w + (g.key == "pockets" ? 0 : 2)); });
	var c = Math.min(Math.floor(($("stash").clientWidth - 16) / Math.max(gw, 1)), Math.floor(($("tact").clientWidth - 24) / tw));
	c = Math.max(26, Math.min(64, c || 48));
	document.documentElement.style.setProperty("--cell", c + "px");

	/* ranuras de equipo: 3 columnas con media ranura de hueco y 4 filas con su pestaña */
	var gear = $("gear");
	var gs = Math.min((gear.clientWidth - 20) / 4, (gear.clientHeight - 30 - 70 - 72 - 42) / 3.9);
	gs = Math.max(60, Math.min(150, Math.floor(gs) || 120));
	document.documentElement.style.setProperty("--gs", gs + "px");
}

function passes(it) {
	return (!query || it.name.toLowerCase().indexOf(query) >= 0) && (!filter || it.cat == filter);
}

function stashDim() {
	document.querySelectorAll("#stash .it").forEach(function (e) { e.classList.toggle("dim", !passes(items[e.dataset.id])); });
}

/* ranura de equipo con su pestaña de título encima */
function gearSlot(area, kind, label, it, weapon, wide) {
	var w = document.createElement("div");
	w.className = "gsl" + (wide ? " wide" : ""); w.style.gridArea = area;
	w.innerHTML = '<div class="ttl">' + esc(label) + "</div>";
	w.appendChild(slotEl(kind, "", it, "", weapon));
	return w;
}

function sectHdr(title) {
	var h = document.createElement("div"); h.className = "ttl"; h.textContent = title;
	return h;
}

function itemEl(it, origin, inv) {
	items[it.id] = it;
	var d = document.createElement("div");
	d.className = "it c-" + it.cat + (it.icon ? "" : " noicon") + (sel == it.id ? " sel" : "");
	d.dataset.id = it.id; d.dataset.origin = origin; if (inv) d.dataset.inv = inv;
	d.innerHTML = (it.icon ? '<img src="' + esc(it.icon) + '" onerror="this.parentNode.classList.add(\'noicon\'); this.remove()">' : "") +
		'<div class="n">' + esc(it.short) + "</div>" + (it.count ? '<div class="c">' + esc(it.count) + "</div>" : "") +
		(it.eq && origin == "grid" && it.wcat ? '<div class="e">EQ</div>' : "");
	if (origin == "grid" && inv == (S && S.stash && S.stash.inv) && !passes(it)) d.classList.add("dim");
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
	document.body.classList.toggle("embedded", !!data.embedded);
	$("who").textContent = data.name;
	var cur = data.cur || [data.money, 0, 0];
	$("money").innerHTML = "<b>" + fmt(cur[0]) + "</b> RUB &nbsp; <b>" + fmt(cur[1]) + "</b> EUR &nbsp; <b>" + fmt(cur[2]) + "</b> USD";
	fitCell();

	var sl = $("silo");
	if (!sl.firstChild) SILO.forEach(function (p) { var im = document.createElement("img"); im.src = "asset://garrysmod/materials/efg/health/" + p + ".png"; sl.appendChild(im); });

	var eq = $("equip"); eq.innerHTML = "";
	EQUIP.forEach(function (e) { eq.appendChild(gearSlot(e[0], e[0], e[1], data.equip[e[0]])); });
	WEPS.forEach(function (w) { eq.appendChild(gearSlot(w[0], w[0], w[1], data.weapons[w[0]], true, w[2] == "long")); });

	var over = data.weight[0] > data.weight[1];
	var hpLow = data.hp[0] < data.hp[1] * 0.35;
	var wa = data.water == null ? 100 : data.water, en = data.energy == null ? 100 : data.energy;
	$("stats").innerHTML =
		'<div class="' + (over ? "bad" : "") + '"><span>Peso</span><b>' + data.weight[0].toFixed(1) + "</b><i>/" + data.weight[1] + " kg</i></div>" +
		'<div class="hp' + (hpLow ? " bad" : "") + '"><span>Salud</span><b>' + data.hp[0] + "</b><i>/" + data.hp[1] + "</i></div>" +
		'<div class="wa' + (wa < 25 ? " bad" : "") + '"><span>Hidratación</span><b>' + Math.floor(wa) + "</b><i>/100</i></div>" +
		'<div class="en' + (en < 25 ? " bad" : "") + '"><span>Energía</span><b>' + Math.floor(en) + "</b><i>/100</i></div>";

	var hb = $("hot"); hb.innerHTML = "";
	QWEPS.forEach(function (q) {
		var qs = document.createElement("div"); qs.className = "qslot";
		qs.innerHTML = '<div class="k">' + q[0] + "</div>";
		var wit = data.weapons[q[1]];
		if (wit) qs.appendChild(itemEl(wit, "qw"));
		hb.appendChild(qs);
	});
	var gp = document.createElement("div"); gp.className = "gap"; hb.appendChild(gp);
	for (var i = 1; i <= 5; i++) {
		var hs = document.createElement("div"); hs.className = "hslot"; hs.dataset.hot = i;
		hs.innerHTML = '<div class="k">' + ((i + 3) % 10) + "</div>";
		var hit = data.hotbar && data.hotbar[i - 1];
		if (hit) { var he = itemEl(hit, "hot"); he.dataset.hot = i; hs.appendChild(he); }
		hb.appendChild(hs);
	}

	var t = $("tact"); t.innerHTML = "";
	data.grids.forEach(function (g) {
		var sec = document.createElement("div"); sec.className = "sect";
		sec.appendChild(sectHdr(g.title));
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

	var fl = $("filt");
	if (!fl.firstChild) FILTERS.forEach(function (f) {
		var b = document.createElement("div"); b.textContent = f[1]; b.dataset.f = f[0];
		b.addEventListener("click", function () { filter = this.dataset.f; markFilter(); stashDim(); });
		fl.appendChild(b);
	});
	markFilter();
}

function markFilter() {
	document.querySelectorAll("#filt div").forEach(function (b) { b.classList.toggle("on", b.dataset.f == filter); });
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
	if (el.dataset.hot) return !!it.hk;
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
	var slot = under.closest(".slot,.wslot,.hslot");
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
	if (ev.button == 2) {
		ev.preventDefault();
		if (d.dataset.hot) efg.hotbar(+d.dataset.hot, 0); else efg.menu(it.id);
		return;
	}
	if (ev.button != 0) return;
	/* las armas del acceso rápido solo reflejan las ranuras de arma */
	if (d.dataset.origin == "qw") { select(it.id); return; }
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
		g.firstChild.style.position = "relative"; g.firstChild.style.top = "0"; g.firstChild.style.left = "0";
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

	var it = d.it;

	/* acceso rápido: soltar en otra ranura la mueve; soltar fuera la vacía */
	if (t && t.slot && t.slot.dataset.hot) {
		if (t.ok && t.slot.dataset.hot != d.el.dataset.hot) efg.hotbar(+t.slot.dataset.hot, it.id);
		return;
	}
	if (d.origin == "hot") { efg.hotbar(+d.el.dataset.hot, 0); return; }

	if (!t || !t.ok) return;

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
	if (ev.keyCode == 27) { ev.preventDefault(); efg.close(); return; }
	/* Ctrl + 4-8 sobre un objeto: lo pone en esa ranura del acceso rápido */
	if (ev.ctrlKey && ev.keyCode >= 52 && ev.keyCode <= 56) {
		var id = hoverID || sel, it = id && items[id];
		ev.preventDefault();
		if (it && it.hk) efg.hotbar(ev.keyCode - 51, it.id);
	}
});

function select(id) {
	sel = (sel == id) ? null : id;
	document.querySelectorAll(".it").forEach(function (e) { e.classList.toggle("sel", e.dataset.id == sel); });
}

/* ── tooltip ── */
var tipFor = null, hoverID = null;
function hideTip() { clearTimeout(tipTimer); tipFor = null; $("tip").style.display = "none"; }
function moveTip(ev) {
	var d = ev.target.closest && ev.target.closest(".it");
	var tip = $("tip");
	hoverID = d ? +d.dataset.id : null;
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
	stashDim();
});

window.addEventListener("resize", function () { if (S) render(S); });
</script>
</body></html>
]==]
