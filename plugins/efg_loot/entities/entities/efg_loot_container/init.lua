AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel(self:GetModel() != "" and self:GetModel() or "models/props_junk/wood_crate001a.mdl")
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local physics = self:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:EnableMotion(false)
	end
end

-- El plugin se busca aquí y no en el ámbito del archivo: las entidades cargan
-- antes de que el plugin quede registrado.
function ENT:Use(activator)
	if (!IsValid(activator) or !activator:IsPlayer()) then return end

	local loot = ix.efg and ix.efg.loot

	if (loot and loot.Open) then
		loot.EnsureContainer(self)
		loot.Open(activator, self)
	end
end

function ENT:OnRemove()
	local loot = ix.efg and ix.efg.loot

	if (loot and loot.ClearEntity) then
		loot.ClearEntity(self)
	end
end
