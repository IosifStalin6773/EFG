-- Página de la pestaña TAREAS (la carga cl_plugin.lua en un DHTML). Estética
-- de EFT: grises #1a1a1a / #2b2b2b, texto beige, verde militar #4b5320 y rojo
-- #8b0000 para los avisos, fuente Bender del HUD (resource/fonts/mbender.ttf).

local PLUGIN = PLUGIN

PLUGIN.tasksHTML = [==[
<!doctype html>
<html><head><meta charset="utf-8">
<style>
@font-face { font-family: "Bender"; src: url("asset://garrysmod/resource/fonts/mbender.ttf"); }
:root {
	--bg0: #0d0d0d; --bg1: #1a1a1a; --bg2: #2b2b2b; --bg3: #353535;
	--line: #3c3c38; --line2: #5a5a52;
	--text: #c7c5b3; --text2: #9a988a; --dim: #6b6a60;
	--green: #4b5320; --greenHi: #7b8a3a; --ok: #8fb34a;
	--red: #8b0000; --redHi: #c0392b; --yellow: #c9a43a; --blue: #4f8fb0;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { width: 100%; height: 100%; overflow: hidden; background: transparent;
	font-family: "Bender", "Arial Narrow", sans-serif; color: var(--text); font-size: 15px; user-select: none; }
body { display: flex; flex-direction: column; gap: 8px; }
/* grano: dos degradados repetidos dan la textura sucia de los paneles de EFT */
.panel { background: var(--bg1); border: 1px solid var(--line);
	background-image: repeating-linear-gradient(0deg, rgba(255,255,255,.012) 0 1px, transparent 1px 3px),
	                  repeating-linear-gradient(90deg, rgba(0,0,0,.18) 0 1px, transparent 1px 4px); }
.hdr { background: var(--bg2); padding: 5px 10px; text-transform: uppercase; letter-spacing: 1px;
	font-size: 13px; color: var(--text2); border-bottom: 1px solid var(--line); }

/* fila de comerciantes */
#traders { display: flex; justify-content: center; gap: 10px; padding: 8px; flex: 0 0 auto; }
.trader { width: 96px; cursor: pointer; text-align: center; }
.trader .pic { position: relative; width: 96px; height: 96px; border: 1px solid var(--line2); background: #111 center/cover no-repeat; }
.trader .pic::after { content: ""; position: absolute; left: 0; top: 0; right: 0; bottom: 0; background: linear-gradient(transparent 60%, rgba(0,0,0,.7)); }
.trader .ll { position: absolute; right: 4px; bottom: 4px; height: 16px; z-index: 1; }
.trader .alert { position: absolute; left: 3px; top: 3px; width: 22px; z-index: 1; }
.trader .name { font-size: 12px; color: var(--text2); margin-top: 3px; text-transform: uppercase; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.trader:hover .pic { border-color: var(--text2); }
.trader.sel .pic { border: 2px solid var(--text); }
.trader.sel .name { color: var(--text); }
.trader.all .pic { display: flex; align-items: center; justify-content: center; font-size: 20px; color: var(--text); background: var(--bg2); }

#main { flex: 1 1 auto; display: flex; gap: 8px; min-height: 0; }

/* lista */
#list { width: 44%; display: flex; flex-direction: column; min-height: 0; }
#filters { display: flex; gap: 4px; padding: 6px; }
.btn { background: var(--bg2); border: 1px solid var(--line2); color: var(--text); padding: 6px 12px;
	text-transform: uppercase; letter-spacing: 1px; font-family: inherit; font-size: 13px; cursor: pointer; }
.btn:hover { background: var(--bg3); border-color: var(--text2); }
.btn.on { background: var(--text); color: var(--bg1); border-color: var(--text); }
.btn.go { background: var(--green); border-color: var(--greenHi); }
.btn.go:hover { background: var(--greenHi); }
.btn.bad { background: transparent; border-color: var(--red); color: var(--redHi); }
.btn.bad:hover { background: var(--red); color: var(--text); }
.btn[disabled] { opacity: .35; pointer-events: none; }
#filters .btn { flex: 1; padding: 6px 4px; }
.cols, .row { display: grid; grid-template-columns: 52px 1fr 90px 150px; align-items: center; gap: 8px; }
.cols { padding: 4px 8px; font-size: 11px; color: var(--dim); text-transform: uppercase; background: var(--bg2); }
.cols span:last-child, .row .st { text-align: right; }
#rows { flex: 1; overflow-y: auto; }
.row { padding: 5px 8px; border-bottom: 1px solid #222; cursor: pointer; background: rgba(20,20,20,.6); }
.row:hover { background: var(--bg2); }
.row.sel { background: #33332a; box-shadow: inset 3px 0 var(--text); }
.row img { width: 44px; height: 44px; object-fit: cover; border: 1px solid var(--line); }
.row .n { font-size: 16px; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.row .t { font-size: 11px; color: var(--dim); text-transform: uppercase; }
.row .k { font-size: 12px; color: var(--text2); text-transform: uppercase; }
.row .k.daily { color: var(--blue); }
.row .st { font-size: 12px; text-transform: uppercase; }
.row.done .n { color: var(--dim); text-decoration: line-through; }
.s-available { color: var(--text); } .s-active { color: var(--yellow); } .s-ready { color: var(--ok); }
.s-done, .s-cooldown { color: var(--dim); } .s-locked { color: var(--redHi); }
.empty { padding: 16px; color: var(--dim); }

/* ficha */
#detail { flex: 1; display: flex; flex-direction: column; min-height: 0; }
#dhead { display: flex; gap: 16px; padding: 14px; border-bottom: 1px solid var(--line); }
#dhead .pic { width: 150px; height: 150px; flex: 0 0 150px; position: relative; border: 1px solid var(--line2); background: #111 center/cover no-repeat; }
#dhead .pic img { position: absolute; right: 5px; bottom: 5px; height: 20px; }
#dhead h1 { font-size: 30px; font-weight: normal; text-transform: uppercase; letter-spacing: 1px; color: var(--text); line-height: 1.05; }
#dhead .who { font-size: 16px; color: var(--text2); text-transform: uppercase; margin-top: 4px; }
#dhead .meta { font-size: 13px; color: var(--dim); margin-top: 3px; }
.badge { display: inline-block; margin-top: 14px; padding: 4px 12px; border: 1px solid currentColor; text-transform: uppercase; font-size: 14px; letter-spacing: 1px; }
.reason { display: inline-block; margin-left: 10px; font-size: 13px; color: var(--text2); }
.reason.locked { color: var(--redHi); }
#dbody { flex: 1; overflow-y: auto; padding: 0 14px 10px; }
#dbody h2 { margin: 14px 0 8px; padding: 5px 10px; background: var(--bg2); border-left: 3px solid var(--green);
	font-size: 14px; font-weight: normal; letter-spacing: 1px; text-transform: uppercase; color: var(--text); }
.desc { color: var(--text2); line-height: 1.45; white-space: pre-wrap; padding: 0 4px; }
.obj { display: flex; gap: 10px; align-items: flex-start; padding: 6px 8px; }
.obj.cur { background: rgba(201,164,58,.07); }
.obj .box { width: 20px; height: 21px; flex: 0 0 20px; position: relative; background: center/contain no-repeat; }
.obj .box img { position: absolute; left: 3px; top: 4px; width: 14px; }
.obj .txt { flex: 1; color: var(--text2); line-height: 1.35; }
.obj.cur .txt { color: var(--text); } .obj.done .txt { color: var(--dim); }
.obj .sub { display: block; font-size: 13px; color: var(--yellow); }
.obj .pct { color: var(--yellow); font-size: 15px; }
.rew { display: flex; flex-wrap: wrap; gap: 6px; padding: 0 4px 6px; align-items: stretch; }
.rew .num { width: 22px; color: var(--greenHi); font-size: 22px; align-self: center; }
.cell { width: 118px; height: 80px; position: relative; background: var(--bg2); border: 1px solid var(--line);
	display: flex; flex-direction: column; align-items: center; justify-content: center; }
.cell img.icon { max-width: 100px; max-height: 50px; }
.cell .v { font-size: 18px; color: var(--text); }
.cell .l { position: absolute; bottom: 4px; left: 0; right: 0; text-align: center; font-size: 11px; color: var(--dim); text-transform: uppercase; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; padding: 0 4px; }
.cell .q { position: absolute; top: 3px; right: 5px; font-size: 13px; }
.cell .ll { position: absolute; top: 5px; right: 5px; height: 14px; }
#dfoot { display: flex; justify-content: flex-end; gap: 8px; padding: 10px 14px; border-top: 1px solid var(--line); min-height: 58px; align-items: center; }
#dfoot .note { margin-right: auto; color: var(--redHi); font-size: 13px; }
#dfoot .btn { width: 200px; padding: 10px; font-size: 15px; }
::-webkit-scrollbar { width: 6px; } ::-webkit-scrollbar-thumb { background: var(--line2); } ::-webkit-scrollbar-track { background: transparent; }
</style></head>
<body>
<div id="traders" class="panel"></div>
<div id="main">
	<div id="list" class="panel">
		<div id="filters"></div>
		<div class="cols"><span>Com.</span><span>Tarea</span><span>Tipo</span><span>Estado</span></div>
		<div id="rows"></div>
	</div>
	<div id="detail" class="panel"></div>
</div>
<script>
var D = {traders: [], tasks: [], inRaid: false, ui: ""};
var state = {trader: null, filter: "all", sel: null};
var STATUS = {available: "Disponible", active: "En curso", ready: "Lista para entregar", done: "Completada", cooldown: "En espera", locked: "Bloqueada"};
var ORDER = {ready: 1, active: 2, available: 3, locked: 4, cooldown: 5, done: 6};

function el(tag, cls, text) {
	var e = document.createElement(tag);
	if (cls) e.className = cls;
	if (text !== undefined && text !== null) e.textContent = text;
	return e;
}
function click() { if (window.efg) efg.click(); }
function act(a, id) { if (window.efg) efg.action(a, String(id)); }
function rub(n) { return String(Math.floor(n || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, " ") + " ₽"; }
function traderOf(key) { for (var i = 0; i < D.traders.length; i++) if (D.traders[i].key === key) return D.traders[i]; return null; }
function portrait(key) { return "asset://garrysmod/materials/efgui/traders/" + key + ".png"; }

function visible() {
	var out = D.tasks.filter(function (t) {
		if (state.trader && t.trader !== state.trader) return false;
		var s = t.status;
		if (state.filter === "active") return s === "active" || s === "ready";
		if (state.filter === "available") return s === "available";
		if (state.filter === "done") return s === "done" || s === "cooldown";
		return true;
	});
	out.sort(function (a, b) {
		var d = (ORDER[a.status] || 9) - (ORDER[b.status] || 9);
		if (d) return d;
		return String(a.name).localeCompare(String(b.name));
	});
	return out;
}

function drawTraders() {
	var box = document.getElementById("traders"); box.innerHTML = "";
	var all = el("div", "trader all" + (state.trader ? "" : " sel"));
	var ap = el("div", "pic", "TODOS"); all.appendChild(ap); all.appendChild(el("div", "name", "Comerciantes"));
	all.onclick = function () { click(); state.trader = null; state.sel = null; draw(); };
	box.appendChild(all);

	D.traders.forEach(function (t) {
		var c = el("div", "trader" + (state.trader === t.key ? " sel" : ""));
		var p = el("div", "pic"); p.style.backgroundImage = "url('" + t.portrait + "')";
		var ll = el("img", "ll"); ll.src = t.loyalty; p.appendChild(ll);
		if (D.tasks.some(function (x) { return x.trader === t.key && x.status === "ready"; })) {
			var a = el("img", "alert"); a.src = D.ui + "dialog_icons_askforquest.png"; p.appendChild(a);
		}
		c.appendChild(p); c.appendChild(el("div", "name", t.name));
		c.onclick = function () { click(); state.trader = t.key; state.sel = null; draw(); };
		box.appendChild(c);
	});
}

function drawList(list) {
	var f = document.getElementById("filters"); f.innerHTML = "";
	[["all", "Todas"], ["active", "En curso"], ["available", "Disponibles"], ["done", "Completadas"]].forEach(function (x) {
		var b = el("button", "btn" + (state.filter === x[0] ? " on" : ""), x[1]);
		b.onclick = function () { click(); state.filter = x[0]; state.sel = null; draw(); };
		f.appendChild(b);
	});

	var rows = document.getElementById("rows"); rows.innerHTML = "";
	if (!list.length) {
		rows.appendChild(el("div", "empty", D.tasks.length ? "No hay tareas con este filtro." :
			"Los comerciantes aún no tienen encargos. Un admin los crea con /MisionAdmin."));
		return;
	}
	list.forEach(function (t) {
		var r = el("div", "row" + (state.sel === t.id ? " sel" : "") + (t.status === "done" ? " done" : ""));
		var img = el("img"); img.src = portrait(t.trader); r.appendChild(img);
		var mid = el("div"); mid.appendChild(el("div", "n", t.name)); mid.appendChild(el("div", "t", t.traderName)); r.appendChild(mid);
		r.appendChild(el("div", "k" + (t.daily ? " daily" : ""), t.daily ? "Diaria" : (t.repeatMode === "once" ? "Historia" : "Repetible")));
		r.appendChild(el("div", "st s-" + t.status, STATUS[t.status] || t.status));
		r.onclick = function () { click(); state.sel = t.id; draw(); };
		rows.appendChild(r);
	});
}

function drawDetail(t) {
	var d = document.getElementById("detail"); d.innerHTML = "";
	if (!t) { d.appendChild(el("div", "empty", "Elige una tarea de la lista.")); return; }
	var tr = traderOf(t.trader);

	var head = el("div"); head.id = "dhead";
	var pic = el("div", "pic"); pic.style.backgroundImage = "url('" + portrait(t.trader) + "')";
	if (tr) { var ll = el("img"); ll.src = tr.loyalty; pic.appendChild(ll); }
	head.appendChild(pic);
	var info = el("div");
	info.appendChild(el("h1", null, t.name));
	info.appendChild(el("div", "who", t.traderName));
	if (tr) info.appendChild(el("div", "meta", "Lealtad " + tr.ll + "  ·  Reputación " + tr.rep));
	info.appendChild(el("span", "badge s-" + t.status, STATUS[t.status] || t.status));
	if (t.reason && t.status !== "available") info.appendChild(el("span", "reason" + (t.status === "locked" ? " locked" : ""), t.reason));
	head.appendChild(info);
	d.appendChild(head);

	var body = el("div"); body.id = "dbody";
	body.appendChild(el("h2", null, "Descripción"));
	body.appendChild(el("div", "desc", t.description || "El comerciante no ha dado más detalles."));

	body.appendChild(el("h2", null, "Objetivos"));
	(t.steps || []).forEach(function (s) {
		var o = el("div", "obj" + (s.current ? " cur" : "") + (s.done ? " done" : ""));
		var box = el("div", "box"); box.style.backgroundImage = "url('" + D.ui + "checkbox.png')";
		if (s.done) { var m = el("img"); m.src = D.ui + "checkmark.png"; box.appendChild(m); }
		o.appendChild(box);
		var txt = el("div", "txt", s.text);
		if (s.current && s.objective && s.objective !== s.text) txt.appendChild(el("span", "sub", s.objective));
		o.appendChild(txt);
		if (s.current && s.percent > 0) o.appendChild(el("div", "pct", s.percent + "%"));
		body.appendChild(o);
	});

	body.appendChild(el("h2", null, t.rewards.length > 1 ? "Recompensas (eliges una al entregar)" : "Recompensas"));
	if (!t.rewards.length) body.appendChild(el("div", "desc", "Sin recompensa."));
	t.rewards.forEach(function (r, i) {
		var row = el("div", "rew");
		if (t.rewards.length > 1) row.appendChild(el("div", "num", String(i + 1)));
		function cell(v, l) { var c = el("div", "cell"); c.appendChild(el("div", "v", v)); c.appendChild(el("div", "l", l)); row.appendChild(c); return c; }
		if (r.rubles > 0) cell(rub(r.rubles), "Rublos");
		if (r.xp > 0) cell("+" + r.xp, "Experiencia");
		if (r.rep > 0) { var c = cell("+" + r.rep, "Reputación " + t.traderName); if (tr) { var li = el("img", "ll"); li.src = tr.loyalty; c.appendChild(li); } }
		(r.items || []).forEach(function (it) {
			var c = el("div", "cell");
			if (it.icon) { var im = el("img", "icon"); im.src = it.icon; c.appendChild(im); } else c.appendChild(el("div", "v", "?"));
			if (it.qty > 1) c.appendChild(el("div", "q", "x" + it.qty));
			c.appendChild(el("div", "l", it.name));
			row.appendChild(c);
		});
		body.appendChild(row);
	});
	d.appendChild(body);

	var foot = el("div"); foot.id = "dfoot";
	if (D.inRaid) foot.appendChild(el("div", "note", "Durante la raid solo puedes consultar tus tareas."));
	function button(label, cls, action, confirmText) {
		var b = el("button", "btn " + cls, label);
		if (D.inRaid) b.disabled = true;
		b.onclick = function () {
			if (confirmText && b.dataset.armed !== "1") { b.dataset.armed = "1"; b.textContent = confirmText; click(); return; }
			act(action, t.id);
		};
		foot.appendChild(b);
	}
	if (t.status === "available") button("Aceptar", "go", "accept");
	if (t.status === "ready") button("Completar", "go", "turnin");
	if (t.status === "active" && (t.steps || []).some(function (s) { return s.current && s.deliver; })) button("Entregar objetos", "go", "deliver");
	if (t.status === "active" || t.status === "ready") button("Abandonar", "bad", "abandon", "¿Seguro? Pulsa otra vez");
	d.appendChild(foot);
}

function draw() {
	var list = visible();
	if (state.sel === null || !list.some(function (t) { return t.id === state.sel; })) state.sel = list.length ? list[0].id : null;
	drawTraders();
	drawList(list);
	var cur = null; D.tasks.forEach(function (t) { if (t.id === state.sel) cur = t; });
	drawDetail(cur);
}

function arr(x) { return Array.isArray(x) ? x : []; }
// util.TableToJSON deja las tablas vacías como {}: se normalizan a listas
function render(data) {
	D = data || {};
	D.traders = arr(D.traders);
	D.tasks = arr(D.tasks);
	D.tasks.forEach(function (t) {
		t.steps = arr(t.steps);
		t.rewards = arr(t.rewards);
		t.rewards.forEach(function (r) { r.items = arr(r.items); });
	});
	draw();
}
draw();
</script>
</body></html>
]==]
