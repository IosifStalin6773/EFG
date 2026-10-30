-- Página de la pantalla de comerciante (ver cl_eft.lua). Chromium 86: nada de
-- inset, aspect-ratio ni :is(); el arrastre va a mano con el ratón.

local PLUGIN = PLUGIN

PLUGIN.traderHTML = [==[
<!doctype html>
<html><head><meta charset="utf-8">
<style>
/*EFG_BASE*/
html, body { margin: 0; height: 100%; overflow: hidden; background: transparent; user-select: none; }
body { font-family: var(--efg-font); color: var(--efg-text); font-size: 12px; }
:root { --cell: 48px; }

#app { position: absolute; top: 0; left: 0; right: 0; bottom: 0; display: flex; flex-direction: column; }

/* ── cabecera ── */
#head { flex: 0 0 auto; display: flex; align-items: stretch; background: #000; border-bottom: 1px solid var(--efg-line); height: 74px; }
#head .pic { width: 74px; height: 74px; background: var(--efg-slot) center/cover no-repeat; border-right: 1px solid var(--efg-line); }
#head .who { padding: 10px 16px; display: flex; flex-direction: column; justify-content: center; min-width: 260px; }
#head .who .n { font-size: 24px; letter-spacing: 2px; text-transform: uppercase; color: #fff; }
#head .who .s { margin-top: 4px; display: flex; gap: 14px; color: var(--efg-text2); font-size: 12px; }
#head .ll { display: inline-block; min-width: 26px; padding: 0 6px; text-align: center; background: var(--efg-text); color: #000; font-weight: bold; }
#tabs { display: flex; align-items: stretch; margin-left: 20px; }
#tabs .t { display: flex; align-items: center; padding: 0 26px; font-size: 14px; letter-spacing: 2px; text-transform: uppercase; color: var(--efg-text2); cursor: pointer; border-left: 1px solid #1a1b18; }
#tabs .t:hover { color: #fff; background: #11120f; }
#tabs .t.on { color: #fff; background: linear-gradient(#2a2c27, #151613); box-shadow: inset 0 -2px 0 var(--efg-text); }
#head .sp { flex: 1; }
#head .money { display: flex; align-items: center; padding: 0 18px; font-size: 16px; color: #fff; }
#head .money span { margin-left: 6px; color: var(--efg-text2); font-size: 12px; }
#head .x { width: 56px; border: 0; background: none; color: var(--efg-text2); font: 20px var(--efg-font); cursor: pointer; }
#head .x:hover { background: var(--efg-red); color: #fff; }

#body { flex: 1; min-height: 0; position: relative; }
.view { position: absolute; top: 0; left: 0; right: 0; bottom: 0; display: none; }
.view.on { display: flex; }

/* ── diálogo ── */
#dialog { padding: 24px; gap: 24px; }
#portrait { flex: 0 0 38%; position: relative; background: #050505; border: 1px solid var(--efg-line); overflow: hidden; }
#portrait img, #portrait video { position: absolute; top: 0; left: 0; width: 100%; height: 100%; object-fit: cover; }
#portrait .fade { position: absolute; left: 0; right: 0; bottom: 0; height: 40%; background: linear-gradient(transparent, rgba(0,0,0,.9)); }
#portrait .cap { position: absolute; left: 18px; bottom: 14px; font-size: 30px; letter-spacing: 3px; text-transform: uppercase; color: #fff; }
#talk { flex: 1; display: flex; flex-direction: column; justify-content: flex-end; min-width: 0; }
#speech { padding: 18px 22px; background: rgba(10,11,9,.85); border: 1px solid var(--efg-line); border-left: 3px solid var(--efg-text); font-size: 18px; line-height: 1.45; color: #e8e6d6; min-height: 90px; cursor: pointer; }
#speech .who2 { display: block; margin-bottom: 6px; font-size: 12px; letter-spacing: 2px; text-transform: uppercase; color: var(--efg-text2); }
#options { margin-top: 12px; display: flex; flex-direction: column; gap: 4px; }
#options .o { padding: 10px 16px; background: rgba(10,11,9,.7); border: 1px solid #1f211d; font-size: 15px; color: var(--efg-text); cursor: pointer; }
#options .o b { display: inline-block; width: 26px; color: var(--efg-text2); font-weight: normal; }
#options .o:hover { background: #20221e; border-color: var(--efg-line2); color: #fff; }
#options.wait .o { opacity: .35; pointer-events: none; }

/* ── compra / venta ── */
.side { min-width: 0; display: flex; flex-direction: column; background: rgba(10,11,9,.75); border: 1px solid #0a0b09; box-shadow: 0 0 0 1px var(--efg-line); }
.side > .bd { flex: 1; min-height: 0; overflow-y: auto; overflow-x: hidden; padding: 8px; }
.hdr { flex: 0 0 auto; display: flex; align-items: center; gap: 8px; height: 26px; padding: 0 10px; background: #000; text-transform: uppercase; letter-spacing: 1.5px; font-size: 12px; color: var(--efg-text); }
.hdr .r { margin-left: auto; color: var(--efg-dim); letter-spacing: .5px; }
#buy, #sell { padding: 10px; gap: 10px; }
#buy .side, #sell .side { flex: 1; }
#cats { display: flex; flex-wrap: wrap; gap: 4px; padding: 6px 8px; background: rgba(0,0,0,.5); border-bottom: 1px solid #0a0b09; }
#cats .c { padding: 4px 10px; border: 1px solid var(--efg-line); color: var(--efg-text2); cursor: pointer; text-transform: uppercase; font-size: 11px; letter-spacing: 1px; }
#cats .c:hover { color: #fff; }
#cats .c.on { background: var(--efg-text); color: #000; border-color: var(--efg-text); }
.sect { margin-bottom: 10px; }
.sect > .hdr { height: 22px; font-size: 11px; margin-bottom: 4px; }
.grid { position: relative; display: grid; grid-template-columns: repeat(var(--gw), var(--cell)); grid-auto-rows: var(--cell);
	width: calc(var(--gw) * var(--cell)); min-height: var(--cell); background-color: var(--efg-slot);
	background-image: linear-gradient(to right, rgba(255,255,255,.07) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,.07) 1px, transparent 1px);
	background-size: var(--cell) var(--cell); border: 1px solid var(--efg-line); box-shadow: inset 0 0 14px rgba(0,0,0,.7); }
.msg { padding: 16px; color: var(--efg-dim); text-transform: uppercase; letter-spacing: 1px; text-align: center; }

.it { position: relative; box-sizing: border-box; margin: 0 1px 1px 0; border: 1px solid rgba(255,255,255,.12); background: rgba(60,62,58,.55); overflow: hidden; cursor: pointer; }
.it img { position: absolute; top: 3px; left: 3px; width: calc(100% - 6px); height: calc(100% - 6px); object-fit: contain; pointer-events: none; filter: drop-shadow(0 1px 1px #000); }
.it .n { position: absolute; top: 1px; right: 3px; left: 3px; text-align: right; font-size: 10px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-shadow: 0 1px 1px #000; pointer-events: none; }
.it .p { position: absolute; left: 2px; bottom: 2px; padding: 0 3px; font-size: 10px; background: rgba(0,0,0,.75); color: #e4d48a; pointer-events: none; }
.it .q { position: absolute; right: 3px; bottom: 1px; font-size: 10px; color: #fff; text-shadow: 0 1px 1px #000; pointer-events: none; }
.it.noicon .n { top: 40%; text-align: center; white-space: normal; }
.it:hover { border-color: var(--efg-text); box-shadow: 0 0 8px rgba(255,255,255,.18); z-index: 3; }
.it.sel { border-color: var(--efg-orange); box-shadow: inset 0 0 0 1px var(--efg-orange); }
.it.lock { filter: grayscale(1) brightness(.5); }
.it .lk { position: absolute; top: 50%; left: 0; right: 0; transform: translateY(-50%); text-align: center; font-size: 12px; color: #fff; pointer-events: none; text-shadow: 0 1px 2px #000; }
.it.no { opacity: .3; }
.it.queued { opacity: .25; }
.it.drag { opacity: .3; }
.c-weapon { background: rgba(38,44,48,.7); } .c-ammo { background: rgba(58,52,30,.6); } .c-mod { background: rgba(34,48,40,.6); }
.c-gear { background: rgba(44,46,40,.7); } .c-med { background: rgba(70,30,30,.55); } .c-food { background: rgba(40,56,40,.55); }

/* barra de trato */
.deal { flex: 0 0 auto; display: flex; align-items: center; gap: 14px; padding: 10px 12px; background: #000; border-top: 1px solid var(--efg-line); min-height: 64px; }
.deal .icon { width: 64px; height: 44px; background: var(--efg-slot) center/contain no-repeat; border: 1px solid var(--efg-line); }
.deal .info { flex: 1; min-width: 0; }
.deal .info .t { font-size: 15px; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.deal .info .d { color: var(--efg-text2); margin-top: 3px; }
.qty { display: flex; align-items: center; }
.qty button { width: 28px; height: 28px; border: 1px solid var(--efg-line); background: #151613; color: var(--efg-text); font: 16px var(--efg-font); cursor: pointer; }
.qty button:hover { color: #fff; border-color: var(--efg-line2); }
.qty input { width: 52px; height: 26px; text-align: center; background: var(--efg-slot); border: 1px solid var(--efg-line); color: #fff; font: 14px var(--efg-font); outline: none; }
.total { min-width: 150px; text-align: right; font-size: 18px; color: #fff; }
.total small { display: block; font-size: 10px; color: var(--efg-dim); letter-spacing: 1px; text-transform: uppercase; }
.dealbtn { height: 44px; padding: 0 28px; border: 1px solid #8a8e5a; background: linear-gradient(#a7ab72, #75794a); color: #0c0d0a; font: bold 16px var(--efg-font); letter-spacing: 2px; text-transform: uppercase; cursor: pointer; }
.dealbtn:hover { background: linear-gradient(#bfc386, #8a8e5a); }
.dealbtn[disabled] { opacity: .35; pointer-events: none; }

#toast { position: fixed; left: 50%; top: 86px; transform: translateX(-50%); padding: 10px 18px; background: rgba(8,9,7,.95); border: 1px solid var(--efg-line2); font-size: 14px; z-index: 70; display: none; }
#toast.ok { border-color: var(--efg-ok); color: #d9e8b8; } #toast.bad { border-color: var(--efg-red-hi); color: #f0c0b8; }
#tip { position: fixed; z-index: 60; display: none; max-width: 300px; padding: 8px 10px; background: rgba(8,9,7,.96); border: 1px solid var(--efg-line2); box-shadow: 0 6px 20px rgba(0,0,0,.8); pointer-events: none; }
#tip .t { font-size: 13px; color: #fff; margin-bottom: 4px; } #tip .k { color: var(--efg-text2); font-size: 11px; margin-bottom: 4px; } #tip .k b { color: var(--efg-text); font-weight: normal; }
#tip .d { color: var(--efg-dim); font-size: 11px; line-height: 1.35; }
#ghost { position: fixed; pointer-events: none; z-index: 50; display: none; opacity: .85; box-shadow: 0 0 0 1px var(--efg-orange), 0 6px 18px rgba(0,0,0,.8); }
.droptarget { box-shadow: inset 0 0 0 2px var(--efg-ok) !important; }
</style></head>
<body>
<div id="app">
	<div id="head">
		<div class="pic" id="hpic"></div>
		<div class="who"><div class="n" id="hname"></div><div class="s" id="hstats"></div></div>
		<div id="tabs"></div>
		<div class="sp"></div>
		<div class="money" id="hmoney"></div>
		<button class="x" onclick="efg.close()">✕</button>
	</div>
	<div id="body">
		<div class="view" id="dialog">
			<div id="portrait"></div>
			<div id="talk"><div id="speech"></div><div id="options"></div></div>
		</div>
		<div class="view" id="buy">
			<div class="side">
				<div class="hdr">Surtido <span class="r" id="stockCount"></span></div>
				<div id="cats"></div>
				<div class="bd" id="stock"></div>
				<div class="deal" id="buyDeal"></div>
			</div>
			<div class="side"><div class="hdr">Tus objetos</div><div class="bd" id="mineBuy"></div></div>
		</div>
		<div class="view" id="sell">
			<div class="side" id="sellSide">
				<div class="hdr">Mesa de venta <span class="r">arrastra o haz clic en tus objetos</span></div>
				<div class="bd" id="table"></div>
				<div class="deal" id="sellDeal"></div>
			</div>
			<div class="side"><div class="hdr">Tus objetos</div><div class="bd" id="mineSell"></div></div>
		</div>
	</div>
</div>
<div id="toast"></div><div id="tip"></div><div id="ghost"></div>

<script>
var S = null, tab = "dialog", cat = "all", sel = null, qty = 1, queue = [], mine = {}, stockBy = {};
var typing = null, lastSeq = -1, lastMsg = -1, drag = null, tipFor = null, tipTimer = null;
var $ = function (id) { return document.getElementById(id); };
var CATS = [["all", "Todo"], ["weapon", "Armas"], ["ammo", "Munición"], ["mod", "Accesorios"], ["gear", "Equipo"], ["med", "Medicina"], ["food", "Provisiones"], ["other", "Otros"]];

function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[c]; }); }
function fmt(n) { return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, " "); }
function cellPx() { return parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--cell")) || 48; }

function fitCell() {
	var w = $("stock").clientWidth || ($("body").clientWidth / 2 - 40);
	var c = Math.max(30, Math.min(64, Math.floor((w - 20) / 10)));
	document.documentElement.style.setProperty("--cell", c + "px");
}

/* objeto en rejilla: posición fija (x, y) o colocada por packGrid */
function itemEl(it, opts) {
	var d = document.createElement("div");
	d.className = "it c-" + (it.cat || "other") + (it.icon ? "" : " noicon");
	d.style.gridColumn = it.x + " / span " + it.w; d.style.gridRow = it.y + " / span " + it.h;
	d.innerHTML = (it.icon ? '<img src="' + esc(it.icon) + '" onerror="this.parentNode.classList.add(\'noicon\'); this.remove()">' : "") +
		'<div class="n">' + esc(it.short || it.name) + "</div>" + (opts.price ? '<div class="p">' + opts.price + "</div>" : "") +
		(opts.q ? '<div class="q">' + esc(opts.q) + "</div>" : "") + (opts.lock ? '<div class="lk">LL ' + esc(opts.lock) + "</div>" : "");
	return d;
}

/* coloca objetos sin posición en una rejilla de ancho w (primer hueco libre) */
function packGrid(list, w) {
	var used = [];
	function free(x, y, iw, ih) {
		if (x + iw - 1 > w) return false;
		for (var yy = y; yy < y + ih; yy++) for (var xx = x; xx < x + iw; xx++) if (used[yy] && used[yy][xx]) return false;
		return true;
	}
	list.forEach(function (it) {
		var iw = Math.min(it.w, w), ih = it.h;
		for (var y = 1; ; y++) {
			var done = false;
			for (var x = 1; x <= w; x++) {
				if (free(x, y, iw, ih)) {
					it.x = x; it.y = y; it.w = iw;
					for (var yy = y; yy < y + ih; yy++) { used[yy] = used[yy] || []; for (var xx = x; xx < x + iw; xx++) used[yy][xx] = true; }
					done = true; break;
				}
			}
			if (done) break;
		}
	});
	return Math.max(1, used.length - 1);
}

function gridBox(w, h) {
	var g = document.createElement("div"); g.className = "grid";
	g.style.setProperty("--gw", w); g.style.gridTemplateRows = "repeat(" + h + ", var(--cell))";
	return g;
}

function render(data) {
	S = data;
	if (data.tab && data.tab != tab) tab = data.tab;

	var pic = data.portrait && data.portrait.image;
	$("hpic").style.backgroundImage = pic ? 'url("' + pic + '")' : "none";
	$("hname").textContent = data.name;
	$("hstats").innerHTML = '<span><span class="ll">' + data.rep.ll + "</span></span><span>Reputación " + (data.rep.rep / 1000).toFixed(2) + "</span>" +
		(data.rep.discount ? "<span>Descuento " + data.rep.discount + "%</span>" : "");
	$("hmoney").innerHTML = fmt(data.money) + "<span>RUB</span>";

	var tabs = [["dialog", "Diálogo"], ["buy", "Comprar"], ["sell", "Vender"]];
	if (data.admin) tabs.push(["admin", "Admin"]);
	$("tabs").innerHTML = tabs.map(function (t) { return '<div class="t' + (t[0] == tab ? " on" : "") + '" data-tab="' + t[0] + '">' + t[1] + "</div>"; }).join("");

	["dialog", "buy", "sell"].forEach(function (v) { $(v).classList.toggle("on", v == tab); });

	renderDialog(data);
	if (tab == "buy") renderBuy(data);
	if (tab == "sell") renderSell(data);

	if (data.message && data.message.seq != lastMsg) {
		lastMsg = data.message.seq;
		var t = $("toast"); t.textContent = data.message.text; t.className = data.message.ok ? "ok" : "bad"; t.style.display = "block";
		clearTimeout(t._h); t._h = setTimeout(function () { t.style.display = "none"; }, 3500);
	}
}

/* ── diálogo ── */
function renderDialog(data) {
	var p = $("portrait");
	if (!p.dataset.key || p.dataset.key != data.key) {
		p.dataset.key = data.key;
		var media = data.portrait.video ? '<video src="' + esc(data.portrait.video) + '" autoplay loop muted></video>' :
			data.portrait.image ? '<img src="' + esc(data.portrait.image) + '">' : "";
		p.innerHTML = media + '<div class="fade"></div><div class="cap">' + esc(data.name) + "</div>";
	}

	var dv = data.dialog;
	if (!dv || dv.seq == lastSeq) return;
	lastSeq = dv.seq;

	var sp = $("speech"), full = dv.text || "", i = 0;
	clearInterval(typing);
	$("options").className = "wait";
	$("options").innerHTML = dv.options.map(function (o, k) { return '<div class="o" data-o="' + (k + 1) + '"><b>' + (k + 1) + ".</b>" + esc(o) + "</div>"; }).join("");

	function show(n) { sp.innerHTML = '<span class="who2">' + esc(data.name) + "</span>" + esc(full.substr(0, n)); }
	typing = setInterval(function () {
		i += 2; show(i);
		if (i >= full.length) { clearInterval(typing); typing = null; $("options").className = ""; }
	}, 22);
	sp.onclick = function () { if (typing) { clearInterval(typing); typing = null; show(full.length); $("options").className = ""; } };
}

/* ── compra ── */
function renderBuy(data) {
	fitCell();
	$("cats").innerHTML = CATS.map(function (c) { return '<div class="c' + (c[0] == cat ? " on" : "") + '" data-cat="' + c[0] + '">' + c[1] + "</div>"; }).join("");

	var box = $("stock"); box.innerHTML = ""; stockBy = {};
	if (!data.hasTrade) { box.innerHTML = '<div class="msg">Cargando el surtido…</div>'; renderBuyDeal(); renderMine($("mineBuy"), false); return; }

	var list = data.stock.filter(function (s) { return cat == "all" || s.cat == cat; }).map(function (s) {
		return {i: s.i, uid: s.uid, name: s.name, short: s.name, icon: s.icon, w: s.w, h: s.h, cat: s.cat, s: s};
	});
	list.sort(function (a, b) { return (b.w * b.h) - (a.w * a.h) || a.s.price - b.s.price; });
	$("stockCount").textContent = data.stock.length + " artículos";

	if (!list.length) { box.innerHTML = '<div class="msg">Nada en esta categoría</div>'; }
	else {
		var rows = packGrid(list, 10), g = gridBox(10, Math.max(rows, 6));
		list.forEach(function (it) {
			stockBy[it.i] = it.s;
			var d = itemEl(it, {price: fmt(it.s.price), q: it.s.qty > 1 ? "x" + it.s.qty : "", lock: it.s.locked ? it.s.ll : null});
			if (it.s.locked) d.classList.add("lock");
			if (sel == it.i) d.classList.add("sel");
			d.dataset.stock = it.i;
			g.appendChild(d);
		});
		box.appendChild(g);
	}

	if (sel && !stockByIndex(sel)) sel = null;
	renderBuyDeal();
	renderMine($("mineBuy"), false);
}

function stockByIndex(i) {
	for (var k = 0; k < (S.stock || []).length; k++) if (S.stock[k].i == i) return S.stock[k];
	return null;
}

function buyTotal(s, n) {
	/* el precio sube con cada unidad que sale del stock (igual que el servidor) */
	var t = 0, rem = s.qty;
	var base = s.price / Math.max(scar(s.qty, s), 0.0001);
	for (var k = 0; k < n; k++) { t += Math.max(1, Math.floor(base * scar(rem, s))); rem--; }
	return t;
}
function scar(q, s) { var m = s.maxQty || s.qty; return m > 0 ? 1 + (1 - Math.max(0, Math.min(1, q / m))) : 1; }

function renderBuyDeal() {
	var s = sel && stockByIndex(sel), el = $("buyDeal");
	if (!s) { el.innerHTML = '<div class="info"><div class="d">Elige un artículo del surtido</div></div>'; return; }
	qty = Math.max(1, Math.min(qty, s.qty, 255));
	var total = buyTotal(s, qty), afford = total <= S.money && !s.locked;
	el.innerHTML = '<div class="icon" style="background-image:url(\'' + esc(s.icon || "") + '\')"></div>' +
		'<div class="info"><div class="t">' + esc(s.name) + '</div><div class="d">' + fmt(s.price) + " RUB / ud · en stock " + s.qty +
		(s.used ? " · " + esc(s.used) : "") + (s.locked ? " · necesita lealtad " + s.ll : "") + "</div></div>" +
		'<div class="qty"><button data-q="-1">−</button><input id="qty" value="' + qty + '"><button data-q="1">+</button><button data-q="max">MÁX</button></div>' +
		'<div class="total"><small>Total</small>' + fmt(total) + " RUB</div>" +
		'<button class="dealbtn" id="buyBtn"' + (afford ? "" : " disabled") + ">Comprar</button>";
	$("qty").oninput = function () { qty = parseInt(this.value, 10) || 1; renderBuyDeal(); var q = $("qty"); q.focus(); q.setSelectionRange(q.value.length, q.value.length); };
}

/* ── tus objetos (compra: solo vista; venta: origen) ── */
function renderMine(box, selling) {
	box.innerHTML = ""; mine = {};
	var groups = (S.grids || []).filter(function (g) { return !g.empty; });
	if (S.stash) groups = groups.concat([S.stash]);

	groups.forEach(function (g) {
		var sec = document.createElement("div"); sec.className = "sect";
		sec.innerHTML = '<div class="hdr">' + esc(g.title) + (g.holder ? " · " + esc(g.holder.name) : "") + '<span class="r">' + g.w + "x" + g.h + "</span></div>";
		var grid = gridBox(g.w, g.h);
		g.items.forEach(function (it) {
			mine[it.id] = it;
			var d = itemEl(it, {price: selling && it.sell ? fmt(it.sell) : null, q: it.count});
			d.dataset.mine = it.id;
			if (selling && !it.sell) d.classList.add("no");
			if (selling && queue.indexOf(it.id) >= 0) d.classList.add("queued");
			grid.appendChild(d);
		});
		sec.appendChild(grid); box.appendChild(sec);
	});

	if (!S.stash && S.stashMsg) { var m = document.createElement("div"); m.className = "msg"; m.textContent = S.stashMsg; box.appendChild(m); }
}

/* ── venta ── */
function renderSell(data) {
	fitCell();
	if (!data.hasTrade) { $("table").innerHTML = '<div class="msg">Cargando…</div>'; $("sellDeal").innerHTML = ""; renderMine($("mineSell"), true); return; }

	renderMine($("mineSell"), true);
	queue = queue.filter(function (id) { return mine[id] && mine[id].sell; });

	var box = $("table"); box.innerHTML = "";
	var list = queue.map(function (id) { var it = mine[id]; return {id: id, name: it.name, short: it.short, icon: it.icon, w: it.w, h: it.h, cat: it.cat, it: it}; });
	var rows = packGrid(list, 10), g = gridBox(10, Math.max(rows, 6));
	list.forEach(function (e) {
		var d = itemEl(e, {price: fmt(e.it.sell), q: e.it.count});
		d.dataset.queued = e.id; g.appendChild(d);
	});
	box.appendChild(g);

	var total = 0; queue.forEach(function (id) { total += mine[id].sell; });
	$("sellDeal").innerHTML = '<div class="info"><div class="t">' + queue.length + " objeto" + (queue.length == 1 ? "" : "s") + '</div><div class="d">' +
		(queue.length ? "Clic en un objeto de la mesa para quitarlo" : "Los que este comerciante no compra salen apagados") + "</div></div>" +
		'<div class="total"><small>Recibes (aprox.)</small>' + fmt(total) + " RUB</div>" +
		'<button class="dealbtn" id="sellBtn"' + (queue.length ? "" : " disabled") + ">Vender</button>";
}

function toggleQueue(id) {
	var it = mine[id];
	if (!it || !it.sell) return;
	var k = queue.indexOf(id);
	if (k >= 0) queue.splice(k, 1); else queue.push(id);
	efg.click(); renderSell(S);
}

/* ── ratón ── */
document.addEventListener("click", function (ev) {
	var t = ev.target;
	var tb = t.closest("[data-tab]");
	if (tb) {
		var id = tb.dataset.tab; efg.click();
		if (id == "admin") { efg.admin(); return; }
		tab = id; S.tab = id; efg.tab(id); render(S); return;
	}
	var c = t.closest("[data-cat]"); if (c) { cat = c.dataset.cat; efg.click(); renderBuy(S); return; }
	var o = t.closest("[data-o]"); if (o) { efg.click(); efg.option(+o.dataset.o); return; }
	var q = t.closest("[data-q]");
	if (q && sel) { var s = stockByIndex(sel); qty = q.dataset.q == "max" ? Math.min(s.qty, Math.floor(S.money / Math.max(1, s.price)) || 1) : qty + (+q.dataset.q); renderBuyDeal(); return; }
	if (t.id == "buyBtn") { efg.buy(sel, qty); return; }
	if (t.id == "sellBtn") { efg.sell(queue.slice()); queue = []; return; }
});

document.addEventListener("mousedown", function (ev) {
	hideTip();
	var st = ev.target.closest("[data-stock]");
	if (st && ev.button == 0) { sel = +st.dataset.stock; qty = 1; efg.click(); renderBuy(S); return; }
	var qd = ev.target.closest("[data-queued]");
	if (qd && ev.button == 0) { toggleQueue(+qd.dataset.queued); return; }
	var m = ev.target.closest("[data-mine]");
	if (!m) return;
	if (ev.button == 2) { efg.inspect(+m.dataset.mine); return; }
	if (tab != "sell" || ev.button != 0) return;
	var r = m.getBoundingClientRect();
	drag = {el: m, id: +m.dataset.mine, sx: ev.clientX, sy: ev.clientY, ox: ev.clientX - r.left, oy: ev.clientY - r.top, on: false};
	ev.preventDefault();
});

document.addEventListener("mousemove", function (ev) {
	if (!drag) { moveTip(ev); return; }
	if (!drag.on) {
		if (Math.abs(ev.clientX - drag.sx) + Math.abs(ev.clientY - drag.sy) < 5) return;
		drag.on = true;
		var g = $("ghost"); g.innerHTML = ""; var cl = drag.el.cloneNode(true);
		cl.style.width = drag.el.offsetWidth + "px"; cl.style.height = drag.el.offsetHeight + "px"; g.appendChild(cl);
		g.style.display = "block"; drag.el.classList.add("drag");
	}
	var gh = $("ghost"); gh.style.left = (ev.clientX - drag.ox) + "px"; gh.style.top = (ev.clientY - drag.oy) + "px";
	var over = document.elementFromPoint(ev.clientX, ev.clientY);
	$("sellSide").classList.toggle("droptarget", !!(over && over.closest("#sellSide")));
});

document.addEventListener("mouseup", function (ev) {
	if (!drag) return;
	var d = drag; drag = null;
	$("ghost").style.display = "none"; d.el.classList.remove("drag"); $("sellSide").classList.remove("droptarget");
	if (!d.on) { toggleQueue(d.id); return; }
	var over = document.elementFromPoint(ev.clientX, ev.clientY);
	if (over && over.closest("#sellSide") && queue.indexOf(d.id) < 0) toggleQueue(d.id);
});

document.addEventListener("contextmenu", function (ev) { ev.preventDefault(); });
document.addEventListener("keydown", function (ev) {
	if (ev.keyCode == 27) { ev.preventDefault(); efg.close(); return; }
	if (tab == "dialog" && ev.keyCode >= 49 && ev.keyCode <= 57 && $("options").className != "wait") efg.option(ev.keyCode - 48);
});

/* ── tooltip ── */
function hideTip() { clearTimeout(tipTimer); tipFor = null; $("tip").style.display = "none"; }
function moveTip(ev) {
	var el = ev.target.closest && ev.target.closest(".it"), tip = $("tip");
	if (!el) { hideTip(); return; }
	var key = el.dataset.stock ? "s" + el.dataset.stock : "m" + (el.dataset.mine || el.dataset.queued);
	if (key != tipFor) {
		hideTip(); tipFor = key;
		tipTimer = setTimeout(function () {
			var s = el.dataset.stock && stockByIndex(+el.dataset.stock), it = s || mine[+(el.dataset.mine || el.dataset.queued)];
			if (!it) return;
			var price = s ? "Precio <b>" + fmt(s.price) + " RUB</b>" : (it.sell ? "Te pagan <b>" + fmt(it.sell) + " RUB</b>" : "No lo compra");
			tip.innerHTML = '<div class="t">' + esc(it.name) + '</div><div class="k">' + price + " · Peso <b>" + (+it.weight || 0).toFixed(2) + " kg</b></div>" +
				(it.desc ? '<div class="d">' + esc(it.desc) + "</div>" : "");
			tip.style.display = "block";
		}, 250);
	}
	var x = ev.clientX + 16, y = ev.clientY + 16;
	if (x + tip.offsetWidth > innerWidth - 4) x = ev.clientX - tip.offsetWidth - 12;
	if (y + tip.offsetHeight > innerHeight - 4) y = ev.clientY - tip.offsetHeight - 12;
	tip.style.left = x + "px"; tip.style.top = y + "px";
}

window.addEventListener("resize", function () { if (S) render(S); });
</script>
</body></html>
]==]
