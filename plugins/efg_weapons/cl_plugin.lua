local PLUGIN = PLUGIN

-- Durabilidad en el tooltip del arma
hook.Add("PopulateItemTooltip", "efgWeapons.Durability", function(tooltip, item)
	if (!item.GetData or !ix.efg.weapons.IsFirearm(item)) then return end

	local durability = ix.efg.weapons.GetDurability(item)
	local row = tooltip:AddRow("efg_wpn_durability")
	row:SetText(("DURABILIDAD: %d/100"):format(math.floor(durability)))
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
