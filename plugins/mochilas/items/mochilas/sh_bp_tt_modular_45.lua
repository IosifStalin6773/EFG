ITEM.name = "Mochila modular 45 L"
ITEM.description = "Mochila modular de 45 L. La tapa superior se puede quitar para ganar espacio en la carga."
ITEM.model = "models/eft_props/gear/backpacks/bp_daypack.mdl" -- [VERIFICAR] modelo propio
ITEM.category = "Mochilas"
ITEM.width = 3
ITEM.height = 5
ITEM.invWidth = 5
ITEM.invHeight = 9 -- con la tapa puesta; ix.efg.backpack.Apply ajusta el resto
ITEM.weight = 1.4
ITEM.noBusiness = true -- [VERIFICAR] precio pendiente
ITEM.efgBackpack = "tt_modular_45"

ITEM.functions.efgFlapOff = {
	name = "Quitar tapa",
	OnRun = function(item)
		local ok, err = ix.efg.backpack.SetFlap(item, false, item.player)

		if (!ok and item.player) then
			item.player:Notify("No se puede quitar la tapa: hay ítems en la fila superior.")
		end

		return false
	end,
	OnCanRun = function(item)
		return !IsValid(item.entity) and ix.efg.backpack.FlapOn(item)
	end
}

ITEM.functions.efgFlapOn = {
	name = "Poner tapa",
	OnRun = function(item)
		ix.efg.backpack.SetFlap(item, true, item.player)

		return false
	end,
	OnCanRun = function(item)
		return !IsValid(item.entity) and !ix.efg.backpack.FlapOn(item)
	end
}
