local PLUGIN = PLUGIN

ix.generadores = ix.generadores or {}

-- Ordena dos vectores en (min, max) por componente para Vector:WithinAABox.
local function sortVector(v1, v2)
	local vMin, vMax = Vector(0, 0, 0), Vector(0, 0, 0)

	for i = 1, 3 do
		if (v1[i] >= v2[i]) then
			vMax[i], vMin[i] = v1[i], v2[i]
		else
			vMax[i], vMin[i] = v2[i], v1[i]
		end
	end

	return vMin, vMax
end

-- ─── Consultas ────────────────────────────────────────────────────────────────

function ix.generadores.getAll()
	return PLUGIN.generators
end

-- Devuelve el generador cuya área contiene esa posición (o nil).
function ix.generadores.getGeneratorAt(pos)
	for _, entry in ipairs(PLUGIN.generators) do
		if (pos:WithinAABox(entry.vMin, entry.vMax)) then
			return entry
		end
	end
end

function PLUGIN:GetGeneratorByID(id)
	for _, entry in ipairs(PLUGIN.generators) do
		if (entry.id == id) then
			return entry
		end
	end
end

-- ─── Entidad ──────────────────────────────────────────────────────────────────

function PLUGIN:UpdateGeneratorNetVars(entry)
	if (IsValid(entry.ent)) then
		entry.ent:SetNetVar("fuel", math.floor(entry.fuel))
		entry.ent:SetNetVar("powered", entry.powered == true)
	end
end

function PLUGIN:SpawnGeneratorEntity(entry)
	if (IsValid(entry.ent)) then
		entry.ent:Remove()
	end

	local ent = ents.Create("metro_generator")
	if (not IsValid(ent)) then return end

	ent:SetPos(entry.pos)
	ent:SetAngles(entry.ang)
	ent:Spawn()
	ent:Activate()
	ent.genID = entry.id

	-- Límites del área (fijos): el cliente los usa para el apagón de pantalla.
	ent:SetNetVar("areaMin", entry.vMin)
	ent:SetNetVar("areaMax", entry.vMax)

	entry.ent = ent
	entry.powered = nil -- fuerza el recálculo del estado de luces
	self:SetGeneratorPowered(entry, entry.fuel > 0)
	self:UpdateGeneratorNetVars(entry)

	return ent
end

function PLUGIN:SpawnAllGenerators()
	for _, entry in ipairs(PLUGIN.generators) do
		if (not IsValid(entry.ent)) then
			self:SpawnGeneratorEntity(entry)
		end
	end

	-- Reaplica el estado de las luces por si tunnel_lights las spawnea después
	-- (ambos usan InitPostEntity/PostCleanupMap y el orden no está garantizado).
	timer.Simple(2, function()
		for _, entry in ipairs(PLUGIN.generators) do
			entry.powered = nil
			PLUGIN:SetGeneratorPowered(entry, entry.fuel > 0)
		end
	end)
end

-- ─── Energía: luces del área + frío (vía hook de temperatura) ─────────────────

-- Clases de luz reales del mapa que se intentan conmutar. Las luces HORNEADAS por
-- VRAD no existen como entidad y se ignoran (limitación del motor); solo se apagan
-- las que el mapa conservó con nombre/estado conmutable.
local LIGHT_CLASSES = {"light", "light_spot", "light_dynamic"}

function PLUGIN:SetGeneratorPowered(entry, bPowered)
	if (entry.powered == bPowered) then return end
	entry.powered = bPowered

	local input = bPowered and "TurnOn" or "TurnOff"

	for _, class in ipairs(LIGHT_CLASSES) do
		for _, light in ipairs(ents.FindByClass(class)) do
			if (IsValid(light) and light:GetPos():WithinAABox(entry.vMin, entry.vMax)) then
				light:Fire(input)
			end
		end
	end

	if (IsValid(entry.ent)) then
		entry.ent:SetNetVar("powered", bPowered)
	end

	hook.Run("GeneratorPowerChanged", entry, bPowered)
end

-- El área sin energía enfría a quien esté dentro (lo consume el plugin temperatura).
hook.Add("GetExtraColdTemp", "ixGeneradores", function(client, pos)
	local coldTemp = ix.config.Get("gen_frio_temp", -15)

	for _, entry in ipairs(PLUGIN.generators) do
		if (not entry.powered and pos:WithinAABox(entry.vMin, entry.vMax)) then
			return coldTemp
		end
	end
end)

-- ─── Alta / baja / repostaje ──────────────────────────────────────────────────

