local PLUGIN = PLUGIN

local nextGeigerSound = 0

surface.CreateFont("MetroHUD", {
	font = "Roboto",
	size = 22,
	weight = 700,
	antialias = true,
})

-- Muestra el resultado de medir la radiación de otro jugador.
netstream.Hook("badair_geigerResult", function(name, rad)
	LocalPlayer():ChatPrint(L("geigerResult", name, math.floor(rad)))
end)

-- Forward-declarada: la usa el CalcView de abajo, pero se define más adelante
-- en el archivo (junto a la capa ambiente continua) — Lua no adelanta locals.
local GetAmbientTierAndFrac

-- ── Tambaleo por radiación ───────────────────────────────────────────────────
-- Al recibir el /it de síntomas de radiación: mareo/blur de cámara durante 4s,
-- con intensidad según el tier (1 = leve, 2 = moderado, 3 = grave), y en los
-- tiers 2 y 3 además 3 pulsaciones aleatorias de W/A/S/D repartidas en ese
-- tiempo, simulando que el personaje pierde el control de sus movimientos.
-- Tras la fase activa, el efecto se desvanece progresivamente en FADE_DURATION
-- segundos en vez de cortarse de golpe.
local STUMBLE_DURATION = 4
local FADE_DURATION = 6
local stumbleStart = 0
local stumbleUntil = 0    -- fin de la fase activa (también corta el tambaleo de movimiento)
local stumbleFadeEnd = 0  -- fin real, incluyendo el desvanecimiento
local stumbleTier = 1
local stumbleKeys = {}

-- Intensidad 0-1 del efecto en este instante: sube durante STUMBLE_DURATION y
-- baja de nuevo a 0 a lo largo de FADE_DURATION.
local function GetStumbleIntensity()
	local t = CurTime()

	if (t <= stumbleStart) then return 0 end

	if (t <= stumbleUntil) then
		return math.Clamp((t - stumbleStart) / STUMBLE_DURATION, 0, 1)
	end

	if (t <= stumbleFadeEnd) then
		return 1 - math.Clamp((t - stumbleUntil) / FADE_DURATION, 0, 1)
	end

	return 0
end

-- button: bit de IN_* para que se vea "pulsado" (animaciones/HUD).
-- forward/side: valores analógicos reales, sin esto el jugador NO se mueve:
-- el movimiento del jugador predicho lo maneja SetForwardMove/SetSideMove,
-- no los bits de IN_*.
local moveOptions = {
	{button = IN_FORWARD,   forward = 250,  side = 0},
	{button = IN_BACK,      forward = -250, side = 0},
	{button = IN_MOVELEFT,  forward = 0,    side = -250},
	{button = IN_MOVERIGHT, forward = 0,    side = 250},
}

-- Parámetros de intensidad por tier: pulso de color/blur y balanceo de cámara.
-- Los tiers 2 y 3 usan "progressive = true": en vez del pulso sinusoidal + tambaleo
-- de cámara del tier 1, es un desenfoque que crece progresivamente durante los 4
-- segundos, sin mover la cámara. El tier 3 es la misma idea que el tier 2 pero más
-- fuerte, con viñeta (oscurece/desenfoca desde los bordes hacia el centro) y un
-- par de parpadeos lentos (la pantalla se cierra a negro y vuelve a abrirse).
-- pitch/yaw/roll/fov (tambaleo de cámara, solo tier 1) se mantienen bajos a
-- propósito y NO escalan con el resto del sistema (tope de radiación 400→800):
-- el resto de efectos (blur/color/viñeta) sí se hacen más notorios cuanto más
-- alto es el tramo, pero mover la cámara del jugador debe seguir siendo
-- discreto para no ser invasivo/desorientador.
local tierFX = {
	[1] = {contrast = 0.15, colourMin = 0.85, colourRange = 0.10, blurAdd = 0.35, blurBlend = 0.75, blurJitter = 0.01,
	       pitch = 1, yaw = 1, roll = 1.5, fov = 1.5},
	[2] = {progressive = true, blurMax = 0.55, blurBlend = 0.85, blurJitter = 0.012, contrastMax = 0.18, colourMin = 0.82},
	[3] = {progressive = true, vignette = true, blurMax = 1.1, blurBlend = 0.97, blurJitter = 0.035,
	       contrastMax = 0.55, colourMin = 0.20, vignetteAlpha = 240, vignetteSize = 320,
	       blinks = 2, blinkDuration = 1.0},
}

