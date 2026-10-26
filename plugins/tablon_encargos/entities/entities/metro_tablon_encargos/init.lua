AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.DefaultModel = "models/props/cs_office/offcorkboarda.mdl"

function ENT:Initialize()
	local model = self.tablonModel
	if (not model or model == "" or not util.IsValidModel(model)) then
		model = self.DefaultModel
	end

	self:SetModel(Model(model))
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:DrawShadow(false)

	local physObj = self:GetPhysicsObject()
	if (IsValid(physObj)) then
		physObj:EnableMotion(false)
		physObj:Wake()
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_PVS
end

function ENT:Use(client, caller)
	local PLUGIN = ix.plugin.Get("tablon_encargos")
	if (not PLUGIN) then return end

	if ((client.ixEncargosCD or 0) > CurTime()) then return end
	client.ixEncargosCD = CurTime() + 0.5
	client.ixEncargosOpen = true

	local steamID = client:SteamID64()
	local orders = ix.encargos.orders
	local pickups = ix.encargos.pickups[steamID] or {}

	net.Start(PLUGIN.netOpen)
		net.WriteUInt(#orders, 16)
		for _, order in ipairs(orders) do
			net.WriteUInt(order.id, 32)
			net.WriteString(order.itemID)
			net.WriteString(order.itemName)
			net.WriteUInt(order.quantity, 16)
			net.WriteUInt(order.reward, 32)
			net.WriteString(order.posterName)
			net.WriteString(order.posterSteamID)
		end

		net.WriteUInt(#pickups, 8)
		for _, pickup in ipairs(pickups) do
			net.WriteString(pickup.type)
			if (pickup.type == "item") then
				net.WriteString(pickup.itemID)
				net.WriteString(pickup.itemName)
				net.WriteUInt(pickup.quantity, 16)
			elseif (pickup.type == "payment") then
				net.WriteUInt(pickup.amount, 32)
				net.WriteString(pickup.reason)
			end
		end
	net.Send(client)
end
