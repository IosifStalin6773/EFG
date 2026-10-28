AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.DefaultModel = "models/props_c17/FurnitureTable001a.mdl"

function ENT:Initialize()
	if (not self.gameType or not ix.cartas.BANK_GAMES[self.gameType]) then
		self.gameType = "blackjack"
	end

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

	-- Estado de partidas por jugador en esta mesa (clave = entidad jugador).
	self.games = {}
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

	-- Si tenía una mano terminada de antes, empezar limpio en fase de apuesta.
	self.games = self.games or {}
	local game = self.games[client]
	if (game and game.state != "playing") then
		self.games[client] = nil
	end

	client.ixCartasTable = self
	ix.cartas.SendState(client, self)
end
