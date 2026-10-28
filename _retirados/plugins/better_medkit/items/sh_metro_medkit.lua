ITEM.name = "Botiquín"
ITEM.weight = 0.5
ITEM.description = "Una caja pequeña naranja que contiene 5 jeringuillas médicas."
ITEM.model = Model("models/weapons/krycek/metro_2k33/prop_medkit_phys.mdl")
ITEM.price = 50
ITEM.IsMMedkit = true
ITEM.iconCam = {
	pos = Vector(403.6, 339.46, 247.68),
	ang = Angle(25, 220, 0),
	fov = 1.80
}

if (CLIENT) then
	function ITEM:PopulateTooltip(tooltip)
		local syringe = tonumber(self:getSyringe()) or 0

		local panel = tooltip:AddRowAfter("name", "syringe_number")
		panel:SetBackgroundColor(Color(39, 174, 96))
		panel:SetText(syringe .. " jeringuillas restantes")
		panel:SizeToContents()

		
	end
end

function ITEM:getSyringe()
	return self:GetData("syringe", 5)
end



-- Devuelve la vida máxima real teniendo en cuenta las heridas acumuladas.
-- Usa el plugin medico si está disponible; cae a GetMaxHealth() si no.
local function GetVidaMaxima(client)
	local char = IsValid(client) and client:GetCharacter()
	local medicoPlugin = ix.plugin.Get("medico")
	if (medicoPlugin and char) then
		return medicoPlugin:CalcularVidaMaxima(char:GetHeridas() or 0)
	end
	return client:GetMaxHealth()
end

local function healPlayer(client, item)

	client.syringeAnim = item:GetData("syringe", 5)

	local activeWep = client:GetActiveWeapon()
	client.previousWep = IsValid(activeWep) and activeWep:GetClass() or "ix_hands"
	client:Give( "weapon_jr_m2k33_medkit" )
	client:SelectWeapon("weapon_jr_m2k33_medkit")
	timer.Simple( 2, function()
		if (!IsValid(client) or !client:Alive()) then return end
		client:StripWeapon("weapon_jr_m2k33_medkit")
		client:SelectWeapon(client.previousWep or "ix_hands")
		client.previousWep = nil
		client.syringeAnim = client.syringeAnim - 1
		item:SetData("syringe", item:GetData("syringe", 5) - 1)

		if (SERVER) then
			local maxhp = GetVidaMaxima(client)
			local hp = client:Health()

			-- Conocimientos Médicos: curas más con la misma jeringuilla.
			local healMult = hook.Run("AdjustHealAmount", client, client:GetCharacter()) or 1
			client:SetHealth( math.Clamp( hp + math.Round(25 * healMult), 0, maxhp ) )
			hook.Run("OnCuracionRealizada", client, true)
			if (!timer.Exists( "medkit_healing_" .. client:AccountID() )) then
				timer.Create( "medkit_healing_" .. client:AccountID(), 5, 50, function()
					if (!client:Alive()) then return end
					local lim = GetVidaMaxima(client)
					if (client:Health() >= lim) then return timer.Remove( "medkit_healing_" .. client:AccountID() ) end
					client:SetHealth( math.Clamp( client:Health() + 1, 0, lim ) )
				end)
			end
		end

		if item:GetData("syringe", 5) == 0 then
			client:SetLocalVar("syringe", nil)
			item:Remove()
		end
	end )

end


function ITEM:Heal(client, item)

	if (!client:Alive()) then return false end
	if item:getSyringe() <= 0 then return false end
	local maxhp = GetVidaMaxima(client)

	if (client:Health() >= maxhp) then
		client:Notify("No te puedes curar mas")
		return false
	end
	healPlayer(client, item)

end

ITEM.functions.heal = {
    name = "Curar",
	tip = "Heal yourself",
	icon = "icon16/heart_add.png",
	OnRun = function(item)
        local client = item.player

        if (!client:Alive()) then return false end
        if item:getSyringe() <= 0 then return false end
		local maxhp = GetVidaMaxima(client)

		if (client:Health() >= maxhp) then
			client:Notify("No te puedes curar mas")
			return false
		end
        healPlayer(client, item)

        return false
    end,
    OnCanRun = function(item)
		return (!IsValid(item.entity))
	end
}

function ITEM:OnInstanced(invID, x, y)
	self:SetData("syringe", 5)
end