local PLUGIN = PLUGIN

-- ============================================================
--  Materiales HUD
-- ============================================================

local matNVG   = Material("efgui/hud/pnv.png", "noclamp smooth")
local matGradL = Material("vgui/gradient-l")
local matGradR = Material("vgui/gradient-r")
local matGradU = Material("vgui/gradient-u")
local matGradD = Material("vgui/gradient-d")

-- ============================================================
--  Ajustes de color exactos de nvg_gpnvg (filtro verde clásico)
-- ============================================================

local NVG_DESAT = {
	["$pp_colour_addr"] = 0,  ["$pp_colour_addg"] = 0,  ["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 0,
	["$pp_colour_mulr"] = 0,  ["$pp_colour_mulg"] = 0,  ["$pp_colour_mulb"] = 0,
}

local NVG_GREEN = {
	["$pp_colour_addr"] = -1,  ["$pp_colour_addg"] = 0,  ["$pp_colour_addb"] = -1,
	["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 3.0, ["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,   ["$pp_colour_mulg"] = 0,  ["$pp_colour_mulb"] = 0,
}

-- ============================================================
--  Colores HUD
-- ============================================================

local COLOR_GREEN = Color(80,  220, 80,  220)
local COLOR_RED   = Color(220, 50,  50,  220)
local COLOR_BG    = Color(0,   0,   0,   140)
local COLOR_BLACK = Color(0,   0,   0,   240)

-- ============================================================
--  Estado local (independiente de ArcticNVGs_Enabled)
-- ============================================================

local nvgEnabled        = false
local nvgNoItemFlash    = false
local nvgNoItemFlashEnd = 0
local nvgKeyWasDown     = false
local nvgLamp           = nil

-- ============================================================
--  Desactivar modelo 3D de gafas sobre el jugador
-- ============================================================

function ArcticNVGs_RebuildNVGsForPlayer(ply)
	if (IsValid(ply.ArcticNVGsModel)) then
		SafeRemoveEntity(ply.ArcticNVGsModel)
		ply.ArcticNVGsModel     = nil
		ply.ArcticNVGsModel_NVG = nil
	end
end

-- ============================================================
--  Lámpara de ambiente (brillo sutil del nvg_gpnvg)
-- ============================================================

local function RebuildLamp(enable)
	if (enable) then
		if (not nvgLamp) then
			nvgLamp = ProjectedTexture()
			nvgLamp:SetTexture("effects/flashlight/square")
			nvgLamp:SetFOV(170)
			nvgLamp:SetFarZ(2069)
			nvgLamp:SetBrightness(0.01)
			nvgLamp:SetConstantAttenuation(0.5)
			nvgLamp:Update()
		end
	else
		if (nvgLamp) then
			nvgLamp:Remove()
			nvgLamp = nil
		end
	end
end

-- ============================================================
--  Toggle: maneja estado local, sonidos, fade y net message
-- ============================================================

local function NVG_Toggle()
	local gogglesID = LocalPlayer():GetNWInt("nvg", 0)
	if (gogglesID == 0) then return end
	local goggles_table = ArcticNVGs and ArcticNVGs[gogglesID]
	if (not goggles_table) then return end

	nvgEnabled = not nvgEnabled

	if (nvgEnabled) then
		surface.PlaySound(goggles_table.EquipSound or "arctic_nvgs/nvg_on_1.wav")
	else
		surface.PlaySound(goggles_table.UnequipSound or "arctic_nvgs/nvg_off_1.wav")
	end

	-- ArcticNVGs_Fade es del addon y es leído por su HUDPaintBackground para el fundido
	ArcticNVGs_Fade     = 1
	ArcticNVGs_Inactive = false

	RebuildLamp(nvgEnabled)

	net.Start("arcticnvgs_toggle", true)
		net.WriteBool(nvgEnabled)
	net.SendToServer()
end

-- ============================================================
--  Tecla N
-- ============================================================

local function NVG_IsMenuOpen()
	local g = ix and ix.gui
	if (g) then
		if (IsValid(g.menu) and not g.menu.bClosing) then return true end
		if (IsValid(g.characterMenu) and not g.characterMenu.bClosing) then return true end
		if (IsValid(g.vendor)) then return true end
		if (IsValid(g.metroInventory)) then return true end
		if (IsValid(g.descEditor)) then return true end
		if (IsValid(g.crafting)) then return true end
		if (IsValid(g.chat) and g.chat:GetActive()) then return true end
	end
	local t = ix and ix.traders
	if (t) then
		if (IsValid(t._dialogueFrame)) then return true end
		if (IsValid(t._tradeFrame)) then return true end
		if (IsValid(t._loreFrame)) then return true end
		if (IsValid(t._adminFrame)) then return true end
	end
	local focus = vgui.GetKeyboardFocus()
	if (IsValid(focus) and focus:GetName() == "DTextEntry") then return true end
	return false
end

hook.Add("Think", "NVG_KeyPress", function()
	local isDown = input.IsKeyDown(ix.efg and ix.efg.binds and ix.efg.binds.Key("nightvision") or KEY_N)
	if (ix.efg and ix.efg.binds and IsValid(ix.efg.binds.capturing)) then isDown = false end

	if (isDown and not nvgKeyWasDown) then
		local ply = LocalPlayer()
		if (IsValid(ply) and ply:Alive() and not NVG_IsMenuOpen()) then
			local hasGoggles = ArcticNVGs_GetPlayerGoggles and ArcticNVGs_GetPlayerGoggles(ply)
			if (hasGoggles) then
				NVG_Toggle()
			else
				nvgNoItemFlash    = true
				nvgNoItemFlashEnd = CurTime() + 2
			end
		end
	end

	nvgKeyWasDown = isDown
end)

-- Resetear estado al morir (lado cliente)
hook.Add("PlayerDeath", "NVG_ResetOnDeath", function(ply)
	if (ply != LocalPlayer()) then return end
	nvgEnabled = false
	RebuildLamp(false)
end)

-- ============================================================
--  Post-proceso: desaturación + tinte verde + bloom
--  Usa nvgEnabled local, no depende de ArcticNVGs_Enabled.
--  Safety: si el servidor quitó las gafas (NWInt = 0), auto-reset.
-- ============================================================

hook.Add("RenderScreenspaceEffects", "NVG_PostProcess", function()
	local ply = LocalPlayer()
	if (not IsValid(ply) or not ply:Alive()) then return end

	if (ply:GetNWInt("nvg", 0) == 0) then
		if (nvgEnabled) then
			nvgEnabled = false
			RebuildLamp(false)
		end
		return
	end

	if (not nvgEnabled) then return end

	if (nvgLamp) then
		nvgLamp:SetPos(EyePos())
		nvgLamp:SetAngles(EyeAngles())
		nvgLamp:Update()
	end

	DrawColorModify(NVG_DESAT)
	DrawColorModify(NVG_GREEN)
	DrawBloom(0, 0.4, 4, 4, 1, 0.6, 1, 1, 1)
end)

-- ============================================================
--  HUD: viñeta circular + icono de estado
-- ============================================================

hook.Add("HUDPaint", "NVG_HUD", function()
	local ply = LocalPlayer()
	if (not IsValid(ply) or not ply:Alive()) then return end

	if (nvgNoItemFlash and CurTime() >= nvgNoItemFlashEnd) then
		nvgNoItemFlash = false
	end

	-- ---- Viñeta NVG ----
	if (nvgEnabled) then
		local scrW, scrH = ScrW(), ScrH()
		local vigW = math.floor(scrW * 0.38)
		local vigH = math.floor(scrH * 0.38)

		surface.SetDrawColor(COLOR_BLACK)

		surface.SetMaterial(matGradL)
		surface.DrawTexturedRect(0, 0, vigW, scrH)

		surface.SetMaterial(matGradR)
		surface.DrawTexturedRect(scrW - vigW, 0, vigW, scrH)

		surface.SetMaterial(matGradU)
		surface.DrawTexturedRect(0, 0, scrW, vigH)

		surface.SetMaterial(matGradD)
		surface.DrawTexturedRect(0, scrH - vigH, scrW, vigH)
	end

	-- ---- Icono de estado ----
	if (not nvgEnabled and not nvgNoItemFlash) then return end

	-- Alineado a la derecha del panel de vida (panX=10, panW=280, gap=8)
	local iconSize = 36
	local boxPad   = 8
	local boxW     = iconSize + boxPad * 2
	local boxH     = iconSize + boxPad * 2
	local x        = 10 + 280 + 8                 -- justo a la derecha del panel de vida
	local y        = ScrH() - boxH - 10            -- alineado por el fondo con el panel

	draw.RoundedBox(6, x, y, boxW, boxH, COLOR_BG)

	local iconColor = nvgEnabled and COLOR_GREEN or COLOR_RED
	surface.SetDrawColor(iconColor)
	surface.SetMaterial(matNVG)
	surface.DrawTexturedRect(x + boxPad, y + boxPad, iconSize, iconSize)
end)
