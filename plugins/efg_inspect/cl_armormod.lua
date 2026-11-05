-- Pantalla de equipo protector (solo lectura): ranuras de la pieza (chaleco o casco)
-- y stats en vivo del jugador. Se abre con clic derecho en un chaleco o casco que
-- declara ranuras (INS.Open). El servidor manda el estado (ixEFGArmorStats) y la
-- página lo pinta; las ranuras se rellenan en la siguiente parte.
-- La página llama a efg.close() y efg.click() como las demás pantallas de inspección.

local PLUGIN = PLUGIN
local INS = ix.efg.inspect

PLUGIN.armorHTML = [==[
<!doctype html>
<html><head><meta charset="utf-8">
<style>
/*EFG_BASE*/
html, body { background: transparent; }
#win { position: absolute; left: 50%; top: 50%; width: 560px; transform: translate(-50%, -50%);
	background: rgba(20,21,19,.95) var(--efg-grunge); border: 1px solid #0a0b09; box-shadow: 0 0 24px rgba(0,0,0,.6); }
#head { display: flex; align-items: center; padding: 10px 14px; border-bottom: 1px solid var(--efg-line); }
#head .t { font-family: var(--efg-font-stencil); font-size: 16px; letter-spacing: 3px; text-transform: uppercase; color: var(--efg-text); }
#head .sp { flex: 1; }
#head .x { width: 36px; height: 30px; border: 0; background: none; color: var(--efg-text2); font-size: 16px; cursor: pointer; }
#head .x:hover { background: var(--efg-red); color: #fff; }
#body { display: flex; gap: 14px; padding: 14px; }
.box { flex: 1; border: 1px solid var(--efg-line); padding: 10px; }
.box h3 { margin: 0 0 8px 0; font-size: 12px; letter-spacing: 2px; text-transform: uppercase; color: var(--efg-dim); }
.row { display: flex; justify-content: space-between; font-size: 14px; padding: 3px 0; color: var(--efg-text); }
.row .v { color: var(--efg-orange); }
.slot { font-size: 14px; padding: 6px 8px; margin-bottom: 5px; border: 1px dashed var(--efg-line); color: var(--efg-text2); }
.slot .e { color: var(--efg-dim); font-style: italic; }
.slot .sl { font-size: 13px; letter-spacing: 1px; text-transform: uppercase; color: var(--efg-dim); margin-bottom: 4px; }
.slot .pl { color: var(--efg-text); margin-bottom: 4px; }
.btn { margin: 2px 4px 2px 0; padding: 3px 8px; border: 1px solid var(--efg-line); background: rgba(0,0,0,.35); color: var(--efg-text); font-size: 12px; cursor: pointer; font-family: var(--efg-font); }
.btn:hover { background: var(--efg-orange); color: #000; }
.zone { font-size: 13px; padding: 2px 0; color: var(--efg-text); }
.zone .c { float: right; color: var(--efg-orange); }
#note { padding: 0 14px 12px 14px; font-size: 12px; color: var(--efg-dim); }
</style>
</head>
<body>
<div id="win">
	<div id="head"><span class="t" id="name">Equipo</span><span class="sp"></span><button class="x" onclick="closeWin()">✕</button></div>
	<div id="body">
		<div class="box">
			<h3>Ranuras</h3>
			<div id="slots"></div>
		</div>
		<div class="box">
			<h3>Estadísticas en vivo</h3>
			<div class="row"><span>Peso</span><span class="v" id="w">—</span></div>
			<div class="row"><span>Ergonomía</span><span class="v" id="e">—</span></div>
			<div class="row"><span>Velocidad de giro</span><span class="v" id="t">—</span></div>
			<h3 style="margin-top:12px">Zonas protegidas</h3>
			<div id="zones"></div>
		</div>
	</div>
	<div id="note"></div>
</div>
<script>
function el(t, c, x) { var e = document.createElement(t); if (c) e.className = c; if (x !== undefined && x !== null) e.textContent = x; return e; }
function call(fn) { if (window.efg && efg[fn]) efg[fn].apply(efg, [].slice.call(arguments, 1)); }
function closeWin() { call("click"); call("close"); }
function render(d) {
	document.getElementById("name").textContent = d.name || "Equipo";
	var s = document.getElementById("slots"); s.innerHTML = "";
	(d.slots || []).forEach(function (x) {
		var box = el("div", "slot");
		box.appendChild(el("div", "sl", x.label));
		if (x.installed) {
			box.appendChild(el("div", "pl", x.installed.name + " (" + x.installed.durability + ")"));
			var rm = el("button", "btn", "Quitar");
			rm.onclick = function () { call("remove", x.k); };
			box.appendChild(rm);
		} else {
			var cands = x.candidates || [];
			if (!cands.length) box.appendChild(el("span", "e", "vacío"));
			cands.forEach(function (c) {
				var b = el("button", "btn", c.name);
				b.onclick = function () { call("install", x.k, c.id); };
				box.appendChild(b);
			});
		}
		s.appendChild(box);
	});
	if (!d.slots || !d.slots.length) s.appendChild(el("div", "e", "Esta pieza no tiene ranuras."));
	var st = d.stats || {};
	document.getElementById("w").textContent = (st.weight || 0).toFixed(2) + " kg";
	document.getElementById("e").textContent = d.modular ? String(st.ergo || 0) : "—";
	document.getElementById("t").textContent = d.modular ? String(st.turn || 0) : "—";
	var z = document.getElementById("zones"); z.innerHTML = "";
	(d.zones || []).forEach(function (x) { var r = el("div", "zone", x.label); r.appendChild(el("span", "c", "clase " + x.class)); z.appendChild(r); });
	if (!d.zones || !d.zones.length) z.appendChild(el("div", "e", "Sin protección puesta."));
	document.getElementById("note").textContent = d.modular ? "Las ranuras se llenan en la siguiente parte." : "Modo modular apagado: sin ergonomía ni giro.";
}
document.addEventListener("keydown", function (ev) { if (ev.keyCode === 27) closeWin(); });
</script>
</body></html>
]==]

net.Receive("ixEFGArmorStats", function()
	local data = util.JSONToTable(net.ReadString())

	if (data and IsValid(ix.gui.efgArmorMod)) then
		ix.gui.efgArmorMod:Receive(data)
	end
end)

local PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.efgArmorMod)) then ix.gui.efgArmorMod:Remove() end
	ix.gui.efgArmorMod = self

	self:SetSize(ScrW(), ScrH())
	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.15)

	self.html = self:Add("DHTML")
	self.html:Dock(FILL)
	self.html:SetAllowLua(false)

	self.html:AddFunction("efg", "click", function() surface.PlaySound("efg/ui/click.wav") end)
	self.html:AddFunction("efg", "close", function() self:Close() end)
	self.html:AddFunction("efg", "install", function(slot, plateID) self:SendSlot("install", slot, plateID) end)
	self.html:AddFunction("efg", "remove", function(slot) self:SendSlot("remove", slot, 0) end)

	self.html.OnDocumentReady = function()
		self.ready = true
		self:Request()
	end

	self.html:SetHTML(ix.efgui.InjectCSS(PLUGIN.armorHTML))

	self.timerName = "efgArmorMod" .. tostring(self)
	timer.Create(self.timerName, 1, 0, function()
		if (!IsValid(self)) then return timer.Remove(self.timerName) end
		self:Request()
	end)
