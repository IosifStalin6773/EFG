FACTION.name = "Civil del metro"
FACTION.description = "Solo hay metro."
FACTION.color = Color(244, 164, 96)

FACTION.models = {
	"models/magma/civilian/civilian_undershirt_redux.mdl",
	"models/magma/civilian/civilian_dress_girl2.mdl"
}

FACTION.weapons = {"ohandsswep"}
FACTION.isDefault = true
FACTION.isGloballyRecognized = false
FACTION.includeNeeds = true

FACTION_CIVIL = FACTION.index

function FACTION:OnCharacterCreated(client, character)
    local inventory = character:GetInventory()
    inventory:Add("flashlight", 1)
	inventory:Add("cw_kry_metro_2k33_revolver", 2)
    inventory:Add("ammo_pistol", 3)
    inventory:Add("water", 3)
    inventory:Add("canned", 3)
    inventory:Add("Bala", 100)
    inventory:Add("vendas", 2)
	inventory:Add("dinamo", 1)
end