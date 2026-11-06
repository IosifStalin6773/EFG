-- Editor visual del grafo por NPC (fase 2). Pestaña GRAFO del TAB, solo admin.
-- Lienzo DHTML con nodos arrastrables (mousedown/mousemove/mouseup) y panel
-- de campos. Guardar envía el grafo al servidor, que lo valida y compila.

ix.flujo = ix.flujo or {}
ix.flujo.clientGraphs = ix.flujo.clientGraphs or {}

net.Receive("flujo_Data", function()
	ix.flujo.clientGraphs = net.ReadTable() or {}

	if (IsValid(ix.gui.flujoEditor)) then
		ix.gui.flujoEditor:Push()
	end
end)

function ix.flujo.Request()
	net.Start("flujo_Request")
	net.SendToServer()
end

ix.flujo.editorHTML = [==[
<!doctype html>
<html><head><meta charset="utf-8">
<style>
/*EFG_BASE*/
body { display: flex; flex-direction: column; gap: 6px; padding: 6px; }
#bar { display: flex; gap: 6px; flex-wrap: wrap; align-items: center; }
.btn { padding: 4px 10px; cursor: pointer; background: var(--efg-bg2); color: var(--efg-text); border: 1px solid var(--efg-line); font-family: var(--efg-font); }
.btn.on { border-color: var(--efg-orange); color: var(--efg-orange); }
.btn.go { background: #2b3a1f; }
#main { display: flex; gap: 8px; min-height: 420px; }
#canvas { position: relative; flex: 1; min-height: 420px; background: #121411; border: 1px solid var(--efg-line); overflow: hidden; }
#canvas svg { position: absolute; left: 0; top: 0; width: 100%; height: 100%; pointer-events: none; }
.node { position: absolute; width: 160px; background: var(--efg-bg2); border: 1px solid var(--efg-line2); cursor: move; user-select: none; }
.node.sel { border-color: var(--efg-orange); }
.node .hd { background: var(--efg-bg3); color: var(--efg-orange); padding: 4px 6px; font-size: 12px; text-transform: uppercase; }
.node .bd { padding: 6px; font-size: 12px; color: var(--efg-text2); min-height: 34px; word-break: break-word; }
#form { width: 340px; background: var(--efg-bg1); border: 1px solid var(--efg-line); padding: 8px; overflow-y: auto; }
#form label { display: block; margin-top: 6px; font-size: 12px; color: var(--efg-dim); }
#form input, #form select, #form textarea { width: 100%; box-sizing: border-box; background: #0b0c0a; color: var(--efg-text); border: 1px solid var(--efg-line); padding: 4px; font-family: var(--efg-font); }
#form textarea { min-height: 60px; }
.step { border-top: 1px solid var(--efg-line); margin-top: 6px; padding-top: 4px; }
#status { font-size: 12px; color: var(--efg-yellow); min-height: 16px; }
</style>
</head><body>
<div id="bar"></div>
<div id="main">
  <div id="canvas"></div>
  <div id="form"></div>
</div>
<div id="status"></div>
<script>
var D = {traders: [], graphs: []};
var ORDER = [["a", "inicio", "Inicio"], ["b", "dialogo", "Diálogo"], ["c", "mision", "Misión"], ["d", "recompensa", "Recompensa"], ["e", "fin", "Fin"]];
var GROUPS = [["scav", "Scav"], ["pmc", "PMC"], ["usec", "USEC"], ["bear", "BEAR"], ["boss", "Jefe"]];
var G = null, sel = null, drag = null;

function arr(x) { return Array.isArray(x) ? x : []; }
function num(v) { var n = parseInt(v, 10); return isNaN(n) ? 0 : n; }
function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; }
function status(t) { document.getElementById("status").textContent = t || ""; }

function blank(key) {
	var g = {id: "g_" + key, traderKey: key, nodes: {}, edges: []};
	var data = {inicio: {}, dialogo: {text: ""}, mision: {name: "", description: "", steps: [{type: "kill", npcGroup: "scav", count: 3}]}, recompensa: {rublos: 0, rep: 0}, fin: {}};
	ORDER.forEach(function (o, i) { g.nodes[o[0]] = {type: o[1], data: data[o[1]], x: 30 + i * 190, y: 70}; });
	for (var i = 0; i < ORDER.length - 1; i++) g.edges.push({from: ORDER[i][0], to: ORDER[i + 1][0]});
	return g;
}

function findGraph(key) {
	var found = null;
	arr(D.graphs).forEach(function (g) { if (g.traderKey === key) found = g; });
	if (!found) return blank(key);
	var c = JSON.parse(JSON.stringify(found));
	ORDER.forEach(function (o, i) {
		var n = c.nodes[o[0]];
		if (!n) { c.nodes[o[0]] = {type: o[1], data: {}, x: 30 + i * 190, y: 70}; n = c.nodes[o[0]]; }
		n.x = n.x || 30 + i * 190; n.y = n.y || 70; n.data = n.data || {};
	});
	c.edges = arr(c.edges);
	return c;
}

function traderName(key) {
	var out = key;
	arr(D.traders).forEach(function (t) { if (t.key === key) out = t.name; });
	return out;
}

function summary(n) {
	var d = n.data || {};
	if (n.type === "inicio") return traderName(G.traderKey);
	if (n.type === "dialogo") return d.text || "(sin texto)";
	if (n.type === "mision") return (d.name || "(sin nombre)") + " · " + arr(d.steps).length + " objetivo(s)";
	if (n.type === "recompensa") return (d.rublos || 0) + " RUB · rep " + (d.rep || 0);
	return "Fin";
}

function drawBar() {
	var bar = document.getElementById("bar"); bar.innerHTML = "";
	arr(D.traders).forEach(function (t) {
		var b = el("button", "btn" + (G.traderKey === t.key ? " on" : ""), t.name);
		b.onclick = function () { G = findGraph(t.key); sel = null; draw(); };
		bar.appendChild(b);
	});
	var save = el("button", "btn go", "GUARDAR");
	save.onclick = function () {
		status("Guardando...");
		efg.save(JSON.stringify(G));
	};
	bar.appendChild(save);
}

function drawEdges() {
	var canvas = document.getElementById("canvas");
	var old = canvas.querySelector("svg"); if (old) canvas.removeChild(old);
	var NS = "http://www.w3.org/2000/svg";
	var svg = document.createElementNS(NS, "svg");
	G.edges.forEach(function (e) {
		var a = G.nodes[e.from], b = G.nodes[e.to];
		if (!a || !b) return;
		var line = document.createElementNS(NS, "line");
		line.setAttribute("x1", a.x + 160); line.setAttribute("y1", a.y + 30);
		line.setAttribute("x2", b.x); line.setAttribute("y2", b.y + 30);
		line.setAttribute("stroke", "#e3722d"); line.setAttribute("stroke-width", "2");
		svg.appendChild(line);
	});
	canvas.insertBefore(svg, canvas.firstChild);
}

function drawCanvas() {
	var canvas = document.getElementById("canvas"); canvas.innerHTML = "";
	ORDER.forEach(function (o) {
		var n = G.nodes[o[0]];
		var box = el("div", "node" + (sel === o[0] ? " sel" : ""));
		box.id = "n_" + o[0];
		box.style.left = n.x + "px"; box.style.top = n.y + "px";
		box.appendChild(el("div", "hd", o[2]));
		box.appendChild(el("div", "bd", summary(n)));
		box.onmousedown = function (e) {
			sel = o[0];
			var c = canvas.getBoundingClientRect();
			drag = {key: o[0], dx: e.clientX - c.left - n.x, dy: e.clientY - c.top - n.y};
			drawForm(); drawCanvasSel();
		};
		canvas.appendChild(box);
	});
	drawEdges();
}

function drawCanvasSel() {
	ORDER.forEach(function (o) {
		var b = document.getElementById("n_" + o[0]);
		if (b) b.className = "node" + (sel === o[0] ? " sel" : "");
	});
}

function drawForm() {
	var f = document.getElementById("form"); f.innerHTML = "";
	if (!sel) { f.appendChild(el("div", "bd", "Selecciona un nodo para editarlo.")); return; }
	var n = G.nodes[sel], d = n.data;

	if (n.type === "inicio") {
		f.appendChild(el("label", null, "Comerciante"));
		var s = el("select");
		arr(D.traders).forEach(function (t) {
			var o = el("option", null, t.name); o.value = t.key; if (t.key === G.traderKey) o.selected = true; s.appendChild(o);
		});
		s.onchange = function () { G = findGraph(s.value); sel = "a"; draw(); };
		f.appendChild(s);
	}

	if (n.type === "dialogo") {
		f.appendChild(el("label", null, "Texto del NPC"));
		var t = el("textarea"); t.value = d.text || "";
		t.oninput = function () { d.text = t.value; drawCanvas(); drawCanvasSel(); };
		f.appendChild(t);
	}

	if (n.type === "mision") {
		f.appendChild(el("label", null, "Nombre de la misión"));
		var nm = el("input"); nm.value = d.name || "";
		nm.oninput = function () { d.name = nm.value; drawCanvas(); drawCanvasSel(); };
		f.appendChild(nm);
		f.appendChild(el("label", null, "Descripción"));
		var ds = el("textarea"); ds.value = d.description || "";
		ds.oninput = function () { d.description = ds.value; };
		f.appendChild(ds);

		d.steps = arr(d.steps);
		d.steps.forEach(function (st, i) {
			var box = el("div", "step");
			box.appendChild(el("label", null, "Objetivo " + (i + 1)));
			var ty = el("select");
			[["kill", "Eliminación"], ["deliver", "Entrega FIR"]].forEach(function (x) {
				var o = el("option", null, x[1]); o.value = x[0]; if (st.type === x[0]) o.selected = true; ty.appendChild(o);
			});
			ty.onchange = function () { st.type = ty.value; if (st.type === "kill") { st.npcGroup = st.npcGroup || "scav"; delete st.itemID; } else { st.itemID = st.itemID || ""; delete st.npcGroup; } draw(); };
			box.appendChild(ty);
			if (st.type === "kill") {
				var gs = el("select");
				GROUPS.forEach(function (g) {
					var o = el("option", null, g[1]); o.value = g[0]; if (st.npcGroup === g[0]) o.selected = true; gs.appendChild(o);
				});
				gs.onchange = function () { st.npcGroup = gs.value; };
				box.appendChild(gs);
			} else {
				var it = el("input"); it.placeholder = "id del objeto (p. ej. salewa)"; it.value = st.itemID || "";
				it.oninput = function () { st.itemID = it.value; };
				box.appendChild(it);
			}
			var cnt = el("input"); cnt.type = "number"; cnt.min = 1; cnt.value = st.count || 1;
			cnt.oninput = function () { st.count = num(cnt.value); };
			box.appendChild(cnt);
			if (d.steps.length > 1) {
				var rm = el("button", "btn", "Quitar");
				rm.onclick = function () { d.steps.splice(i, 1); draw(); };
				box.appendChild(rm);
			}
			f.appendChild(box);
		});
		var add = el("button", "btn", "+ Objetivo");
		add.onclick = function () { d.steps.push({type: "kill", npcGroup: "scav", count: 1}); draw(); };
		f.appendChild(add);
	}

	if (n.type === "recompensa") {
		f.appendChild(el("label", null, "Rublos (RUB)"));
		var ru = el("input"); ru.type = "number"; ru.min = 0; ru.value = d.rublos || 0;
		ru.oninput = function () { d.rublos = num(ru.value); drawCanvas(); drawCanvasSel(); };
		f.appendChild(ru);
		f.appendChild(el("label", null, "Reputación"));
		var rp = el("input"); rp.type = "number"; rp.min = 0; rp.value = d.rep || 0;
		rp.oninput = function () { d.rep = num(rp.value); drawCanvas(); drawCanvasSel(); };
		f.appendChild(rp);
	}

	if (n.type === "fin") f.appendChild(el("div", "bd", "Fin del camino."));
}

function draw() {
	if (!G) return;
	drawBar(); drawCanvas(); drawForm();
}

// Arrastre a mano: HTML5 drag and drop no es fiable en Chromium 86.
document.onmousemove = function (e) {
	if (!drag) return;
	var c = document.getElementById("canvas").getBoundingClientRect();
	var n = G.nodes[drag.key];
	n.x = Math.max(0, e.clientX - c.left - drag.dx);
	n.y = Math.max(0, e.clientY - c.top - drag.dy);
	var b = document.getElementById("n_" + drag.key);
	if (b) { b.style.left = n.x + "px"; b.style.top = n.y + "px"; }
	drawEdges();
};
document.onmouseup = function () { drag = null; };

function render(data) {
	D = data || {};
	D.traders = arr(D.traders);
	D.graphs = arr(D.graphs);
	if (!G) G = findGraph(D.traders.length ? D.traders[0].key : "");
	draw();
}
</script>
</body></html>
]==]

