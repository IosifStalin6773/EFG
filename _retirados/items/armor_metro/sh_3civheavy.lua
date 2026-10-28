ITEM.name = "Armadura de Placas"
ITEM.weight = 5.0
ITEM.description = "Conjunto blindado ensamblado a partir de equipo militar reutilizado y placas improvisadas del metro. Diseñado para soportar fuego intenso, sacrificando bastante la movilidad y comodidad. Protección: Excelente"
ITEM.model = "models/kek1ch/stalker_outfit.mdl"
ITEM.height = 2
ITEM.width = 2
ITEM.price = 20
ITEM.gasmask = false -- Protege del aire contaminado
ITEM.resistance = true -- Activa la reducción de daño
ITEM.damage = { -- It is scaled; so 100 damage * 0.8 will makes the damage be 80.
			0.5, -- Balas
			0.7, -- Corte
			0.7, -- Electricidad
			0.7, -- Fuego
			1, -- Radiación
			0.7, -- Ácido
			0.7, -- Explosión
}
ITEM.coldThreshold = -10 -- Aísla del frío hasta -20°C (plugin temperatura)
ITEM.replacements = "models/magma/stalker/stalker_02.mdl"
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