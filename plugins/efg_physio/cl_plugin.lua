-- HUD de fisiología: constantes (solo cuando algo va mal), pantalla de
-- inconsciente, efectos de shock e hipoxia, estado en la pestaña SALUD y
-- lo que se ve al mirar a un herido inconsciente.
local PH = ix.efg.physio
local FLAG = PH.FLAG

local function S(v) return ix.efgui and ix.efgui.Scale(v) or v end

local COLORS = {
	ok = Color(143, 179, 74), warn = Color(201, 164, 58), crit = Color(214, 70, 58),
	text = Color(200, 198, 180), dim = Color(120, 120, 108), bg = Color(10, 11, 9, 215),
}

local function grade(value, warn, crit, higherIsBetter)
	if (higherIsBetter == false) then
		return value >= crit and COLORS.crit or (value >= warn and COLORS.warn or COLORS.ok)
	end

	return value <= crit and COLORS.crit or (value <= warn and COLORS.warn or COLORS.ok)
end

-- avisos activos: {texto, color}
function PH.Warnings(vitals)
	local out = {}
	local function add(flag, text, color) if (PH.HasFlag(vitals, flag)) then out[#out + 1] = {text, color or COLORS.crit} end end

	add(FLAG.ARREST, "PARADA CARDIACA")
	add(FLAG.AIRWAY, "VÍA AÉREA OBSTRUIDA")
	add(FLAG.TENSION, "NEUMOTÓRAX A TENSIÓN")
	add(FLAG.PNEUMO, "NEUMOTÓRAX", COLORS.warn)
	add(FLAG.SHOCK4, "SHOCK HIPOVOLÉMICO IV")
	add(FLAG.SHOCK3, "SHOCK HIPOVOLÉMICO III", COLORS.warn)
	add(FLAG.SHOCK2, "SHOCK HIPOVOLÉMICO II", COLORS.warn)
	add(FLAG.INTERNAL, "HEMORRAGIA INTERNA")
	add(FLAG.GUEDEL, "CÁNULA DE GUEDEL", COLORS.ok)
	add(FLAG.TUBE, "INTUBADO", COLORS.ok)
	add(FLAG.INFUSION, "TRANSFUSIÓN EN CURSO", COLORS.ok)
	add(FLAG.CPR, "RCP EN CURSO", COLORS.ok)

	return out
end

local function abnormal(v)
	return v[1] < 95 or v[5] < PH.BLOOD_MAX * 0.92 or v[6] > 0 or bit.band(v[7], bit.bnot(0)) != 0
end

-- ─── Constantes (abajo a la izquierda, encima del HUD de EFG) ────────────────
local function drawVitals(v)
	local x, y = S(20), ScrH() - S(250)
	local w, h = S(250), S(72)
	local warnings = PH.Warnings(v)

	h = h + #warnings * S(16)

	surface.SetDrawColor(COLORS.bg)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(58, 61, 54)
	surface.DrawOutlinedRect(x, y, w, h)

	local cells = {
		{"SpO2", v[1] .. "%", grade(v[1], 92, 85)},
		{"FC", v[2] > 0 and (v[2] .. "") or "--", v[2] == 0 and COLORS.crit or grade(v[2], 110, 140, false)},
		{"TA", v[3] > 0 and (v[3] .. "/" .. v[4]) or "--", grade(v[3], 95, 70)},
		{"SANGRE", math.Round(v[5] / 1000, 1) .. " L", grade(v[5] / PH.BLOOD_MAX, 0.85, 0.7)},
	}

	local cw = w / #cells

	for i, cell in ipairs(cells) do
		local cx = x + (i - 1) * cw + cw / 2
		draw.SimpleText(cell[1], "efgx.Label", cx, y + S(10), COLORS.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(cell[2], "efgx.Title", cx, y + S(32), cell[3], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if (v[6] > 0) then
		draw.SimpleText("DAÑO CEREBRAL", "efgx.Label", x + S(10), y + S(56), COLORS.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(30, 31, 28)
		surface.DrawRect(x + S(100), y + S(52), w - S(110), S(8))
		surface.SetDrawColor(COLORS.crit)
		surface.DrawRect(x + S(100), y + S(52), (w - S(110)) * math.min(v[6], 100) / 100, S(8))
	end

	for i, warning in ipairs(warnings) do
		draw.SimpleText(warning[1], "efgx.Small", x + S(10), y + S(64) + i * S(16) - S(4), warning[2], TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

-- ─── Pantalla de inconsciente ────────────────────────────────────────────────
local function drawUnconscious(v)
	local w, h = ScrW(), ScrH()
	local pulse = PH.HasFlag(v, FLAG.ARREST) and 0 or math.abs(math.sin(CurTime() * math.max(v[2], 40) / 60 * math.pi))

	surface.SetDrawColor(0, 0, 0, 245 - pulse * 15)
	surface.DrawRect(0, 0, w, h)

	draw.SimpleText("INCONSCIENTE", "efgui.Huge", w / 2, h * 0.38, COLORS.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local lines = {}
	for _, warning in ipairs(PH.Warnings(v)) do lines[#lines + 1] = warning end

	if (#lines == 0) then lines[1] = {"Esperando a recuperar el conocimiento...", COLORS.dim} end

	for i, line in ipairs(lines) do
		draw.SimpleText(line[1], "efgx.Header", w / 2, h * 0.38 + S(46) + i * S(22), line[2], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local barW = S(320)
	local by = h * 0.62
	draw.SimpleText("DAÑO CEREBRAL " .. v[6] .. "%", "efgx.Label", w / 2, by - S(10), COLORS.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	surface.SetDrawColor(30, 31, 28)
	surface.DrawRect(w / 2 - barW / 2, by, barW, S(8))
	surface.SetDrawColor(COLORS.crit)
	surface.DrawRect(w / 2 - barW / 2, by, barW * math.min(v[6], 100) / 100, S(8))

	local hint = PH.HasFlag(v, FLAG.ARREST) and "Un compañero necesita hacerte RCP (/RCP) y usar un desfibrilador."
		or (PH.HasFlag(v, FLAG.AIRWAY) and "Un compañero debe asegurarte la vía aérea (cánula de Guedel o intubación).")
		or "Un compañero puede tratarte mirándote y usando «Aplicar al compañero»."
	draw.SimpleText(hint, "efgx.Small", w / 2, by + S(30), COLORS.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "efgPhysioHUD", function()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:GetCharacter() or !client:Alive()) then return end

	local v = client:GetNetVar("efgVitals")
	if (!v) then return end

	if (PH.HasFlag(v, FLAG.UNCONSCIOUS)) then
		drawUnconscious(v)
		return
	end

	if (abnormal(v)) then drawVitals(v) end

	-- herido inconsciente delante: lo que se ve a simple vista
	local patient = PH.GetPatient(client, 150)
	local pv = patient and patient:GetNetVar("efgVitals")

	if (pv and PH.HasFlag(pv, FLAG.UNCONSCIOUS)) then
		local text = PH.HasFlag(pv, FLAG.ARREST) and "No respira y no tiene pulso"
			or (PH.HasFlag(pv, FLAG.AIRWAY) and "Inconsciente · respira con ruido (vía aérea obstruida)") or "Inconsciente · respira"

		draw.SimpleText(patient:Name(), "efgx.Header", ScrW() / 2, ScrH() * 0.58, COLORS.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(text, "efgx.Small", ScrW() / 2, ScrH() * 0.58 + S(20), COLORS.warn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)

-- con la pantalla de inconsciente no se dibuja el resto del HUD
hook.Add("HUDShouldDraw", "efgPhysioHUD", function(name)
	if (name == "CHudGMod") then return end

	local client = LocalPlayer()
	local v = IsValid(client) and client:GetNetVar("efgVitals")

	if (v and PH.HasFlag(v, FLAG.UNCONSCIOUS) and name != "CHudChat") then return false end
end)

-- ─── Shock e hipoxia: color apagado y visión de túnel ────────────────────────
local tab = {
	["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}

hook.Add("RenderScreenspaceEffects", "efgPhysioFX", function()
	local client = LocalPlayer()
	local v = IsValid(client) and client:Alive() and client:GetNetVar("efgVitals")
	if (!v or PH.HasFlag(v, FLAG.UNCONSCIOUS)) then return end

	local ratio = v[5] / PH.BLOOD_MAX
	local shock = math.Clamp((0.85 - ratio) / 0.25, 0, 1)
	local hypoxia = math.Clamp((94 - v[1]) / 24, 0, 1)
	local amount = math.max(shock, hypoxia)
	if (amount <= 0) then return end

	tab["$pp_colour_colour"] = 1 - amount * 0.75
	tab["$pp_colour_brightness"] = -amount * 0.12
	tab["$pp_colour_addb"] = hypoxia * 0.03
	DrawColorModify(tab)

	if (amount > 0.4) then DrawMotionBlur(0.2, amount * 0.6, 0.01) end
end)

-- ─── Pestaña SALUD ───────────────────────────────────────────────────────────
function PLUGIN:EFGBodyStatus(out, client)
	local v = client:GetNetVar("efgVitals")
	if (!v) then return end

	out[#out + 1] = {"icon_buff", "SpO2", v[1] .. "%", grade(v[1], 92, 85)}
	out[#out + 1] = {"icon_buff", "Sangre", math.Round(v[5]) .. " ml", grade(v[5] / PH.BLOOD_MAX, 0.85, 0.7)}

	local character = client:GetCharacter()
	local bloodType = character and character.GetEfgBloodType and character:GetEfgBloodType()
	if (bloodType and bloodType != "") then out[#out + 1] = {"icon_buff", "Grupo sanguíneo", bloodType} end

	for _, warning in ipairs(PH.Warnings(v)) do
		out[#out + 1] = {"icon_debuff", warning[1], nil, warning[2]}
	end
end
