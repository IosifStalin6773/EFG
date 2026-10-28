ITEM.name = "Armadura pesada de Guardia de Hansa"
ITEM.coldThreshold = -20 -- Armadura pesada de defensa (plugin temperatura)
ITEM.weight = 5.0
ITEM.description = "Traje pertrechado para defender las estaciones de Hansa de hordas y ataques"
ITEM.model = "models/kek1ch/cs_heavy_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.5, -- Balas
			0.5, -- Corte
			0.8, -- Electricidad
			0.8, -- Fuego
			1, -- Radiación
			0.8, -- Ácido
			0.5, -- Explosión
}
ITEM.replacements = "models/ganza/hanza_soldier_heavy_mask.mdl"
ITEM.handsModel = "models/eft/hands/hand_scav_rainparka.mdl"

function ITEM:OnEquipped()
	if (SERVER) then
		local client = self.player
		if (IsValid(client)) then
			self:SetData("prevWalkSpeed", client:GetWalkSpeed())
			self:SetData("prevRunSpeed", client:GetRunSpeed())
			client:SetWalkSpeed(90)
			client:SetRunSpeed(120)
		end
	end
end

function ITEM:OnUnequipped()
	if (SERVER) then
		local client = self.player
		if (IsValid(client)) then
			client:SetWalkSpeed(self:GetData("prevWalkSpeed", 90))
			client:SetRunSpeed(self:GetData("prevRunSpeed", 180))
		end
	end
end