-- Viñeta: oscurece la pantalla desde los cuatro bordes hacia el centro dibujando
-- bandas concéntricas de alpha creciente (sin depender de texturas de gradiente).
local function DrawEdgeVignette(alpha, size)
	if (alpha <= 0 or size <= 0) then return end

	local steps = 24
	local sw, sh = ScrW(), ScrH()
	local thickness = size / steps + 1

	surface.SetDrawColor(6, 6, 6, alpha / steps)

	for i = 0, steps - 1 do
		local inset = (i / steps) * size

		surface.DrawRect(0, inset, sw, thickness)
		surface.DrawRect(0, sh - inset - thickness, sw, thickness)
		surface.DrawRect(inset, 0, thickness, sh)
		surface.DrawRect(sw - inset - thickness, 0, thickness, sh)
	end
end

-- Parpadeos: un par de veces durante la fase activa, la pantalla se funde a negro
-- y vuelve a abrirse (curva suave, no un simple on/off) simulando que el personaje
-- cierra los ojos lentamente por el mareo.
local blinkEvents = {}

local function GetBlinkAlpha()
	local t = CurTime()
	local alpha = 0

	for _, b in ipairs(blinkEvents) do
		if (t >= b.startTime and t <= b.startTime + b.duration) then
			local p = (t - b.startTime) / b.duration
			alpha = math.max(alpha, math.sin(p * math.pi)) -- 0 → 1 → 0, subida y bajada suaves
		end
	end

	return alpha
end

netstream.Hook("badair_radiationStumble", function(tier)
	stumbleStart = CurTime()
	stumbleUntil = CurTime() + STUMBLE_DURATION
	stumbleFadeEnd = stumbleUntil + FADE_DURATION
	stumbleTier = tierFX[tier] and tier or 1
	stumbleKeys = {}
	blinkEvents = {}

	local fx = tierFX[stumbleTier]

	-- Solo tiers 2 y 3 hacen que el personaje se tambalee de verdad.
	if (stumbleTier >= 2) then
		for i = 1, 3 do
			local start = math.Rand(0, STUMBLE_DURATION - 0.5)
			local option = moveOptions[math.random(#moveOptions)]

			stumbleKeys[i] = {
				option = option,
				startTime = CurTime() + start,
				endTime = CurTime() + start + math.Rand(0.25, 0.5)
			}
		end
	end

	if (fx.blinks) then
		for i = 1, fx.blinks do
			-- repartidos con espacio entre ellos para que no se pisen
			local slot = (STUMBLE_DURATION - fx.blinkDuration) / fx.blinks
			local start = (i - 1) * slot + math.Rand(0, slot - fx.blinkDuration)

			blinkEvents[i] = {
				startTime = CurTime() + math.max(0, start),
				duration = fx.blinkDuration
			}
		end
	end
end)

hook.Add("RenderScreenspaceEffects", "badair_radiationStumbleEffect", function()
	if (CurTime() >= stumbleFadeEnd) then return end

	local intensity = GetStumbleIntensity()
	if (intensity <= 0) then return end

	local fx = tierFX[stumbleTier]
	local t = CurTime()

	if (fx.progressive) then
		-- Desenfoque que crece hasta blurMax y luego se desvanece de vuelta a 0,
		-- sin pulso ni tambaleo: el jugador se va "nublando" y despejando poco a poco.
		DrawColorModify({
			["$pp_colour_addr"] = 0,
			["$pp_colour_addg"] = 0,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = 0,
			["$pp_colour_contrast"] = 1 - fx.contrastMax * intensity,
			["$pp_colour_colour"] = 1 - (1 - fx.colourMin) * intensity,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0,
		})

		-- El 2º parámetro (frameblendalpha) controla cuánta "estela" borrosa se
		-- retiene entre fotogramas; si se deja fijo, el rastro acumulado no se
		-- disuelve con el addalpha y el efecto parece cortarse de golpe al final.
		-- Escalarlo también por la intensidad hace que el buffer se vaya limpiando.
		DrawMotionBlur(fx.blurMax * intensity, fx.blurBlend * intensity, fx.blurJitter)

		if (fx.vignette) then
			DrawEdgeVignette(fx.vignetteAlpha * intensity, fx.vignetteSize * intensity)
		end

		if (fx.blinks) then
			local blinkAlpha = GetBlinkAlpha()

			if (blinkAlpha > 0) then
				surface.SetDrawColor(0, 0, 0, 255 * blinkAlpha)
				surface.DrawRect(0, 0, ScrW(), ScrH())
			end
		end

		return
	end

	local pulse = 0.5 + 0.5 * math.sin(t * 6)

	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.05 * (fx.contrast / 0.5) * intensity,
		["$pp_colour_contrast"] = 1 - fx.contrast * pulse * intensity,
		["$pp_colour_colour"] = 1 - (1 - (fx.colourMin + fx.colourRange * pulse)) * intensity,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	})

	DrawMotionBlur((fx.blurAdd + 0.1 * pulse) * intensity, fx.blurBlend * intensity, fx.blurJitter)
end)

