-- Recalculo único del equipo protector de un jugador: peso, ergonomía, velocidad de
-- giro y clase efectiva por zona del cuerpo. La usan efg_ballistics, efg_health y la UI
-- para no repartir la fórmula por varios plugins.
-- Los campos efgErgoPenalty y efgTurnPenalty de cada ítem son opcionales (0 si faltan).
-- Con efgArmorModular desactivado solo cuenta el equipo monolítico (comportamiento antiguo).

ix.efg = ix.efg or {}
ix.efg.armor = ix.efg.armor or {}

local armor = ix.efg.armor

-- Devuelve todos los ítems de armadura equipados del personaje (sin duplicar).
local function equippedArmor(character)
	local list, seen = {}, {}
	local inventories = {character:GetInventory()}
	local equipInv = ix.GetEquipInventory and ix.GetEquipInventory(character)

	if (equipInv) then
		inventories[#inventories + 1] = equipInv
	end

	for _, inventory in ipairs(inventories) do
		for _, item in pairs(inventory:GetItems(true)) do
			if (item.isEFGArmor and item:GetData("equip") and !seen[item]) then
				seen[item] = true
				list[#list + 1] = item
			end
		end
	end

	return list
end

-- Recalculo completo. Devuelve una tabla {weight, ergo, turn, zones, items}.
-- zones[partID] = {class = clase efectiva más alta, item = nombre del ítem que la da}
function armor.Recalc(ply)
	local result = {weight = 0, ergo = 0, turn = 0, zones = {}, items = {}}
	local character = IsValid(ply) and ply:GetCharacter()

	if (!character) then return result end

	local modular = ix.config.Get("efgArmorModular", true)

	for _, item in ipairs(equippedArmor(character)) do
		-- con el modo modular apagado, el ítem solo cuenta si es monolítico
		if (modular or !item.efgPlates) then
			result.items[#result.items + 1] = item
			result.weight = result.weight + (item.weight or 0)

			-- ergonomía y giro solo en modo modular: apagado, siguen en 0 (saves antiguos)
			if (modular) then
				result.ergo = result.ergo + (item.efgErgoPenalty or 0)
				result.turn = result.turn + (item.efgTurnPenalty or 0)
			end

			local class = armor.EffectiveClass(item)

			for _, partID in ipairs(item.efgCovers or {}) do
				local zone = result.zones[partID]

				if (!zone or class > zone.class) then
					result.zones[partID] = {class = class, item = item.name}
				end
			end
		end
	end

	return result
end
