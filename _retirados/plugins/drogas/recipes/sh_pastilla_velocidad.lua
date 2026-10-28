RECIPE.oficio = "quimico"
RECIPE.tierRequired = 2
RECIPE.name = "Síntesis de Estimulante de Combate"
RECIPE.description = "Refina químicos y pólvora para fabricar un potente estimulante de velocidad."
RECIPE.category = "Drogas"
RECIPE.model = "models/props_junk/popcan01a.mdl"
RECIPE.requirements = {
	["j_scrap_chems"] = 3,
	["polvora"] = 1,
}
RECIPE.results = {
	["pastilla_velocidad"] = 2,
}

RECIPE:PostHook("OnCanCraft", function(recipeTable, client)
	for _, v in pairs(ents.FindByClass("ix_station_chemistrystationlvl1")) do
		if (client:GetPos():DistToSqr(v:GetPos()) < 100 * 100) then
			return true
		end
	end

	return false, L("noWorkbench")
end)
