-- [VERIFICAR wiki: Medical] valores de memoria
ITEM.name = "Ibuprofeno"
ITEM.description = "Analgésico durante 280 segundos. 15 usos."
ITEM.model = "models/props_lab/jar01b.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.useTime = 2
ITEM.maxUses = 15
ITEM.price = 14000
ITEM.useSound = "pills"
ITEM.painSeconds = 280

function ITEM:CanApply(client)
	return true
end

function ITEM:Apply(client)
	ix.efg.health.AddPainkiller(client, self.painSeconds)
	return 1
end
