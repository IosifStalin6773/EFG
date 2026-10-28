RECIPE.oficio = "quimico"
RECIPE.tierRequired = 2
RECIPE.name = "Síntesis de Pastilla de Yoduro"
RECIPE.description = "Combina químicos y carbón para crear pastillas que bloquean la radiación."
RECIPE.category = "Drogas"
RECIPE.model = "models/props_lab/jar01c.mdl"
RECIPE.requirements = {
	["j_scrap_chems"] = 3,
	["j_scrap_carbon"] = 2,
}
RECIPE.results = {
	["pastilla_radiacion"] = 2,
}

RECIPE:PostHook("OnCanCraft", function(recipeTable, client)
	for _, v in pairs(ents.FindByClass("ix_station_chemistrystationlvl1")) do
		if (client:GetPos():DistToSqr(v:GetPos()) < 100 * 100) then
			return true
		end
	end

	return false, L("noWorkbench")
end)
