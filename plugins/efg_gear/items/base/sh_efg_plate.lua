-- items/base/sh_efg_plate.lua
-- Placa balística extraíble. Se inserta en chalecos con ranura de placa
-- (ix.efg.armor.Setup con plates = true) y mientras tenga durabilidad
-- manda su clase. La durabilidad viaja en data "durability".

ITEM.name           = "Placa balística"
ITEM.description    = "Placa rígida para chaleco portaplacas."
ITEM.model          = "models/props_debris/metal_panel02a.mdl"
ITEM.width          = 2
ITEM.height         = 2
ITEM.weight         = 2.5
ITEM.category       = "Placas"
ITEM.isEFGPlate     = true
ITEM.plateClass     = 3
ITEM.plateDurability = 40

function ITEM:GetDescription()
	return ("%s\n\nClase de protección: %d\nDurabilidad: %d/%d"):format(self.description, self.plateClass,
		math.ceil(self:GetData("durability", self.plateDurability)), self.plateDurability)
end
