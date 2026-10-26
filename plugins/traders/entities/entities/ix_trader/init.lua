-- ============================================================
--  ix_trader  |  init.lua  (SERVER)
--  Lógica del trader: inicialización, configuración, uso,
--  restock y persistencia de inventario.
-- ============================================================

-- Modelos por defecto según facción
local FACTION_MODELS = {
	prapor      = "models/eft/pmcs/bear_extended_pm.mdl",
	therapist   = "models/eft/scavs/scav_extended_pm.mdl",
	fence       = "models/eft/scavs/scav_extended_pm.mdl",
	skier       = "models/eft/scavs/scav_extended_pm.mdl",
	peacekeeper = "models/eft/pmcs/usec_extended_pm.mdl",
	mechanic    = "models/eft/scavs/scav_extended_pm.mdl",
	ragman      = "models/eft/scavs/scav_extended_pm.mdl",
	jaeger      = "models/eft/pmcs/bear_extended_pm.mdl",
}

function ENT:Initialize()
	self:SetModel("models/eft/scavs/scav_extended_pm.mdl")
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysicsInitBox(Vector(-16, -16, 0), Vector(16, 16, 72))
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:DrawShadow(true)
	self:SetCollisionGroup(COLLISION_GROUP_NPC)

	local phys = self:GetPhysicsObject()
	if (IsValid(phys)) then
		phys:EnableMotion(false)
		phys:Wake()
	end

	self.inventory              = {}
	self.maxSlots               = ix.config.Get("traders_maxSlots", 20)
	self.factionKey             = "prapor"
	self.lastUse                = {}
	self.traderModel            = nil
	self.traderAnim             = ""
	self.traderBodygroups       = {}
	self.traderCustomName       = nil
	self.traderCustomLore       = nil
	self.traderAllowedFactions  = {}
	self.buyWhitelist            = {}
end

-- Aplica el modelo y la animación actuales del trader
function ENT:ApplyAppearance()
	local model = self.traderModel or FACTION_MODELS[self.factionKey] or FACTION_MODELS["prapor"]
	if (util.IsValidModel(model)) then
		self:SetModel(model)
	end
	self:SetNetVar("traderModel", self:GetModel())
	self:SetNetVar("traderAnim",  self.traderAnim or "")

	-- Las claves pueden venir como string tras un round-trip por JSON (persistencia)
	for id, val in pairs(self.traderBodygroups or {}) do
		self:SetBodygroup(tonumber(id) or 0, tonumber(val) or 0)
	end

	if (self.traderAnim and self.traderAnim != "") then
		local seq = self:LookupSequence(self.traderAnim)
		if (seq and seq > 0) then
			self:ResetSequence(seq)
			self:SetPlaybackRate(1)
		end
	end
end

-- Llamado por GMod después de SetPos cuando el entity se spawnea (incluso desde el spawn menu).
-- Garantiza que traderKey siempre esté seteado, incluso sin llamar SetupTrader explícitamente.
function ENT:Spawn()
	self:PhysicsInitBox(Vector(-16, -16, 0), Vector(16, 16, 72))
	if (not self._setupDone) then
		self:SetupTrader(self.factionKey or "prapor")
	end
end

-- Configura la facción del trader, su modelo y carga el inventario persistido
function ENT:SetupTrader(factionKey)
	self._setupDone = true
	self.factionKey = factionKey or "prapor"
	self:SetNetVar("factionKey", self.factionKey)
	self:SetNetVar("traderKey",  self:GetPersistKey())

	-- Restaurar datos persistidos si existen
	local savedData = ix.traders.data or {}
	local key = self:GetPersistKey()
	if (savedData[key]) then
		self.inventory        = savedData[key].inventory or {}
		self.maxSlots         = savedData[key].maxSlots or self.maxSlots
		self.traderModel      = savedData[key].traderModel or nil
		self.traderAnim       = savedData[key].traderAnim or ""
		self.traderBodygroups = savedData[key].traderBodygroups or {}
		self.traderCustomName      = savedData[key].traderCustomName or nil
		self.traderCustomLore      = savedData[key].traderCustomLore or nil
		self.traderAllowedFactions = savedData[key].traderAllowedFactions or {}
		self.buyWhitelist          = savedData[key].buyWhitelist or {}
	elseif (ix.traders.ApplyDefaultStock) then
		-- trader nuevo: stock y lista de compra por defecto de su comerciante de EFT
		ix.traders.ApplyDefaultStock(self, self.factionKey)
		timer.Simple(0, function()
			if (IsValid(self) and self.SaveToData) then self:SaveToData() end
		end)
	end

	-- El nombre de red usa el nombre custom si está definido; si no, el nombre de facción
	self:SetNetVar("traderName", self.traderCustomName or ix.traders.names[self.factionKey] or "Comerciante")

	self:ApplyAppearance()