end

function PANEL:Setup(item)
	self.itemID = item:GetID()
	self:Request()
end

-- pide el estado al servidor; la respuesta llega por ixEFGArmorStats
function PANEL:Request()
	if (!self.ready or !self.itemID) then return end

	net.Start("ixEFGArmorStats")
	net.WriteUInt(self.itemID, 32)
	net.SendToServer()
end

-- instalar (plateID = instancia de la placa) o quitar (plateID = 0) en una ranura
function PANEL:SendSlot(action, slot, plateID)
	if (!self.itemID or !isstring(slot)) then return end

	net.Start("ixEFGArmorSlot")
	net.WriteString(action)
	net.WriteUInt(self.itemID, 32)
	net.WriteString(slot)
	net.WriteUInt(tonumber(plateID) or 0, 32)
	net.SendToServer()
end

function PANEL:Receive(data)
	if (!self.ready) then return end
	self.html:RunJavascript("render(" .. util.TableToJSON(data) .. ")")
end

function PANEL:Close()
	self:AlphaTo(0, 0.12, 0, function() self:Remove() end)
end

function PANEL:OnRemove()
	if (self.timerName) then timer.Remove(self.timerName) end
	if (ix.gui.efgArmorMod == self) then ix.gui.efgArmorMod = nil end
end

vgui.Register("efgxArmorMod", PANEL, "EditablePanel")

function INS.OpenArmorMod(item)
	if (!item) then return end

	surface.PlaySound("ui/buttonclickrelease.wav")

	local panel = vgui.Create("efgxArmorMod")
	panel:Setup(item)
	return panel
end
