FACTION.name = "Scav"
FACTION.description = "Saqueador local de la zona. Entra a la raid con equipo aleatorio y no arriesga nada de tu PMC."
FACTION.color = Color(110, 110, 80)

FACTION.models = {
	"models/eft/scavs/scav_extended_pm.mdl",
	-- Raider de Welcome To Tarkov
	"models/eft_raider_male.mdl"
}

FACTION.weapons = {"ohandsswep"}
-- No se elige al crear personaje: lo asignará el sistema de Scav run
FACTION.isDefault = false
FACTION.isGloballyRecognized = false
FACTION.includeNeeds = true

FACTION_SCAV = FACTION.index
