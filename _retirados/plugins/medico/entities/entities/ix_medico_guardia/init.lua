-- ============================================================
--  ix_medico_guardia  |  init.lua  (SERVER)
-- ============================================================

local DEFAULT_MODEL = "models/Humans/Group01/male_07.mdl"

function ENT:Initialize()
	self:SetModel(self.npcModel or DEFAULT_MODEL)
	self:SetSolid(SOLID_BBOX)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetUseType(SIMPLE_USE)
	self:DrawShadow(true)
	self:SetCollisionGroup(COLLISION_GROUP_NPC)

	self.lastUse = {}
	self:ApplyAppearance()
end

-- Aplica el modelo y la animación actuales y los replica a los clientes.
function ENT:ApplyAppearance()
	local model = self.npcModel or DEFAULT_MODEL
	if (util.IsValidModel(model)) then
		self:SetModel(model)
	end

	self:SetNetVar("npcModel", self:GetModel())
	self:SetNetVar("npcAnim", self.npcAnim or "")

	if (self.npcAnim and self.npcAnim != "") then
		local seq = self:LookupSequence(self.npcAnim)
		if (seq and seq > 0) then
			self:ResetSequence(seq)
			self:SetPlaybackRate(1)
		end
	end
end

-- Avance de animación (necesario para que los SENT animen correctamente).
function ENT:Think()
	if (self.npcAnim and self.npcAnim != "") then
		self:FrameAdvance()
	end
	self:NextThink(CurTime())
	return true
end

-- Comprueba si hay algún jugador médico (vivo) dentro del rango configurado.
-- @param ignorar Player  Jugador a excluir de la búsqueda (el que usa el NPC).
function ENT:HayMedicoCerca(ignorar)
	local rango = ix.config.Get("medico_npc_rango_medico", 1500)
	local rangoSqr = rango * rango

	for _, ply in ipairs(player.GetAll()) do
		if (ply != ignorar and IsValid(ply) and ply:Alive()) then
			local character = ply:GetCharacter()
			if (character and character:GetOficio() == "medico") then
				if (self:GetPos():DistToSqr(ply:GetPos()) <= rangoSqr) then
					return true
				end
			end
		end
	end

	return false
end

-- Cooldown compartido entre los dos servicios de pago.
function ENT:EnCooldown(client)
	local id = client:SteamID()
	if (self.lastUse[id] and self.lastUse[id] > CurTime()) then
		return math.ceil(self.lastUse[id] - CurTime())
	end
	return false
end

function ENT:MarcarCooldown(client)
	self.lastUse[client:SteamID()] = CurTime() + ix.config.Get("medico_npc_cooldown", 60)
end

-- Servicio de pago: restaurar la vida.
function ENT:IntentarCurar(client)
	local character = client:GetCharacter()
	if (!character) then return end

	if (self:HayMedicoCerca(client)) then
		client:Notify("Hay un médico de servicio en la zona. Acude a él para que te atienda.")
		return
	end

	local restante = self:EnCooldown(client)
	if (restante) then
		client:Notify("El médico de guardia te atendió hace poco. Vuelve en " .. restante .. "s.")
		return
	end

	-- La cura llega hasta la capacidad vital actual: las heridas limitan el techo.
	-- Con un 30% de heridas, la capacidad es el 70%, así que cura hasta ahí.
	local plugin    = ix.plugin.Get("medico")
	local heridas   = character:GetHeridas() or 0
	local capacidad = plugin and plugin:CalcularVidaMaxima(heridas) or client:GetMaxHealth()

	if (client:Health() >= capacidad) then
		client:Notify("Ya tienes la vida al máximo de tu capacidad.")
		return
	end

	local precio = ix.config.Get("medico_npc_precio_curar", 25)
	if (character:GetMoney() < precio) then
		client:Notify("No tienes suficientes Balas. La cura cuesta " .. precio .. " Balas.")
		return
	end

	character:TakeMoney(precio)
	client:SetHealth(capacidad)
	client:EmitSound("items/smallmedkit1.wav")
	client:Notify("El médico de guardia te ha curado por " .. precio .. " Balas.")

	self:MarcarCooldown(client)
end

-- Servicio de pago: tratar las heridas acumuladas.
function ENT:IntentarTratar(client)
	local character = client:GetCharacter()
	if (!character) then return end

	if (self:HayMedicoCerca(client)) then
		client:Notify("Hay un médico de servicio en la zona. Acude a él para que te atienda.")
		return
	end

	local restante = self:EnCooldown(client)
	if (restante) then
		client:Notify("El médico de guardia te atendió hace poco. Vuelve en " .. restante .. "s.")
		return
	end

	local heridas = character:GetHeridas() or 0
	if (heridas <= 0) then
		client:Notify("No tienes heridas que tratar.")
		return
	end

	local precio = ix.config.Get("medico_npc_precio_heridas", 25)
	if (character:GetMoney() < precio) then
		client:Notify("No tienes suficientes Balas. El tratamiento cuesta " .. precio .. " Balas.")
		return
	end

	character:TakeMoney(precio)
	character:SetHeridas(0)

	-- Tratar las heridas restaura la capacidad y deja la vida al 100%.
	local plugin = ix.plugin.Get("medico")
	if (plugin) then
		plugin:AplicarHeridas(client, true)
	else
		client:SetHealth(client:GetMaxHealth())
	end

	client:EmitSound("items/smallmedkit1.wav")
	client:Notify("El médico de guardia ha tratado todas tus heridas por " .. precio .. " Balas.")

	self:MarcarCooldown(client)
end

function ENT:Use(activator)
	if (!IsValid(activator) or !activator:IsPlayer() or !activator:Alive()) then return end

	local character = activator:GetCharacter()
	if (!character) then return end

	net.Start("medico_npc_OpenDialogue")
		net.WriteEntity(self)
		net.WriteUInt(math.Clamp(character:GetMoney(), 0, 4294967295), 32)
		net.WriteUInt(math.Clamp(character:GetHeridas() or 0, 0, 100), 8)
		net.WriteBool(self:HayMedicoCerca(activator))
		net.WriteUInt(ix.config.Get("medico_npc_precio_curar", 100), 16)
		net.WriteUInt(ix.config.Get("medico_npc_precio_heridas", 200), 16)
	net.Send(activator)
end
