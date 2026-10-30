FACTION.name = "USEC"
FACTION.description = "PMC de la compañía militar privada USEC, contratada por TerraGroup. Entra a las raids con su propio equipo y lo pierde si muere."
FACTION.color = Color(70, 110, 160)

FACTION.models = {
	"models/eft/pmcs/usec_extended_pm.mdl",
	"models/eft/pm_gear/pm/usec_pm_body.mdl",
	"models/eft/pm_gear/pm/usec_pm_armor.mdl",
	"models/eft/pm_gear/pm/usec_pm_chestrig.mdl",
	-- Welcome To Tarkov (ropa modular con /Atuendo)
	"models/eft_usec1.mdl",
	"models/eft_usec3.mdl",
	"models/eft_usec4.mdl",
	"models/eft_usec5.mdl"
}

FACTION.weapons = {"ohandsswep"}
FACTION.isDefault = true
FACTION.isGloballyRecognized = false
FACTION.includeNeeds = true

FACTION_USEC = FACTION.index

-- Equipo común de todo PMC; las armas, el chaleco y los médicos los da el rol
-- elegido en el creador (efg_pmc/sh_creation.lua, PMC.roles)
function FACTION:OnCharacterCreated(client, character)
	local inventory = character:GetInventory()
	inventory:Add("arc9_eft_melee_6x5", 1)
	inventory:Add("water", 1)
	inventory:Add("canned", 1)
	inventory:Add("rublos", 1, {count = 50000})
	inventory:Add("secure_alpha", 1)
end
