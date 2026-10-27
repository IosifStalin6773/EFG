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

function WEP.GetDurability(item)
	return math.Clamp(tonumber(item:GetData("durability", 100)) or 100, 0, 100)
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

-- ─── Reparación con el kit de armas (Repair) ────────────────────────────────
function PLUGIN:InitializedPlugins()
	for _, item in pairs(ix.item.list) do
		if (WEP.IsFirearm(item)) then
			item.functions = item.functions or {}
			item.functions.efgRepair = {
				name = "Reparar (kit de armas)",
				icon = "icon16/wrench.png",
				OnCanRun = function(it)
					if (!WEP.IsFirearm(it) or IsValid(it.entity) or WEP.GetDurability(it) >= 100) then return false end

					local client = it.player
					local character = IsValid(client) and client:GetCharacter()

					return character != nil and character:GetInventory():HasItem("weptools") != false
				end,
				OnRun = function(it)
					local client = it.player
					local character = client:GetCharacter()
					local kit = character:GetInventory():HasItem("weptools")

					if (!kit) then return false end

					-- la calidad depende de Mantenimiento (70-100 %)
					local quality = hook.Run("GetCalidadReparacion", character) or 85
					it:SetData("durability", math.max(WEP.GetDurability(it), quality))
					kit:Remove()

					hook.Run("OnEquipoReparado", client)
					client:Notify(("Arma reparada al %d%%."):format(quality))

					return false
				end
			}
		end
	end
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
