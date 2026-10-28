RECIPE.oficio = "quimico"
RECIPE.tierRequired = 2
RECIPE.name = "Síntesis de Energizante Sintético"
RECIPE.description = "Mezcla químicos y carbón para crear un energizante que multiplica el aguante."
RECIPE.category = "Drogas"
RECIPE.model = "models/props_lab/jar01a.mdl"
RECIPE.requirements = {
	["j_scrap_chems"] = 3,
	["j_scrap_carbon"] = 1,
}
RECIPE.results = {
	["pastilla_stamina"] = 2,
}

RECIPE:PostHook("OnCanCraft", function(recipeTable, client)
	for _, v in pairs(ents.FindByClass("ix_station_chemistrystationlvl1")) do
		if (client:GetPos():DistToSqr(v:GetPos()) < 100 * 100) then
			return true
		end
	end

	return false, L("noWorkbench")
end)
