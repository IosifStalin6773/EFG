-- ITEM META START --
local ITEM = ix.meta.item or {}

function ITEM:GetBaseWeight()
	return self:GetData("weight", nil) or self.weight or nil
end

function ITEM:GetWeight()
	local base = self:GetBaseWeight()
	if (!base) then return nil end

	local amount = self:GetData("Amount", 1)
	return base * amount
end

ix.meta.item = ITEM
-- ITEM META END --

-- CHARACTER META START --
local CHAR = ix.meta.character or {}

-- Peso máximo del personaje: base de config + bonus de perks (Fuerza / Mula de
-- carga) + bonus temporal de drogas (Musculoso).
function CHAR:GetMaxWeight()
	local base = ix.config.Get("maxWeight", 30)
	local bonus = (ix.perks and ix.perks.GetWeightBonus) and ix.perks.GetWeightBonus(self) or 0
	local drogas = (ix.drogas and ix.drogas.GetWeightBonus) and ix.drogas.GetWeightBonus(self) or 0
	-- efg_effects: M.U.L.E. y otros estimulantes
	local client = self.GetPlayer and self:GetPlayer()
	local mult = IsValid(client) and hook.Run("EFGGetCarryMultiplier", client) or 1
	return (base + bonus + drogas) * mult
end

function CHAR:Overweight()
	return self:GetData("carry", 0) > self:GetMaxWeight()
end

function CHAR:CanCarry(item)
	local max = self:GetMaxWeight() + ix.config.Get("maxOverWeight", 20)
	return (item:GetWeight() + self:GetData("carry", 0)) <= max
end

function CHAR:AddCarry(item)
	self:SetData("carry", math.max(self:GetData("carry", 0) + item:GetWeight(), 0))
end

function CHAR:RemoveCarry(item)
	self:SetData("carry", math.max(self:GetData("carry", 0) - item:GetWeight(), 0))
end

function CHAR:DropWeight(weight)
	self:SetData("carry", math.max(self:GetData("carry", 0) - weight, 0))
end

ix.meta.char = CHAR
-- CHARACTER META END --
