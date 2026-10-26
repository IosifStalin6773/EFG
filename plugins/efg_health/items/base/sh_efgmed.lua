ITEM.name = "Medicamento EFG"
ITEM.description = "Objeto médico."
ITEM.model = "models/props_junk/garbage_metalcan001a.mdl"
ITEM.category = "Medicamentos"
ITEM.width = 1
ITEM.height = 1
ITEM.weight = 0.1
ITEM.useTime = 3
ITEM.maxUses = 1 -- en los botiquines, puntos de vida que quedan

function ITEM:GetUses()
	return self:GetData("uses", self.maxUses)
end

if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		if (item.maxUses > 1) then
			draw.SimpleText(item:GetUses() .. "/" .. item.maxUses, "DermaDefault", w - 5, h - 5,
				color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black)
		end
	end
end

-- Cada medicamento define:
--   ITEM:CanApply(client) -> bool, motivo
--   ITEM:Apply(client)    -> usos gastados (0 si no ha hecho nada)
ITEM.functions.Use = {
	name = "Usar",
	icon = "icon16/heart.png",
	OnCanRun = function(item)
		return !IsValid(item.entity) and !item:GetData("using")
	end,
	OnRun = function(item)
		local client = item.player

		if (!ix.efg or !ix.efg.health or !IsValid(client)) then
			return false
		end

		ix.efg.health.GetHP(client) -- crea la tabla si el personaje aún no tiene

		local ok, reason = item:CanApply(client)

		if (!ok) then
			client:Notify(reason or "No lo necesitas ahora.")
			return false
		end

		item:SetData("using", true)
		client:SetAction("Usando " .. item.name .. "...", item.useTime)
		client:EmitSound("items/medshot4.wav", 60, 110)

		local itemID = item.id

		timer.Simple(item.useTime, function()
			local current = ix.item.instances[itemID]
			if (!current) then return end

			current:SetData("using", nil)

			if (!IsValid(client) or !client:Alive() or current:GetOwner() != client) then return end

			local spent = current:Apply(client) or 0

			if (spent > 0) then
				hook.Run("OnCuracionRealizada", client, true)
				local left = current:GetUses() - spent

				if (left <= 0) then
					current:Remove()
				else
					current:SetData("uses", left)
				end
			end
		end)

		return false
	end
}
