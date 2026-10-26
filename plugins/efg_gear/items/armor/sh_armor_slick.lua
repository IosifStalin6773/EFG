ITEM.name = "Portaplacas ligero"
ITEM.description = "Portaplacas ligero de clase 6 con ranura de placa. Solo cubre el tórax."
ITEM.model = "models/eft_props/gear/armor/ar_slick_b.mdl"
ITEM.category = "Chalecos"
ITEM.outfitCategory = "model"
ITEM.width = 3
ITEM.height = 3
ITEM.weight = 8

ix.efg.armor.Setup(ITEM, {class = 6, durability = 80, price = 450000, plates = true, covers = {"thorax"}})
