ITEM.name = "Analgésico"
ITEM.description = "Analgésico: quita el dolor durante 95 segundos. 4 usos."
ITEM.model = "models/props_lab/jar01b.mdl"
ITEM.useTime = 2
ITEM.maxUses = 4
ITEM.price = 7000

function ITEM:CanApply(client)
	return true
end

function ITEM:Apply(client)
	ix.efg.health.AddPainkiller(client, 95)
	return 1
end
