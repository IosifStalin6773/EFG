local PLUGIN = PLUGIN

-- Aplica una droga a un jugador: activa el efecto durante su duración y
-- consume reservas de comida y bebida. Devuelve true si se aplicó.
function ix.drogas.Apply(client, id)
	if (!IsValid(client) or !client:Alive()) then return false end

	local buff = ix.drogas.buffs[id]
	if (!buff) then return false end

	local char = client:GetCharacter()
	if (!char) then return false end

	client:SetNetVar(buff.netVar, CurTime() + buff.duration)

	client.ixDrogaActive = client.ixDrogaActive or {}
	client.ixDrogaActive[buff.netVar] = true

	if (buff.drainSatiety and buff.drainSatiety > 0) then
		char:DowngradeSatiety(buff.drainSatiety)
	end

	if (buff.drainSaturation and buff.drainSaturation > 0) then
		char:DowngradeSaturation(buff.drainSaturation)
	end

	client:EmitSound("items/smallmedkit1.wav", 70, 110)
	client:Notify(buff.onUse)

	return true
end

-- Limpia todos los efectos activos de un jugador (al morir, por ejemplo).
function ix.drogas.ClearAll(client)
	if (!IsValid(client)) then return end

	for _, buff in pairs(ix.drogas.buffs) do
		client:SetNetVar(buff.netVar, 0)
	end

	client.ixDrogaActive = nil
end

-- Resaca: consume reservas al agotarse el efecto. El personaje puede haber
-- desaparecido entre el tick y la expiración, de ahí la comprobación.
local function applyEndDrain(client, buff)
	local char = client:GetCharacter()
	if (!char) then return end

	if (buff.endDrainSatiety and buff.endDrainSatiety > 0) then
		char:DowngradeSatiety(buff.endDrainSatiety)
	end

	if (buff.endDrainSaturation and buff.endDrainSaturation > 0) then
		char:DowngradeSaturation(buff.endDrainSaturation)
	end
end

-- Expira los efectos cuando se agota su duración y avisa al jugador una sola vez.
timer.Create("ixDrogasTick", 1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (!IsValid(client)) then continue end

		client.ixDrogaActive = client.ixDrogaActive or {}

		for _, buff in pairs(ix.drogas.buffs) do
			local endTime = client:GetNetVar(buff.netVar, 0)

			if (endTime > CurTime()) then
				client.ixDrogaActive[buff.netVar] = true
			elseif (client.ixDrogaActive[buff.netVar]) then
				client.ixDrogaActive[buff.netVar] = nil
				client:SetNetVar(buff.netVar, 0)
				applyEndDrain(client, buff)
				client:Notify(buff.onEnd)
			end
		end
	end
end)

-- Reducción de daño de las drogas activas (narcótico casero).
function PLUGIN:ScalePlayerDamage(client, hitgroup, dmgInfo)
	for _, buff in pairs(ix.drogas.buffs) do
		if (buff.damageScale and client:GetNetVar(buff.netVar, 0) > CurTime()) then
			dmgInfo:ScaleDamage(buff.damageScale)
		end
	end
end

function PLUGIN:DoPlayerDeath(client)
	ix.drogas.ClearAll(client)
end

function PLUGIN:PlayerDisconnected(client)
	client.ixDrogaActive = nil
end
