-- Pestaña PERSONAJE del TAB: copia de la pantalla OVERALL de EFT.
--   arriba: GENERAL · EQUIPO · SALUD · HABILIDADES · MAPA · TAREAS · LOGROS
--   izquierda (VGUI): nivel, emblema del bando, modelo 3D, nombre, EXP,
--     resumen R / S/R / K / K/D / L/R / horas y la ropa (chaqueta y pantalón)
--   derecha (DHTML, cl_html.lua): resumen GENERAL / PMC / SCAV y ESTADÍSTICAS
local PLUGIN = PLUGIN
local PROFILE = ix.efg.profile
local ASSET = "asset://garrysmod/materials/"

local NAV = {
	{"overall", "General"}, {"gear", "Equipo", "inv"}, {"health", "Salud", "health"},
	{"skills", "Habilidades"}, {"map", "Mapa", "raid"}, {"tasks", "Tareas", "tasks"},
	{"achievements", "Logros"},
}

local PERK_ICONS = {
	aguante = "vitality", mantenimiento = "aim_drills", medicina = "surgery", resistencia = "endurance",
	fuerza = "strength", explorador = "perception", superviviente = "metabolism", radiacion = "immunity",
	manitas = "heal", negociador = "stress_resistance", apanado = "health",
}

local function S(v) return ix.efgui.Scale(v) end

local function num(t, key) return tonumber(t and t[key]) or 0 end

local function comma(n) return string.Comma(math.floor(tonumber(n) or 0)) end

