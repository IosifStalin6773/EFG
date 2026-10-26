
ITEM.name = "Vendas"
ITEM.weight = 0.1
ITEM.description = "Venda: detiene un sangrado leve por uso."
-- modelo del addon de medicinas si está instalado; si no, uno de HL2
ITEM.model = file.Exists("models/weapons/sweps/eft/afak/w_meds_afak.mdl", "GAME") and "models/weapons/sweps/eft/afak/w_meds_afak.mdl" or "models/healthvial.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Medicamentos"
ITEM.maxUses = 4
ITEM.iconCam = {
	pos = Vector(403.6, 339.46, 247.68),
	ang = Angle(25, 220, 0),
	fov = 1.80
}


function ITEM:OnInstanced(invID, x, y, item)
	if item then
		item:SetData("uses", item.maxUses)
	end
end

function ITEM:GetUses()
	return self:GetData("uses", self.maxUses)
end

function ITEM:SetUses(n)
	self:SetData("uses", math.max(n, 0))
end

if CLIENT then
	function ITEM:PopulateTooltip(tooltip)
		local uses = self:GetData("uses", self.maxUses)
		local maxUses = self.maxUses
		local panel = tooltip:AddRowAfter("name", "uses")
		panel:SetText("Usos: " .. uses .. "/" .. maxUses)
		panel:SizeToContents()
	end
end

ITEM.functions.Apply = {
	name = "Aplicar",
	tip = "useTip",
	icon = "icon16/tick.png",
	OnCanRun = function(item)
		if item:GetData("bandaging", false) then return false end
		return item:GetData("uses", item.maxUses) > 0
	end,
	OnRun = function(item)
		local ply = item.player
		if not IsValid(ply) then return false end

		item:SetData("bandaging", true)

		local class = "weapon_eft_afak"
		-- sin el addon de animaciones no se da el SWEP: solo barra de acción
		local wep = ix.eftMeds.GiveAndSelectMedWep(ply, class, item)

		if SERVER and IsValid(wep) then
			ply:GiveAmmo(60, "afak", true)
		end

		local function PlayMedsSequence(ply2, list, gap)
			gap = tonumber(gap) or 0.45
			local t = 0
			for _, snd in ipairs(list) do
				timer.Simple(t, function()
					if IsValid(ply2) then ply2:EmitSound(snd) end
				end)
				t = t + gap
			end
		end

		PlayMedsSequence(ply, {
			"MedsGrizzly.Open",
			"MedsGeneric.Rustle",
			"MedsGeneric.Rustle",
			"MedsGeneric.Close"
		}, 0.45)

		if IsValid(wep) and wep.StartBandageSequence then
			wep:StartBandageSequence(true)
		end

		local duration = 6.0
		ply:SetAction("Aplicando Vendaje...", duration)

		timer.Simple(duration, function()
			if not IsValid(ply) then return end

			item:SetData("bandaging", false)

			local newUses = item:GetUses() - 1
			item:SetUses(newUses)

			if SERVER then
				if newUses > 0 then
					ply:Notify("Vendaje aplicado. Usos restantes: " .. newUses)
				else
					ply:Notify("Vendaje agotado.")
				end

				-- EFG: la venda detiene un sangrado leve (no cura vida, como en EFT)
				if (ix.efg and ix.efg.health and ply.efgHP) then
					ix.efg.health.StopBleeding(ply, "light")
				end

				if IsValid(ply:GetWeapon(class)) then
					ply:StripWeapon(class)
				end
				local left = ply:GetAmmoCount("afak")
				if left > 0 then ply:RemoveAmmo(left, "afak") end

				if newUses <= 0 then item:Remove() end
			end

			local prevClass = item:GetData("prevWepClass")
			if prevClass then
				local prevW = ply:GetWeapon(prevClass)
				if IsValid(prevW) then ply:SelectWeapon(prevClass) end
			end
		end)

		return false
	end
}
