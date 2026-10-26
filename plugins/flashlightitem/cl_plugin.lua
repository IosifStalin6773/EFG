-- El addon "metro_2033_flashlight_rechargable" registra un Think ("d_dynamo_checkUptime")
-- que intenta indexar "LocalPlayer().d_flashlight" y provoca un error cada frame en
-- nuestro sistema (donde ese campo es nil). Lo eliminamos al cargar el plugin.
hook.Remove("Think", "d_dynamo_checkUptime")

-- Cada cliente mantiene sus propias ProjectedTexture para TODOS los jugadores con linterna.
-- Esto hace la luz visible para todos sin depender del sistema nativo (que no soporta color).
local g_flashlights = {}

-- Carga máxima de la linterna (el dinamo topa "chargeAmount" en 11).
local MAX_CHARGE = 11

-- Umbral (fracción de batería) a partir del cual la linterna empieza a fallar/parpadear.
local LOW_THRESHOLD = 0.30

local FULL_COLOR = Color(255, 255, 200) -- Haz blanco-cálido con batería sana.
local DYING_COLOR = Color(255, 220, 150) -- Tono ámbar sucio cuando la batería agoniza.

-- Calcula brillo, alcance y color del haz según la batería restante, replicando el
-- comportamiento de Metro 2033: la luz se atenúa y acorta al bajar la carga y, cuando
-- queda muy poca, parpadea de forma inestable hasta que recargas con el dinamo.
local function GetBeamState(charge)
	local frac = math.Clamp(charge / MAX_CHARGE, 0, 1)

	-- Con la batería sana el haz es estable y decae de forma gradual.
	local brightness = Lerp(frac, 0.35, 1)
	local farZ = Lerp(frac, 550, 1000)
	local color = LerpColor(frac, DYING_COLOR, FULL_COLOR)

	if (frac <= LOW_THRESHOLD) then
		-- "instability" va de 0 (justo en el umbral) a 1 (batería casi vacía).
		local instability = 1 - (frac / LOW_THRESHOLD)
		local t = CurTime()

		-- Mientras está encendida, tiembla un poco.
		brightness = brightness + math.sin(t * 22) * 0.08 * instability

		-- Parpadeo real: apagones intermitentes e irregulares (mezcla de ondas)
		-- que se vuelven más frecuentes cuanto más vacía está la batería, como una
		-- linterna que agoniza cortándose y volviendo. El umbral sube con la
		-- inestabilidad: cerca de vacío la luz pasa buena parte del tiempo apagada.
		local noise = math.sin(t * 13) + math.sin(t * 27.3) + math.sin(t * 7.1)
		local blinkThreshold = Lerp(instability, -2.6, 1.2)

		if (noise < blinkThreshold) then
			brightness = 0 -- apagada
		end
	end

	return math.max(brightness, 0), farZ, color
end

hook.Add("Think", "metrorp_flashlight_projected", function()
	for _, ply in ipairs(player.GetAll()) do
		if (!IsValid(ply)) then continue end

		local idx = ply:EntIndex()
		local active = ply:Alive() and ply:GetNW2Bool("flashlight_active", false)

		if (active) then
			if (!g_flashlights[idx]) then
				local light = ProjectedTexture()
				light:SetTexture("metrorp/flashlight001")
				light:SetFOV(60)
				light:SetEnableShadows(false)
				g_flashlights[idx] = light
			end

			local brightness, farZ, color = GetBeamState(ply:GetNW2Int("chargeAmount", 0))

			local light = g_flashlights[idx]
			light:SetPos(ply:EyePos())
			light:SetAngles(ply:EyeAngles())
			light:SetBrightness(brightness)
			light:SetFarZ(farZ)
			light:SetColor(color)
			light:Update()
		else
			if (g_flashlights[idx]) then
				g_flashlights[idx]:Remove()
				g_flashlights[idx] = nil
			end
		end
	end
end)

hook.Add("EntityRemoved", "metrorp_flashlight_cleanup", function(ent)
	if (!ent:IsPlayer()) then return end
	local idx = ent:EntIndex()
	if (g_flashlights[idx]) then
		g_flashlights[idx]:Remove()
		g_flashlights[idx] = nil
	end
end)
