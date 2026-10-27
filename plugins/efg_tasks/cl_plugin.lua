-- ─── Pestaña TAREAS del TAB (DHTML, como la de EFT) ──────────────────────────
-- Página HTML/CSS (tasks.html.lua) con la fila de comerciantes arriba, la
-- lista de tareas a la izquierda y la ficha a la derecha: retrato, descripción,
-- objetivos y recompensas. Lua le pasa los datos con render(json) y la página
-- llama a efg.action(accion, id) y efg.click() para los botones.

local PLUGIN = PLUGIN

PLUGIN.traders = PLUGIN.traders or {}
PLUGIN.tasks = PLUGIN.tasks or {}

local ASSET = "asset://garrysmod/materials/"
local loyaltyIcons = {"loyalty_one", "loyalty_two", "loyalty_three", "loyalty_king_new"}

net.Receive("ixEFGTasksData", function()
	PLUGIN.traders = net.ReadTable()
	PLUGIN.tasks = net.ReadTable()

	if (IsValid(ix.gui.efgTasks)) then
		ix.gui.efgTasks:Push()
	end
end)

function PLUGIN:Request()
	net.Start("ixEFGTasksRequest")
	net.SendToServer()
end

local function traderName(key)
	return ix.traders and ix.traders.names and ix.traders.names[key] or key
end

-- Lo que necesita la página: rutas asset:// de retratos e iconos, nombres de
-- los objetos de recompensa y la XP que da cada opción (la misma fórmula que
-- missions/sv_plugin.lua).
function PLUGIN:BuildPayload()
	local traders = {}

	for _, t in ipairs(self.traders) do
		traders[#traders + 1] = {
			key = t.key, name = traderName(t.key), ll = t.ll, rep = t.rep,
			portrait = ASSET .. "efgui/traders/" .. t.key .. ".png",
			loyalty = ASSET .. "efg/ui/" .. loyaltyIcons[math.Clamp(t.ll or 1, 1, 4)] .. ".png"
		}
	end

	local tasks = {}

	for _, task in ipairs(self.tasks) do
		local rewards = {}

		for _, option in ipairs(task.rewards or {}) do
			local items = {}

			for _, entry in ipairs(option.items or {}) do
				local item = ix.item.list[entry.id]

				if (item) then
					local icon = ix.efg.icons.Resolve(item)
					items[#items + 1] = {name = item.name, qty = entry.qty or 1, icon = icon and (ASSET .. icon) or nil}
				end
			end

			rewards[#rewards + 1] = {
				rubles = option.balas or 0,
				rep = option.rep or 0,
				xp = math.floor((option.balas or 0) / 20) + (option.rep or 0) * 20,
				items = items
			}
		end

		tasks[#tasks + 1] = {
			id = task.id, name = task.name, description = task.description, trader = task.trader,
			traderName = traderName(task.trader), status = task.status, reason = task.reason,
			daily = task.daily, repeatMode = task.repeatMode, steps = task.steps, rewards = rewards
		}
	end

	local client = LocalPlayer()

	return {
		traders = traders,
		tasks = tasks,
		inRaid = client.InRaid and client:InRaid() or false,
		ui = ASSET .. "efg/ui/"
	}
end

local PANEL = {}

function PANEL:Init()
	ix.gui.efgTasks = self

	self.html = self:Add("DHTML")
	self.html:Dock(FILL)
	self.html:SetAllowLua(false)

	self.html:AddFunction("efg", "click", function()
		surface.PlaySound("efg/ui/click.wav")
	end)

	self.html:AddFunction("efg", "action", function(name, id)
		if (!isstring(name) or !isstring(id)) then return end
		if (name != "accept" and name != "deliver" and name != "turnin" and name != "abandon") then return end

		surface.PlaySound("efg/ui/click.wav")

		net.Start("ixEFGTasksAction")
			net.WriteString(name)
			net.WriteString(id)
		net.SendToServer()
	end)

	self.html.OnDocumentReady = function()
		self.ready = true
		self:Push()
	end

	self.html:SetHTML(PLUGIN.tasksHTML)

	PLUGIN:Request()
end

-- manda los datos a la página (cuando ya ha cargado)
function PANEL:Push()
	if (!self.ready or !IsValid(self.html)) then return end
	self.html:RunJavascript("render(" .. util.TableToJSON(PLUGIN:BuildPayload()) .. ")")
end

function PANEL:Paint() end

function PANEL:OnRemove()
	if (ix.gui.efgTasks == self) then ix.gui.efgTasks = nil end
end

vgui.Register("efgxTasks", PANEL, "DPanel")
