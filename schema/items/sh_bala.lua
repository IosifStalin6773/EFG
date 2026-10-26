ITEM.name = "Rublos"
ITEM.weight = 0.01
ITEM.model = Model("models/m2033r/npc/dark_child_ammo.mdl")
ITEM.description = "Un fajo de rublos. La moneda principal de la zona."
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = true
ITEM.noTrade = true
-- Apilable sin límite: la UI (Ctrl+clic) lo trata como stack aunque no tenga maxstack.
ITEM.unlimitedStack = true

-- ── Recoger del suelo: auto-stackear con el montón existente ──────────────
ITEM.functions.take = {
	tip = "takeTip",
	icon = "icon16/box.png",
	OnCanRun = function(item)
		return IsValid(item.entity)
	end,
	OnRun = function(item)
		local client   = item.player
		local char     = client:GetCharacter()
		if not char then return false end

		local inventory = char:GetInventory()
		if not inventory then return false end

		local pickupCount = item:GetData("count", 1)
		local existing    = inventory:GetItemsByUniqueID("bala")
		local stack       = existing[1]

		if stack then
			-- Ya hay un montón: sumar y destruir el item del suelo limpiamente
			stack:SetData("count", stack:GetData("count", 1) + pickupCount)
			-- ixIsSafe evita que ENT:OnRemove borre de la DB (item:Remove lo hará)
			item.entity.ixIsSafe = true
			item:Remove()
			client:EmitSound("npc/zombie/foot_slide" .. math.random(1, 3) .. ".wav", 75, math.random(90, 120), 1)
			return false  -- PerformInventoryAction no hace más limpieza
		else
			-- Sin montón existente: transferencia normal al inventario
			local bSuccess, err = item:Transfer(inventory:GetID(), nil, nil, client)
			if not bSuccess then
				client:NotifyLocalized(err or "unknownError")
				return false
			end
			client:EmitSound("npc/zombie/foot_slide" .. math.random(1, 3) .. ".wav", 75, math.random(90, 120), 1)
			if item.data then
				for k, v in pairs(item.data) do
					item:SetData(k, v)
				end
			end
			return true
		end
	end
}

-- ── Fusionar dos montones arrastrando uno encima del otro ─────────────────
ITEM.functions.combine = {
	OnCanRun = function(item, data)
		local other = ix.item.instances[data[1]]
		return other ~= nil and other.uniqueID == "bala" and other.id ~= item.id
	end,
	OnRun = function(item, data)
		local other = ix.item.instances[data[1]]
		if not other or other.uniqueID ~= "bala" or other.id == item.id then
			return false
		end

		local myCount    = item:GetData("count", 1)
		local otherCount = other:GetData("count", 1)
		item:SetData("count", myCount + otherCount)

		local otherInv = ix.item.inventories[other.invID]
		if otherInv then
			otherInv:Remove(other.id)
		end

		return false  -- no eliminar el item destino
	end
}

-- ── Juntar todos los montones de balas en uno ────────────────────────────
ITEM.functions.Juntar = {
	name = "Juntar todo",
	tip  = "Fusiona todos los montones de rublos (incluye taquilla abierta).",
	icon = "icon16/add.png",
	OnCanRun = function(item)
		return not IsValid(item.entity)
	end,
	OnRun = function(item)
		local client = item.player
		local char   = client:GetCharacter()
		if not char then return false end

		local inv = char:GetInventory()
		if not inv then return false end

		local inventories = {inv}
		local storageInv  = client.ixOpenStorage
		if storageInv and storageInv ~= inv then
			inventories[#inventories + 1] = storageInv
		end

		local total = 0
		for _, currentInv in ipairs(inventories) do
			for _, v in pairs(currentInv:GetItems()) do
				if v.uniqueID == "bala" then
					total = total + v:GetData("count", 1)
					v:Remove()
				end
			end
		end

		if total > 0 then
			inv:Add("bala", 1, {count = total})
		end

		client:EmitSound("ambient/materials/dinnerplates1.wav", 65, 130)
		return false
	end
}

-- ── Dividir el montón ─────────────────────────────────────────────────────
ITEM.functions.split = {
	name = "balaSplit",
	icon = "icon16/arrow_divide.png",
	OnCanRun = function(item)
		return not IsValid(item.entity) and item:GetData("count", 1) > 1
	end,
	OnClick = function(item)
		local maxSplit = item:GetData("count", 1) - 1

		Derma_StringRequest(
			L("balaSplitTitle"),
			L("balaSplitPrompt", maxSplit),
			tostring(math.floor(maxSplit / 2)),
			function(text)
				local amount = math.floor(tonumber(text) or 0)
				if amount >= 1 and amount <= maxSplit then
					net.Start("ix_bala_split")
						net.WriteUInt(item.id, 32)
						net.WriteUInt(amount, 32)
					net.SendToServer()
				end
			end
		)
		return false  -- no enviar la acción genérica al servidor
	end,
	OnRun = function(item, data)
		return false
	end
}

-- ── Dibujar el contador encima del icono del inventario ───────────────────
if CLIENT then
	function ITEM:PaintOver(item, w, h)
		local count = item:GetData("count", 1)
		draw.SimpleText(
			count, "DermaDefault", w - 5, h - 5,
			color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black
		)
	end
end
