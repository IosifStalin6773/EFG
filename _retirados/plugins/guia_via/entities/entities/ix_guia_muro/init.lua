AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetNoDraw(true)
	self:DrawShadow(false)
end

-- Redefine el tamaño real (invisible) del muro a partir de medio-largo, medio-grosor
-- y alto en unidades locales. La base queda en Z local 0 y crece hacia arriba.
-- Se llama justo después de Spawn().
function ENT:SetupSize(halfLen, halfThick, height)
	self:ApplyBox(Vector(-halfLen, -halfThick, 0), Vector(halfLen, halfThick, height))
end

-- Igual que SetupSize, pero para un suelo/losa: la SUPERFICIE queda en Z local 0
-- (la altura a la que debe rodar la dresina) y el grosor crece hacia abajo, para
-- que el bulto/escombro real del mapa quede siempre por debajo de la superficie.
function ENT:SetupFloor(halfLen, halfWidth, thickness)
	self:ApplyBox(Vector(-halfLen, -halfWidth, -thickness), Vector(halfLen, halfWidth, 0))
end

function ENT:ApplyBox(mins, maxs)
	self:PhysicsInitBox(mins, maxs)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionBounds(mins, maxs)

	local phys = self:GetPhysicsObject()
	if (IsValid(phys)) then
		phys:EnableMotion(false)
	end
end
