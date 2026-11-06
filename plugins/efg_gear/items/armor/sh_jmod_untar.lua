ITEM.name = "Casco UNTAR"
ITEM.description = "Casco UNTAR de clase 3. Datos de la wiki de EFT. [VERIFICAR] rejilla y precio."
ITEM.model = "models/eft_props/gear/helmets/helmet_un.mdl"
ITEM.category = "Cascos"
ITEM.outfitCategory = "helmet"
ITEM.width = 2
ITEM.height = 2
ITEM.weight = 2.2
ITEM.noBusiness = true -- [VERIFICAR] precio pendiente

ix.efg.armor.Setup(ITEM, {class = 3, durability = 45, covers = {"head"}})
