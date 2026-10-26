ITEM.name = "Chaleco de escolta pesado"
ITEM.description = "Chaleco pesado de unidades de escolta. Admite placa. Clase 5."
ITEM.model = "models/eft_props/gear/armor/ar_korundvm.mdl"
ITEM.category = "Chalecos"
ITEM.outfitCategory = "model"
ITEM.width = 3
ITEM.height = 3
ITEM.weight = 10.5

ix.efg.armor.Setup(ITEM, {class = 5, durability = 75, price = 200000, plates = true, covers = {"thorax", "stomach"}})
