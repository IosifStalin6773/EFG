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
.btn + .btn { margin-left: 0; }
.step { border-top: 1px solid var(--efg-line); margin-top: 6px; padding-top: 4px; }
.port { position: absolute; right: -6px; width: 10px; height: 10px; border-radius: 5px; background: var(--efg-orange); cursor: crosshair; }
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
var TYPES = [["dialogo", "Diálogo"], ["respuesta", "Respuesta"], ["requisito", "Requisito"], ["mision", "Misión"], ["recompensa", "Recompensa"], ["fin", "Fin"]];
var NAMES = {inicio: "Inicio", dialogo: "Diálogo", respuesta: "Respuesta", requisito: "Requisito", mision: "Misión", recompensa: "Recompensa", fin: "Fin"};
var REQ_KINDS = [["level", "Nivel PMC"], ["loyalty", "Lealtad (LL)"], ["rep", "Reputación"], ["mission", "Misión previa"], ["item", "Objeto en inventario"]];
var GROUPS = [["scav", "Scav"], ["pmc", "PMC"], ["usec", "USEC"], ["bear", "BEAR"], ["boss", "Jefe"]];
var MAX_OPTIONS = 4, MAX_NODES = 64;
var G = null, sel = null, drag = null, link = null, seq = 0;

// Salidas de un nodo: cada una es un conector que se arrastra con el botón izquierdo.
function portsOf(id) {
	var n = G.nodes[id];
	if (!n || n.type === "fin") return [];
	if (n.type === "respuesta") return arr(n.data.options).map(function (o, i) { return {label: i + 1}; });
	if (n.type === "requisito") return [{label: "si"}, {label: "no"}];
	return [{label: undefined}];
}

function portY(id, label) {
	var ports = portsOf(id);
	for (var i = 0; i < ports.length; i++) {
		if (ports[i].label === label) return 38 + i * 18;
	}
	return 38;
}

function arr(x) { return Array.isArray(x) ? x : []; }
function num(v) { var n = parseInt(v, 10); return isNaN(n) ? 0 : n; }
function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; }
function status(t) { document.getElementById("status").textContent = t || ""; }
function newId(prefix) { seq = seq + 1; return prefix + Date.now().toString(36) + seq; }

function blank(key) {
	var g = {id: "g_" + key, traderKey: key, nodes: {}, edges: []};
	g.nodes.a = {type: "inicio", data: {}, x: 30, y: 70};
	g.nodes.b = {type: "dialogo", data: {text: ""}, x: 220, y: 70};
	g.nodes.c = {type: "mision", data: {name: "", description: "", steps: [{type: "kill", npcGroup: "scav", count: 3}]}, x: 410, y: 70};
	g.nodes.d = {type: "recompensa", data: {rublos: 0, rep: 0}, x: 600, y: 70};
	g.nodes.e = {type: "fin", data: {}, x: 790, y: 70};
	g.edges = [{from: "a", to: "b"}, {from: "b", to: "c"}, {from: "c", to: "d"}, {from: "d", to: "e"}];
	return g;
}

