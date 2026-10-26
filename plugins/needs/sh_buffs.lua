
local PLUGIN = PLUGIN

ix.needs = ix.needs or {}

-- Efectos temporales derivados de comer/beber. netVar guarda el CurTime()
-- de expiración del efecto, sincronizado a todos los clientes.
ix.needs.buffs = {
	nutrido = {
		netVar = "nutridoEnd",
		label  = "NUTRIDO",
	},
	intoxicado = {
		netVar = "intoxicadoEnd",
		label  = "INTOXICADO",
	},
}

--- Devuelve true si el jugador tiene activo el buff indicado ("nutrido" o "intoxicado").
function ix.needs.IsBuffActive(client, id)
	local buff = ix.needs.buffs[id]
	if (!buff or !IsValid(client)) then return false end

	return client:GetNetVar(buff.netVar, 0) > CurTime()
end

--- Segundos restantes del buff indicado (0 si no está activo).
function ix.needs.GetBuffRemaining(client, id)
	local buff = ix.needs.buffs[id]
	if (!buff or !IsValid(client)) then return 0 end

	return math.max(0, client:GetNetVar(buff.netVar, 0) - CurTime())
end