function PLUGIN:AddGenerator(v1, v2, pos, ang)
	local vMin, vMax = sortVector(v1, v2)

	local entry = {
		id = PLUGIN.nextGenID,
		vMin = vMin,
		vMax = vMax,
		pos = pos,
		ang = ang,
		fuel = ix.config.Get("gen_max_horas", 24) * 3600, -- arranca con el tanque lleno (24 h)
		powered = nil,
	}

	PLUGIN.nextGenID = PLUGIN.nextGenID + 1
	PLUGIN.generators[#PLUGIN.generators + 1] = entry

	self:SpawnGeneratorEntity(entry)
	self:SaveData()

	return entry
end

function PLUGIN:RemoveGenerator(entry)
	-- Restaura las luces antes de borrar (deja el área encendida).
	self:SetGeneratorPowered(entry, true)

	if (IsValid(entry.ent)) then
		entry.ent:Remove()
	end

	for i = #PLUGIN.generators, 1, -1 do
		if (PLUGIN.generators[i] == entry) then
			table.remove(PLUGIN.generators, i)
			break
		end
	end

	self:SaveData()
end

-- Consume un bidón de combustible del inventario del jugador.
local function TakeFuelItem(client)
	local char = client:GetCharacter()
	if (not char) then return false end

	local inv = char:GetInventory()
	if (not inv) then return false end

	for _, item in pairs(inv:GetItems()) do
		if (item.uniqueID == GENERATOR_FUEL_ITEM) then
			item:Remove()
			return true
		end
	end

	return false
end

function PLUGIN:RefuelGenerator(entry, client)
	local maxFuel = ix.config.Get("gen_max_horas", 24) * 3600
	local perDrum = ix.config.Get("gen_horas_bidon", 6) * 3600

	if (entry.fuel >= maxFuel) then
		return client:Notify("El generador ya tiene el tanque lleno.")
	end

	if (not TakeFuelItem(client)) then
		return client:Notify("Necesitas un Bidón de gasolina en tu inventario.")
	end

	entry.fuel = math.min(maxFuel, entry.fuel + perDrum)
	self:SetGeneratorPowered(entry, entry.fuel > 0)
	self:UpdateGeneratorNetVars(entry)
	self:SaveData()

	if (IsValid(entry.ent)) then
		entry.ent:EmitSound("ambient/machines/machine1_hit1.wav", 70)
	end

	client:Notify("Has repostado el generador. Autonomía: " .. GeneratorFormatFuel(entry.fuel) .. ".")
end

-- ─── Consumo de combustible (pausable en restart) ─────────────────────────────
-- Se decrementa en vivo solo mientras el servidor corre; al reiniciar se restaura
-- el valor guardado, así el tiempo restante NO se pierde ni se consume apagado.

local TICK = 10

timer.Create("ixGeneradoresTick", TICK, 0, function()
	for _, entry in ipairs(PLUGIN.generators) do
		if (entry.fuel > 0) then
			entry.fuel = math.max(0, entry.fuel - TICK)
			PLUGIN:UpdateGeneratorNetVars(entry)

			if (entry.fuel <= 0) then
				PLUGIN:SetGeneratorPowered(entry, false)
			end
		elseif (entry.powered) then
			PLUGIN:SetGeneratorPowered(entry, false)
		end
	end
end)

-- ─── Persistencia ─────────────────────────────────────────────────────────────
-- Se guarda desde la tabla en memoria (no desde las entidades), así es seguro
-- incluso durante el apagado y el combustible restante queda registrado.

function PLUGIN:SaveData()
	local data = {}

	for _, entry in ipairs(PLUGIN.generators) do
		data[#data + 1] = {
			id = entry.id,
			vMin = entry.vMin,
			vMax = entry.vMax,
			pos = entry.pos,
			ang = entry.ang,
			fuel = math.floor(entry.fuel),
		}
	end

	self:SetData(data)
end

function PLUGIN:LoadData()
	local data = self:GetData()
	if (not data) then return end

	PLUGIN.generators = {}
	local maxID = 0

	for _, v in ipairs(data) do
		local entry = {
			id = v.id or (maxID + 1),
			vMin = v.vMin,
			vMax = v.vMax,
			pos = v.pos,
			ang = v.ang,
			fuel = v.fuel or 0,
			powered = nil,
		}

		PLUGIN.generators[#PLUGIN.generators + 1] = entry
		maxID = math.max(maxID, entry.id)
	end

	PLUGIN.nextGenID = maxID + 1

	self:SpawnAllGenerators()
end
-- Nota: no hace falta ShutDown ni PostCleanupMap propios. Helix ya llama a
-- SaveData cada 600 s, en GM:ShutDown y en GM:PreCleanupMap; y GM:PostCleanupMap
-- re-ejecuta LoadData (que vuelve a spawnear los generadores desde la tabla).
-- El combustible se guarda como segundos restantes, así el tiempo se PAUSA en el
-- reinicio en lugar de seguir consumiéndose.
