AddCSLuaFile()

ENT.Type 			= "anim"
ENT.PrintName = "Stash"
ENT.Category 	= "Helix"
ENT.Spawnable = true
ENT.AdminOnly = true

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_c17/Lockers001a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)

		local physics = self:GetPhysicsObject()
		physics:EnableMotion(false)
		physics:Sleep()

		self.lockerID = self.savedLockerID or ix.strongbox.GetNextLockerID()
	end

	-- las taquillas SÍ permiten que varias personas la usen a la vez (cada una ve su
	-- propio contenido, guardado aparte por personaje vía dataKey), a diferencia de
	-- los cadáveres que son de un solo saqueador a la vez (ver persistent_corpses.lua),
	-- así que no hace falta rastrear ni avisar "en uso".
	function ENT:Use(activator)
		self.nextUse = self.nextUse or CurTime()
		if (self.nextUse > CurTime()) then
			return
		else
			self.nextUse = CurTime() + 1
		end

		timer.Simple(0.7, function()
			local closeSeq = self:LookupSequence("Close")
			self:ResetSequence(closeSeq)
			self:EmitSound("items/ammocrate_close.wav")
		end)

		ix.strongbox.Open(activator, self, "strongbox")
	end
end
