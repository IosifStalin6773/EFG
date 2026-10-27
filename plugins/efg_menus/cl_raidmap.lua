-- Mapa de la selección de raid (DHTML): plano topográfico oscuro con
-- cuadrícula, nodos de las ubicaciones con hover y selección, líneas de
-- conexión entre ellas. Lua llama a render(json) y la página devuelve el
-- clic con efg.select(id). Usa el CSS base de efg_ui (/*EFG_BASE*/).

local PLUGIN = PLUGIN

PLUGIN.raidMapHTML = [==[
<!doctype html>
<html><head><meta charset="utf-8">
<style>
/*EFG_BASE*/
#map { position: absolute; left: 0; top: 0; right: 0; bottom: 0; overflow: hidden;
	background: #121411 url("asset://garrysmod/materials/efg/menu/topo_map.png") center/cover no-repeat;
	border: 1px solid #0a0b09; box-shadow: inset 0 0 0 1px var(--efg-line); }
/* cuadrícula: menor cada 4 %, mayor cada 20 %, con coordenadas */
#map::before { content: ""; position: absolute; left: 0; top: 0; right: 0; bottom: 0; pointer-events: none;
	background-image:
		linear-gradient(rgba(200,198,180,.10) 1px, transparent 1px),
		linear-gradient(90deg, rgba(200,198,180,.10) 1px, transparent 1px),
		linear-gradient(rgba(200,198,180,.035) 1px, transparent 1px),
		linear-gradient(90deg, rgba(200,198,180,.035) 1px, transparent 1px);
	background-size: 20% 20%, 20% 20%, 4% 4%, 4% 4%; }
/* viñeta */
#map::after { content: ""; position: absolute; left: 0; top: 0; right: 0; bottom: 0; pointer-events: none;
	background: radial-gradient(ellipse at center, transparent 45%, rgba(0,0,0,.75) 100%); }
.coord { position: absolute; font-family: var(--efg-font-type); font-size: 10px; color: rgba(200,198,180,.35); pointer-events: none; z-index: 1; }

svg#links { position: absolute; left: 0; top: 0; width: 100%; height: 100%; pointer-events: none; z-index: 1; }
svg#links line { stroke: rgba(200,198,180,.18); stroke-width: 1; stroke-dasharray: 4 4; }

.node { position: absolute; transform: translate(-50%, -50%); z-index: 2; cursor: pointer; }
.node .dot { width: 14px; height: 14px; margin: 0 auto; background: var(--efg-text); transform: rotate(45deg);
	box-shadow: 0 0 0 2px rgba(0,0,0,.8), 0 0 10px rgba(200,198,180,.25); transition: transform .12s; }
.node .ring { position: absolute; left: 50%; top: 7px; width: 34px; height: 34px; margin: -17px 0 0 -17px;
	border: 1px solid transparent; transform: rotate(45deg); transition: all .15s; }
.node .lbl { position: absolute; left: 50%; top: 20px; transform: translateX(-50%); white-space: nowrap;
	padding: 2px 8px; background: rgba(0,0,0,.75); border: 1px solid rgba(255,255,255,.06);
	font-family: var(--efg-font-stencil); font-size: 14px; letter-spacing: 1.5px; text-transform: uppercase; color: var(--efg-text); }
.node .sub { display: block; font-family: var(--efg-font-type); font-size: 10px; letter-spacing: 0; text-transform: none; color: var(--efg-dim); text-align: center; }
.node:hover .dot { transform: rotate(45deg) scale(1.3); }
.node:hover .ring { border-color: rgba(200,198,180,.45); }
.node:hover .lbl { color: #fff; border-color: rgba(200,198,180,.3); }
.node.off .dot { background: var(--efg-dim); box-shadow: 0 0 0 2px rgba(0,0,0,.8); }
.node.off .lbl { color: var(--efg-dim); }
.node.sel .dot { background: var(--efg-orange); box-shadow: 0 0 0 2px rgba(0,0,0,.8), 0 0 16px rgba(227,114,45,.8); }
.node.sel .ring { border-color: var(--efg-orange); animation: pulse 1.6s infinite; }
.node.sel .lbl { color: var(--efg-orange); border-color: var(--efg-orange); background: rgba(20,10,4,.85); }
@keyframes pulse { 0% { opacity: 1; width: 34px; height: 34px; margin: -17px 0 0 -17px; }
	100% { opacity: 0; width: 64px; height: 64px; margin: -32px 0 0 -32px; } }

#legend { position: absolute; left: 10px; bottom: 10px; z-index: 3; padding: 6px 10px; background: rgba(0,0,0,.7);
	border: 1px solid rgba(255,255,255,.06); font-family: var(--efg-font-type); font-size: 11px; color: var(--efg-text2); }
