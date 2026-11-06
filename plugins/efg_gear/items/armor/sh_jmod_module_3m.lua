ITEM.name = "Chaleco BNTI Module-3M"
ITEM.description = "Chaleco BNTI Module-3M de clase 2. Datos de la wiki de EFT. [VERIFICAR] rejilla y precio."
ITEM.model = "models/eft_props/gear/armor/ar_module3m.mdl"
ITEM.category = "Chalecos"
ITEM.outfitCategory = "model"
ITEM.width = 3
ITEM.height = 3
ITEM.weight = 6
ITEM.noBusiness = true -- [VERIFICAR] precio pendiente

ix.efg.armor.Setup(ITEM, {class = 2, durability = 80, covers = {"thorax", "stomach"}})
