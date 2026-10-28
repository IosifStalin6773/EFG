ITEM.name = "Medicamento EFG"
ITEM.description = "Objeto médico."
ITEM.model = "models/props_junk/garbage_metalcan001a.mdl"
ITEM.category = "Medicamentos"
ITEM.width = 1
ITEM.height = 1
ITEM.weight = 0.1
ITEM.useTime = 3
ITEM.maxUses = 1 -- en los botiquines, puntos de vida que quedan
ITEM.useSound = "salewa" -- secuencia de sonidos de EFT (ver useSounds)

-- Sonidos de uso de EFT (content/sound/efg/health/items), repartidos a lo largo
-- de useTime en el orden de la lista.
local useSounds = {
	salewa = {"medkit_salewa_00_draw", "medkit_salewa_01_open", "medkit_salewa_02_bandagetake", "medkit_salewa_03_use", "medkit_salewa_04_end"},
	bandage = {"bandage_00_draw", "bandage_01_open", "bandage_02_bandagetake", "bandage_03_use", "bandage_04_end"},
	esmarch = {"esmarch_00_draw", "esmarch_01_use", "esmarch_02_fasten", "esmarch_03_end"},
	splint = {"splint_00_start", "splint_01_middle", "splint_02_end"},
	pills = {"pillsbottle_00_draw", "pillsbottle_01_open", "pillsbottle_02_pilltake", "pillsbottle_03_use", "pillsbottle_04_close", "pillsbottle_05_putaway"},
	surgery = {"surgicalkit_00_draw", "surgicalkit_01_scissors_draw", "surgicalkit_02_scissors_use", "surgicalkit_03_scissors_putaway",
		"surgicalkit_04_picker_draw", "surgicalkit_05_picker_use", "surgicalkit_06_picker_putaway", "surgicalkit_07_stapler_draw",
		"surgicalkit_08_stapler_use", "surgicalkit_09_stapler_putaway", "surgicalkit_10_close", "surgicalkit_11_close_button",
		"surgicalkit_12_close_button", "surgicalkit_13_putaway"}
}

local function playUseSounds(client, kind, duration)
	local list = useSounds[kind]

	if (!list) then return end

	for i, name in ipairs(list) do
		timer.Simple(duration * (i - 1) / #list, function()
			if (IsValid(client) and client:Alive()) then
				client:EmitSound("efg/health/items/item_" .. name .. ".wav", 60)
			end
		end)
	end
end

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
--   ITEM:CanApply(client, part) -> bool, motivo
--   ITEM:Apply(client, part)    -> usos gastados (0 si no ha hecho nada)
-- part es la parte del cuerpo sobre la que se ha soltado la medicina en la
-- pestaña SALUD (nil si se ha usado desde el inventario: elige la más urgente).
ITEM.functions.Use = {
	name = "Usar",
	icon = "icon16/heart.png",
	OnCanRun = function(item)
		return !IsValid(item.entity) and !item:GetData("using")
	end,
	OnRun = function(item, data)
		local client = item.player
		local part = istable(data) and isstring(data.part) and ix.efg and ix.efg.health and ix.efg.health.byID[data.part] and data.part or nil

		if (!ix.efg or !ix.efg.health or !IsValid(client)) then
			return false
		end

		ix.efg.health.GetHP(client) -- crea la tabla si el personaje aún no tiene

		local ok, reason = item:CanApply(client, part)

		if (!ok) then
			client:Notify(reason or "No lo necesitas ahora.")
			return false
		end

		item:SetData("using", true)
		client:SetAction("Usando " .. item.name .. "...", item.useTime)
		playUseSounds(client, item.useSound, item.useTime)

		local itemID = item.id

		timer.Simple(item.useTime, function()
			local current = ix.item.instances[itemID]
			if (!current) then return end

			current:SetData("using", nil)

			if (!IsValid(client) or !client:Alive() or current:GetOwner() != client) then return end

			local spent = current:Apply(client, part) or 0

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
