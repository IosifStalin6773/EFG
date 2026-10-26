
ix.spoilage = ix.spoilage or {}

ix.spoilage.duration = 1200 -- 20 minutos (por defecto, para perecederos sin duración propia)
ix.spoilage.spoiledModel = Model("models/vj_base/gibs/alien/gib7.mdl")

-- Duraciones estándar para comida cruda/cocinada (ver ix.spoilage.Register).
-- Centralizadas aquí para poder ajustarlas desde un único sitio.
ix.spoilage.RAW_DURATION = 4 * 3600    -- 4 horas
ix.spoilage.COOKED_DURATION = 12 * 3600 -- 12 horas

--- Convierte un ITEM (definición) en perecedero: pasadas `duration` segundos de
-- tiempo activo (o ix.spoilage.duration si se omite) se pudre y cambia de
-- modelo. El tiempo restante solo avanza mientras el jugador dueño está
-- conectado (ver schema/libs/sv_spoilage.lua), tanto si el ítem está en su
-- inventario como en su taquilla, y nunca se reinicia al moverlo entre ambos.
-- El tiempo restante se añade a la descripción del ítem.
function ix.spoilage.Register(ITEM, duration)
	if (ITEM.isPerishable) then return end -- evita envolver GetDescription/GetModel varias veces si el archivo se recarga

	ITEM.isPerishable = true
	ITEM.spoilDuration = duration or ix.spoilage.duration

	local baseGetName = ITEM.GetName
	local baseGetDescription = ITEM.GetDescription
	local baseGetModel = ITEM.GetModel

	function ITEM:GetName()
		local name = baseGetName and baseGetName(self) or self.name

		if (self:GetData("spoiled", false)) then
			return "Restos podridos de " .. name
		end

		return name
	end

	function ITEM:GetDescription()
		if (self:GetData("spoiled", false)) then
			return "Ya no es más que basura orgánica en descomposición. Nadie en su sano juicio se lo comería."
		end

		local desc = baseGetDescription and baseGetDescription(self) or ""
		local remaining = math.max(0, self:GetData("spoilRemaining", self.spoilDuration))
		local hours = math.floor(remaining / 3600)
		local mins = math.floor((remaining % 3600) / 60)
		local secs = math.floor(remaining % 60)

		if (hours > 0) then
			return desc .. string.format("\n\nSe pudre en %d:%02d:%02d", hours, mins, secs)
		end

		return desc .. string.format("\n\nSe pudre en %d:%02d", mins, secs)
	end

	function ITEM:GetModel()
		if (self:GetData("spoiled", false)) then
			return self.spoiledModel or ix.spoilage.spoiledModel
		end

		return baseGetModel and baseGetModel(self) or self.model
	end
end
