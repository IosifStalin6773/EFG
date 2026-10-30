if (!CLIENT) then return end

-- Stubs de cliente para que los comandos aparezcan en el autocompletado del chat.
-- La lógica real se ejecuta en el servidor (sv_plugin.lua).
ix.command.Add("Habilidades", {
	description = "Abre el menú de tus habilidades y su progreso.",
	OnRun = function(self, client) end
})
ix.command.Add("HabilidadesAdmin", {
	adminOnly = true,
	description = "Abre el panel de administración de habilidades.",
	OnRun = function(self, client) end
})
ix.command.Add("SetPerk", {
	adminOnly = true,
	arguments = { ix.type.player, ix.type.string, ix.type.number },
	description = "Establece el nivel de una habilidad de un personaje.",
	OnRun = function(self, client, target, perkID, level) end
})

-- ── Fuentes ──────────────────────────────────────────────────────────────────
local function registerFonts()
	surface.CreateFont("ixPerksTitle", {
		font = "MBender", extended = true, size = SScale(14), weight = 600, antialias = true,
	})
	surface.CreateFont("ixPerksName", {
		font = "MBender", extended = true, size = SScale(10), weight = 600, antialias = true,
	})
	surface.CreateFont("ixPerksText", {
		font = "MBender", extended = true, size = SScale(8), weight = 500, antialias = true,
	})
end
registerFonts()
hook.Add("OnScreenSizeChanged", "ixPerks.Fonts", registerFonts)

-- ── Estilo ───────────────────────────────────────────────────────────────────
local AMBER = Color(145, 148, 108)
local PAD   = 8

local function paintFrame(self, w, h)
	if (ix.util and ix.util.DrawBlur) then ix.util.DrawBlur(self, 5) end
	surface.SetDrawColor(28, 28, 28, 240)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(AMBER.r, AMBER.g, AMBER.b, 220)
	surface.DrawRect(0, 0, w, SScale(3))
	surface.SetDrawColor(66, 66, 66, 90)
	surface.DrawOutlinedRect(0, 0, w, h, 2)
end

local function paintEntry(self, w, h)
	surface.SetDrawColor(44, 44, 44, 220)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(88, 88, 88, 150)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end

-- ── Tarjeta de un perk (vista del jugador) ───────────────────────────────────
local BAR_H = SScale(18)

