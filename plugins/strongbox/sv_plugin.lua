if (not SERVER) then return end

local TYPE = "strongbox"

local function setup(inv)
	-- NO marcar como bolsa: queremos poder meter mochilas/rigs dentro del stash
	inv.vars.isBag       = nil
	inv.vars.isContainer = true
	inv.vars.isEFGStash  = true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Evita que Helix restaure el stash automáticamente en CharacterLoaded;
-- lo restauramos nosotros con la altura correcta vía EnsureStash.
function PLUGIN:ShouldRestoreInventory(charID, invID, invType)
	if (invType == TYPE) then return false end
end

-- Registrar el tipo con el tamaño máximo posible; el tamaño real de cada
-- personaje se ajusta al restaurar/crear (FitHeight).
function PLUGIN:InitializedPlugins()
	ix.inventory.Register(TYPE, ix.strongbox.WIDTH, ix.strongbox.MAX_HEIGHT)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Crea o restaura el stash del personaje. callback(inv) cuando esté listo.
function ix.strongbox.EnsureStash(character, callback)
	local stored = character:GetData("strongbox_stash", false)
	local w      = ix.strongbox.WIDTH
	local target = ix.strongbox.GetTargetHeight(character)

	if (not stored) then
		ix.inventory.New(character:GetID(), TYPE, function(inv)
			setup(inv)
			inv:SetSize(w, target)
			character:SetData("strongbox_stash", {id = inv:GetID(), height = target})
			if (callback) then callback(inv) end
		end)
	elseif (ix.item.inventories[stored.id]) then
		local inv = ix.item.inventories[stored.id]
		setup(inv)
		ix.strongbox.FitHeight(character, inv)
		if (callback) then callback(inv) end
	else
		local h = math.max(stored.height or 30, target)
		ix.inventory.Restore(stored.id, w, h, function(inv)
			setup(inv)
			ix.strongbox.FitHeight(character, inv)
			character:SetData("strongbox_stash", {id = inv:GetID(), height = inv:GetSize() or h})
			if (callback) then callback(inv) end
		end)
	end
end

-- Ajusta la altura al máximo entre la almacenada y la del nivel actual de hideout.
function ix.strongbox.FitHeight(character, inv)
	local stored  = character:GetData("strongbox_stash", {})
	local current = stored.height or 30
	local target  = ix.strongbox.GetTargetHeight(character)
	local newH    = math.max(current, target)
	if (newH != current) then
		local w = ix.strongbox.WIDTH
		inv:SetSize(w, newH)
		stored.height = newH
		character:SetData("strongbox_stash", stored)
	end
end

-- Devuelve el inventario del stash si ya está cargado en memoria
function ix.strongbox.GetStash(character)
	local stored = character:GetData("strongbox_stash", false)
	return stored and ix.item.inventories[stored.id] or nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Abre el stash físico desde una taquilla en el mapa
function ix.strongbox.Open(client, entity, type)
	type = type or TYPE
	local character = client:GetCharacter()
	if (not character) then return end

	if (client.InRaid and client:InRaid()) then
		client:Notify("No puedes abrir el alijo durante una raid.")
		return
	end

	ix.strongbox.EnsureStash(character, function(inv)
		if (inv.storageInfo) then inv.storageInfo.bMultipleUsers = true end
		ix.storage.CloseCurrent(client, inv)
		ix.storage.Open(client, inv, {
			name          = "Alijo",
			bMultipleUsers = true,
			searchTime    = 0.7,
			entity        = entity,
			searchText    = "Abriendo...",
			OnPlayerClose = function()
				if (entity and IsValid(entity)) then
					entity:EmitSound("items/ammocrate_open.wav")
					entity.nextUse = CurTime() + 1
				end
			end
		})
	end)
end

-- Abre el stash sin taquilla física (desde lobby o comando /Alijo)
function ix.strongbox.OpenRemote(client)
	local character = client:GetCharacter()
	if (not character) then return end

	ix.strongbox.EnsureStash(character, function(inv)
		if (inv.storageInfo) then inv.storageInfo.bMultipleUsers = true end
		ix.storage.CloseCurrent(client, inv)
		ix.storage.Open(client, inv, {
			name           = "Alijo",
			bMultipleUsers = true,
			searchTime     = 0,
		})
	end)
end

-- Llama cuando el jugador mejora el módulo Alijo del escondite
function ix.strongbox.Refresh(client)
	local character = client:GetCharacter()
	if (not character) then return end

	local inv = ix.strongbox.GetStash(character)
	if (inv) then
		ix.strongbox.FitHeight(character, inv)
		ix.storage.Sync(client, inv)
		client:Notify("¡Tu alijo ha crecido!")
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Carga el stash al conectar (sin abrirlo, solo restaurarlo en memoria)
function PLUGIN:CharacterLoaded(character)
	local client = character:GetPlayer()
	if (not IsValid(client)) then return end

	timer.Simple(1, function()
		if (IsValid(client) and client:GetCharacter() == character) then
			ix.strongbox.EnsureStash(character)
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Persistencia de las entidades de taquilla en el mapa

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end
	local data = {}
	for _, v in pairs(ents.FindByClass("ix_strongbox")) do
		data[#data + 1] = {v:GetPos(), v:GetAngles(), v:GetModel(), v:GetNetVar("name", 0), v.lockerID}
	end
	ix.data.SetSafe(self.uniqueID, data)
end

function PLUGIN:LoadData()
	local data = self:GetData({})
	if (not data) then return end
	for _, v in pairs(data) do
		local ent = ents.Create("ix_strongbox")
		ent.savedLockerID = v[5]
		ent:SetPos(v[1]); ent:SetAngles(v[2]); ent:Spawn()
		ent:SetModel(v[3]); ent:SetSolid(SOLID_VPHYSICS)
		ent:PhysicsInit(SOLID_VPHYSICS)
		ent:SetNetVar("name", v[4]); ent:DrawShadow(false)
		local phys = ent:GetPhysicsObject()
		if (IsValid(phys)) then phys:Wake(); phys:EnableMotion(false) end
	end
end