local function hours(seconds)
	seconds = math.floor(seconds or 0)
	return ("%dh%02dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

local function clock(seconds)
	seconds = math.floor(seconds or 0)
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function pct(a, b)
	return b > 0 and (math.Round(a / b * 100) .. " %") or "0 %"
end

local function date(stamp)
	return (stamp or 0) > 0 and os.date("%d.%m.%Y", stamp) or "-"
end

-- ─── Datos para la página ────────────────────────────────────────────────────
function PROFILE.SideSummary(data, side, extra)
	local t = PROFILE.Side(data, side)
	local raids, survived, kia, mia, awol = num(t, "raids"), num(t, "survived"), num(t, "kia"), num(t, "mia"), num(t, "awol")
	local deaths = kia + mia
	local kd = deaths > 0 and math.Round(num(t, "kills") / deaths, 2) or num(t, "kills")
	local lifetime = (extra.created or 0) > 0 and math.floor((os.time() - extra.created) / 86400) or 0

	return {
		raids = raids, survived = survived, kills = num(t, "kills"), kd = kd, awol = awol,
		row1 = {
			{icon = "raid", value = comma(raids), label = "(R) Raids"},
			{icon = "survived", value = comma(survived), label = "(S) Sobrevividas"},
			{icon = "kia", value = comma(kia), label = "Muerto en combate"},
			{icon = "mia", value = comma(mia), label = "Desaparecido (MIA)"},
			{icon = "awol", value = comma(awol), label = "(L) Abandonos"},
			{icon = "kills", value = comma(num(t, "kills")), label = "(K) Bajas"},
			{icon = "online", value = hours(num(data, "online")), label = "En línea"},
		},
		row2 = {
			{value = comma(num(t, "runthrough")), label = "(RT) Run-throughs"},
			{value = pct(survived, raids), label = "(S/R) Supervivencia"},
			{value = clock(raids > 0 and num(t, "lifeTime") / raids or 0), label = "Vida media"},
			{value = comma(num(t, "bestStreak")), label = "Seguidas"},
			{value = pct(awol, raids), label = "(L/R) Abandono"},
			{value = tostring(kd), label = "(K/D)"},
			{value = lifetime .. "d", label = "Antigüedad"},
		},
	}
end

local function survivorClass(overall)
	if (overall.raids < 10) then return "Desconocida" end

	local rate = overall.survived / overall.raids
	if (rate >= 0.6) then return "Superviviente" end
	if (rate >= 0.4) then return "Veterano" end
	if (rate >= 0.2) then return "Combatiente" end
	return "Novato"
end

local function leastDamaged(data)
	local parts = ix.efg.health and ix.efg.health.parts
	if (!parts) then return "-" end

	local best, bestCount
	for _, part in ipairs(parts) do
		local count = num(data.parts, part.id)
		if (!bestCount or count < bestCount) then best, bestCount = part, count end
	end

	return best and string.upper(best.name) or "-"
end

function PROFILE.BuildPayload(page)
	local character = LocalPlayer():GetCharacter()
	local data = PROFILE.Get(character)
	local extra = page.extra or {}
	local payload = {view = page.view}

	if (page.view == "overall") then
		payload.sides = {}
		for _, side in ipairs({"overall", "pmc", "scav"}) do payload.sides[side] = PROFILE.SideSummary(data, side, extra) end

		local overall, sideAll = payload.sides.overall, PROFILE.Side(data, "overall")
		local xp, health, combat, loot = data.xp or {}, data.health or {}, data.combat or {}, data.loot or {}

		payload.columns = {
			{
				{title = "Estadísticas generales", glyph = "common", rows = {
					{"Fecha de registro", date(extra.created)},
					{"Última sesión", date(extra.lastJoin)},
					{"Clase de superviviente", survivorClass(overall)},
					{"Experiencia por bajas", comma(num(xp, "kill"))},
					{"Experiencia por botín", comma(num(xp, "loot"))},
					{"Experiencia por curación", comma(num(xp, "heal"))},
					{"Experiencia por supervivencia", comma(num(xp, "survival"))},
					{"Experiencia por tareas", comma(num(xp, "task"))},
					{"Racha más larga", comma(num(sideAll, "bestStreak"))},
					{"Racha actual", comma(num(data.pmc, "streak"))},
					{"Valor total del alijo", extra.stash and (comma(extra.stash) .. " RUB") or "..."},
				}},
				{title = "Botín", glyph = "looting", rows = {
					{"Km recorridos", ("%.3f"):format(num(loot, "distance") / 1000)},
					{"Objetos recogidos", comma(num(loot, "items"))},
				}},
			},
			{
				{title = "Salud y condición física", glyph = "health", rows = {
					{"Daño recibido", comma(num(health, "taken"))},
					{"Extremidades perdidas", comma(num(health, "lost"))},
					{"Parte menos castigada", leastDamaged(data)},
					{"Vida curada", comma(num(health, "healed"))},
					{"Fracturas", comma(num(health, "fractures"))},
					{"Sangrados", comma(num(health, "bleeds"))},
					{"Bebidas consumidas", comma(num(health, "drink"))},
					{"Comida consumida", comma(num(health, "food"))},
					{"Medicinas usadas", comma(num(health, "meds"))},
				}},
				{title = "Combate", glyph = "combat", rows = {
					{"Daño infligido", comma(num(combat, "dealt"))},
					{"Daño absorbido por el blindaje", comma(num(combat, "absorbed"))},
					{"Bajas de PMC", comma(num(sideAll, "killsPMC"))},
					{"Bajas de Scav", comma(num(sideAll, "killsScav"))},
					{"Bajas de IA", comma(num(sideAll, "killsAI"))},
					{"Bajas a la cabeza", comma(num(sideAll, "headshots"))},
				}},
			},
		}
	elseif (page.view == "skills") then
		payload.skills = {}

		for _, def in ipairs(ix.perks and ix.perks.list or {}) do
			if (def.category == "perk" and character.GetPerkXP) then
				local level, into, need = ix.perks.GetProgress(character:GetPerkXP(def.id))
				local icon = ix.efg.utils and ix.efg.utils.UIPath(PERK_ICONS[def.id] or "health")

				payload.skills[#payload.skills + 1] = {
					name = def.name or def.id, level = level, max = ix.perks.maxLevel or 50,
					into = math.floor(into), need = math.floor(need), frac = need > 0 and into / need or 1,
					icon = icon and (ASSET .. icon) or "",
				}
			end
		end
	elseif (page.view == "achievements") then
		payload.achievements, payload.achDone = {}, 0

		for _, ach in ipairs(PROFILE.achievements) do
			local done = ach.check(data) == true
			payload.achDone = payload.achDone + (done and 1 or 0)
			payload.achievements[#payload.achievements + 1] = {name = ach.name, desc = ach.desc, done = done}
		end
	end

	return payload
end

net.Receive("ixEFGProfileExtra", function()
	local extra = {created = net.ReadUInt(32), lastJoin = net.ReadUInt(32), stash = net.ReadDouble()}
	local page = ix.gui.efgProfile

	if (IsValid(page)) then
		page.extra = extra
		page.sig = nil
	end
end)

-- ─── Panel ───────────────────────────────────────────────────────────────────
local PAGE = {}

function PAGE:Init()
	ix.gui.efgProfile = self
	self.view = "overall"
	self.extra = {}

	local character = LocalPlayer():GetCharacter()
	local sideKey = character and ix.efg.pmc and ix.efg.pmc.GetSideKey(character:GetFaction())
	self.sideKey = sideKey
	self.emblem = Material("efgui/factions/" .. (sideKey or "scav") .. ".png", "smooth")
	self.badge = ix.efg.utils and Material(ix.efg.utils.LevelBadge(character and character:GetEFGLevel() or 1), "smooth") or nil

	self.html = self:Add("DHTML")
	self.html:SetAllowLua(false)
	self.html:AddFunction("efg", "click", function() surface.PlaySound("efg/ui/click.wav") end)
	self.html:SetHTML(ix.efgui.InjectCSS(PLUGIN.profileHTML))
	self.html.OnDocumentReady = function()
		self.ready = true
		self.sig = nil
	end

	self:BuildNav()
	self:BuildLeft()

	net.Start("ixEFGProfileExtra")
	net.SendToServer()
end

function PAGE:BuildNav()
	local C = ix.efgui.color
	self.navButtons = {}

	for _, info in ipairs(NAV) do
		local b = self:Add("DButton")
		b:SetText("")
		b.Paint = function(this, w, h)
			local active = self.view == info[1]

			if (active) then
				surface.SetDrawColor(226, 224, 204)
				surface.DrawRect(0, 0, w, h)
			elseif (this:IsHovered()) then
				surface.SetDrawColor(255, 255, 255, 12)
				surface.DrawRect(0, 0, w, h)
			end

			draw.SimpleText(string.upper(info[2]), "efgx.Header", w / 2, h / 2,
				active and Color(17, 17, 15) or (this:IsHovered() and C.text or C.text2), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function()
			surface.PlaySound("efg/ui/click.wav")

			if (info[3]) then
				if (self.OnNavigate) then self:OnNavigate(info[3]) end
				return
			end

			self.view = info[1]
			self.sig = nil
		end
		self.navButtons[#self.navButtons + 1] = b
	end
end

-- ropa: lista de {opción, nombre} y bodygroup del jugador
function PAGE:LookCombo(parent, list, bodygroup)
	local C = ix.efgui.color
	local client = LocalPlayer()

	local combo = parent:Add("DComboBox")
	combo:SetFont("efgx.Small")
	combo:SetTextColor(C.text)
	combo:SetSortItems(false)
	combo.Paint = function(this, w, h)
		surface.SetDrawColor(10, 11, 9, 235)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(this:IsHovered() and C.lineHi or C.line)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	local current = client:GetBodygroup(bodygroup)

	for _, entry in ipairs(list or {}) do
		combo:AddChoice(entry[2], entry[1], entry[1] == current)
	end

	combo.OnSelect = function(_, _, _, value)
		self:SendLook(bodygroup, value)
	end

	return combo
end

function PAGE:SendLook(bodygroup, value)
	local PMC = ix.efg.pmc
	local client = LocalPlayer()
	local character = client:GetCharacter()
	if (!character or !PMC) then return end

	local top = bodygroup == PMC.BG_TOP and value or client:GetBodygroup(PMC.BG_TOP)
	local legs = bodygroup == PMC.BG_LEGS and value or client:GetBodygroup(PMC.BG_LEGS)
	local chosen = character:GetData("efgCosmetic", {})

	if (IsValid(self.model) and IsValid(self.model.Entity)) then
		self.model.Entity:SetBodygroup(PMC.BG_TOP, top)
		self.model.Entity:SetBodygroup(PMC.BG_LEGS, legs)
	end

	net.Start("ixEFGPMCLook")
		net.WriteUInt(top, 8)
		net.WriteUInt(legs, 8)

		for _, info in ipairs(PMC.cosmetics) do
			net.WriteUInt(tonumber(chosen[info.id]) or 0, 8)
		end
	net.SendToServer()
end

-- menú de accesorios estéticos (gorro, máscara, gafas, auriculares)
function PAGE:OpenCosmetics()
	local PMC = ix.efg.pmc
	local character = LocalPlayer():GetCharacter()
	if (!PMC or !character) then return end

	local chosen = table.Copy(character:GetData("efgCosmetic", {}))
	local menu = DermaMenu()

	for _, info in ipairs(PMC.cosmetics) do
		local sub = menu:AddSubMenu(info.name)

		for _, option in ipairs(info.options) do
			local entry = sub:AddOption(option[2], function()
				chosen[info.id] = option[1]

				net.Start("ixEFGPMCLook")
					net.WriteUInt(LocalPlayer():GetBodygroup(PMC.BG_TOP), 8)
					net.WriteUInt(LocalPlayer():GetBodygroup(PMC.BG_LEGS), 8)
					for _, other in ipairs(PMC.cosmetics) do net.WriteUInt(tonumber(chosen[other.id]) or 0, 8) end
				net.SendToServer()

				if (IsValid(self.model) and PMC.SetPanelCosmetics) then PMC.SetPanelCosmetics(self.model, chosen) end
			end)

			if ((tonumber(chosen[info.id]) or 0) == option[1]) then entry:SetChecked(true) end
		end
	end

	menu:Open()
end

function PAGE:BuildLeft()
	local client = LocalPlayer()
	local PMC = ix.efg.pmc

	local model = self:Add("DModelPanel")
	model:SetModel(client:GetModel())
	model:SetFOV(30)
	model:SetCamPos(Vector(120, 0, 44))
	model:SetLookAt(Vector(0, 0, 37))
	model:SetAmbientLight(Color(60, 62, 60))
	model:SetDirectionalLight(BOX_FRONT, Color(215, 208, 190))
	model:SetDirectionalLight(BOX_TOP, Color(90, 90, 100))
	model.yaw = 30
	model.LayoutEntity = function(this, entity)
		if (this.dragX) then
			local mx = gui.MousePos()
			this.yaw = this.yaw + (mx - this.dragX) * 0.5
			this.dragX = mx
		end

		if (!this.idle) then
			local seq = entity:LookupSequence("idle_all_01")
			if (seq and seq > 0) then entity:ResetSequence(seq) end
			this.idle = true
		end

		entity:SetAngles(Angle(0, this.yaw, 0))
		this:RunAnimation()
	end
	model.OnMousePressed = function(this) this.dragX = gui.MousePos() end
	model.OnMouseReleased = function(this) this.dragX = nil end

	if (IsValid(model.Entity)) then
		model.Entity:SetSkin(client:GetSkin())
		for _, group in ipairs(client:GetBodyGroups()) do model.Entity:SetBodygroup(group.id, client:GetBodygroup(group.id)) end
	end

	local character = client:GetCharacter()
	if (PMC and PMC.SetPanelCosmetics and character) then PMC.SetPanelCosmetics(model, character:GetData("efgCosmetic", {})) end
	self.model = model

	if (PMC and self.sideKey) then
		self.topCombo = self:LookCombo(self, PMC.tops[self.sideKey], PMC.BG_TOP)
		self.legsCombo = self:LookCombo(self, PMC.legs[self.sideKey], PMC.BG_LEGS)

		local acc = self:Add("DButton")
		acc:SetText("Accesorios")
		ix.efgui.StyleButton(acc, "efgx.Small", "ghost")
		acc.DoClick = function() self:OpenCosmetics() end
		self.accButton = acc
	end
end

function PAGE:PerformLayout(w, h)
	local navH = S(24)
	local x = 0

	surface.SetFont("efgx.Header")
	for i, b in ipairs(self.navButtons or {}) do
		local bw = surface.GetTextSize(string.upper(NAV[i][2])) + S(40)
		b:SetPos(x, 0)
		b:SetSize(bw, navH)
		x = x + bw + S(2)
	end

	local leftW = math.floor(w * 0.33)
	self.leftW = leftW
	self.navH = navH

	self.model:SetPos(S(40), navH + S(40))
	self.model:SetSize(leftW - S(80), h - navH - S(150))

	local comboY = h - S(42)
	local comboW = math.floor((leftW - S(80)) / 2)

	if (IsValid(self.topCombo)) then
		self.topCombo:SetPos(S(40), comboY)
		self.topCombo:SetSize(comboW, S(22))
		self.legsCombo:SetPos(S(56) + comboW, comboY)
		self.legsCombo:SetSize(comboW, S(22))
		self.accButton:SetPos(leftW - S(150), comboY - S(30))
		self.accButton:SetSize(S(110), S(22))
	end

	self.html:SetPos(leftW + S(10), navH + S(8))
	self.html:SetSize(w - leftW - S(10), h - navH - S(8))
end

function PAGE:Paint(w, h)
	local C = ix.efgui.color
	local character = LocalPlayer():GetCharacter()
	if (!character) then return end

	-- línea bajo la barra de secciones
	surface.SetDrawColor(C.line)
	surface.DrawRect(0, self.navH or 0, w, 1)

	local leftW = self.leftW or w * 0.33
	local top = (self.navH or 0) + S(12)
	local level = character:GetEFGLevel()

	if (self.badge) then
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(self.badge)
		surface.DrawTexturedRect(S(14), top, S(38), S(38))
	end

	draw.SimpleText(level, "efgx.Display", S(62), top + S(19), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 220)
	surface.SetMaterial(self.emblem)
	surface.DrawTexturedRect(S(16), top + S(52), S(50), S(50))

	-- resumen rápido arriba a la derecha de la columna (se recalcula en Think)
	local summary = self.quick
	if (!summary) then return end

	local lines = {
		{"R: " .. summary.raids, "S/R: " .. (summary.raids > 0 and math.Round(summary.survived / summary.raids * 100) or 0) .. "%"},
		{"K: " .. summary.kills, "K/D: " .. summary.kd},
		{"L/R: " .. (summary.raids > 0 and math.Round(summary.awol / summary.raids * 100) or 0) .. "%", "Online: " .. ("%.2fh"):format(summary.online / 3600)},
	}

	for i, line in ipairs(lines) do
		local y = top + (i - 1) * S(16)
		draw.SimpleText(line[1], "efgx.Small", leftW - S(150), y, C.text2)
		draw.SimpleText(line[2], "efgx.Small", leftW - S(84), y, C.text2)
	end

	-- nombre y experiencia bajo el modelo
	local nameY = h - S(100)
	draw.SimpleText(character:GetName(), "efgx.Title", leftW / 2, nameY, Color(226, 196, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local xpText = string.Comma(character:GetEFGXP())
	surface.SetFont("efgx.Title")
	local tw = surface.GetTextSize(xpText)
	local pillW = S(34)
	local startX = leftW / 2 - (tw + pillW + S(6)) / 2

	draw.RoundedBox(4, startX, nameY + S(14), pillW, S(18), Color(200, 198, 180))
	draw.SimpleText("EXP", "efgx.Label", startX + pillW / 2, nameY + S(23), Color(17, 17, 15), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(xpText, "efgx.Title", startX + pillW + S(6), nameY + S(23), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (IsValid(self.topCombo)) then
		local comboY = h - S(42)
		draw.SimpleText("CHAQUETA", "efgx.Label", S(40), comboY - S(4), C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		draw.SimpleText("PANTALÓN", "efgx.Label", self.legsCombo:GetX(), comboY - S(4), C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end
end

local function signature(page)
	local character = LocalPlayer():GetCharacter()
	return page.view .. util.TableToJSON(PROFILE.Get(character)) .. util.TableToJSON(page.extra or {})
end

function PAGE:Think()
	if ((self.nextCheck or 0) > RealTime()) then return end
	self.nextCheck = RealTime() + 0.5

	local character = LocalPlayer():GetCharacter()
	if (!self:IsVisible() or !character) then return end

	local data = PROFILE.Get(character)
	self.quick = PROFILE.SideSummary(data, "overall", self.extra or {})
	self.quick.online = num(data, "online")

	local sig = signature(self)

	if (self.ready and sig != self.sig) then
		self.sig = sig
		self.html:RunJavascript("render(" .. util.TableToJSON(PROFILE.BuildPayload(self)) .. ")")
	end
end

function PAGE:OnRemove()
	if (ix.gui.efgProfile == self) then ix.gui.efgProfile = nil end
end

vgui.Register("efgxCharacterPage", PAGE, "EditablePanel")
