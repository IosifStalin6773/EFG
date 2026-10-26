-- ShortName del modelo asignado al ítem "nvg" (Quadtube Pro: filtro verde clásico)
local NVG_SHORTNAME = "nvg_gpnvg"

local function GetGoggleID()
	if (ArcticNVGs_ShortNameToID) then
		return ArcticNVGs_ShortNameToID[NVG_SHORTNAME] or 0
	end
	return 0
end

local function SyncNVG(client)
	if (not IsValid(client)) then return end
	local character = client:GetCharacter()
	if (not character) then return end
	local inventory = character:GetInventory()

	if (inventory and inventory:HasItem("nvg")) then
		client:SetNWInt("nvg", GetGoggleID())
	else
		client:SetNWInt("nvg", 0)
		client:SetNWBool("nvg_on", false)
	end
end

-- Sincronizar al cargar personaje (se ejecuta después de PlayerSpawn, que es donde Arctic resetea)
function PLUGIN:PlayerLoadedCharacter(client, character, lastCharacter)
	SyncNVG(client)
end

-- Ítem añadido al inventario del jugador
-- Firma real de Helix: InventoryItemAdded(oldInv, targetInv, item)
function PLUGIN:InventoryItemAdded(oldInv, targetInv, item)
	if (item.uniqueID != "nvg") then return end
	local client = targetInv:GetOwner() -- GetOwner() devuelve el jugador directamente
	if (not IsValid(client)) then return end
	client:SetNWInt("nvg", GetGoggleID())
end

-- Ítem eliminado del inventario del jugador
-- Firma real de Helix: InventoryItemRemoved(inventory, item)
function PLUGIN:InventoryItemRemoved(inventory, item)
	if (item.uniqueID != "nvg") then return end
	local client = inventory:GetOwner()
	if (not IsValid(client)) then return end
	client:SetNWInt("nvg", 0)
	client:SetNWBool("nvg_on", false)
end

-- Apagar gafas al morir
hook.Add("PlayerDeath", "NVG_Death", function(client)
	if (not IsValid(client)) then return end
	client:SetNWBool("nvg_on", false)
end)

function PLUGIN:PlayerDisconnected(client)
	-- NWVars se limpian solas al desconectar
end
