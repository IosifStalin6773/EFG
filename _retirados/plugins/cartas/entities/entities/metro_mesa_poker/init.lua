AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.DefaultModel = "models/props_c17/FurnitureTable002a.mdl"

function ENT:Initialize()
	local model = self.mesaModel
	if (not model or model == "" or not util.IsValidModel(model)) then
		model = self.DefaultModel
	end

	self:SetModel(Model(model))
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local physObj = self:GetPhysicsObject()
	if (IsValid(physObj)) then
		physObj:EnableMotion(false)
		physObj:Wake()
	end

	-- Estado de la mesa de póker (mesa compartida).
	self.seats = {}
	self.viewers = {}
	self.board = {}
	self.deck = {}
	self.state = "waiting"
	self.pot = 0
	self.currentBet = 0
	self.minRaise = 0
	self.dealerSeat = 0
	self.result = ""
end

function ENT:UpdateTransmitState()
	return TRANSMIT_PVS
end

function ENT:Use(client, caller)
	local PLUGIN = ix.plugin.Get("cartas")
	if (not PLUGIN) then return end

	if ((client.ixCartasCD or 0) > CurTime()) then return end
	client.ixCartasCD = CurTime() + 0.5

	if (not client:GetCharacter()) then return end
	if (not ix.cartas.PokerOpen) then return end

	ix.cartas.PokerOpen(client, self)
end

-- Devolver fichas a quien siga sentado si se elimina la mesa.
function ENT:OnRemove()
	if (not self.seats) then return end

	for _, s in pairs(self.seats) do
		if (s and s.stack > 0 and IsValid(s.client) and s.client:GetCharacter()) then
			s.client:GetCharacter():GiveMoney(s.stack)
		end
	end
end