function findGraph(key) {
	var found = null;
	arr(D.graphs).forEach(function (g) { if (g.traderKey === key) found = g; });
	if (!found) return blank(key);
	var c = JSON.parse(JSON.stringify(found));
	c.nodes = c.nodes || {};
	var i = 0;
	Object.keys(c.nodes).forEach(function (id) {
		var n = c.nodes[id];
		n.data = n.data || {};
		n.x = n.x || 30 + (i % 6) * 190;
		n.y = n.y || 70 + Math.floor(i / 6) * 120;
		i++;
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
	if (n.type === "respuesta") return (d.text || "(sin pregunta)") + " · " + arr(d.options).length + " opción(es)";
	if (n.type === "requisito") return (d.kind || "?") + " " + (d.value !== undefined ? d.value : (d.itemID || ""));
	if (n.type === "mision") return (d.name || "(sin nombre)") + " · " + arr(d.steps).length + " objetivo(s)";
	if (n.type === "recompensa") return (d.rublos || 0) + " RUB · rep " + (d.rep || 0);
	return "Fin";
}

function outgoing(id) { return G.edges.filter(function (e) { return e.from === id; }); }

function setEdge(from, to, label) {
	G.edges = G.edges.filter(function (e) { return !(e.from === from && e.label === label); });
	if (to) {
		var edge = {from: from, to: to};
		if (label !== undefined) edge.label = label;
		G.edges.push(edge);
	}
}

function removeNode(id) {
	if (G.nodes[id] && G.nodes[id].type === "inicio") return;
	delete G.nodes[id];
	G.edges = G.edges.filter(function (e) { return e.from !== id && e.to !== id; });
	sel = null;
	draw();
}

function addNode(type) {
	if (Object.keys(G.nodes).length >= MAX_NODES) { status("El grafo llega al máximo de " + MAX_NODES + " nodos."); return; }
	var id = newId("n");
	var data = {
		dialogo: {text: ""},
		respuesta: {text: "", options: [{text: "Sí"}, {text: "No"}]},
		requisito: {kind: "level", value: 1},
		mision: {name: "", description: "", steps: [{type: "kill", npcGroup: "scav", count: 1}]},
		recompensa: {rublos: 0, rep: 0},
		fin: {}
	}[type];
	G.nodes[id] = {type: type, data: data, x: 60 + (Object.keys(G.nodes).length % 6) * 170, y: 220 + Math.floor(Object.keys(G.nodes).length / 6) * 110};
	sel = id;
	draw();
}

function drawBar() {
	var bar = document.getElementById("bar"); bar.innerHTML = "";
	arr(D.traders).forEach(function (t) {
		var b = el("button", "btn" + (G.traderKey === t.key ? " on" : ""), t.name);
		b.onclick = function () { G = findGraph(t.key); sel = null; draw(); };
		bar.appendChild(b);
	});
	TYPES.forEach(function (t) {
		var b = el("button", "btn", "+ " + t[1]);
		b.onclick = function () { addNode(t[0]); };
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
		line.setAttribute("x1", a.x + 160); line.setAttribute("y1", a.y + portY(e.from, e.label));
		line.setAttribute("x2", b.x); line.setAttribute("y2", b.y + 30);
		line.setAttribute("stroke", "#e3722d"); line.setAttribute("stroke-width", "2");
		svg.appendChild(line);
	});
	if (link) {
		var a2 = G.nodes[link.from];
		var tmp = document.createElementNS(NS, "line");
		tmp.setAttribute("x1", a2.x + 160); tmp.setAttribute("y1", a2.y + portY(link.from, link.label));
		tmp.setAttribute("x2", link.x); tmp.setAttribute("y2", link.y);
		tmp.setAttribute("stroke", "#f2b179"); tmp.setAttribute("stroke-width", "2");
		tmp.setAttribute("stroke-dasharray", "6 4");
		svg.appendChild(tmp);
	}
	canvas.insertBefore(svg, canvas.firstChild);
}

function drawCanvas() {
	var canvas = document.getElementById("canvas"); canvas.innerHTML = "";
	Object.keys(G.nodes).forEach(function (id) {
		var n = G.nodes[id];
		var box = el("div", "node" + (sel === id ? " sel" : ""));
		box.id = "n_" + id;
		box.setAttribute("data-id", id);
		box.style.left = n.x + "px"; box.style.top = n.y + "px";
		box.appendChild(el("div", "hd", NAMES[n.type] || n.type));
		box.appendChild(el("div", "bd", summary(n)));
		box.onmousedown = function (e) {
			sel = id;
			var c = canvas.getBoundingClientRect();
			drag = {key: id, dx: e.clientX - c.left - n.x, dy: e.clientY - c.top - n.y};
			drawForm(); drawCanvasSel();
		};
		portsOf(id).forEach(function (p, i) {
			var port = el("div", "port");
			port.style.top = (38 + i * 18 - 5) + "px";
			port.title = "Arrastra para conectar. Suéltalo en el vacío para desconectar.";
			port.onmousedown = function (e) {
				e.stopPropagation(); e.preventDefault();
				var c = canvas.getBoundingClientRect();
				link = {from: id, label: p.label, x: e.clientX - c.left, y: e.clientY - c.top};
				sel = id; drawForm(); drawCanvasSel(); drawEdges();
			};
			box.appendChild(port);
		});
		canvas.appendChild(box);
	});
	drawEdges();
}

function drawCanvasSel() {
	Object.keys(G.nodes).forEach(function (id) {
		var b = document.getElementById("n_" + id);
		if (b) b.className = "node" + (sel === id ? " sel" : "");
	});
}

// Desplegable que elige el nodo de destino de una salida (o ninguno).
function targetSelect(from, label, current, allowNone) {
	var s = el("select");
	if (allowNone) s.appendChild(el("option", null, "— ninguno —")).value = "";
	Object.keys(G.nodes).forEach(function (id) {
		if (id === from || G.nodes[id].type === "inicio") return;
		var o = el("option", null, NAMES[G.nodes[id].type] + " · " + summary(G.nodes[id]).slice(0, 30)); o.value = id;
		if (current === id) o.selected = true;
		s.appendChild(o);
	});
	s.onchange = function () { setEdge(from, s.value, label); draw(); };
	return s;
}

function drawForm() {
	var f = document.getElementById("form"); f.innerHTML = "";
	if (!sel || !G.nodes[sel]) { f.appendChild(el("div", "bd", "Selecciona un nodo para editarlo.")); return; }
	var id = sel, n = G.nodes[id], d = n.data;
	f.appendChild(el("div", "bd", NAMES[n.type]));

	if (n.type === "inicio") {
		f.appendChild(el("label", null, "Comerciante"));
		var s = el("select");
		arr(D.traders).forEach(function (t) {
			var o = el("option", null, t.name); o.value = t.key; if (t.key === G.traderKey) o.selected = true; s.appendChild(o);
		});
		s.onchange = function () { G = findGraph(s.value); sel = null; draw(); };
		f.appendChild(s);
	}

	if (n.type === "dialogo") {
		f.appendChild(el("label", null, "Texto del NPC"));
		var t = el("textarea"); t.value = d.text || "";
		t.oninput = function () { d.text = t.value; drawCanvas(); drawCanvasSel(); };
		f.appendChild(t);
	}

	if (n.type === "respuesta") {
		f.appendChild(el("label", null, "Pregunta del NPC"));
		var rt = el("textarea"); rt.value = d.text || "";
		rt.oninput = function () { d.text = rt.value; drawCanvas(); drawCanvasSel(); };
		f.appendChild(rt);
		d.options = arr(d.options);
		d.options.forEach(function (opt, i) {
			var box = el("div", "step");
			box.appendChild(el("label", null, "Opción " + (i + 1)));
			var ti = el("input"); ti.value = opt.text || "";
			ti.oninput = function () { opt.text = ti.value; drawCanvas(); drawCanvasSel(); };
			box.appendChild(ti);
			box.appendChild(el("label", null, "Lleva a"));
			box.appendChild(targetSelect(id, i + 1, (outgoing(id).filter(function (e) { return e.label === i + 1; })[0] || {}).to, true));
			if (d.options.length > 1) {
				var rm = el("button", "btn", "Quitar");
				rm.onclick = function () {
					d.options.splice(i, 1);
					G.edges = G.edges.filter(function (e) { return !(e.from === id && e.label === i + 1); });
					G.edges.forEach(function (e) { if (e.from === id && e.label > i + 1) e.label = e.label - 1; });
					draw();
				};
				box.appendChild(rm);
			}
			f.appendChild(box);
		});
		if (d.options.length < MAX_OPTIONS) {
			var add = el("button", "btn", "+ Opción");
			add.onclick = function () { d.options.push({text: "Opción " + (d.options.length + 1)}); draw(); };
			f.appendChild(add);
		}
	}

	if (n.type === "requisito") {
		f.appendChild(el("label", null, "Tipo"));
		var ks = el("select");
		REQ_KINDS.forEach(function (k) {
			var o = el("option", null, k[1]); o.value = k[0]; if (d.kind === k[0]) o.selected = true; ks.appendChild(o);
		});
		ks.onchange = function () { d.kind = ks.value; if (d.kind === "item") { d.itemID = d.itemID || ""; d.count = d.count || 1; } draw(); };
		f.appendChild(ks);
		if (d.kind === "item") {
			f.appendChild(el("label", null, "Objeto (id)"));
			var ii = el("input"); ii.value = d.itemID || "";
			ii.oninput = function () { d.itemID = ii.value; drawCanvas(); drawCanvasSel(); };
			f.appendChild(ii);
			f.appendChild(el("label", null, "Cantidad"));
			var ic = el("input"); ic.type = "number"; ic.min = 1; ic.value = d.count || 1;
			ic.oninput = function () { d.count = num(ic.value) || 1; };
			f.appendChild(ic);
		} else if (d.kind === "mission") {
			f.appendChild(el("label", null, "Id de la misión previa"));
			var mi = el("input"); mi.value = d.value || "";
			mi.oninput = function () { d.value = mi.value; drawCanvas(); drawCanvasSel(); };
			f.appendChild(mi);
		} else {
			f.appendChild(el("label", null, d.kind === "loyalty" ? "Nivel de lealtad (1-4)" : d.kind === "level" ? "Nivel mínimo" : "Reputación mínima"));
			var vi = el("input"); vi.type = "number"; vi.min = 0; vi.value = d.value !== undefined ? d.value : 1;
			vi.oninput = function () { d.value = num(vi.value); drawCanvas(); drawCanvasSel(); };
			f.appendChild(vi);
		}
		f.appendChild(el("label", null, "Si se cumple"));
		f.appendChild(targetSelect(id, "si", (outgoing(id).filter(function (e) { return e.label === "si"; })[0] || {}).to, true));
		f.appendChild(el("label", null, "Si no se cumple"));
		f.appendChild(targetSelect(id, "no", (outgoing(id).filter(function (e) { return e.label === "no"; })[0] || {}).to, true));
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
				var rm2 = el("button", "btn", "Quitar");
				rm2.onclick = function () { d.steps.splice(i, 1); draw(); };
				box.appendChild(rm2);
			}
			f.appendChild(box);
		});
		var addStep = el("button", "btn", "+ Objetivo");
		addStep.onclick = function () { d.steps.push({type: "kill", npcGroup: "scav", count: 1}); draw(); };
		f.appendChild(addStep);
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

	if (n.type === "inicio" || n.type === "dialogo" || n.type === "mision" || n.type === "recompensa") {
		f.appendChild(el("label", null, "Siguiente"));
		f.appendChild(targetSelect(id, undefined, (outgoing(id)[0] || {}).to, true));
	}

	if (n.type !== "inicio") {
		var del = el("button", "btn", "Borrar nodo");
		del.onclick = function () { removeNode(id); };
		f.appendChild(del);
	}
	if (n.type === "fin") f.appendChild(el("div", "bd", "Fin del camino."));
}