local PANEL = {}

function PANEL:Init()
	ix.gui.flujoEditor = self

	self.html = self:Add("DHTML")
	self.html:Dock(FILL)
	self.html:SetAllowLua(false)

	self.html:AddFunction("efg", "save", function(json)
		if (!isstring(json)) then return end

		local graph = util.JSONToTable(json)
		if (!istable(graph)) then return end

		net.Start("flujo_Save")
			net.WriteTable(graph)
		net.SendToServer()
	end)

	self.html.OnDocumentReady = function()
		self.ready = true
		self:Push()
	end

	self.html:SetHTML(ix.efgui.InjectCSS(ix.flujo.editorHTML))

	ix.flujo.Request()
end

function PANEL:Push()
	if (!self.ready or !IsValid(self.html)) then return end

	local traders = {}
	for _, key in ipairs(ix.traders and ix.traders.factions or {}) do
		traders[#traders + 1] = {key = key, name = ix.traders.names and ix.traders.names[key] or key}
	end

	self.html:RunJavascript("render(" .. util.TableToJSON({traders = traders, graphs = ix.flujo.clientGraphs}) .. ")")
end

function PANEL:OnRemove()
	if (ix.gui.flujoEditor == self) then ix.gui.flujoEditor = nil end
end

vgui.Register("efgxFlujoEditor", PANEL, "DPanel")
