ITEM.name = "Carne extraña"
ITEM.weight = 0.2
ITEM.description = "Un trozo de carne de rata recien capturada. Cruda no es buena idea, pero asada da para varias recetas."
ITEM.model = Model("models/props_junk/garbage_takeoutcarton001a.mdl")
ITEM.category = "Comestibles"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 10
ITEM.maxstack = 64

-- ── Recoger del suelo: auto-stackear con montones existentes ──────────────
ITEM.functions.take = {
	tip  = "takeTip",
	icon = "icon16/box.png",
	OnCanRun = function(item)
		return IsValid(item.entity)
	end,
	OnRun = function(item)
		local client = item.player
		local char   = client:GetCharacter()
		if (not char) then return false end

		local inventory = char:GetInventory()
		if (not inventory) then return false end

		local remaining = item:GetData("Amount", 1)
		local maxS      = item.maxstack or 64

		for _, v in pairs(inventory:GetItems()) do
			if (remaining <= 0) then break end
			if (v.uniqueID == item.uniqueID) then
				local current = v:GetData("Amount", 1)
				if (current < maxS) then
					local toAdd = math.min(remaining, maxS - current)
					v:SetData("Amount", current + toAdd)
					remaining = remaining - toAdd
				end
			end
		end

		if (remaining <= 0) then
			item.entity.ixIsSafe = true
			item:Remove()
			client:EmitSound("npc/zombie/foot_slide" .. math.random(1, 3) .. ".wav", 75, math.random(90, 120), 1)
			return false
		end

		item:SetData("Amount", remaining)
		local bSuccess, err = item:Transfer(inventory:GetID(), nil, nil, client)

		if (not bSuccess) then
			client:NotifyLocalized(err or "unknownError")
			return false
		end

		client:EmitSound("npc/zombie/foot_slide" .. math.random(1, 3) .. ".wav", 75, math.random(90, 120), 1)
		return true
	end,
}

ITEM.functions.Comer = {
	sound = "npc/barnacle/barnacle_crunch3.wav",
	OnRun = function(item)
		local client = item.player
		local character = client:GetCharacter()
		if (character) then
			character:RestoreSatiety(8)
			ix.needs.TryIntoxicate(client)
		end

		local cur = item:GetData("Amount", 1) - 1
		if (cur <= 0) then
			return true
		end

		item:SetData("Amount", cur)
		return false
	end,
	OnCanRun = function(item)
		return IsValid(item.player) and not IsValid(item.entity)
	end
}

-- ── Separar 1 unidad del stack ─────────────────────────────────────────────
ITEM.functions.Separar = {
	name = "Separar",
	tip  = "Saca una unidad del montón.",
	icon = "icon16/delete.png",
	OnCanRun = function(item)
		if (IsValid(item.entity)) then return false end
		return item:GetData("Amount", 1) > 1
	end,
	OnRun = function(item)
		local client = item.player
		local inv    = client:GetCharacter():GetInventory()

		item:SetData("Amount", item:GetData("Amount", 1) - 1)

		-- Si es perecedero, la unidad separada debe conservar el mismo tiempo
		-- restante de podredumbre del montón del que sale, no reiniciarlo a
		-- la duración completa (inv:Add sin datos crea el ítem "de cero").
		local extraData = nil
		if (item.isPerishable) then
			extraData = {
				spoilRemaining = item:GetData("spoilRemaining", item.spoilDuration or ix.spoilage.duration),
				spoiled = item:GetData("spoiled", false) or nil,
			}
		end

		local x = inv:Add(item.uniqueID, 1, extraData)
		if (not x) then
			ix.item.Spawn(item.uniqueID, client:GetItemDropPos(), nil, nil, extraData)
		end

		client:EmitSound("ambient/materials/dinnerplates1.wav", 65, 80)
		return false
	end,
}

-- ── Juntar todos los ítems del mismo tipo en un stack ─────────────────────
ITEM.functions.Juntar = {
	name = "Juntar todo",
	tip  = "Fusiona todos los montones del mismo tipo (incluye taquilla abierta).",
	icon = "icon16/add.png",
	OnCanRun = function(item)
		if (IsValid(item.entity)) then return false end
		return (item.maxstack or 1) > 1
	end,
	OnRun = function(item)
		local client = item.player
		local inv    = client:GetCharacter():GetInventory()
		local maxS   = item.maxstack or 64
		local total  = 0

		local inventories = {inv}
		local storageInv  = client.ixOpenStorage
		if (storageInv and storageInv ~= inv) then
			inventories[#inventories + 1] = storageInv
		end

		for _, currentInv in ipairs(inventories) do
			for _, v in pairs(currentInv:GetItems()) do
				if (v.uniqueID == item.uniqueID) then
					total = total + v:GetData("Amount", 1)
					v:Remove()
				end
			end
		end

		local pos = client:GetItemDropPos()
		for _, currentInv in ipairs(inventories) do
			while (total > 0) do
				local chunk = math.min(total, maxS)
				local x = currentInv:Add(item.uniqueID, 1, {Amount = chunk})
				if (not x) then break end
				total = total - chunk
			end
		end

		while (total > 0) do
			local chunk = math.min(total, maxS)
			total = total - chunk
			ix.item.Spawn(item.uniqueID, pos, nil, nil, {Amount = chunk})
		end

		client:EmitSound("ambient/materials/dinnerplates1.wav", 65, 130)
		return false
	end,
}

-- ── Combinar arrastrando un ítem sobre otro del mismo tipo ────────────────
ITEM.functions.combine = {
	OnCanRun = function(item, data)
		local other = ix.item.instances[data[1]]
		return other ~= nil and other.uniqueID == item.uniqueID and other.id ~= item.id
	end,
	OnRun = function(item, data)
		local other = ix.item.instances[data[1]]
		if (not other or other.uniqueID ~= item.uniqueID or other.id == item.id) then
			return false
		end

		local maxS     = item.maxstack or 64
		local myAmt    = item:GetData("Amount", 1)
		local otherAmt = other:GetData("Amount", 1)
		local combined = myAmt + otherAmt

		if (combined <= maxS) then
			item:SetData("Amount", combined)
			local otherInv = ix.item.inventories[other.invID]
			if (otherInv) then
				otherInv:Remove(other.id)
			end
		else
			item:SetData("Amount", maxS)
			other:SetData("Amount", combined - maxS)
		end

		item.player:EmitSound("ambient/materials/dinnerplates1.wav", 65, 130)
		return false
	end,
}

-- ── Mostrar cantidad en la esquina del slot ───────────────────────────────
if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		local qty = item:GetData("Amount", 1)
		if (qty > 1) then
			draw.SimpleText(
				tostring(qty),
				"DermaDefault",
				w - 4, h - 2,
				Color(80, 255, 80),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM
			)
		end
	end
end

ix.spoilage.Register(ITEM, ix.spoilage.RAW_DURATION)
