ITEM.name = "Chaleco Defender-2"
ITEM.description = "Chaleco Defender-2 de clase 5. Datos de la wiki de EFT. [VERIFICAR] rejilla y precio."
ITEM.model = "models/eft_props/gear/armor/ar_defender2.mdl"
ITEM.category = "Chalecos"
ITEM.outfitCategory = "model"
ITEM.width = 3
ITEM.height = 3
ITEM.weight = 5.7
ITEM.noBusiness = true -- [VERIFICAR] precio pendiente

ix.efg.armor.Setup(ITEM, {class = 5, durability = 320, covers = {"thorax", "stomach"}})
