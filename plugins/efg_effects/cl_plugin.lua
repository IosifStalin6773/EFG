local PLUGIN = PLUGIN

local FX = ix.efg.effects

-- Iconos en la pantalla SALUD (efg_health HEALTH:BodyStatus)
function PLUGIN:EFGBodyStatus(out, client)
	local now = CurTime()
	local shown = {}

	for _, e in ipairs(FX.Get(client)) do
		if (e[2] > now and (e[4] or 0) <= now and !shown[e[1]]) then
			shown[e[1]] = true

			local negative = FX.negative[e[1]] or ((e[1] == "regen" or e[1] == "water" or e[1] == "energy") and (e[3] or 0) < 0)
			out[#out + 1] = {negative and "icon_debuff" or "icon_buff", FX.names[e[1]] or e[1], math.ceil(e[2] - now) .. "s",
				negative and Color(225, 95, 80) or Color(120, 200, 120)}
		end
	end
end

-- Temblor de manos (estimulantes, intoxicación, alcohol)
function PLUGIN:CalcView(client, origin, angles)
	if (!client:Alive()) then return end

	local tremor = FX.Has(client, "tremor") or FX.Has(client, "toxin")
	local alcohol = FX.Has(client, "alcohol")

	if (tremor or alcohol) then
		local t = CurTime()
		local k = alcohol and 1.6 or 1
		angles.p = angles.p + math.sin(t * 8.1) * 0.3 * k + math.sin(t * 21.7) * 0.1
		angles.y = angles.y + math.cos(t * 6.9) * 0.3 * k
		angles.r = angles.r + (alcohol and math.sin(t * 0.7) * 2 or 0)
	end
end

local vignette = Material("vgui/gradient-r")

function PLUGIN:HUDPaintBackground()
	local client = LocalPlayer()
	if (!client:Alive()) then return end

	local tunnel = FX.Has(client, "tunnel") or FX.Has(client, "fatigue")

	if (tunnel) then
		local w, h = ScrW(), ScrH()
		local edge = w * 0.25

		surface.SetMaterial(vignette)
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawTexturedRectRotated(edge / 2, h / 2, edge, h, 180)
		surface.DrawTexturedRectRotated(w - edge / 2, h / 2, edge, h, 0)
	end

	if (FX.Has(client, "radiation")) then
		surface.SetDrawColor(120, 255, 120, 10 + math.abs(math.sin(CurTime() * 2)) * 10)
		surface.DrawRect(0, 0, ScrW(), ScrH())
	end
end

function PLUGIN:RenderScreenspaceEffects()
	local client = LocalPlayer()

	if (IsValid(client) and client:Alive() and FX.Has(client, "alcohol")) then
		DrawMotionBlur(0.15, 0.6, 0.01)
	end
end

-- Descripción de los estimulantes en el tooltip
hook.Add("PopulateItemTooltip", "efgEffects.Stim", function(tooltip, item)
	if (!item.efgStim) then return end

	local row = tooltip:AddRow("efg_stim")
	row:SetText(FX.Describe(item.efgStim))
	row:SetTextColor(Color(200, 200, 200))
	row:SizeToContents()
end)
