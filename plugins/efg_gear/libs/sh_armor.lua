-- Armaduras de EFT: clase (1-6), durabilidad en puntos y zonas que cubre.
-- Va en libs/ porque Helix carga libs antes que los ítems y así los ítems
-- pueden llamar a ix.efg.armor.Setup al definirse.

ix.efg = ix.efg or {}
ix.efg.armor = ix.efg.armor or {}

local armor = ix.efg.armor

-- daño que absorbe cada clase con la armadura nueva (con menos durabilidad absorbe menos)
armor.protection = {[1] = 0.2, [2] = 0.35, [3] = 0.5, [4] = 0.62, [5] = 0.72, [6] = 0.8}

-- parte del daño absorbido que se resta de la durabilidad
armor.durabilityDamage = 0.15

-- cada reparación pierde este porcentaje de lo que faltaba (como en EFT)
armor.repairDegradation = 0.1

armor.partNames = {
	head = "Cabeza", thorax = "Tórax", stomach = "Estómago",
	larm = "Brazo izq.", rarm = "Brazo der.", lleg = "Pierna izq.", rleg = "Pierna der."
}

-- data = {class, durability, covers = {"thorax", ...}, price}
function armor.Setup(ITEM, data)
	ITEM.isEFGArmor = true
	ITEM.efgArmorClass = data.class
	ITEM.efgMaxDurability = data.durability
	ITEM.efgCovers = data.covers
	ITEM.price = data.price or ITEM.price

	-- desactiva el sistema de resistencias y desgaste de better_armor: la protección
	-- la calcula efg_health por zona del cuerpo
	ITEM.resistance = false
	ITEM.durabilityLoss = 0
	ITEM.damage = {1, 1, 1, 1, 1, 1, 1}

	function ITEM:GetEFGMaxDurability()
		return self:GetData("efgRepairMax", self.efgMaxDurability)
	end

	function ITEM:GetEFGDurability()
		return self:GetData("efgDurability", self:GetEFGMaxDurability())
	end

	function ITEM:GetDescription()
		local covers = {}

		for _, partID in ipairs(self.efgCovers or {}) do
			covers[#covers + 1] = armor.partNames[partID] or partID
		end

		return ("%s\n\nClase de protección: %d\nDurabilidad: %d/%d\nProtege: %s"):format(
			self.description, self.efgArmorClass,
			math.ceil(self:GetEFGDurability()), math.ceil(self:GetEFGMaxDurability()),
			table.concat(covers, ", "))
	end

	-- en EFT se puede llevar una armadura rota (simplemente no protege)
	function ITEM:CanEquipOutfit()
		return true
	end

	ITEM.functions.RepararConKit = {
		name = "Reparar con kit",
		icon = "icon16/wrench.png",
		OnRun = function(item)
			local client = item.player
			local character = IsValid(client) and client:GetCharacter()
			if (!character) then return false end

			local kit = character:GetInventory():HasItem("kit_reparacion_armadura")

			if (!kit) then
				client:Notify("Necesitas un kit de reparación de armadura.")
				return false
			end

			local current = item:GetEFGDurability()
			local maximum = item:GetEFGMaxDurability()
			-- GetCalidadReparacion devuelve 70–100: calidad del 100% = sin pérdida permanente
			local quality = hook.Run("GetCalidadReparacion", character) or 70
			local loss = (1 - quality / 100) * (maximum - current)
			local newMax = math.max(1, maximum - loss)

			kit:Remove()
			item:SetData("efgRepairMax", newMax)
			item:SetData("efgDurability", newMax)
			hook.Run("OnEquipoReparado", client)
			client:Notify(("Has reparado %s (%d/%d)."):format(item.name, math.ceil(newMax), item.efgMaxDurability))

			return false
		end,
		OnCanRun = function(item)
			return !IsValid(item.entity) and IsValid(item.player) and item:GetEFGDurability() < item:GetEFGMaxDurability()
		end
	}
end

-- ─── Balística de penetración ────────────────────────────────────────────────
-- Potencia de penetración (0-100) por nombre de tipo de munición de GMod/Arc9.
-- Los nombres coinciden con swep.Primary.Ammo en minúsculas.
-- Calibres no listados usan el valor "default".
armor.ammoPen = {
	-- Pistola
	["9x18pm"]       = 15,  -- 9x18 PM Pst gs
	["9x19para"]     = 22,  -- 9x19 FMJ
	["9x19"]         = 22,
	["357"]          = 28,
	["pistol"]       = 15,  -- fallback pistola
	-- SMG / PDW
	["4.6x30"]       = 36,
	["46x30"]        = 36,
	["5.7x28"]       = 38,
	["57x28"]        = 38,
	["smg1"]         = 22,  -- fallback SMG
	-- Subfusil / shotgun
	["9mm"]          = 20,
	["12g"]          = 6,   -- perdigones
	["12gauge"]      = 6,
	["20g"]          = 5,
	["buckshot"]     = 5,
	-- Rifle de asalto
	["545x39"]       = 42,  -- 5.45x39 PS
	["5.45x39"]      = 42,
	["556x45"]       = 45,  -- 5.56x45 M855
	["5.56x45"]      = 45,
	["762x39"]       = 36,  -- 7.62x39 PS
	["7.62x39"]      = 36,
	["762x35"]       = 38,  -- .300 Blackout
	["ar2"]          = 42,  -- fallback rifle
	-- DMR / francotirador
	["762x51"]       = 58,  -- 7.62x51 M80
	["7.62x51"]      = 58,
	["762x54r"]      = 55,  -- 7.62x54R LPS
	["7.62x54r"]     = 55,
	["338lapua"]     = 88,  -- .338 Lapua AP
	["127x55"]       = 70,  -- 12.7x55
	-- Fallback genérico
	["default"]      = 25
}

-- Umbral de penetración por clase de armadura (pen mínima para empezar a reducir protección)
armor.penThreshold = {[1] = 15, [2] = 25, [3] = 35, [4] = 45, [5] = 55, [6] = 65}

-- Devuelve la potencia de penetración de un tipo de munición por su nombre GMod
function armor.GetBulletPen(ammoName)
	if (!ammoName or ammoName == "") then return armor.ammoPen.default end
	return armor.ammoPen[string.lower(ammoName)] or armor.ammoPen.default
end

-- Multiplicador de protección efectiva tras aplicar la penetración (0.05 - 1.0).
-- penFactor < 1 significa que la bala supera (al menos parcialmente) la armadura.
function armor.GetPenFactor(pen, armorClass)
	local threshold = armor.penThreshold[armorClass] or 50
	if (pen <= threshold) then return 1.0 end
	-- entre el umbral y el doble del umbral: reducción lineal a 0.05
	local excess = pen - threshold
	return math.Clamp(1.0 - excess / threshold, 0.05, 1.0)
end

-- Protección que da un ítem ahora mismo (0 si está roto)
function armor.GetProtection(item)
	local maximum = item.efgMaxDurability or 1
	local durability = item:GetEFGDurability()

	if (durability <= 0) then return 0 end

	return (armor.protection[item.efgArmorClass] or 0) * (0.5 + 0.5 * math.Clamp(durability / maximum, 0, 1))
end

-- Armaduras equipadas que cubren una parte del cuerpo
function armor.GetCovering(character, partID)
	local result = {}
	local inventories = {character:GetInventory()}
	local equipInv = ix.GetEquipInventory and ix.GetEquipInventory(character)

	if (equipInv) then
		inventories[#inventories + 1] = equipInv
	end

	for _, inventory in ipairs(inventories) do
		for _, item in pairs(inventory:GetItems(true)) do
			if (item.isEFGArmor and item:GetData("equip") and item.efgCovers and table.HasValue(item.efgCovers, partID)) then
				result[#result + 1] = item
			end
		end
	end

	return result
end