#legend i { display: inline-block; width: 8px; height: 8px; margin: 0 6px 0 12px; transform: rotate(45deg); }
#legend i:first-child { margin-left: 0; }
#title { position: absolute; left: 0; top: 0; z-index: 3; height: 26px; padding: 0 14px; display: flex; align-items: center;
	background: #000; font-family: var(--efg-font-stencil); font-size: 13px; letter-spacing: 2px; color: var(--efg-text); }
</style></head>
<body>
<div id="map">
	<div id="title">REGIÓN DE NORVINSK · TARKOV</div>
	<svg id="links"></svg>
	<div id="nodes"></div>
	<div id="legend"><i style="background:#e3722d"></i>Seleccionada<i style="background:#c8c6b4"></i>Disponible<i style="background:#686a5e"></i>Próximamente</div>
</div>
<script>
var D = {locations: [], selected: null};

function click() { if (window.efg) efg.click(); }

function draw() {
	var box = document.getElementById("nodes"), svg = document.getElementById("links");
	box.innerHTML = ""; svg.innerHTML = "";
	var map = document.getElementById("map"), W = map.clientWidth, H = map.clientHeight;

	// coordenadas de la cuadrícula mayor
	for (var i = 1; i < 5; i++) {
		var cx = document.createElement("div"); cx.className = "coord"; cx.textContent = String.fromCharCode(64 + i);
		cx.style.left = (i * 20 - 10) + "%"; cx.style.top = "30px"; box.appendChild(cx);
		var cy = document.createElement("div"); cy.className = "coord"; cy.textContent = String(i);
		cy.style.left = "4px"; cy.style.top = (i * 20 - 10) + "%"; box.appendChild(cy);
	}

	var byId = {};
	D.locations.forEach(function (l) { byId[l.id] = l; });
	D.locations.forEach(function (l) {
		(l.links || []).forEach(function (to) {
			var t = byId[to]; if (!t) return;
			var ln = document.createElementNS("http://www.w3.org/2000/svg", "line");
			ln.setAttribute("x1", l.x * W); ln.setAttribute("y1", l.y * H);
			ln.setAttribute("x2", t.x * W); ln.setAttribute("y2", t.y * H);
			svg.appendChild(ln);
		});
	});

	D.locations.forEach(function (l) {
		var n = document.createElement("div");
		n.className = "node" + (l.available ? "" : " off") + (D.selected === l.id ? " sel" : "");
		n.style.left = (l.x * 100) + "%"; n.style.top = (l.y * 100) + "%";
		n.innerHTML = '<div class="ring"></div><div class="dot"></div><div class="lbl"><span class="n"></span><span class="sub"></span></div>';
		n.querySelector(".n").textContent = l.name;
		n.querySelector(".sub").textContent = l.available ? (l.players || "") : "Próximamente";
		n.onmouseenter = function () { if (window.efg) efg.hover(l.id); };
		n.onclick = function () { click(); D.selected = l.id; draw(); if (window.efg) efg.select(l.id); };
		box.appendChild(n);
	});
}

function arr(x) { return Array.isArray(x) ? x : []; }
function render(data) {
	D = data || {}; D.locations = arr(D.locations);
	D.locations.forEach(function (l) { l.links = arr(l.links); });
	draw();
}
window.onresize = draw;
</script>
</body></html>
]==]
