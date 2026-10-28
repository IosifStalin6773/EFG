ITEM.name = "Botiquín de Médico"
ITEM.weight = 1.0
ITEM.description = "Maletín médico profesional. Solo un médico cualificado sabe emplearlo para curar, tratar heridas y rebajar la radiación de otros supervivientes."
ITEM.model = Model("models/illusion/eftcontainers/grizzly.mdl")
ITEM.category = "Medicamentos"
ITEM.width = 2
ITEM.height = 1
ITEM.price = 75

-- Usos restantes del botiquín (por defecto, según config del plugin).
function ITEM:getUsos()
	return self:GetData("usos", ix.config.Get("medico_botiquin_usos", 10))
end

if (CLIENT) then
	function ITEM:PopulateTooltip(tooltip)
		local usos = self:getUsos()

		local panel = tooltip:AddRowAfter("name", "usos")
		panel:SetBackgroundColor(Color(41, 74, 128))
		panel:SetText(usos .. " usos restantes")
		panel:SizeToContents()
	end
end

-- Consume un uso del botiquín; si se agota, elimina el ítem.
function ITEM:ConsumirUso()
	local restantes = self:getUsos() - 1
	self:SetData("usos", restantes)

	if (restantes <= 0) then
		if (IsValid(self.player)) then
			self.player:Notify("El botiquín se ha quedado sin material.")
		end
		self:Remove()
	end
end

-- Solo los médicos pueden usar las funciones del botiquín, y no estando soltado.
local function PuedeUsar(item)
	if (IsValid(item.entity)) then return false end

	local client = item.player
	if (!IsValid(client)) then return false end

	local character = client:GetCharacter()
	if (!character) then return false end

	return character:GetOficio() == "medico"
end

ITEM.functions.Curar = {
	name = "Curar a otro",
	tip = "Apunta a un superviviente y mantén la posición 10 segundos para restaurar su vida.",
	icon = "icon16/heart_add.png",
	OnRun = function(item)
		local plugin = ix.plugin.Get("medico")
		if (plugin) then
			plugin:IniciarTratamiento(item.player, item, "curar")
		end

		return false
	end,
	OnCanRun = function(item)
		return PuedeUsar(item)
	end
}

ITEM.functions.Tratar = {
	name = "Tratar heridas",
	tip = "Apunta a un superviviente y mantén la posición 10 segundos para retirar sus heridas.",
	icon = "icon16/user_add.png",
	OnRun = function(item)
		local plugin = ix.plugin.Get("medico")
		if (plugin) then
			plugin:IniciarTratamiento(item.player, item, "tratar")
		end

		return false
	end,
	OnCanRun = function(item)
		return PuedeUsar(item)
	end
}

ITEM.functions.Radiacion = {
	name = "Rebajar Radiación",
	tip = "Apunta a un superviviente y mantén la posición 10 segundos para rebajar su radiación.",
	icon = "icon16/shield_add.png",
	OnRun = function(item)
		local plugin = ix.plugin.Get("medico")
		if (plugin) then
			plugin:IniciarTratamiento(item.player, item, "radiacion")
		end

		return false
	end,
	OnCanRun = function(item)
		return PuedeUsar(item)
	end
}

function ITEM:OnInstanced(invID, x, y)
	-- OnInstanced corre DESPUÉS de asignar item.data; sobrescribir aquí borraría
	-- los usos preservados al recomprar/restaurar un botiquín ya gastado (exploit).
	if (self:GetData("usos") == nil) then
		self:SetData("usos", ix.config.Get("medico_botiquin_usos", 10))
	end
end
