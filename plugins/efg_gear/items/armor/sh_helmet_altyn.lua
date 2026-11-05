ITEM.name = "Casco de asalto de titanio"
ITEM.description = "Casco pesado de titanio con visor, clase 5."
ITEM.model = "models/eft_props/gear/helmets/helmet_altyn.mdl"
ITEM.category = "Cascos"
ITEM.outfitCategory = "helmet"
ITEM.width = 2
ITEM.height = 2
ITEM.weight = 4.4

ix.efg.armor.Setup(ITEM, {class = 5, durability = 36, price = 200000, material = "titan", covers = {"head"}})
ITEM.efgHelmetSlots = {visor = true, jaw = true, ears = true} -- [VERIFICAR] tabla de cascos
ITEM.efgErgoPenalty = 10 -- [VERIFICAR]
