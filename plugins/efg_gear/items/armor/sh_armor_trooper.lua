ITEM.name = "Chaleco táctico modular"
ITEM.description = "Chaleco modular con ranura de placa. Clase 4."
ITEM.model = "models/eft_props/gear/armor/ar_trooper.mdl"
ITEM.category = "Chalecos"
ITEM.outfitCategory = "model"
ITEM.width = 3
ITEM.height = 3
ITEM.weight = 7

ix.efg.armor.Setup(ITEM, {class = 4, durability = 85, price = 90000, plates = true, covers = {"thorax", "stomach"}})
