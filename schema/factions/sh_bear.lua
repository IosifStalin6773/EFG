FACTION.name = "BEAR"
FACTION.description = "PMC de BEAR, la compañía militar privada rusa. Entra a las raids con su propio equipo y lo pierde si muere."
FACTION.color = Color(150, 60, 50)

FACTION.models = {
	"models/eft/pmcs/bear_extended_pm.mdl",
	"models/eft/pm_gear/pm/bear_pm_body.mdl",
	"models/eft/pm_gear/pm/bear_pm_armor.mdl",
	"models/eft/pm_gear/pm/bear_pm_chestrig.mdl"
}

FACTION.weapons = {"ohandsswep"}
FACTION.isDefault = true
FACTION.isGloballyRecognized = false
FACTION.includeNeeds = true

FACTION_BEAR = FACTION.index

-- Equipo inicial: lo justo para la primera raid, el resto se compra a los traders
function FACTION:OnCharacterCreated(client, character)
	local inventory = character:GetInventory()
	inventory:Add("arc9_eft_pm", 1)
	inventory:Add("ammo_pistol", 3)
	inventory:Add("arc9_eft_melee_6x5", 1)
	inventory:Add("water", 1)
	inventory:Add("canned", 1)
	inventory:Add("vendas", 2)
	inventory:Add("ai2", 1)
	inventory:Add("bala", 1, {count = 50000})
	inventory:Add("secure_alpha", 1)
end
