RECIPE.oficio = "quimico"
RECIPE.tierRequired = 1
RECIPE.name = "Lote de Pastillas Adulteradas"
RECIPE.description = "Una tanda barata y mal sintetizada. No sirve para nada salvo provocar mareos."
RECIPE.category = "Drogas"
RECIPE.model = "models/props_junk/garbage_glassbottle003a.mdl"
RECIPE.requirements = {
	["j_scrap_chems"] = 2,
}
RECIPE.results = {
	["pastilla_mareo"] = 3,
}

RECIPE:PostHook("OnCanCraft", function(recipeTable, client)
	for _, v in pairs(ents.FindByClass("ix_station_chemistrystationlvl1")) do
		if (client:GetPos():DistToSqr(v:GetPos()) < 100 * 100) then
			return true
		end
	end

	return false, L("noWorkbench")
end)
