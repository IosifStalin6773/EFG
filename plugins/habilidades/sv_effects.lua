local PLUGIN = PLUGIN

-- ════════════════════════════════════════════════════════════════════════════════
--  Efectos (recompensas) y ganancia de XP (objetivos) de cada perk.
--  Las constantes de abajo controlan la intensidad de cada efecto y se pueden ajustar.
-- ════════════════════════════════════════════════════════════════════════════════

-- Recompensas (escalan con el nivel del perk).
local AGUANTE_MAX_REDUCCION   = 0.30  -- −30% daño recibido a nivel 50
local RESISTENCIA_MAX_OFFSET  = 1.00  -- + estamina por tick a nivel 50
local SUPERVIV_MAX_REDUCCION  = 0.50  -- −50% desgaste de hambre/sed a nivel 50
local RADIACION_MAX_REDUCCION = 0.60  -- −60% radiación absorbida a nivel 50
local RADIACION_FILTRO_MAX_DURACION = 600  -- el filtro dura hasta 10 minutos a nivel 50
local MEDICINA_MAX_BONUS      = 0.75  -- +75% curación a nivel 50
local MANTEN_MAX_REDUCCION    = 0.60  -- −60% desgaste de armadura a nivel 50
local MANTEN_REPAR_BASE       = 70    -- % de durabilidad al reparar a nivel 1
local MANTEN_REPAR_MAX        = 100   -- % de durabilidad al reparar a nivel 50
local MANITAS_MAX_DURABILIDAD = 0.50  -- +50% durabilidad crafteada a nivel 50
local APANADO_MAX_AHORRO      = 0.30  -- 30% chance de ahorrar cada material a nivel 50

-- XP otorgado por cada objetivo.
local XP_AGUANTE_POR_DANO   = 0.3
local XP_RESISTENCIA_AGOTAR = 8
local XP_FUERZA_TICK        = 3
local XP_SUPERVIV_CONSUMO   = 0.4
local XP_RADIACION_TICK     = 2
local XP_MANTENIMIENTO      = 15
local XP_MEDICINA_OTRO      = 12
local XP_MEDICINA_PROPIO    = 5
local XP_EXPLORADOR         = 8
local XP_MANITAS            = 10
local XP_NEGOCIADOR         = 25
local XP_APANADO            = 10

local function frac(character, id)
	return ix.perks.Fraction(character:GetPerkLevel(id))
end

local function award(client, id, amount)
	if (!IsValid(client)) then return end
	local character = client:GetCharacter()
	if (!character) then return end
	character:AddPerkXP(id, amount)
end

-- ── Aguante: menos daño recibido + XP al recibir daño ───────────────────────────
function PLUGIN:ScalePlayerDamage(client, hitgroup, dmgInfo)
	local character = client:GetCharacter()
	if (!character) then return end

	local reduction = AGUANTE_MAX_REDUCCION * frac(character, "aguante")
	if (reduction > 0) then
		dmgInfo:ScaleDamage(1 - reduction)
	end
end

function PLUGIN:PlayerHurt(client, attacker, healthRemaining, damageTaken)
	if (!IsValid(client) or !client:IsPlayer()) then return end
	award(client, "aguante", math.Round(damageTaken * XP_AGUANTE_POR_DANO))
end

-- ── Resistencia: más estamina (vía hook del plugin stamina de Helix) ────────────
function PLUGIN:AdjustStaminaOffset(client, offset)
	local character = client:GetCharacter()
	if (!character) then return end

	local bonus = RESISTENCIA_MAX_OFFSET * frac(character, "resistencia")
	if (bonus != 0) then
		return offset + bonus
	end
end

-- Resistencia: XP al agotar la estamina (esfuerzo físico prolongado).
function PLUGIN:PlayerStaminaLost(client)
	award(client, "resistencia", XP_RESISTENCIA_AGOTAR)
end

-- Fuerza: el bonus de peso máximo es shared (ix.perks.GetWeightBonus) y lo
-- consume weight/sh_meta directamente, para que la barra de peso del cliente coincida.

-- Fuerza: XP mientras se lleva sobrepeso. Llamado desde InitializedPlugins (sh_plugin).
function PLUGIN:SetupServerEffects()
	timer.Create("habilidades_fuerza", 10, 0, function()
		for _, client in player.Iterator() do
			local character = client:GetCharacter()
			if (!character or !client:Alive()) then continue end

			if (character:Overweight()) then
				character:AddPerkXP("fuerza", XP_FUERZA_TICK)
			end
		end
	end)

	-- Superviviente: XP al comer/beber. Se envuelven los métodos de "needs" una vez
	-- todos los plugins han cargado (orden de carga no garantizado en include).
	local CHAR = ix.meta.character

	if (CHAR.RestoreSatiety and !CHAR.ixPerksWrappedSatiety) then
		CHAR.ixPerksWrappedSatiety = true
		local original = CHAR.RestoreSatiety
		function CHAR:RestoreSatiety(value)
			original(self, value)
			if ((value or 0) > 0) then
				self:AddPerkXP("superviviente", math.Round(value * XP_SUPERVIV_CONSUMO))
			end
		end
	end

	if (CHAR.RestoreSaturation and !CHAR.ixPerksWrappedSaturation) then
		CHAR.ixPerksWrappedSaturation = true
		local original = CHAR.RestoreSaturation
		function CHAR:RestoreSaturation(value)
			original(self, value)
			if ((value or 0) > 0) then
				self:AddPerkXP("superviviente", math.Round(value * XP_SUPERVIV_CONSUMO))
			end
		end
	end