function draw() {
	if (!G) return;
	drawBar(); drawCanvas(); drawForm();
}

// Arrastre a mano: HTML5 drag and drop no es fiable en Chromium 86.
document.onmousemove = function (e) {
	if (link) {
		var cl = document.getElementById("canvas").getBoundingClientRect();
		link.x = e.clientX - cl.left; link.y = e.clientY - cl.top;
		drawEdges();
		return;
	}
	if (!drag) return;
	var c = document.getElementById("canvas").getBoundingClientRect();
	var n = G.nodes[drag.key];
	if (!n) return;
	n.x = Math.max(0, e.clientX - c.left - drag.dx);
	n.y = Math.max(0, e.clientY - c.top - drag.dy);
	var b = document.getElementById("n_" + drag.key);
	if (b) { b.style.left = n.x + "px"; b.style.top = n.y + "px"; }
	drawEdges();
};
document.onmouseup = function (e) {
	if (link) {
		var target = document.elementFromPoint(e.clientX, e.clientY);
		var box = target && target.closest ? target.closest(".node") : null;
		var toId = box ? box.getAttribute("data-id") : null;
		var from = link.from, label = link.label;
		link = null;
		if (toId === null) {
			setEdge(from, null, label);
		} else if (toId !== from && G.nodes[toId] && G.nodes[toId].type !== "inicio") {
			setEdge(from, toId, label);
		}
		draw();
		return;
	}
	drag = null;
};

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

	-- barra superior: acceso a los editores clásicos (npc_custom y formulario de misiones)
	self.bar = self:Add("DPanel")
	self.bar:Dock(TOP)
	self.bar:SetTall(30)
	self.bar.Paint = function() end

	self.classic = self.bar:Add("DButton")
	self.classic:Dock(RIGHT)
	self.classic:DockMargin(4, 3, 4, 3)
	self.classic:SetWide(200)
	self.classic:SetText("EDITORES CLÁSICOS")
	if (ix.efgui and ix.efgui.StyleButton) then
		ix.efgui.StyleButton(self.classic, "efgui.Header")
	end
	self.classic.DoClick = function() self:OpenClassicMenu() end

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

-- Menú con los editores clásicos. Son los mismos de siempre, sin cambios.
function PANEL:OpenClassicMenu()
	local menu = DermaMenu()

	menu:AddOption("Diálogos de NPC (npc_custom): mira al NPC", function()
		RunConsoleCommand("say", "/CustomNPCAdmin")
	end)

	menu:AddOption("Formulario de misiones: mira al comerciante", function()
		local ent = LocalPlayer():GetEyeTraceNoCursor().Entity
		if (IsValid(ent) and ent:GetClass() == "ix_trader" and ix.missions and ix.missions.OpenAdmin) then
			ix.missions.OpenAdmin(ent)
		else
			notification.AddLegacy("Apunta a un comerciante.", NOTIFY_ERROR, 4)
		end
	end)

	menu:Open()
end

function PANEL:OnRemove()
	if (ix.gui.flujoEditor == self) then ix.gui.flujoEditor = nil end
end

vgui.Register("efgxFlujoEditor", PANEL, "DPanel")
