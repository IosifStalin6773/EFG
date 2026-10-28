local PLUGIN = PLUGIN

util.AddNetworkString("ixTempZonesSync")

ix.temperatura = ix.temperatura or {}

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

-- Devuelve todas las zonas frías.
function ix.temperatura.getAll()
	return PLUGIN.coldAreas
end

-- Añade una zona fría con su temperatura (°C).
function ix.temperatura.addArea(v1, v2, temp)
	local vMin, vMax = sortVector(v1, v2)

	table.insert(PLUGIN.coldAreas, {vMin, vMax, tonumber(temp) or -20})
end

-- Elimina la zona en el índice dado.
function ix.temperatura.removeArea(index)
	if (PLUGIN.coldAreas[index]) then
		table.remove(PLUGIN.coldAreas, index)

		return true
	end

	return false
end

-- Índice de la zona fría (la más fría) que contiene esa posición, o nil.
function ix.temperatura.getAreaAt(pos)
	local best, bestTemp

	for index, area in ipairs(PLUGIN.coldAreas) do
		if (pos:WithinAABox(area[1], area[2])) then
			if (not bestTemp or area[3] < bestTemp) then
				best, bestTemp = index, area[3]
			end
		end
	end

	return best, bestTemp
end

-- Envía la lista de zonas a un admin para visualizarlas (o para ocultarlas).
function ix.temperatura.sendZones(client, bShow)
	net.Start("ixTempZonesSync")
		net.WriteBool(bShow)

		if (bShow) then
			local zones = PLUGIN.coldAreas
			local count = math.min(#zones, 255)

			net.WriteUInt(count, 8)
			for i = 1, count do
				net.WriteVector(zones[i][1])
				net.WriteVector(zones[i][2])
				net.WriteFloat(zones[i][3])
			end
		end
	net.Send(client)
end

-- ─── Tolerancia al frío del jugador ───────────────────────────────────────────
-- Umbral base (config) sobrescrito por la armadura más abrigada equipada. Menor
-- umbral = aguanta temperaturas más bajas. Se iteran el inventario principal Y el
-- de equipo, porque al equipar la armadura se mueve a ix_equipinv (ver ix_invkey).
local function GetColdTolerance(client, char)
	local tolerance = ix.config.Get("frio_tolerancia_base", 10)

	local inv = char:GetInventory()
	local items = inv and inv:GetItems() or {}

	local equipInv = ix.GetEquipInventory and ix.GetEquipInventory(char)
	if (equipInv) then
		items = table.Merge(table.Copy(items), equipInv:GetItems())
	end

	for _, item in pairs(items) do
		if (item.base == "base_armor" and item:GetData("equip") and item.coldThreshold != nil) then
			tolerance = math.min(tolerance, item.coldThreshold)
		end
	end

	return hook.Run("AdjustColdTolerance", client, char, tolerance) or tolerance
end

-- ─── Persistencia ─────────────────────────────────────────────────────────────

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData(PLUGIN.coldAreas)
end

function PLUGIN:LoadData()
	PLUGIN.coldAreas = self:GetData() or {}
end

-- ─── Avisos de frío/calor en pantalla (estilo loot, azul celeste) ─────────────

util.AddNetworkString("ixTempMessage")

local COLOR_COLD    = Color(120, 200, 255) -- azul celeste (frío)
local COLOR_WARM    = Color(255, 150, 70)  -- calor de la hoguera
local COLOR_CLEARED = Color(150, 230, 180) -- alivio: ya no tienes frío

local coldMessages = {
	[1] = {
		"Sientes el frío calándote la ropa.",
		"Un escalofrío te recorre la espalda.",
		"El aire helado te muerde la piel.",
		"Empiezas a notar los dedos entumecidos.",
	},
	[2] = {
		"El frío se te mete en los huesos.",
		"Tiemblas sin poder evitarlo.",
		"Los músculos se te agarrotan por el frío.",
		"Cada respiración te sale en un vaho tembloroso.",
	},
	[3] = {
		"El frío es insoportable, apenas sientes las manos.",
		"La hipotermia se está apoderando de ti.",
		"Necesitas calor cuanto antes o no lo contarás.",
		"Notas cómo la consciencia se te escapa por el frío.",
	},
}

local onsetMessages = {
	"Comienzas a sentir el frío del metro.",
	"Un frío incómodo empieza a envolverte.",
	"El ambiente se vuelve gélido a tu alrededor.",
	"Notas cómo la temperatura empieza a caer.",
}

local warmMessages = {
	"El calor del fuego empieza a reconfortarte.",
	"Sientes cómo el calor te devuelve la vida al cuerpo.",
	"Acercas las manos al fuego y el frío va cediendo.",
	"La hoguera ahuyenta poco a poco el frío de tus huesos.",
}

local clearedMessages = {
	"Has entrado en calor. El frío ha desaparecido.",
	"Tu cuerpo vuelve a estar caliente. Ya no tienes frío.",
	"El frío se ha ido del todo. Vuelves a sentirte bien.",
}

local function SendTempMessage(client, text, color)
	net.Start("ixTempMessage")
		net.WriteString(text)
		net.WriteUInt(color.r, 8)
		net.WriteUInt(color.g, 8)
		net.WriteUInt(color.b, 8)
	net.Send(client)
end

-- Reduce la congelación de un jugador (p. ej. al comer algo recién cocinado).
-- Solo actúa si tiene frío acumulado; avisa igual que al acercarse a una hoguera.
function ix.temperatura.Calentar(client, amount)
	local char = client:GetCharacter()
	if (not char) then return end

	local cong = char:GetCongelacion()
	if (cong <= 0) then return end

	local newCong = math.max(0, cong - (tonumber(amount) or 0))
	char:SetCongelacion(newCong)

	SendTempMessage(client, warmMessages[math.random(#warmMessages)], COLOR_WARM)

	if (newCong == 0) then
		SendTempMessage(client, clearedMessages[math.random(#clearedMessages)], COLOR_CLEARED)
	end
end

-- ─── Acumulación de congelación (cada 3 s) ────────────────────────────────────

-- Recopila las posiciones de todas las fuentes de calor activas del mapa.
local function GetHeatSourcePositions()
	local positions = {}

	for class in pairs(PLUGIN.heatSources) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if (IsValid(ent)) then
				positions[#positions + 1] = ent:WorldSpaceCenter()
			end
		end
	end

	return positions
end

timer.Create("ixTemperaturaTick", 3, 0, function()
	-- Se recopilan una vez por tick (no por jugador) por rendimiento.
	local heatSources = GetHeatSourcePositions()
	local heatRadius = ix.config.Get("frio_hoguera_radio", 200)
	local heatRadiusSqr = heatRadius * heatRadius

	for _, client in ipairs(player.GetAll()) do
		local char = client:GetCharacter()
		if (!char or !client:Alive()) then continue end
		if (client:GetMoveType() == MOVETYPE_NOCLIP) then continue end

		local pos = client:GetPos() + client:OBBCenter()

		-- Temperatura efectiva: por defecto la ambiente de todo el mapa; una zona la
		-- SOBREESCRIBE (puede ser más fría o más cálida).
		local temp = ix.config.Get("frio_temp_ambiente", 5)
		local _, zoneTemp = ix.temperatura.getAreaAt(pos)
		if (zoneTemp) then
			temp = zoneTemp
		end

		-- Otros plugins pueden aportar frío dinámico (p. ej. un generador sin
		-- energía enfría su área). Solo puede enfriar más (se toma el mínimo).
		local extraTemp = hook.Run("GetExtraColdTemp", client, pos)
		if (extraTemp and extraTemp < temp) then
			temp = extraTemp
		end

		-- ¿Está dentro del radio de una fuente de calor? Anula el frío.
		local nearHeat = false
		for _, heatPos in ipairs(heatSources) do
			if (pos:DistToSqr(heatPos) <= heatRadiusSqr) then
				nearHeat = true
				break
			end
		end

		client:SetNetVar("nearHeat", nearHeat)

		local cong = char:GetCongelacion()
		local tolerance = GetColdTolerance(client, char)
		local freezing = (not nearHeat and temp < tolerance)

		client:SetNetVar("inColdZone", freezing)

		-- Aviso inmediato al empezar a congelarte (transición: no tenías frío → sí).
		if (freezing and not client.ixWasFreezing) then
			SendTempMessage(client, onsetMessages[math.random(#onsetMessages)], COLOR_COLD)
		end
		client.ixWasFreezing = freezing

		-- Aviso inmediato al acercarse/entrar en el radio de una hoguera con frío aún.
		if (nearHeat and not client.ixWasNearHeat and cong > 0) then
			SendTempMessage(client, warmMessages[math.random(#warmMessages)], COLOR_WARM)
		end
		client.ixWasNearHeat = nearHeat

		if (freezing) then
			local diff = tolerance - temp
			local gain = ix.config.Get("frio_ganancia", 1.5) + ix.config.Get("frio_ganancia_grado", 0.2) * diff

			gain = gain * (hook.Run("AdjustColdGain", client, char, temp) or 1)

			char:SetCongelacion(math.min(100, cong + gain))
		elseif (cong > 0) then
			local newCong = math.max(0, cong - ix.config.Get("frio_recuperacion", 2))
			char:SetCongelacion(newCong)

			-- Aviso al recuperarse por completo (frío a 0).
			if (newCong == 0) then
				SendTempMessage(client, clearedMessages[math.random(#clearedMessages)], COLOR_CLEARED)
			end
		end
	end
end)

-- ─── Efectos por tramos (cada 2 s) ────────────────────────────────────────────
-- La ralentización de velocidad la aplica SetupMove en sh_plugin.lua.

timer.Create("ixTemperaturaEffects", 2, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local char = client:GetCharacter()
		if (!char or !client:Alive()) then continue end

		local cong = char:GetCongelacion()
		if (cong <= 0) then continue end

		-- Muerte por hipotermia al llegar a 100.
		if (cong >= 100) then
			client:Notify("Tu cuerpo se ha congelado por completo. Has muerto de hipotermia.")
			client:Kill()
			continue
		end

		-- Daño continuo por hipotermia grave.
		if (cong >= 75) then
			client:TakeDamage(3)
			client:ScreenFade(1, Color(120, 170, 255, 60), 0.6, 0)
		end
	end
end)

-- ─── Mensajes /it de síntomas (cada 30 s) ─────────────────────────────────────

local frioMessages = {
	[1] = {
		"tirita ligeramente, frotándose los brazos para entrar en calor.",
		"nota los dedos entumecidos y el aliento condensándose frente a su cara.",
		"se abraza a sí mismo mientras un escalofrío le recorre la espalda.",
		"castañetea los dientes un instante, buscando conservar el calor.",
	},
	[2] = {
		"tiembla con fuerza, incapaz de mantener las manos quietas.",
		"siente cómo el frío le cala hasta los huesos, ralentizando sus movimientos.",
		"respira con dificultad, el vaho saliendo en bocanadas temblorosas.",
		"se mueve con torpeza, los músculos agarrotados por el frío.",
	},
	[3] = {
		"apenas puede moverse, la piel amoratada y los labios pálidos por la hipotermia.",
		"tirita de forma violenta e incontrolable mientras pierde la sensibilidad en las extremidades.",
		"se tambalea, la mirada perdida y la consciencia desvaneciéndose por el frío extremo.",
		"siente un peligroso adormecimiento invadirle el cuerpo mientras se congela.",
	},
}

timer.Create("ixTemperaturaIT", 30, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local char = client:GetCharacter()
		if (!char or !client:Alive()) then continue end
		if (client:GetMoveType() == MOVETYPE_NOCLIP) then continue end

		local cong = char:GetCongelacion()
		if (cong < 25) then continue end

		local tier = (cong < 50) and 1 or ((cong < 75) and 2 or 3)
		local pool = frioMessages[tier]

		ix.chat.Send(client, "it", pool[math.random(#pool)])
	end
end)

-- ─── Avisos de estado en pantalla (cada 5 min, según el frío que tengas) ──────

timer.Create("ixTemperaturaAvisos", 300, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local char = client:GetCharacter()
		if (!char or !client:Alive()) then continue end

		local cong = char:GetCongelacion()

		if (client:GetNetVar("nearHeat") and cong > 0) then
			SendTempMessage(client, warmMessages[math.random(#warmMessages)], COLOR_WARM)
		elseif (cong >= 20) then
			local tier = (cong < 50) and 1 or ((cong < 75) and 2 or 3)
			local pool = coldMessages[tier]
			SendTempMessage(client, pool[math.random(#pool)], COLOR_COLD)
		end
	end
end)

-- Al morir, la congelación se resetea (el cuerpo respawnea sano).
hook.Add("DoPlayerDeath", "ixTemperatura_reset", function(client)
	local char = client:GetCharacter()
	if (!char) then return end

	char:SetCongelacion(0)
end)

-- ─── Menú de administración ───────────────────────────────────────────────────

util.AddNetworkString("ixTempAdmin_Open")        -- SV → CL : datos del menú
util.AddNetworkString("ixTempAdmin_Req")         -- CL → SV : abrir/refrescar
util.AddNetworkString("ixTempAdmin_SetAmbient")  -- CL → SV : temperatura ambiente
util.AddNetworkString("ixTempAdmin_AddZone")     -- CL → SV : crear zona
util.AddNetworkString("ixTempAdmin_RemoveZone")  -- CL → SV : borrar zona
util.AddNetworkString("ixTempAdmin_SetZoneTemp") -- CL → SV : cambiar temperatura de zona
util.AddNetworkString("ixTempAdmin_ToggleShow")  -- CL → SV : ver/ocultar zonas
util.AddNetworkString("ixTempAdmin_Goto")        -- CL → SV : teletransportarse a la zona

-- Cambia la temperatura de una zona ya creada.
function ix.temperatura.setAreaTemp(index, temp)
	local area = PLUGIN.coldAreas[index]
	if (area) then
		area[3] = tonumber(temp) or area[3]
		return true
	end

	return false
end

-- Envía al admin el estado del menú (ambiente, si ve zonas, y la lista de zonas).
function ix.temperatura.sendAdminData(client)
	local zones = PLUGIN.coldAreas
	local count = math.min(#zones, 255)

	net.Start("ixTempAdmin_Open")
		net.WriteFloat(ix.config.Get("frio_temp_ambiente", 5))
		net.WriteBool(client.ixTempShowZones == true)
		net.WriteUInt(count, 8)
		for i = 1, count do
			local z = zones[i]
			net.WriteFloat(z[3])
			net.WriteVector((z[1] + z[2]) * 0.5)
		end
	net.Send(client)
end

local function refresh(client)
	if (client.ixTempShowZones) then
		ix.temperatura.sendZones(client, true)
	end
	ix.temperatura.sendAdminData(client)
end

net.Receive("ixTempAdmin_Req", function(_, client)
	if (not client:IsAdmin()) then return end
	ix.temperatura.sendAdminData(client)
end)

net.Receive("ixTempAdmin_SetAmbient", function(_, client)
	if (not client:IsAdmin()) then return end
	local v = math.Clamp(math.Round(net.ReadFloat()), -50, 30)
	ix.config.Set("frio_temp_ambiente", v)
	ix.temperatura.sendAdminData(client)
end)

net.Receive("ixTempAdmin_AddZone", function(_, client)
	if (not client:IsAdmin()) then return end
	local vMin = net.ReadVector()
	local vMax = net.ReadVector()
	local temp = math.Clamp(math.Round(net.ReadFloat()), -50, 30)

	ix.temperatura.addArea(vMin, vMax, temp)
	PLUGIN:SaveData()
	refresh(client)
end)

net.Receive("ixTempAdmin_RemoveZone", function(_, client)
	if (not client:IsAdmin()) then return end
	local index = net.ReadUInt(8)

	ix.temperatura.removeArea(index)
	PLUGIN:SaveData()
	refresh(client)
end)

net.Receive("ixTempAdmin_SetZoneTemp", function(_, client)
	if (not client:IsAdmin()) then return end
	local index = net.ReadUInt(8)
	local temp = math.Clamp(math.Round(net.ReadFloat()), -50, 30)

	ix.temperatura.setAreaTemp(index, temp)
	PLUGIN:SaveData()
	refresh(client)
end)

net.Receive("ixTempAdmin_ToggleShow", function(_, client)
	if (not client:IsAdmin()) then return end
	client.ixTempShowZones = not client.ixTempShowZones
	ix.temperatura.sendZones(client, client.ixTempShowZones)
	ix.temperatura.sendAdminData(client)
end)

net.Receive("ixTempAdmin_Goto", function(_, client)
	if (not client:IsAdmin()) then return end
	local index = net.ReadUInt(8)
	local area = PLUGIN.coldAreas[index]
	if (not area) then return end

	local center = (area[1] + area[2]) * 0.5
	local tr = util.TraceLine({start = center, endpos = center - Vector(0, 0, 512), filter = client})
	client:SetPos((tr.Hit and tr.HitPos or center) + Vector(0, 0, 8))
end)