end

-- ── Superviviente: menos desgaste de hambre/sed (consumido en needs) ────────────
-- Devuelve el multiplicador (≤1) a aplicar al consumo de hambre/sed.
function PLUGIN:AdjustNeedsConsume(client, character)
	return 1 - (SUPERVIV_MAX_REDUCCION * frac(character, "superviviente"))
end

-- ── Radiación: menos radiación absorbida (consumido en badair) ──────────────────
-- Devuelve el multiplicador (≤1) a aplicar a la radiación absorbida.
function PLUGIN:AdjustRadiationIntake(client, character)
	return 1 - (RADIACION_MAX_REDUCCION * frac(character, "radiacion"))
end

-- Radiación: XP por cada tick mientras se está vivo en una zona radioactiva.
function PLUGIN:OnRadiacionTick(client, character)
	award(client, "radiacion", XP_RADIACION_TICK)
end

-- Técnico de radiación: el filtro de la máscara se consume más despacio, haciendo
-- que dure más tiempo (hasta ix.perks.filtroMaxDuracion segundos a nivel 50).
-- Devuelve el multiplicador (≤1) a aplicar al desgaste del filtro por tick.
function PLUGIN:AdjustFilterDrain(client, character)
	return ix.perks.GetFilterMultiplier(character)
end

-- ── Medicina: más curación (consumido en items de curación) ─────────────────────
-- Devuelve el multiplicador (≥1) a aplicar a las cantidades de curación del médico.
function PLUGIN:AdjustHealAmount(client, character)
	return 1 + (MEDICINA_MAX_BONUS * frac(character, "medicina"))
end

-- ── Mantenimiento: menos desgaste de armadura (consumido en better_armor) ───────
-- Devuelve el multiplicador (≤1) a aplicar a la pérdida de durabilidad de armadura.
function PLUGIN:AdjustArmorDurabilityLoss(client, character)
	return 1 - (MANTEN_MAX_REDUCCION * frac(character, "mantenimiento"))
end

-- ── Mantenimiento: calidad de reparación (consumido en better_armor) ────────────
-- Durabilidad resultante tras usar un kit de reparación (70% a nivel 1, 100% a nivel máximo).
function PLUGIN:GetCalidadReparacion(character)
	return Lerp(frac(character, "mantenimiento"), MANTEN_REPAR_BASE, MANTEN_REPAR_MAX)
end

-- ── Manitas: bonus de durabilidad en objetos crafteados ─────────────────────────
function PLUGIN:GetManitasDurabilityBonus(character)
	return MANITAS_MAX_DURABILIDAD * frac(character, "manitas")
end

-- ── Apañado: probabilidad de ahorrar materiales al craftear ────────────────────
function PLUGIN:GetApanadoSaveChance(character)
	return APANADO_MAX_AHORRO * frac(character, "apanado")
end

-- ── XP por objetivos enganchados desde otros plugins ────────────────────────────

-- Mantenimiento: XP al reparar equipo.
function PLUGIN:OnEquipoReparado(client)
	award(client, "mantenimiento", XP_MANTENIMIENTO)
end

-- Medicina: XP al curar a otro o a uno mismo.
function PLUGIN:OnCuracionRealizada(client, bSelf)
	award(client, "medicina", bSelf and XP_MEDICINA_PROPIO or XP_MEDICINA_OTRO)
end

-- Explorador: XP al saquear un contenedor con éxito.
function PLUGIN:OnContenedorSaqueado(client)
	award(client, "explorador", XP_EXPLORADOR)
end

-- Explorador: reducción del tiempo de saqueo (segundos). Consumido en loot.
function PLUGIN:GetTiempoSaqueo(character, baseTime)
	local minTime = 1
	return Lerp(frac(character, "explorador"), baseTime, minTime)
end

-- Manitas + Apañado: XP al craftear.
function PLUGIN:OnBlueprintCrafted(client, character, blueprint)
	award(client, "manitas", XP_MANITAS)
	award(client, "apanado", XP_APANADO)
end

-- Apañado: XP al cocinar.
function PLUGIN:OnRecipeCooked(client, character, recipe)
	award(client, "apanado", XP_APANADO)
end

-- Negociador: multiplicador de balas de recompensa de misión. Consumido en missions.
function PLUGIN:AdjustMissionReward(client, character)
	return 1 + (0.50 * frac(character, "negociador"))
end

-- Negociador: XP al completar una misión.
function PLUGIN:OnMissionCompleted(client, character, mission)
	award(client, "negociador", XP_NEGOCIADOR)
end