end

-- Avance de animación (necesario para que los SENT animen correctamente)
function ENT:Think()
	if (self.traderAnim and self.traderAnim != "") then
		self:FrameAdvance()
	end
	self:NextThink(CurTime())
	return true
end

-- Clave única estable del trader, independiente de su posición.
-- Se genera una sola vez y se conserva al mover el trader o cambiar su
-- apariencia, para que las misiones que lo referencian no se rompan.
function ENT:GetPersistKey()
	if (!self.traderID) then
		self.traderID = ix.traders.GenerateID()
	end
	return self.traderID
end

function ENT:Use(activator)
	if (!IsValid(activator) or !activator:IsPlayer()) then return end
	if (!activator:GetCharacter()) then return end

	-- Cooldown por jugador de 1 segundo para evitar spam
	local steamID = activator:SteamID()
	self.lastUse = self.lastUse or {}
	if (self.lastUse[steamID] and self.lastUse[steamID] > CurTime()) then
		return
	end
	self.lastUse[steamID] = CurTime() + 1

	local character = activator:GetCharacter()

	-- Restricción de facción del jugador
	local allowedFac = self.traderAllowedFactions
	if (allowedFac and #allowedFac > 0) then
		local factionIndex = character:GetFaction()
		local factionData  = ix.faction.indices and ix.faction.indices[factionIndex]
		local playerFk     = factionData and factionData.uniqueID or ""
		if (!table.HasValue(allowedFac, playerFk)) then
			activator:Notify("No tienes acceso a este comerciante.")
			return
		end
	end

	local traderRep = character:GetTraderRep() or {}
	local fk        = self.factionKey or "prapor"
	local rep       = ix.traders.GetEffectiveRep(character, fk)
	local money     = math.Clamp(character:GetMoney(), 0, 4294967295)

	-- Misión lista para entregar con este trader
	local missionReady  = false
	local missionName   = ""
	local missionActive = character:GetMissionActive()

	-- [DEBUG] imprime en consola del servidor para diagnóstico
	MsgN("[Trader:Use] jugador=" .. activator:Nick() .. " trader_fk=" .. fk)
	if (missionActive) then
		MsgN("[Trader:Use]   missionId="       .. tostring(missionActive.missionId))
		MsgN("[Trader:Use]   traderFaction="   .. tostring(missionActive.traderFaction))
		MsgN("[Trader:Use]   readyToComplete=" .. tostring(missionActive.readyToComplete))
		MsgN("[Trader:Use]   stepIndex="       .. tostring(missionActive.stepIndex))
	else
		MsgN("[Trader:Use]   missionActive = nil (sin misión activa)")
	end

	local myKey = self:GetPersistKey()
	local missionMatchesTrader = missionActive and missionActive.readyToComplete and (
		(missionActive.traderKey and missionActive.traderKey == myKey) or
		(not missionActive.traderKey and missionActive.traderFaction == fk)
	)
	if (missionMatchesTrader) then
		missionReady = true
		missionName  = missionActive.missionName or ""
	end

	-- Paso de ENTREGA listo (el jugador ya lleva encima el ítem que pide el
	-- paso "deliver" actual, aunque la misión en conjunto no esté terminada
	-- todavía) — se ofrece como acción rápida en el diálogo en vez de obligar
	-- a pasar por el Tablón de misiones.
	local deliverReady    = false
	local deliverItemName = ""
	-- OJO: "X and f()" trunca el multi-retorno de f() a un solo valor en Lua
	-- (mission/step se quedaban siempre en nil) — llamar directo sin el "and".
	local active, _, step = ix.missions.GetActive(character)
	if (active and step and step.type == "deliver") then
		local deliverMatchesTrader = (active.traderKey and active.traderKey == myKey)
			or (not active.traderKey and active.traderFaction == fk)

		if (deliverMatchesTrader) then
			local total = 0
			for _, it in pairs(character:GetInventory():GetItems()) do
				if (it.uniqueID == step.itemID) then
					total = total + (it:GetData("Amount") or it:GetData("count") or 1)
				end
			end

			if (total >= (step.count or 1)) then
				deliverReady = true
				local itemData = ix.item.list[step.itemID]
				deliverItemName = itemData and itemData.name or step.itemID
			end
		end
	end

	net.Start("traders_OpenDialogue")
		net.WriteEntity(self)
		net.WriteString(fk)
		net.WriteString(self:GetNetVar("traderName", "Comerciante"))
		net.WriteUInt(rep, 10)
		net.WriteUInt(money, 32)
		net.WriteBool(missionReady)
		net.WriteString(missionName)
		net.WriteBool(deliverReady)
		net.WriteString(deliverItemName)
	net.Send(activator)
end

-- Repone el stock de los slots del trader; elimina los slots de jugador agotados
function ENT:Restock()
	local i = 1
	while (i <= #self.inventory) do
		local slot = self.inventory[i]
		if (slot.playerStock) then
			if ((slot.qty or 0) <= 0) then
				table.remove(self.inventory, i)
			else
				i = i + 1
			end
		else
			slot.qty = slot.maxQty or slot.qty
			-- El restock de admin repone stock por defecto: descartar datos preservados
			slot.instances = nil
			i = i + 1
		end
	end
	self:SaveToData()
end

-- Restock de ciclo: fuerza el stock de admin al máximo y borra TODO el stock
-- vendido por jugadores, sin importar cuánto quede.
function ENT:CycleRestock()
	local i = 1
	while (i <= #self.inventory) do
		local slot = self.inventory[i]
		if (slot.playerStock) then
			table.remove(self.inventory, i)
		else
			slot.qty = slot.maxQty or slot.qty
			slot.instances = nil
			i = i + 1
		end
	end
	self:SaveToData()
end

-- Guarda el estado del trader en la tabla global del plugin y solicita persistencia
function ENT:SaveToData()
	ix.traders.data = ix.traders.data or {}
	local key = self:GetPersistKey()
	local pos = self:GetPos()
	local ang = self:GetAngles()
	ix.traders.data[key] = {
		traderID               = key,
		pos                    = {x = pos.x, y = pos.y, z = pos.z},
		ang                    = {p = ang.p, y = ang.y, r = ang.r},
		inventory              = self.inventory,
		maxSlots               = self.maxSlots,
		factionKey             = self.factionKey,
		traderModel            = self.traderModel,
		traderAnim             = self.traderAnim,
		traderBodygroups       = self.traderBodygroups or {},
		traderCustomName       = self.traderCustomName,
		traderCustomLore       = self.traderCustomLore,
		traderAllowedFactions  = self.traderAllowedFactions or {},
		buyWhitelist           = self.buyWhitelist or {},
	}
	local plugin = ix.plugin and ix.plugin.Get("traders")
	if (plugin) then
		plugin:SaveData()
	end
end

function ENT:OnRemove()
	if (self._deleting) then return end
	self:SaveToData()
end

function ENT:PhysgunPickup(ply)
	if (not ply:IsAdmin()) then return false end
	local phys = self:GetPhysicsObject()
	if (IsValid(phys)) then phys:EnableMotion(true) end
	return true
end

-- El traderID no cambia al mover el trader, así que basta con guardar
-- la nueva posición/rotación; las misiones que lo referencian siguen
-- siendo válidas.
function ENT:PhysgunDrop(ply)
	timer.Simple(0.5, function()
		if (not IsValid(self)) then return end
		local phys = self:GetPhysicsObject()
		if (IsValid(phys)) then phys:EnableMotion(false) end
		self:SaveToData()
	end)
end
