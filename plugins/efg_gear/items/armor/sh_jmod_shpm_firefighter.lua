ITEM.name = "Casco de bombero SHPM"
ITEM.description = "Casco de bombero SHPM de clase 2. Datos de la wiki de EFT. [VERIFICAR] rejilla y precio."
ITEM.model = "models/eft_props/gear/helmets/helmet_shpm.mdl"
ITEM.category = "Cascos"
ITEM.outfitCategory = "helmet"
ITEM.width = 2
ITEM.height = 2
ITEM.weight = 1.5
ITEM.noBusiness = true -- [VERIFICAR] precio pendiente

ix.efg.armor.Setup(ITEM, {class = 2, durability = 96, covers = {"head"}})
