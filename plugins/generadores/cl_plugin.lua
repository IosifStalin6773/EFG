local PLUGIN = PLUGIN

surface.CreateFont("ixGenTitle", {
	font = "EFGX Display",
	size = 22,
	weight = 700,
	antialias = true,
})

surface.CreateFont("ixGenText", {
	font = "EFGX Body",
	size = 17,
	weight = 500,
	antialias = true,
})

local COLOR_ON = Color(120, 220, 130)
local COLOR_OFF = Color(230, 90, 80)

-- Muestra el estado del generador al que mira el jugador (fuel + energía + ayuda).
function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	if (not IsValid(client) or not client:Alive()) then return end

	local ent = client:GetEyeTrace().Entity
	if (not IsValid(ent) or ent:GetClass() != "metro_generator") then return end
	if (client:EyePos():DistToSqr(ent:GetPos()) > 220 * 220) then return end

	local fuel = ent:GetNetVar("fuel", 0)
	local powered = ent:GetNetVar("powered", false)

	local sw, sh = ScrW(), ScrH()
	local cx = sw * 0.5
	local y = sh * 0.62

	draw.SimpleText("GENERADOR DIÉSEL", "ixGenTitle", cx, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local estado = powered and "ENCENDIDO" or "SIN ENERGÍA"
	draw.SimpleText(estado, "ixGenText", cx, y + 24, powered and COLOR_ON or COLOR_OFF, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText("Combustible restante: " .. GeneratorFormatFuel(fuel), "ixGenText", cx, y + 44,
		Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText("Pulsa E con un Bidón de gasolina para repostar (+" .. ix.config.Get("gen_horas_bidon", 6) .. "h)",
		"ixGenText", cx, y + 68, Color(255, 210, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- ─── Apagón: oscurece la pantalla dentro de un área sin energía ───────────────
-- La iluminación horneada del mapa no se puede apagar en Source, así que el
-- "corte de luz" se simula oscureciendo la vista del cliente. Al reducir el brillo
-- de forma relativa, las superficies iluminadas por la linterna siguen visibles.

local blackout = 0 -- intensidad suavizada 0..1

local function IsLocalInBlackout()
	local client = LocalPlayer()
	if (not IsValid(client)) then return false end

	local pos = client:EyePos()

	for _, ent in ipairs(ents.FindByClass("metro_generator")) do
		if (not IsValid(ent)) then continue end
		if (ent:GetNetVar("powered", true)) then continue end

		local vMin = ent:GetNetVar("areaMin")
		local vMax = ent:GetNetVar("areaMax")

		if (vMin and vMax and pos:WithinAABox(vMin, vMax)) then
			return true
		end
	end

	return false
end

local blackColmod = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0,
}

function PLUGIN:Think()
	local target = IsLocalInBlackout() and 1 or 0
	blackout = math.Approach(blackout, target, FrameTime() * 2) -- fundido ~0.5 s
end

function PLUGIN:RenderScreenspaceEffects()
	if (blackout <= 0.01) then return end

	blackColmod["$pp_colour_brightness"] = -0.6 * blackout
	blackColmod["$pp_colour_contrast"] = Lerp(blackout, 1, 0.9)
	blackColmod["$pp_colour_colour"] = Lerp(blackout, 1, 0.2)

	DrawColorModify(blackColmod)
end