local function buildPerkCard(parent, def, level, xpInto, xpNeeded)
	local card = parent:Add("DPanel")
	card:Dock(TOP)
	card:DockMargin(0, 0, 0, 6)
	card.Paint = paintEntry

	-- icono de habilidad EFT (ix.efg.utils.perks)
	local utils = ix.efg and ix.efg.utils
	local skillIcon = utils and utils.perks[def.id]
	local iconSz = SScale(40)

	if (skillIcon) then
		card.PaintOver = function(_, w, h)
			utils.DrawUI(skillIcon, w - PAD - iconSz, 6, iconSz, iconSz)
		end
	end

	local name = card:Add("DLabel")
	name:Dock(TOP)
	name:DockMargin(PAD, 6, PAD + (skillIcon and iconSz + PAD or 0), 2)
	name:SetFont("ixPerksName")
	name:SetTextColor(color_white)
	name:SetText(def.name .. "  [" .. level .. "/" .. ix.perks.maxLevel .. "]")
	name:SetAutoStretchVertical(true)

	local reward = card:Add("DLabel")
	reward:Dock(TOP)
	reward:DockMargin(PAD, 0, PAD + (skillIcon and iconSz + PAD or 0), 4)
	reward:SetFont("ixPerksText")
	reward:SetTextColor(Color(181, 184, 156))
	reward:SetText("Recompensa: " .. def.recompensa)
	reward:SetWrap(true)
	reward:SetAutoStretchVertical(true)

	-- Barra de progreso de XP.
	local bar = card:Add("DPanel")
	bar:Dock(TOP)
	bar:DockMargin(PAD, 0, PAD, 6)
	bar:SetTall(BAR_H)
	bar.Paint = function(_, w, h)
		surface.SetDrawColor(20, 20, 20, 220)
		surface.DrawRect(0, 0, w, h)

		local progress = (xpNeeded > 0) and math.Clamp(xpInto / xpNeeded, 0, 1) or 1
		surface.SetDrawColor(AMBER.r, AMBER.g, AMBER.b, 230)
		surface.DrawRect(0, 0, math.floor(w * progress), h)

		surface.SetDrawColor(88, 88, 88, 150)
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		local txt = (xpNeeded > 0) and (xpInto .. " / " .. xpNeeded .. " XP") or "NIVEL MÁXIMO"
		draw.SimpleText(txt, "ixPerksText", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- Auto-ajusta la altura de la tarjeta al contenido docked.
	card.PerformLayout = function(self, w, h)
		self:SizeToChildren(false, true)
	end

	return card
end

-- ── Menú del jugador: /habilidades ────────────────────────────────────────────
local function OpenMenu()
	local character = LocalPlayer():GetCharacter()
	if (!character) then return end

	if (IsValid(ix.gui.perksMenu)) then ix.gui.perksMenu:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(460), sw - SScale(20))
	local H = math.min(SScale(520), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	ix.gui.perksMenu = frame
	frame:SetSize(W, H)
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:MakePopup()
	frame.Paint = paintFrame

	local title = frame:Add("DLabel")
	title:Dock(TOP)
	title:DockMargin(PAD, PAD, PAD, 0)
	title:SetTall(SScale(20))
	title:SetFont("ixPerksTitle")
	title:SetTextColor(color_white)
	title:SetText("HABILIDADES")

	local close = frame:Add("DButton")
	close:SetText("X")
	close:SetFont("ixPerksName")
	close:SetTextColor(color_white)
	close:SetSize(SScale(22), SScale(22))
	close.Paint = function(s, w, h)
		surface.SetDrawColor(AMBER.r, AMBER.g, AMBER.b, s:IsHovered() and 200 or 120)
		surface.DrawRect(0, 0, w, h)
	end
	close.DoClick = function() frame:Remove() end
	frame.PerformLayout = function(self, w, h)
		close:SetPos(w - SScale(22) - PAD, PAD)
	end

	local scroll = frame:Add("DScrollPanel")
	scroll:Dock(FILL)
	scroll:DockMargin(PAD, SScale(26), PAD, PAD)

	local function addSection(label)
		local header = scroll:Add("DLabel")
		header:Dock(TOP)
		header:DockMargin(0, 4, 0, 4)
		header:SetTall(SScale(16))
		header:SetFont("ixPerksName")
		header:SetTextColor(AMBER)
		header:SetText(label)
	end

	addSection("PERKS")
	for _, def in ipairs(ix.perks.list) do
		if (def.category != "perk") then continue end
		local level, xpInto, xpNeeded = ix.perks.GetProgress(character:GetPerkXP(def.id))
		buildPerkCard(scroll, def, level, xpInto, xpNeeded)
	end

end

net.Receive("habilidades_Open", OpenMenu)

-- ── Panel de administración ────────────────────────────────────────────────────
local function OpenAdmin(players)
	if (IsValid(ix.gui.perksAdmin)) then ix.gui.perksAdmin:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(720), sw - SScale(20))
	local H = math.min(SScale(540), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	ix.gui.perksAdmin = frame
	frame:SetSize(W, H)
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:MakePopup()
	frame.Paint = paintFrame

	local title = frame:Add("DLabel")
	title:Dock(TOP)
	title:DockMargin(PAD, PAD, PAD, 4)
	title:SetTall(SScale(20))
	title:SetFont("ixPerksTitle")
	title:SetTextColor(color_white)
	title:SetText("ADMINISTRACIÓN DE HABILIDADES")

	local close = frame:Add("DButton")
	close:SetText("X")
	close:SetFont("ixPerksName")
	close:SetTextColor(color_white)
	close:SetSize(SScale(22), SScale(22))
	close.Paint = function(s, w, h)
		surface.SetDrawColor(AMBER.r, AMBER.g, AMBER.b, s:IsHovered() and 200 or 120)
		surface.DrawRect(0, 0, w, h)
	end
	close.DoClick = function() frame:Remove() end

	-- Lista de jugadores (izquierda).
	local list = frame:Add("DScrollPanel")
	list:Dock(LEFT)
	list:SetWide(SScale(180))
	list:DockMargin(PAD, 0, PAD, PAD)

	-- Detalle del jugador seleccionado (derecha).
	local detail = frame:Add("DScrollPanel")
	detail:Dock(FILL)
	detail:DockMargin(0, 0, PAD, PAD)

	frame.PerformLayout = function(self, w, h)
		close:SetPos(w - SScale(22) - PAD, PAD)
	end

	local function showPlayer(entry)
		detail:Clear()

		local head = detail:Add("DLabel")
		head:Dock(TOP)
		head:DockMargin(0, 0, 0, 6)
		head:SetTall(SScale(16))
		head:SetFont("ixPerksName")
		head:SetTextColor(color_white)
		head:SetText(entry.name)

		local sliders = {}

		for _, def in ipairs(ix.perks.list) do
			local row = detail:Add("DPanel")
			row:Dock(TOP)
			row:DockMargin(0, 0, 0, 4)
			row.Paint = paintEntry

			local perkLabel = row:Add("DLabel")
			perkLabel:Dock(TOP)
			perkLabel:DockMargin(PAD, 4, PAD, 0)
			perkLabel:SetTall(SScale(14))
			perkLabel:SetFont("ixPerksText")
			perkLabel:SetTextColor(Color(200, 200, 200))
			perkLabel:SetText(def.name)

			local slider = row:Add("DNumSlider")
			slider:Dock(TOP)
			slider:DockMargin(PAD, 2, PAD, 4)
			slider:SetTall(SScale(22))
			slider:SetText("")
			slider:SetMin(1)
			slider:SetMax(ix.perks.maxLevel)
			slider:SetDecimals(0)
			slider:SetValue(ix.perks.GetLevelFromXP((entry.perks or {})[def.id] or 0))

			row:SetTall(SScale(14) + SScale(22) + SScale(10))

			sliders[def.id] = slider
		end

		local apply = detail:Add("DButton")
		apply:Dock(TOP)
		apply:DockMargin(0, 6, 0, 0)
		apply:SetTall(SScale(26))
		apply:SetText("APLICAR CAMBIOS")
		apply:SetFont("ixPerksName")
		apply:SetTextColor(color_white)
		apply.Paint = function(s, w, h)
			surface.SetDrawColor(AMBER.r, AMBER.g, AMBER.b, s:IsHovered() and 200 or 120)
			surface.DrawRect(0, 0, w, h)
		end
		apply.DoClick = function()
			for perkID, slider in pairs(sliders) do
				net.Start("habilidades_AdminSet")
					net.WriteUInt(entry.index, 16)
					net.WriteString(perkID)
					net.WriteUInt(math.Clamp(math.Round(slider:GetValue()), 1, ix.perks.maxLevel), 8)
				net.SendToServer()
			end
			surface.PlaySound("buttons/button14.wav")
		end
	end

	for _, entry in ipairs(players) do
		local btn = list:Add("DButton")
		btn:Dock(TOP)
		btn:DockMargin(0, 0, 0, 4)
		btn:SetTall(SScale(24))
		btn:SetText(entry.name)
		btn:SetFont("ixPerksText")
		btn:SetTextColor(color_white)
		btn.Paint = function(s, w, h)
			surface.SetDrawColor(44, 44, 44, s:IsHovered() and 240 or 200)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(88, 88, 88, 150)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end
		btn.DoClick = function() showPlayer(entry) end
	end

	if (players[1]) then showPlayer(players[1]) end
end

net.Receive("habilidades_AdminData", function()
	local players = util.JSONToTable(net.ReadString()) or {}

	if (IsValid(ix.gui.perksAdmin)) then
		ix.gui.perksAdmin:Remove()
	end

	OpenAdmin(players)
end)
