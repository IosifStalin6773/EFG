local PLUGIN = PLUGIN

PLUGIN.name = "Drogas"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Los químicos pueden sintetizar pastillas que otorgan buffs temporales a cambio de consumir reservas de comida y bebida."

ix.drogas = ix.drogas or {}

-- Definición compartida de cada droga. La duración está en segundos.
-- netVar: variable de red que guarda el CurTime() de expiración del efecto.
-- drainSatiety / drainSaturation: comida y bebida que consume al tomarla.
-- endDrainSatiety / endDrainSaturation: lo mismo, pero al expirar el efecto (resaca).
-- speedMult: multiplicador de velocidad de movimiento mientras dura.
-- damageScale: multiplicador del daño recibido (0.85 = 15% menos daño).
-- weightBonus: kilos extra de capacidad de carga mientras dura.
-- blurVision: nubla la vista del jugador (efecto cliente).
ix.drogas.buffs = {
	radiacion = {
		netVar          = "drogaRadResist",
		name            = "Antirradiación",
		duration        = 60,
		drainSatiety    = 15,
		drainSaturation = 20,
		onUse           = "Un cosquilleo metálico recorre tu cuerpo. La radiación apenas te afecta.",
		onEnd           = "El blindaje químico de tus células se desvanece.",
	},
	velocidad = {
		netVar          = "drogaSpeed",
		name            = "Estimulante",
		duration        = 60,
		speedMult       = 1.35,
		drainSatiety    = 20,
		drainSaturation = 20,
		onUse           = "Tu corazón se acelera y tus piernas arden. Te sientes más rápido.",
		onEnd           = "La euforia se apaga y tus piernas pesan de nuevo.",
	},
	stamina = {
		netVar          = "drogaStamina",
		name            = "Energizante",
		duration        = 60,
		drainSatiety    = 25,
		drainSaturation = 15,
		onUse           = "Una oleada de energía inunda tus músculos. No sientes el cansancio.",
		onEnd           = "El agotamiento regresa de golpe.",
	},
	mareo = {
		netVar          = "drogaMareo",
		name            = "Compuesto defectuoso",
		duration        = 90,
		drainSatiety    = 10,
		drainSaturation = 10,
		onUse           = "Tragas la pastilla... pero algo va mal. El túnel empieza a dar vueltas.",
		onEnd           = "El mareo por fin remite.",
	},
	alcohol = {
		netVar          = "drogaAlcohol",
		name            = "Ebriedad",
		duration        = 120,
		drainSatiety    = 0,
		drainSaturation = 0,
		onUse           = "El alcohol te sube a la cabeza. Todo empieza a balancearse.",
		onEnd           = "La borrachera se disipa lentamente.",
	},
	narcotico = {
		netVar          = "drogaNarcotico",
		name            = "Narcótico casero",
		duration        = 180,
		damageScale     = 0.85,
		blurVision      = true,
		onUse           = "El narcótico quema al bajar. El dolor se apaga y el túnel se vuelve borroso.",
		onEnd           = "La vista se aclara y el dolor vuelve a morderte.",
	},
	coctel = {
		netVar             = "drogaCoctel",
		name               = "Cóctel energético",
		duration           = 180,
		speedMult          = 1.15,
		endDrainSaturation = 40,
		onUse              = "El brebaje te sacude. Tus piernas responden más rápido.",
		onEnd              = "El chute se apaga y una sed brutal te seca la garganta.",
	},
	musculoso = {
		netVar             = "drogaMusculoso",
		name               = "Musculoso",
		duration           = 300,
		weightBonus        = 25,
		endDrainSatiety    = 40,
		endDrainSaturation = 40,
		onUse              = "Tus músculos se hinchan. Podrías cargar con medio túnel a la espalda.",
		onEnd              = "El músculo se deshincha. Tienes un hambre y una sed que te doblan.",
	},
}

-- Devuelve true si el buff indicado sigue activo en el jugador.
function ix.drogas.IsActive(client, id)
	local buff = ix.drogas.buffs[id]
	if (!buff or !IsValid(client)) then return false end

	return client:GetNetVar(buff.netVar, 0) > CurTime()
end

-- Kilos extra de capacidad de carga que otorgan las drogas activas.
-- Es shared porque la barra de peso del inventario se dibuja en el cliente.
function ix.drogas.GetWeightBonus(character)
	if (!character) then return 0 end

	local client = character:GetPlayer()
	if (!IsValid(client)) then return 0 end

	local bonus = 0

	for _, buff in pairs(ix.drogas.buffs) do
		if (buff.weightBonus and client:GetNetVar(buff.netVar, 0) > CurTime()) then
			bonus = bonus + buff.weightBonus
		end
	end

	return bonus
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

-- Buffs de velocidad. SetupMove se ejecuta en cliente y servidor para que la
-- predicción de movimiento sea coherente con la autoridad del servidor.
hook.Add("SetupMove", "ixDrogas_speed", function(client, mv)
	local mult = 1

	for _, buff in pairs(ix.drogas.buffs) do
		if (buff.speedMult and client:GetNetVar(buff.netVar, 0) > CurTime()) then
			mult = mult * buff.speedMult
		end
	end

	if (mult != 1) then
		mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
	end
end)

-- Buff de stamina. AdjustStaminaOffset modifica el cálculo del plugin de stamina
-- de Helix (se evalúa en ambos realms). Devolver un offset positivo evita el
-- drenaje al esprintar y acelera la regeneración.
hook.Add("AdjustStaminaOffset", "ixDrogas_stamina", function(client, offset)
	if (client:GetNetVar("drogaStamina", 0) > CurTime()) then
		return math.max(offset, 0) + 1.5
	end
end)