local PLUGIN = PLUGIN

PLUGIN.name = "EFG Armas"
PLUGIN.author = "EFG"
PLUGIN.description = "Desgaste de armas, encasquillamientos, reparación con kit y efectos de los brazos heridos al disparar."

-- Fuentes (wiki de EFT):
--   Weapon durability ... https://escapefromtarkov.fandom.com/wiki/Weapon_malfunctions
--   Repair .............. https://escapefromtarkov.fandom.com/wiki/Repair
--   Status effects ...... https://escapefromtarkov.fandom.com/wiki/Status_effects (fractura de brazo)
-- Valores [VERIFICAR]: configurables, la wiki no es accesible desde el entorno de desarrollo.

ix.efg = ix.efg or {}
ix.efg.weapons = ix.efg.weapons or {}

local WEP = ix.efg.weapons

ix.config.Add("efgWeaponWearPerShot", 0.03, "[VERIFICAR wiki: Weapon_malfunctions] Durabilidad (de 100) que pierde un arma por disparo.", nil, {
	data = {min = 0, max = 1, decimals = 3}, category = "EFG Armas"
})
ix.config.Add("efgJamThreshold", 70, "[VERIFICAR wiki: Weapon_malfunctions] Por debajo de esta durabilidad el arma puede encasquillarse.", nil, {
	data = {min = 0, max = 100}, category = "EFG Armas"
})
ix.config.Add("efgJamMaxChance", 4, "[VERIFICAR] Probabilidad (%) de encasquillarse por disparo con durabilidad 0.", nil, {
	data = {min = 0, max = 50, decimals = 1}, category = "EFG Armas"
})
ix.config.Add("efgJamSeconds", 2.5, "Segundos que tarda en desencasquillarse.", nil, {
	data = {min = 0.5, max = 10, decimals = 1}, category = "EFG Armas"
})

ix.config.Add("efgHeatPerShot", 1.2, "[VERIFICAR wiki: Weapon_overheating] Calor (de 100) que suma cada disparo.", nil, {
	data = {min = 0, max = 10, decimals = 2}, category = "EFG Armas"
})
ix.config.Add("efgHeatCooling", 4, "Calor que pierde el arma por segundo.", nil, {
	data = {min = 0, max = 30, decimals = 1}, category = "EFG Armas"
})
ix.config.Add("efgRepairKitDegrade", 0.08, "[VERIFICAR wiki: Repair] Parte de lo que faltaba que se pierde de durabilidad máxima al reparar con kit (la habilidad la reduce).", nil, {
	data = {min = 0, max = 0.5, decimals = 3}, category = "EFG Armas"
})

-- Tipos de fallo (Weapon_malfunctions): peso relativo y segundos para arreglarlo
WEP.malfunctions = {
	misfire    = {name = "Fallo de disparo",     weight = 30, seconds = 0.8},
	jam        = {name = "Vaina encasquillada",  weight = 30, seconds = 2.5},
	feed       = {name = "Fallo de alimentación", weight = 25, seconds = 2.0},
	doublefeed = {name = "Doble alimentación",   weight = 15, seconds = 3.5}
}

-- Durabilidad máxima: baja con cada reparación (Repair)
function WEP.GetMaxDurability(item)
	return math.Clamp(tonumber(item:GetData("efgMaxDur", 100)) or 100, 1, 100)
end

function WEP.GetDurability(item)
	return math.Clamp(tonumber(item:GetData("durability", 100)) or 100, 0, WEP.GetMaxDurability(item))
end

-- Repara hasta el máximo actual, perdiendo `degrade` de lo que faltaba
function WEP.Repair(item, degrade)
	local maximum = WEP.GetMaxDurability(item)
	local current = WEP.GetDurability(item)
	local newMax = math.max(1, maximum - (maximum - current) * degrade)

	item:SetData("efgMaxDur", math.Round(newMax, 1))
	item:SetData("durability", math.floor(newMax))
	item.efgWearAcc = 0

	return newMax
end

function WEP.IsFirearm(item)
	return item and item.isWeapon and isstring(item.class) and item.class:find("^arc9_") != nil
end

-- Brazos: con un brazo roto o destruido y sin analgésico no se puede apuntar
-- con ambos brazos destruidos (Status effects: Fracture / Blacked limb).
hook.Add("StartCommand", "ixEFGWeaponArms", function(client, cmd)
	if (!client:Alive() or !client:GetNetVar("efgArmsOut")) then return end

	cmd:RemoveKey(IN_ATTACK2)
end)

-- Con el arma averiada no se puede disparar hasta arreglarla
hook.Add("StartCommand", "ixEFGWeaponMalfunction", function(client, cmd)
	if (client:GetNetVar("efgMalf")) then
		cmd:RemoveKey(IN_ATTACK)
	end
end)

-- ─── Reparación con el kit de armas (Repair) ────────────────────────────────
function PLUGIN:InitializedPlugins()
	for _, item in pairs(ix.item.list) do
		if (WEP.IsFirearm(item)) then
			item.functions = item.functions or {}
			item.functions.efgRepair = {
				name = "Reparar (kit de armas)",
				icon = "icon16/wrench.png",
				OnCanRun = function(it)
					if (!WEP.IsFirearm(it) or IsValid(it.entity) or WEP.GetDurability(it) >= WEP.GetMaxDurability(it)) then return false end

					local client = it.player
					local character = IsValid(client) and client:GetCharacter()

					return character != nil and character:GetInventory():HasItem("weptools") != false
				end,
				OnRun = function(it)
					local client = it.player
					local character = client:GetCharacter()
					local kit = character:GetInventory():HasItem("weptools")

					if (!kit) then return false end

					-- la calidad depende de Mantenimiento (70-100 %): mejor calidad, menos pérdida
					local quality = hook.Run("GetCalidadReparacion", character) or 85
					local degrade = ix.config.Get("efgRepairKitDegrade", 0.08) * (1.5 - quality / 100)
					local newMax = WEP.Repair(it, degrade)
					kit:Remove()

					hook.Run("OnEquipoReparado", client)
					client:Notify(("Arma reparada: %d/%d (máximo perdido %.1f)."):format(math.floor(newMax), 100, 100 - newMax))

					return false
				end
			}
		end
	end
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
