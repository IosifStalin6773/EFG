ITEM.name = "Chaleco RBAV-AF"
ITEM.description = "Chaleco RBAV-AF de clase 3. Datos de la wiki de EFT. [VERIFICAR] rejilla y precio."
ITEM.model = "models/eft_props/gear/armor/cr/cr_bae_rbav_af.mdl"
ITEM.category = "Chalecos"
ITEM.outfitCategory = "model"
ITEM.width = 3
ITEM.height = 3
ITEM.weight = 4
ITEM.noBusiness = true -- [VERIFICAR] precio pendiente

ix.efg.armor.Setup(ITEM, {class = 3, durability = 120, covers = {"thorax", "stomach"}})
