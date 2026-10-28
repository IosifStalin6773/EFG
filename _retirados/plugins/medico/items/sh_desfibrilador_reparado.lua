ITEM.name = "Desfibrilador Reparado"
ITEM.weight = 1.5
ITEM.description = "Desfibrilador médico restaurado y funcional. Solo un médico cualificado sabe usarlo para reanimar a un superviviente recién caído."
ITEM.model = Model("models/illusion/eftcontainers/defib.mdl")
ITEM.category = "Medicamentos"
ITEM.width = 1
ITEM.height = 1
ITEM.noBusiness = true

-- Solo los médicos pueden usarlo, y no estando soltado en el suelo.
local function PuedeUsar(item)
	if (IsValid(item.entity)) then return false end

	local client = item.player
	if (!IsValid(client)) then return false end

	local character = client:GetCharacter()
	if (!character) then return false end

	return character:GetOficio() == "medico"
end

ITEM.functions.Revivir = {
	name = "Revivir",
	tip = "Apunta al cadáver de un superviviente caído recientemente para reanimarlo.",
	icon = "icon16/heart.png",
	OnRun = function(item)
		local plugin = ix.plugin.Get("medico")
		if (plugin) then
			plugin:IntentarRevivir(item.player, item)
		end

		return false
	end,
	OnCanRun = function(item)
		return PuedeUsar(item)
	end
}
