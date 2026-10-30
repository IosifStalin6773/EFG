-- Material médico de fisiología (efg_physio). Cada objeto define:
--   ITEM.physioKind  clave de ix.efg.physio.treatments, "blood", "saline" o "monitor"
--   ITEM.useTime     segundos (más con un brazo roto o destruido)
--   ITEM.selfUse     se puede usar sobre uno mismo
--   ITEM.maxUses     cargas (desfibrilador); 0 = no se gasta (pulsioxímetro)
-- El cliente solo pide la acción: el servidor comprueba el objeto, el paciente,
-- la distancia y el estado al empezar Y al terminar, y solo entonces lo aplica.
ITEM.name = "Material médico"
ITEM.description = "Material de soporte vital."
ITEM.model = "models/healthvial.mdl"
ITEM.category = "Medicamentos"
ITEM.width = 1
ITEM.height = 1
ITEM.weight = 0.2
ITEM.useTime = 5
ITEM.selfUse = false
ITEM.maxUses = 1
ITEM.physioKind = "guedel"
ITEM.useSoundStart = "efg/health/items/item_bandage_01_open.wav"
ITEM.useSoundEnd = "efg/health/items/item_bandage_04_end.wav"

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

	function ITEM:PopulateTooltip(tooltip)
		local row = tooltip:AddRow("efgPhysio")
		row:SetText(self.selfUse and "Uso propio o sobre un compañero (míralo y elige Aplicar)." or "Solo sobre otro jugador: míralo y elige Aplicar.")
		row:SetBackgroundColor(Color(60, 62, 56))
		row:SizeToContents()
	end
end

local PH = function() return ix.efg and ix.efg.physio end

-- texto de constantes para el pulsioxímetro
local function vitalsText(patient)
	local v = patient:GetNetVar("efgVitals")
	if (!v) then return "Sin datos." end

	local FLAG = PH().FLAG
	local text = ("%s · SpO2 %d%% · FC %d lpm · TA %d/%d · Sangre %d ml"):format(patient:Name(), v[1], v[2], v[3], v[4], v[5])

	if (PH().HasFlag(v, FLAG.ARREST)) then text = text .. " · PARADA CARDIACA" end
	if (PH().HasFlag(v, FLAG.TENSION)) then text = text .. " · neumotórax a tensión" end
	if (PH().HasFlag(v, FLAG.PNEUMO)) then text = text .. " · neumotórax" end
	if (PH().HasFlag(v, FLAG.AIRWAY)) then text = text .. " · vía aérea obstruida" end

	return text
end

-- validación común al empezar y al terminar
local function check(item, client, patient)
	local physio = PH()
	if (!physio or !IsValid(client) or !client:Alive()) then return false end

	local state = client.efgPhysio
	if (state and state.unconscious) then return false, "Estás inconsciente." end

	if (item:GetOwner() != client) then return false end
	if (!IsValid(patient) or !patient:Alive() or !patient:GetCharacter()) then return false, "El paciente ya no está." end

	if (item.physioKind == "monitor") then return true end

	return physio.CanTreat(patient, item.physioKind, item)
end

local function finish(item, client, patient)
	local physio = PH()
	local current = ix.item.instances[item.id]

	if (!current) then return end
	current:SetData("using", nil, nil, true)

	local ok, reason = check(current, client, patient)

	if (!ok) then
		if (reason) then client:Notify(reason) end
		return
	end

	if (current.physioKind == "monitor") then
		client:Notify(vitalsText(patient))
		return
	end

	local applied, message = physio.Treat(patient, current.physioKind, current)

	if (message) then client:Notify(message) end
	if (!applied) then return end

	client:EmitSound(current.useSoundEnd, 60)
	hook.Run("EFGPhysioTreated", client, patient, current.physioKind)

	if (patient != client) then
		patient:Notify(client:Name() .. " te ha aplicado: " .. current.name .. ".")
	end

	if (current.maxUses > 0) then
		local left = current:GetUses() - 1

		if (left <= 0) then
			current:Remove()
		else
			current:SetData("uses", left)
		end
	end
end

local function useTime(item, client)
	local mult = ix.efg.health and ix.efg.health.UseTimeMult and ix.efg.health.UseTimeMult(client) or 1
	return item.useTime * mult
end

ITEM.functions.Use = {
	name = "Usar",
	icon = "icon16/heart.png",
	OnCanRun = function(item)
		return item.selfUse and !IsValid(item.entity) and !item:GetData("using")
	end,
	OnRun = function(item)
		local client = item.player
		local ok, reason = check(item, client, client)

		if (!ok) then
			if (reason) then client:Notify(reason) end
			return false
		end

		local time = useTime(item, client)
		item:SetData("using", true, nil, true)
		client:EmitSound(item.useSoundStart, 60)
		client:SetAction("Usando " .. item.name .. "...", time)

		local startPos = client:GetPos()

		timer.Create("efgPhysioUse" .. client:SteamID64(), time, 1, function()
			if (!IsValid(client)) then return end

			-- moverse mucho cancela el tratamiento propio
			if (client:GetPos():DistToSqr(startPos) > 128 * 128) then
				local current = ix.item.instances[item.id]
				if (current) then current:SetData("using", nil, nil, true) end
				client:Notify("Te has movido: tratamiento cancelado.")
				return
			end

			finish(item, client, client)
		end)

		return false
	end
}

ITEM.functions.Apply = {
	name = "Aplicar al compañero",
	icon = "icon16/user_go.png",
	OnCanRun = function(item)
		local client = item.player
		local physio = PH()

		return !IsValid(item.entity) and !item:GetData("using") and IsValid(client) and physio and physio.GetPatient(client) != nil
	end,
	OnRun = function(item)
		local client = item.player
		local physio = PH()
		local patient, entity = physio.GetPatient(client)

		if (!patient) then
			client:Notify("Mira al paciente desde cerca.")
			return false
		end

		local ok, reason = check(item, client, patient)

		if (!ok) then
			if (reason) then client:Notify(reason) end
			return false
		end

		local time = useTime(item, client)
		item:SetData("using", true, nil, true)
		client:EmitSound(item.useSoundStart, 60)
		client:SetAction("Aplicando " .. item.name .. "...", time)

		client:DoStaredAction(entity, function()
			finish(item, client, patient)
		end, time, function()
			local current = ix.item.instances[item.id]
			if (current) then current:SetData("using", nil, nil, true) end
			if (IsValid(client)) then client:SetAction() end
		end, 110)

		return false
	end
}