-- Balanceo de cámara PERMANENTE por tramo (no solo durante los episodios de
-- 4s): lento y de amplitud pequeña a propósito, para que siempre haya una
-- señal de "no estás bien" sin llegar a estorbar al apuntar/jugar. Escala con
-- el tramo (más notorio en crítico) y con la fracción DENTRO del tramo, igual
-- que la capa de color/blur ambiente de arriba.
local AMBIENT_VIEW_FX = {
	[1] = {pitch = 0.3, yaw = 0.3, roll = 0.5, fov = 0.5},
	[2] = {pitch = 0.6, yaw = 0.6, roll = 1.0, fov = 1.0},
	[3] = {pitch = 1.0, yaw = 1.0, roll = 1.6, fov = 1.6},
}

-- Un único CalcView que SUMA la base permanente de arriba con el pico puntual
-- del episodio (si hay uno activo), en vez de dos hooks separados — CalcView
-- solo usa el valor del PRIMER hook que devuelva algo, así que dos hooks
-- independientes se pisarían entre sí en vez de combinarse.
hook.Add("CalcView", "badair_radiationStumbleView", function(client, pos, ang, fov)
	local t = CurTime()

	local ambPitch, ambYaw, ambRoll, ambFov = 0, 0, 0, 0
	local char = client:GetCharacter()
	if (char) then
		local tier, frac = GetAmbientTierAndFrac(char:GetRadiation())
		local afx = AMBIENT_VIEW_FX[tier]
		if (afx) then
			ambPitch = math.sin(t * 0.7) * afx.pitch * frac
			ambYaw   = math.sin(t * 0.5) * afx.yaw   * frac
			ambRoll  = math.sin(t * 0.9) * afx.roll  * frac
			ambFov   = math.sin(t * 0.6) * afx.fov   * frac
		end
	end

	local epPitch, epYaw, epRoll, epFov = 0, 0, 0, 0
	if (CurTime() < stumbleFadeEnd) then
		local fx = tierFX[stumbleTier]
		if (not fx.progressive) then -- tiers progresivos (2 y 3): sin pico de cámara
			local intensity = GetStumbleIntensity()
			if (intensity > 0) then
				epPitch = math.sin(t * 5)   * fx.pitch * intensity
				epYaw   = math.sin(t * 3.3) * fx.yaw   * intensity
				epRoll  = math.sin(t * 4.5) * fx.roll  * intensity
				epFov   = math.sin(t * 3)   * fx.fov   * intensity
			end
		end
	end

	if (ambPitch == 0 and ambYaw == 0 and ambRoll == 0 and ambFov == 0
	and epPitch == 0 and epYaw == 0 and epRoll == 0 and epFov == 0) then
		return
	end

	return {
		origin = pos,
		angles = Angle(ang.p + ambPitch + epPitch, ang.y + ambYaw + epYaw, ang.r + ambRoll + epRoll),
		fov = fov + ambFov + epFov,
	}
end)

hook.Add("CreateMove", "badair_radiationStumbleMove", function(cmd)
	if (CurTime() >= stumbleUntil or stumbleTier < 2) then return end

	local now = CurTime()

	for _, k in ipairs(stumbleKeys) do
		if (now >= k.startTime and now <= k.endTime) then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), k.option.button))
			cmd:SetForwardMove(cmd:GetForwardMove() + k.option.forward)
			cmd:SetSideMove(cmd:GetSideMove() + k.option.side)
		end
	end
end)

-- ── Capa ambiente continua ───────────────────────────────────────────────────
-- Los episodios de arriba (badair_radiationStumble) solo duran 4s cada 20s: el
-- resto del tiempo el jugador no tenía ningún indicio visual de su estado.
-- Esta capa refleja el tramo de radiación EN VIVO todo el tiempo, a intensidad
-- baja (techo AMBIENT_MAX_INTENSITY), reutilizando los mismos tierFX/
-- DrawEdgeVignette en vez de un sistema aparte — los episodios puntuales quedan
-- como picos añadidos por encima de esta base, no como única fuente de aviso.
-- Techo de intensidad ambiente POR TRAMO (no un único valor fijo): así la
-- escalada se nota progresivamente más conforme sube el tramo, sin tocar la
-- cámara (eso lo sigue controlando solo el pitch/yaw/roll/fov de tier 1
-- arriba, que no ha subido).
local AMBIENT_MAX_INTENSITY = {
	[1] = 0.25,
	[2] = 0.35,
	[3] = 0.50,
}

