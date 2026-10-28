-- ============================================================
--  arcas_hanza  |  sv_plugin.lua  (SERVER)
--  Persistencia del saldo y de las huchas físicas, retiro de Balas.
-- ============================================================

util.AddNetworkString(PLUGIN.netOpen)
util.AddNetworkString(PLUGIN.netWithdraw)

-- ============================================================
--  Persistencia
-- ============================================================

function PLUGIN:LoadData()
	local saved = self:GetData() or {}
	ix.arcas.hanza = saved.balance or 0
	ix.arcas.huchas = saved.huchas or {}

	-- Restaurar huchas guardadas tras un frame para asegurarnos de que el mapa
	-- esté completamente cargado (mismo patrón que traders/tablon_encargos).
	timer.Simple(1, function()
		for _, info in ipairs(ix.arcas.huchas) do
			local pos = Vector(info.px, info.py, info.pz)

			local exists = false
			for _, e in pairs(ents.FindByClass("ix_arcas_hanza")) do
				if (IsValid(e) and e:GetPos():DistToSqr(pos) < 100) then
					exists = true
					break
				end
			end

			if (not exists) then
				local ent = ents.Create("ix_arcas_hanza")
				if (IsValid(ent)) then
					ent:SetPos(pos)
					ent:SetAngles(Angle(0, info.ay or 0, 0))
					ent:Spawn()
					ent:Activate()
				end
			end
		end
	end)
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData({
		balance = ix.arcas.hanza,
		huchas = ix.arcas.huchas,
	})
end

-- Recalcula y guarda la lista de posiciones de huchas físicas en el mapa
function ix.arcas.SaveHuchas()
	ix.arcas.huchas = {}

	for _, ent in pairs(ents.FindByClass("ix_arcas_hanza")) do
		if (IsValid(ent)) then
			local pos = ent:GetPos()
			local ang = ent:GetAngles()
			table.insert(ix.arcas.huchas, {
				px = pos.x, py = pos.y, pz = pos.z,
				ay = ang.yaw,
			})
		end
	end

	local plugin = ix.plugin.Get("arcas_hanza")
	if (plugin) then plugin:SaveData() end
end

function ix.arcas.RemoveHucha(ent)
	if (not IsValid(ent)) then return end

	local pos = ent:GetPos()
	for i = #ix.arcas.huchas, 1, -1 do
		local info = ix.arcas.huchas[i]
		if (Vector(info.px, info.py, info.pz):DistToSqr(pos) < 100) then
			table.remove(ix.arcas.huchas, i)
		end
	end

	local plugin = ix.plugin.Get("arcas_hanza")
	if (plugin) then plugin:SaveData() end
end

-- ============================================================
--  ArcasHanza.Withdraw — un miembro de Hanza retira Balas de las arcas
-- ============================================================

net.Receive(PLUGIN.netWithdraw, function(len, client)
	if (not IsValid(client)) then return end

	local ent = net.ReadEntity()
	local amount = math.floor(net.ReadUInt(32))

	if (not IsValid(ent) or ent:GetClass() != "ix_arcas_hanza") then return end
	if (client:GetPos():Distance(ent:GetPos()) > 200) then return end

	local character = client:GetCharacter()
	if (not character) then return end

	if (character:GetFaction() != FACTION_HANZA) then
		client:Notify("No perteneces a Hanza.")
		return
	end

	if (amount <= 0) then return end

	if (amount > ix.arcas.hanza) then
		client:Notify(("Las arcas solo tienen %i Balas."):format(ix.arcas.hanza))
		return
	end

	-- Se descuenta el total pedido de las arcas, pero el jugador recibe menos:
	-- la merma se destruye (no se le da a nadie), como un mini-sumidero propio.
	local fee = math.floor(amount * ix.arcas.withdrawFeeRate)
	local received = amount - fee

	ix.arcas.hanza = ix.arcas.hanza - amount
	character:GiveMoney(received)

	local plugin = ix.plugin.Get("arcas_hanza")
	if (plugin) then plugin:SaveData() end

	client:Notify(("Has retirado %i Balas de las arcas de Hanza (%i de merma)."):format(received, fee))

	net.Start(PLUGIN.netOpen)
		net.WriteEntity(ent)
		net.WriteUInt(math.Clamp(ix.arcas.hanza, 0, 4294967295), 32)
	net.Send(client)
end)
