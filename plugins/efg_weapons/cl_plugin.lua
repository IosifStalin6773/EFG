local PLUGIN = PLUGIN

-- Durabilidad en el tooltip del arma
hook.Add("PopulateItemTooltip", "efgWeapons.Durability", function(tooltip, item)
	if (!item.GetData or !ix.efg.weapons.IsFirearm(item)) then return end

	local durability = ix.efg.weapons.GetDurability(item)
	local row = tooltip:AddRow("efg_wpn_durability")
	row:SetText(("DURABILIDAD: %d/%d (máx. 100)"):format(math.floor(durability), math.floor(ix.efg.weapons.GetMaxDurability(item))))
	row:SetTextColor(durability < ix.config.Get("efgJamThreshold", 70) and Color(225, 95, 80) or Color(200, 200, 200))
	row:SizeToContents()
end)

-- Brazo roto sin analgésico: el arma se balancea más (Status effects: Fracture)
function PLUGIN:CalcView(client, origin, angles)
	if (!client:Alive() or client:GetNetVar("efgPainkiller")) then return end

	local hp = client:GetNetVar("efgHP")
	if (!hp) then return end

	-- orden de ix.efg.health.parts: 4 = brazo izq, 5 = brazo der; flag 4 = fractura
	local function hurt(i) return hp[i] and (hp[i][1] <= 0 or bit.band(hp[i][2], 4) != 0) end

	if (hurt(4) or hurt(5)) then
		local t = CurTime()
		angles.p = angles.p + math.sin(t * 1.7) * 0.6
		angles.y = angles.y + math.cos(t * 1.3) * 0.8
	end
end

-- Arma averiada: recargar la arregla (Weapon_malfunctions)
function PLUGIN:PlayerBindPress(client, bind, pressed)
	if (pressed and bind:find("+reload", 1, true) and client:GetNetVar("efgMalf")) then
		RunConsoleCommand("efg_arreglar")
		return true
	end
end

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	local kind = client:GetNetVar("efgMalf")
	local weapon = client:GetActiveWeapon()
	local heat = IsValid(weapon) and weapon:GetNW2Float("efgHeat", 0) or 0
	local w, h = ScrW(), ScrH()

	if (kind) then
		local m = ix.efg.weapons.malfunctions[kind]
		local fix = client:GetNetVar("efgMalfFix")
		local text = fix and ("ARREGLANDO… %.1f s"):format(math.max(0, fix - CurTime()))
			or ((m and m.name:upper() or "FALLO") .. " · pulsa recargar")

		draw.SimpleTextOutlined(text, "ixMediumFont", w / 2, h * 0.62, Color(225, 95, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end

	if (heat > 70) then
		draw.SimpleTextOutlined("ARMA SOBRECALENTADA", "ixSmallFont", w / 2, h * 0.66, Color(240, 160, 60, 120 + (heat - 70) * 4), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end
end