-- tier 0..3 y fracción 0-1 de cuánto se ha avanzado DENTRO de ese tramo, para
-- que la intensidad ambiente crezca conforme se acerca al siguiente umbral en
-- vez de saltar de golpe al entrar en el tramo. Resuelto contra la tabla
-- compartida ix.badair.radStates (sh_plugin.lua) en vez de umbrales propios
-- duplicados, así nunca se puede desincronizar de sv_plugin.lua/hud.
function GetAmbientTierAndFrac(rad)
	local stateIndex = ix.badair.GetRadiationStateIndex(rad)
	if (stateIndex == 0) then return 0, 0 end

	-- GetRadiationStateIndex es 0-based, radStates es 1-based: +1 para la fila.
	local state = ix.badair.radStates[stateIndex + 1]
	local nextState = ix.badair.radStates[stateIndex + 2]
	local nextMin = nextState and nextState.min or ix.badair.RAD_DEATH

	local frac = math.Clamp((rad - state.min) / (nextMin - state.min), 0, 1)
	return stateIndex, frac
end

hook.Add("RenderScreenspaceEffects", "badair_radiationAmbient", function()
	local client = LocalPlayer()
	if (not IsValid(client) or not client:Alive()) then return end
	local char = client:GetCharacter()
	if (not char) then return end

	local tier, frac = GetAmbientTierAndFrac(char:GetRadiation())
	if (tier == 0) then return end

	local fx = tierFX[tier]
	local intensity = frac * AMBIENT_MAX_INTENSITY[tier]
	if (intensity <= 0) then return end

	if (fx.progressive) then
		DrawColorModify({
			["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = 0,
			["$pp_colour_contrast"] = 1 - fx.contrastMax * intensity,
			["$pp_colour_colour"] = 1 - (1 - fx.colourMin) * intensity,
			["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
		})

		if (fx.vignette) then
			DrawEdgeVignette(fx.vignetteAlpha * intensity * 0.6, fx.vignetteSize * intensity)
		end
	else
		DrawColorModify({
			["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = 0,
			["$pp_colour_contrast"] = 1 - fx.contrast * intensity,
			["$pp_colour_colour"] = 1 - (1 - fx.colourMin) * intensity,
			["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
		})
	end
end)

-- ── Flash de daño (sin máscara en zona tóxica) ───────────────────────────────
-- Antes era un ScreenFade blanco crudo (sh_plugin.lua, badairTick) que no
-- encajaba con el resto del lenguaje visual de arriba. Ahora es un pulso corto
-- de la misma viñeta, con tinte enfermizo en vez de blanco puro.
local DAMAGE_FLASH_DURATION = 0.4
local damageFlashStart = 0

netstream.Hook("badair_radDamageFlash", function()
	damageFlashStart = CurTime()
end)

hook.Add("RenderScreenspaceEffects", "badair_radiationDamageFlash", function()
	local elapsed = CurTime() - damageFlashStart
	if (elapsed < 0 or elapsed >= DAMAGE_FLASH_DURATION) then return end

	-- 0 → 1 → 0 en vez de un corte seco al terminar.
	local alpha = math.sin((elapsed / DAMAGE_FLASH_DURATION) * math.pi)

	DrawEdgeVignette(180 * alpha, 260)
	surface.SetDrawColor(120, 200, 90, 25 * alpha)
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)

-- Sonido de contador Geiger escalado con la radiación.
-- Solo suena si el jugador tiene el Contador Geiger en su inventario.
hook.Add("Think", "badair_radiation_cl", function()
	local client = LocalPlayer()
	if (!client:GetCharacter() or !client:Alive()) then return end
	if (!client:GetNetVar("inRadZone", false)) then return end

	local inv = client:GetCharacter():GetInventory()
	if (!inv) then return end

	local hasGeiger = false
	for _, itm in pairs(inv:GetItems()) do
		if (itm.uniqueID == "contador_geiger") then
			hasGeiger = true
			break
		end
	end
	if (!hasGeiger) then return end

	local rad = client:GetCharacter():GetRadiation()
	local interval = math.max(0.3, 2 - (rad / 400))

	if (nextGeigerSound < CurTime()) then
		surface.PlaySound("player/Geiger1.wav")
		nextGeigerSound = CurTime() + interval
	end
end)

