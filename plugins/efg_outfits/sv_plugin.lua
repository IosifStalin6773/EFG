local PLUGIN = PLUGIN
local outfits = ix.efg.outfits

util.AddNetworkString("ixEFGOutfitMenu")
util.AddNetworkString("ixEFGOutfitSave")

-- ropa del personaje → netvar del jugador (la dibujan los clientes)
function outfits.Sync(client)
	local character = client:GetCharacter()
	local set = character and outfits.GetSet(client:GetModel())

	if (!set) then
		client:SetNetVar("efgOutfit", nil)
		return
	end

	local data = character:GetData("efgOutfit")

	-- primer uso: ropa al azar, como un PMC recién llegado
	if (!data) then
		data = {top = math.random(0, set.tops - 1), legs = math.random(0, set.legsCount - 1)}
		character:SetData("efgOutfit", data)
	end

	local top, legs = outfits.Clamp(set, data.top, data.legs)
	client:SetNetVar("efgOutfit", {top, legs})
end

-- equipo con modelo para llevar puesto (item.efgAttach) → netvar del jugador
function outfits.SyncAttach(client)
	local character = client:GetCharacter()
	local eqInv = character and ix.GetEquipInventory and ix.GetEquipInventory(character)
	local list = {}

	if (eqInv and client:Alive()) then
		for _, item in pairs(eqInv:GetItems()) do
			if (item.efgAttach) then list[#list + 1] = item.efgAttach end
		end
	end

	table.sort(list)
	local sig = table.concat(list, ";")

	if (client.efgAttachSig != sig) then
		client.efgAttachSig = sig
		client:SetNetVar("efgAttach", #list > 0 and list or nil)
	end
end

-- equipo con pacData en las ranuras → partes de PAC del jugador. Solo toca las
-- partes de outfits.pacItems; el resto (ropa de Helix, armas) es de pac.lua.
function outfits.SyncPAC(client)
	if (!client.AddPart or !client.GetParts) then return end

	local character = client:GetCharacter()
	local eqInv = character and ix.GetEquipInventory and ix.GetEquipInventory(character)
	local wanted = {}

	-- muerto u observador (pac.lua ya quitó las partes): nada puesto
	if (eqInv and client:Alive() and !client:GetNoDraw()) then
		for _, item in pairs(eqInv:GetItems()) do
			if (outfits.pacItems[item.uniqueID]) then wanted[item.uniqueID] = item end
		end
	end

	local parts = client:GetParts() or {}

	for uniqueID, item in pairs(wanted) do
		if (!parts[uniqueID]) then client:AddPart(uniqueID, item) end
	end

	for uniqueID in pairs(parts) do
		if (outfits.pacItems[uniqueID] and !wanted[uniqueID]) then client:RemovePart(uniqueID) end
	end
end

function PLUGIN:PlayerLoadedCharacter(client)
	timer.Simple(0.5, function()
		if (IsValid(client)) then outfits.Sync(client) end
	end)
end

function PLUGIN:PlayerModelChanged(client)
	timer.Simple(0, function()
		if (IsValid(client)) then outfits.Sync(client) end
	end)
end

function PLUGIN:PostPlayerLoadout(client)
	outfits.Sync(client)
end

local nextAttach = 0

function PLUGIN:Think()
	if (nextAttach > CurTime()) then return end
	nextAttach = CurTime() + 1

	for _, client in player.Iterator() do
		if (client:GetCharacter()) then
			outfits.SyncAttach(client)
			outfits.SyncPAC(client)
		end
	end
end

-- el cadáver conserva la ropa y el equipo visible
function PLUGIN:OnPlayerCorpseCreated(client, entity)
	entity:SetNetVar("efgOutfit", client:GetNetVar("efgOutfit"))
	entity:SetNetVar("efgAttach", client:GetNetVar("efgAttach"))
end

net.Receive("ixEFGOutfitSave", function(_, client)
	local head, top, legs = net.ReadUInt(4), net.ReadUInt(8), net.ReadUInt(8)
	local character = client:GetCharacter()
	local set = character and outfits.GetSet(client:GetModel())
	if (!set or (client.InRaid and client:InRaid())) then return end

	if ((client.efgOutfitNext or 0) > CurTime()) then return end
	client.efgOutfitNext = CurTime() + 1

	local model = set.heads[head]

	if (model and model != string.lower(client:GetModel())) then
		character:SetModel(model)
	end

	top, legs = outfits.Clamp(set, top, legs)
	character:SetData("efgOutfit", {top = top, legs = legs})
	outfits.Sync(client)
	client:Notify("Atuendo guardado.")
end)
