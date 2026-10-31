PLUGIN.name = "EFG Inventario"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Inventario con TAB: ranuras de equipo, bolsillos, mochila y contenedor seguro. Menú base de Helix disponible para admins via /openHelixMenu."

-- ─── Inventario de equipo ────────────────────────────────────────────────────
-- NO se registra como bolsa (4º param): si lo fuera, su vars.isBag dispararía el
-- bloqueo "nestedBags" al intentar meter una mochila/rig dentro.
ix.EQUIP_INV_W, ix.EQUIP_INV_H = 20, 10

-- Nombres de ranura de EFT (clave → label en español)
ix.EQUIP_SLOT_NAMES = {
	headset  = "auriculares",
	helmet   = "casco",
	facecover= "cubrecaras",
	eyewear  = "gafas",
	armband  = "brazalete",
	armor    = "chaleco",
	rig      = "chaleco táctico",
	backpack = "mochila",
	secure   = "contenedor seguro",
}

-- Devuelve la ranura de equipo de EFT a la que pertenece el ítem (nil si ninguna).
function ix.GetEquipSlotKind(item)
	if (not item) then return nil end
	if (item.isSecureContainer) then return "secure" end
	-- Wearables específicos (auriculares, gafas, cubrecaras, brazalete, rig)
	if (item.efgSlot and ix.EQUIP_SLOT_NAMES[item.efgSlot]) then return item.efgSlot end
	-- Bolsas sin flag especial → mochila
	if (item.isBag and not item.efgCase) then return "backpack" end
	-- Armor / helmets del sistema de outfits
	if (item.outfitCategory == "model")   then return "armor" end
	if (item.outfitCategory == "helmet")  then return "helmet" end
end

if (ix.inventory and ix.inventory.Register) then
	ix.inventory.Register("ix_equipinv", ix.EQUIP_INV_W, ix.EQUIP_INV_H)
end

-- Devuelve el inventario de equipo del personaje (o nil).
-- Limpia vars.isBag para que no bloquee meter mochilas/rigs dentro.
function ix.GetEquipInventory(char)
	if (not char) then return nil end
	local id = char:GetData("equipInvID")
	if (not id) then return nil end
	local inv = ix.item.inventories[id]
	if (inv) then
		inv.vars.isEquipment = true
		inv.vars.isBag = nil
	end
	return inv
end

-- ─── Acceso rápido (teclas 4-8) ─────────────────────────────────────────────
-- Como en EFT: 1, 2 y 3 sacan el arma de pistolera, bandolera y espalda; las
-- ranuras del acceso rápido (1..SLOTS) van en las teclas 4 a 8 y solo admiten
-- objetos del chaleco o de los bolsillos. 9 y 0 siguen siendo del staff.
-- Se guarda en el personaje (data "hotbar" = {[ranura] = id del objeto}).
-- Helix guarda data en JSON: según cómo se cargue, las claves pueden llegar
-- como texto ("1"), así que se lee siempre con ix.hotbar.Get.
ix.hotbar = ix.hotbar or {}
ix.hotbar.SLOTS = 5
ix.hotbar.MAX_PRIMARY = 2
ix.hotbar.KEY_OFFSET = 3
ix.hotbar.WEAPON_KEYS = {"secondary", "primary", "primary2"}

-- número de tecla de una ranura (1 → "4")
function ix.hotbar.KeyLabel(index)
	return tostring((index + ix.hotbar.KEY_OFFSET) % 10)
end

function ix.hotbar.Get(char)
	local raw, out = char and char:GetData("hotbar", {}) or {}, {}

	for i = 1, ix.hotbar.SLOTS do
		local id = tonumber(raw[i] or raw[tostring(i)])
		if (id and id > 0) then out[i] = id end
	end

	return out
end

-- cualquier objeto con una acción que no sea tirarlo/combinarlo; las armas
-- tienen sus teclas propias (1-3)
function ix.hotbar.CanAssign(item)
	if (!item or item.isWeapon) then return false end

	for key in pairs(item.functions or {}) do
		if (key != "drop" and key != "combine" and key != "View" and key:sub(1, 3) != "efg") then return true end
	end

	return false
end

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")
