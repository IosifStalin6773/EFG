local SEARCH_SOUND = "metrorp/search_body.wav"

-- No se colocan props sobre el jugador atado/con saco: el estado se muestra en el
-- tooltip del personaje (cl_hooks: PopulateCharacterInfo) al mirarle.

-- Correr y saltar se bloquean de forma componible en sh_plugin.lua (SetupMove,
-- capando velocidad y quitando IN_JUMP del comando), NO con SetRunSpeed/
-- SetJumpPower: guardar el valor "original" y restaurarlo luego es frágil,
-- porque si ese guardado captura un valor YA corrompido por un bug anterior
-- (el de RunSpeed pisándose con la ralentización por radiación de badair, o
-- cualquier otro futuro) lo perpetúa para siempre en vez de arreglarlo. Al
-- bloquear por input nunca se toca el stat real, así que no hay nada que
-- pueda quedarse "pegado" tras quitar las bridas.

-- ============================================================
--  POSE DE MANOS ATRÁS (PAC3) — client:AddPart()/RemovePart() son de
--  SERVIDOR (mismo uso que plugins/badair/items/pacoutfit/sh_gasmask.lua,
--  siempre llamado desde OnRun de un ítem, que corre en servidor); PAC3
--  networkea el outfit a todos los clientes por su cuenta. Se llama una
--  vez por cambio de estado, no en un Think.
-- ============================================================

local HANDCUFF_PART_UID = "ixHandcuffPose"

local HANDCUFF_PAC_DATA = {
	[1] = {
		["children"] = {
			[1] = {
				["children"] = {
				},
				["self"] = {
					["FollowAnglesOnly"] = false,
					["DrawOrder"] = 0,
					["UniqueID"] = "eb331dc0b156f5ada7d17d9384a89cae48b272b77a62d1ee8b0e99a59395e810",
					["TargetEntityUID"] = "",
					["AimPartName"] = "",
					["FollowPartUID"] = "",
					["Bone"] = "right upperarm",
					["InvertHideMesh"] = false,
					["ScaleChildren"] = false,
					["MoveChildrenToOrigin"] = false,
					["Angles"] = Angle(-11.929385185242, 25.116806030273, -9.6199493408203),
					["Position"] = Vector(0, 0, 0),
					["AimPartUID"] = "",
					["Notes"] = "",
					["Hide"] = false,
					["Name"] = "",
					["Scale"] = Vector(1, 1, 1),
					["EditorExpand"] = false,
					["AngleOffset"] = Angle(0, 0, 0),
					["Size"] = 1,
					["PositionOffset"] = Vector(0, 0, 0),
					["IsDisturbing"] = false,
					["ClassName"] = "bone3",
					["EyeAngles"] = false,
					["HideMesh"] = false,
				},
			},
			[2] = {
				["children"] = {
				},
				["self"] = {
					["FollowAnglesOnly"] = false,
					["DrawOrder"] = 0,
					["UniqueID"] = "a9c18f68fd22d7f408dd57476411e3381e354c175624c825d11fb31e5d757537",
					["TargetEntityUID"] = "",
					["AimPartName"] = "",
					["FollowPartUID"] = "",
					["Bone"] = "left upperarm",
					["InvertHideMesh"] = false,
					["ScaleChildren"] = false,
					["MoveChildrenToOrigin"] = false,
					["Angles"] = Angle(27.93904876709, 13.199929237366, -1.497703909874),
					["Position"] = Vector(0, 0, 0),
					["AimPartUID"] = "",
					["Notes"] = "",
					["Hide"] = false,
					["Name"] = "",
					["Scale"] = Vector(1, 1, 1),
					["EditorExpand"] = false,
					["AngleOffset"] = Angle(0, 0, 0),
					["Size"] = 1,
					["PositionOffset"] = Vector(0, 0, 0),
					["IsDisturbing"] = false,
					["ClassName"] = "bone3",
					["EyeAngles"] = false,
					["HideMesh"] = false,
				},
			},
			[3] = {
				["children"] = {
				},
				["self"] = {
					["FollowAnglesOnly"] = false,
					["DrawOrder"] = 0,
					["UniqueID"] = "1ed022c99212c173a39bb0e20305fa18cd95be9e89d925178cd097cd1d48e13a",
					["TargetEntityUID"] = "",
					["AimPartName"] = "",
					["FollowPartUID"] = "",
					["Bone"] = "left hand",
					["InvertHideMesh"] = false,
					["ScaleChildren"] = false,
					["MoveChildrenToOrigin"] = false,
					["Angles"] = Angle(1.1974518299103, 32.324401855469, 0.75754970312119),
					["Position"] = Vector(0, 0, 0),
					["AimPartUID"] = "",
					["Notes"] = "",
					["Hide"] = false,
					["Name"] = "",
					["Scale"] = Vector(1, 1, 1),
					["EditorExpand"] = false,
					["AngleOffset"] = Angle(0, 0, 0),
					["Size"] = 1,
					["PositionOffset"] = Vector(0, 0, 0),
					["IsDisturbing"] = false,
					["ClassName"] = "bone3",
					["EyeAngles"] = false,
					["HideMesh"] = false,
				},
			},
			[4] = {
				["children"] = {
				},
				["self"] = {
					["FollowAnglesOnly"] = false,
					["DrawOrder"] = 0,
					["UniqueID"] = "d74c4196e974d617fd5ecece2d22166f0c217f153ecbf3af64df19daa1116338",
					["TargetEntityUID"] = "",
					["AimPartName"] = "",
					["FollowPartUID"] = "",
					["Bone"] = "right forearm",
					["InvertHideMesh"] = false,
					["ScaleChildren"] = false,
					["MoveChildrenToOrigin"] = false,
					["Angles"] = Angle(-36.017288208008, -7.3202705383301, 4.3199319839478),
					["Position"] = Vector(0, 0, 0),
					["AimPartUID"] = "",
					["Notes"] = "",
					["Hide"] = false,
					["Name"] = "",
					["Scale"] = Vector(1, 1, 1),
					["EditorExpand"] = false,
					["AngleOffset"] = Angle(0, 0, 0),
					["Size"] = 1,
					["PositionOffset"] = Vector(0, 0, 0),
					["IsDisturbing"] = false,
					["ClassName"] = "bone3",
					["EyeAngles"] = false,
					["HideMesh"] = false,
				},
			},
			[5] = {
				["children"] = {
				},
				["self"] = {
					["FollowAnglesOnly"] = false,
					["DrawOrder"] = 0,
					["UniqueID"] = "c9bfdeee504b1f064c08aa206321d2b9e20501ca62b58025bfd661f3390b0895",
					["TargetEntityUID"] = "",
					["AimPartName"] = "",
					["FollowPartUID"] = "",
					["Bone"] = "right hand",
					["InvertHideMesh"] = false,
					["ScaleChildren"] = false,
					["MoveChildrenToOrigin"] = false,
					["Angles"] = Angle(1.7075473124351e-06, 25.445846557617, -1.0672170901671e-05),
					["Position"] = Vector(0, 0, 0),
					["AimPartUID"] = "",
					["Notes"] = "",
					["Hide"] = false,
					["Name"] = "",
					["Scale"] = Vector(1, 1, 1),
					["EditorExpand"] = false,
					["AngleOffset"] = Angle(0, 0, 0),
					["Size"] = 1,
					["PositionOffset"] = Vector(0, 0, 0),
					["IsDisturbing"] = false,
					["ClassName"] = "bone3",
					["EyeAngles"] = false,
					["HideMesh"] = false,
				},
			},
			[6] = {
				["children"] = {
				},
				["self"] = {
					["FollowAnglesOnly"] = false,
					["DrawOrder"] = 0,
					["UniqueID"] = "f41c5f9ef5e2d3e258672eb58ffd45c706f2c3232d53a48f68d2959c6fbf3845",
					["TargetEntityUID"] = "",
					["AimPartName"] = "",
					["FollowPartUID"] = "",
					["Bone"] = "left forearm",
					["InvertHideMesh"] = false,
					["ScaleChildren"] = false,
					["MoveChildrenToOrigin"] = false,
					["Angles"] = Angle(10.265263557434, -1.041194445861e-05, -2.2993046513875e-05),
					["Position"] = Vector(0, 0, 0),
					["AimPartUID"] = "",
					["Notes"] = "",
					["Hide"] = false,
					["Name"] = "",
					["Scale"] = Vector(1, 1, 1),
					["EditorExpand"] = false,
					["AngleOffset"] = Angle(0, 0, 0),
					["Size"] = 1,
					["PositionOffset"] = Vector(0, 0, 0),
					["IsDisturbing"] = false,
					["ClassName"] = "bone3",
					["EyeAngles"] = false,
					["HideMesh"] = false,
				},
			},
		},
		["self"] = {
			["DrawOrder"] = 0,
			["UniqueID"] = "008c9eeafe61d5f6d275a333d62904aaffe2f91284ddbacd6659d5e4f8fa1b51",
			["Notes"] = "",
			["Hide"] = false,
			["Name"] = "my outfit",
			["TargetEntityUID"] = "",
			["EditorExpand"] = true,
			["OwnerName"] = "self",
			["Duplicate"] = false,
			["IsDisturbing"] = false,
			["ModelTracker"] = "models/magma/civilian/civilian_undershirt_redux.mdl",
			["ClassTracker"] = "player",
			["ClassName"] = "group",
		},
	},
}

local function ApplyHandcuffPacPose(client)
	if (client.AddPart) then
		client:AddPart(HANDCUFF_PART_UID, {pacData = HANDCUFF_PAC_DATA})
	end
end

local function ClearHandcuffPacPose(client)
	if (client.RemovePart) then
		client:RemovePart(HANDCUFF_PART_UID)
	end
end

-- ============================================================
--  SACO (capucha que ciega a un esposado)
--  Solo el netvar "bagged" en servidor (ciega al que lo lleva y lo
--  muestra en el tooltip del personaje); el modelo visible sobre la
--  cabeza es puramente cliente (ver cl_hooks.lua, bonemerge al NetVar).
-- ============================================================

local function PonerSaco(target)
	target:SetNetVar("bagged", true)
end

-- Limpia el estado de saco. Se usa tanto en el desatado automático como desde
-- PLUGIN:QuitarSacoDe (que además devuelve el ítem aparte).
local function QuitarSaco(target)
	target:SetNetVar("bagged")
	target:SetNetVar("sacoBusy")
end

-- Coloca el saco sobre un esposado al que apunta "client". Canaliza 3s
-- (se cancela si deja de apuntarle, igual que el resto de acciones de bridas).
-- "item" es la instancia del ítem "saco" en el inventario de client; se
-- elimina al completarse (lo llama plugins/handcuffs/items/sh_saco.lua).
function PLUGIN:EquiparSaco(client, target, item)
	if (!IsValid(client) or !IsValid(target) or target == client) then return end

	if (!target:IsPlayer() or !target:GetCharacter()) then
		client:NotifyLocalized("plyNotValid")
		return
	end

	if (!target:IsRestricted()) then
		client:NotifyLocalized("sacoNeedsRestricted")
		return
	end

	if (target:GetNetVar("bagged") or target:GetNetVar("sacoBusy")) then
		client:NotifyLocalized("sacoAlready")
		return
	end

	if (item) then item.bBeingUsed = true end

	target:SetNetVar("sacoBusy", true)
	client:SetAction("Colocando el saco", 3)
	target:SetAction("Te están poniendo un saco", 3)
	client:Say("/me le coloca un saco en la cabeza al sujeto")

	client:DoStaredAction(target, function()
		if (IsValid(target)) then
			target:SetNetVar("sacoBusy")
			target:SetAction()
		end
		client:SetAction()
		if (item) then item.bBeingUsed = false end

		if (!IsValid(target) or !target:IsRestricted() or target:GetNetVar("bagged")) then return end

		PonerSaco(target)

		client:NotifyLocalized("sacoPlacedSelf", target:Name())
		target:NotifyLocalized("sacoPlaced")

		if (item) then item:Remove() end
	end, 3, function()
		if (IsValid(target)) then
			target:SetNetVar("sacoBusy")
			target:SetAction()
		end
		if (IsValid(client)) then client:SetAction() end
		if (item) then item.bBeingUsed = false end
	end)
end

-- Quita el saco a quien lo lleva puesto; el saco vuelve al inventario de quien
-- lo quita (a diferencia del desatado automático, que lo pierde).
function PLUGIN:QuitarSacoDe(client, target)
	if (!IsValid(client) or !IsValid(target) or target == client) then return end

	if (!target:GetNetVar("bagged")) then
		client:NotifyLocalized("sacoNotBagged")
		return
	end

	if (target:GetNetVar("sacoBusy")) then return end

	target:SetNetVar("sacoBusy", true)
	client:SetAction("Quitando el saco", 3)
	client:Say("/me le quita el saco de la cabeza al sujeto")

	client:DoStaredAction(target, function()
		if (IsValid(target)) then target:SetNetVar("sacoBusy") end
		client:SetAction()

		if (!IsValid(target) or !target:GetNetVar("bagged")) then return end

		QuitarSaco(target)

		local character = client:GetCharacter()
		if (character) then
			character:GetInventory():Add("saco")
		end

		client:NotifyLocalized("sacoRemovedSelf", target:Name())
		target:NotifyLocalized("sacoRemoved")
	end, 3, function()
		if (IsValid(target)) then target:SetNetVar("sacoBusy") end
		if (IsValid(client)) then client:SetAction() end
	end)
end

--[[ El movimiento se sincroniza solo con el estado real de restricción, sin importar
	si el jugador se libera con cizalla, forcejeando o por un admin. ]]--

function PLUGIN:OnPlayerRestricted(client)
	ApplyHandcuffPacPose(client)

	-- Limpieza defensiva: si un intento de desatado anterior quedó a medias
	-- (p. ej. el timer se interrumpió sin pasar por su rama de cancelación),
	-- "untying" se quedaba pegado en true para siempre, ocultando el hint de
	-- "Mantén [E]" y bloqueando IniciarDesatado sin que nada lo repare salvo
	-- reconectar. Al volver a esposar se resetea a un estado conocido.
	client:SetNetVar("untying")

	-- SetRestricted ya quitó la entidad del arma, pero deja el ítem marcado
	-- "equip"=true en el inventario. ITEM:CanTransfer (base/sh_weapons.lua)
	-- bloquea CUALQUIER transferencia mientras ese flag siga activo, así que
	-- el arma quedaba imposible de sustraer al cachear a un esposado. Se
	-- limpia aquí y se restaura al soltarlo (si el ítem sigue siendo suyo).
	if (client.ixRestrictWeps) then
		client.ixHandcuffEquippedItems = {}

		for _, v in ipairs(client.ixRestrictWeps) do
			if (v.item) then
				v.item:SetData("equip", nil)
				client.ixHandcuffEquippedItems[#client.ixHandcuffEquippedItems + 1] = v.item
			end
		end
	end
end

function PLUGIN:OnPlayerUnRestricted(client)
	ClearHandcuffPacPose(client)

	-- Ver comentario en OnPlayerRestricted: mismo reseteo defensivo al soltarlo.
	client:SetNetVar("untying")

	if (client.ixHandcuffEquippedItems) then
		local character = client:GetCharacter()
		local invID = character and character:GetInventory() and character:GetInventory():GetID()

		for _, item in ipairs(client.ixHandcuffEquippedItems) do
			-- Solo se restaura si el ítem sigue siendo suyo (no se lo quitaron
			-- durante el registro mientras estaba esposado).
			if (ix.item.instances[item.id] == item and item.invID == invID) then
				item:SetData("equip", true)
			end
		end

		client.ixHandcuffEquippedItems = nil
	end

	-- El saco no tiene sentido sin las bridas: si te liberan (cizalla, forcejeo,
	-- admin...) se pierde el saco (nadie concreto lo "quita" en ese camino).
	if (client:GetNetVar("bagged")) then
		QuitarSaco(client)
	end

	client.ixNextStruggle = nil
end

-- ============================================================
--  ARRASTRAR (toque de E) / DESATAR (mantener E)
-- ============================================================
--
-- Un solo toque de E sobre un sujeto atado lo arrastra/suelta; mantener E
-- pulsada (por encima de TAP_THRESHOLD) sobre él inicia el desatado, que
-- exige seguir apuntando Y con la tecla pulsada durante toda la duración
-- (se cancela si sueltas E o dejas de apuntarle).

local TAP_THRESHOLD  = 0.3   -- segundos: por debajo, un toque de E; por encima, mantener
local DRAG_DISTANCE  = 42    -- distancia a la que se coloca el arrastrado tras de ti
local DRAG_MAX_RANGE = 150   -- si el arrastrado queda más lejos que esto, se suelta solo

-- Devuelve el jugador restringido al que apunta "client" dentro de rango, o nil.
local function GetBridasTarget(client)
	local data = {}
		data.start = client:GetShootPos()
		data.endpos = data.start + client:GetAimVector() * 96
		data.filter = client
	local target = util.TraceLine(data).Entity

	if (!IsValid(target) or target == client or !target:IsPlayer()) then return nil end
	if (!target:IsRestricted()) then return nil end

	return target
end

-- ── Arrastrar ──────────────────────────────────────────────────────────────

local function DetenerArrastre(client, avisar)
	local target = IsValid(client) and client.ixDragging or nil
	if (IsValid(client)) then client.ixDragging = nil end

	if (IsValid(target)) then
		target.ixDraggedBy = nil
		target:SetNetVar("bridasDraggedBy")

		if (avisar) then
			if (IsValid(client)) then client:NotifyLocalized("bridasDragStop", target:Name()) end
			target:NotifyLocalized("bridasDragStopTarget", IsValid(client) and client:Name() or "Alguien")
		end
	end
end

local function IniciarArrastre(client, target)
	if (IsValid(target.ixDraggedBy) and target.ixDraggedBy != client) then
		client:NotifyLocalized("bridasDragBusy")
		return
	end

	client.ixDragging = target
	target.ixDraggedBy = client
	target:SetNetVar("bridasDraggedBy", client)

	client:NotifyLocalized("bridasDragStart", target:Name())
	target:NotifyLocalized("bridasDragStartTarget", client:Name())
end

-- Sincroniza la posición de cada arrastrado tras su arrastrador. Un único
-- timer global (no uno por jugador) para no acumular timers al reconectar.
timer.Create("BridasDragSync", 0.05, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local target = client.ixDragging
		if (!IsValid(target)) then continue end

		if (!IsValid(client) or !client:Alive() or !target:Alive() or !target:IsRestricted()
		or client:GetPos():DistToSqr(target:GetPos()) > (DRAG_MAX_RANGE * DRAG_MAX_RANGE)) then
			DetenerArrastre(client, true)
			continue
		end

		local ang = client:EyeAngles()
		local forward = Angle(0, ang.y, 0):Forward()
		local pos = client:GetPos() - forward * DRAG_DISTANCE

		local groundTrace = util.TraceLine({
			start = pos + Vector(0, 0, 32),
			endpos = pos - Vector(0, 0, 64),
			filter = {client, target},
		})
		if (groundTrace.Hit) then
			pos = groundTrace.HitPos
		end

		target:SetPos(pos)
		target:SetEyeAngles(Angle(0, ang.y, 0))
	end
end)

-- Limpia cualquier arrastre en el que "client" participe, ya sea como quien
-- arrastra o como el arrastrado (desconexión/muerte de cualquiera de los dos).
local function LimpiarArrastre(client)
	DetenerArrastre(client, false)

	if (IsValid(client.ixDraggedBy)) then
		if (client.ixDraggedBy.ixDragging == client) then
			client.ixDraggedBy.ixDragging = nil
		end
		client.ixDraggedBy = nil
	end
	client:SetNetVar("bridasDraggedBy")
end

function PLUGIN:PlayerDisconnected(client)
	LimpiarArrastre(client)
end

-- Si el jugador atado muere, las bridas ya no tienen sentido: sin esto, el
-- estado "restricted" sobrevivía al respawn.
function PLUGIN:PlayerDeath(client)
	if (client:IsRestricted()) then
		client:SetRestricted(false)
	end

	LimpiarArrastre(client)
end

-- ── Desatar (mantener E) ─────────────────────────────────────────────────

local function IniciarDesatado(client, target)
	if (!IsValid(client) or !IsValid(target)) then return end
	if (client:IsRestricted() or target == client or !target:IsPlayer()
	or !target:IsRestricted() or target:GetNetVar("untying")) then
		return
	end

	local character = client:GetCharacter()
	if (!character) then return end

	local hasKey = character:GetInventory():HasItem("key")
	local duration = hasKey and 5 or 10

	target:SetNetVar("untying", true)
	target:SetAction(hasKey and "Siendo desatado" or "Sujeto forzando las bridas", duration)

	client:SetAction(hasKey and "Cortando las bridas" or "Forzando las bridas", duration)
	client:Say(hasKey and "/me le corta las bridas al sujeto" or "/me intenta forzar las bridas del sujeto")

	local uniqueID = "bridasDesatar_" .. client:SteamID64()
	local reps = math.ceil(duration / 0.1)

	timer.Create(uniqueID, 0.1, reps, function()
		local cancelar = !IsValid(client) or !IsValid(target)
			or !client:KeyDown(IN_USE) or (GetBridasTarget(client) != target)

		if (cancelar) then
			timer.Remove(uniqueID)

			if (IsValid(target)) then
				target:SetNetVar("untying")
				target:SetAction()
			end
			if (IsValid(client)) then
				client:SetAction()
			end
			return
		end

		if (timer.RepsLeft(uniqueID) == 0) then
			local bSuccess = hasKey or math.random(100) <= 60

			if (bSuccess) then
				target:SetRestricted(false)
				target:NotifyLocalized("bridasFreed")
				client:NotifyLocalized("bridasFreedSelf", target:Name())
			else
				client:NotifyLocalized("bridasForceFail")
				target:NotifyLocalized("bridasForceFailTarget")
			end

			target:SetNetVar("untying")
			target:SetAction()
			client:SetAction()
		end
	end)
end

-- Tecla I: cachea al esposado al que apuntas (mismo efecto que /CharSearch).
-- Se usa PlayerButtonDown (no KeyPress) porque KeyPress solo recibe botones IN_*,
-- nunca teclas KEY_* como KEY_I. Corre en el servidor para todos los jugadores.
function PLUGIN:PlayerButtonDown(client, button)
	if (button != KEY_I) then return end
	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end
	if (client:IsRestricted()) then return end

	local target = GetBridasTarget(client)
	if (!target) then return end

	Schema:SearchPlayer(client, target)
end

-- KeyPress/KeyRelease del servidor (autoritativos, no predichos) para distinguir
-- un toque rápido (arrastrar) de mantener pulsada la tecla (desatar).
function PLUGIN:KeyPress(client, key)
	if (key != IN_USE) then return end
	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end
	if (client:IsRestricted()) then return end

	client.ixBridasHoldPending = true

	-- Si ya está arrastrando a alguien, un toque lo soltará (ver KeyRelease);
	-- no hace falta temporizador de "mantener" aquí.
	if (IsValid(client.ixDragging)) then return end

	local target = GetBridasTarget(client)
	if (!target or target:GetNetVar("untying")) then return end

	local uniqueID = "bridasHold_" .. client:SteamID64()
	timer.Create(uniqueID, TAP_THRESHOLD, 1, function()
		if (!IsValid(client)) then return end
		client.ixBridasHoldPending = nil

		if (!client:KeyDown(IN_USE)) then return end
		if (!IsValid(target) or target:GetNetVar("untying")) then return end
		if (GetBridasTarget(client) != target) then return end

		IniciarDesatado(client, target)
	end)
end

function PLUGIN:KeyRelease(client, key)
	if (key != IN_USE) then return end
	if (!IsValid(client)) then return end

	local wasPending = client.ixBridasHoldPending
	client.ixBridasHoldPending = nil
	if (!wasPending) then return end

	timer.Remove("bridasHold_" .. client:SteamID64())

	-- Toque rápido (se soltó antes de llegar al umbral de "mantener").
	if (IsValid(client.ixDragging)) then
		DetenerArrastre(client, true)
		return
	end

	local target = GetBridasTarget(client)
	if (IsValid(target) and !target:GetNetVar("untying")) then
		IniciarArrastre(client, target)
	end
end

-- ── Registro / robo de un jugador atado ───────────────────────────────────────
-- Abre el inventario del sujeto inmovilizado al registrador para que pueda
-- sustraerle objetos. Lo llama el comando /CharSearch (sh_commands.lua).
function Schema:SearchPlayer(client, target)
	if (!IsValid(client) or !IsValid(target) or !target:IsPlayer()) then return end
	if (!target:IsRestricted()) then return end

	local character = target:GetCharacter()
	if (!character) then return end

	local inventory = character:GetInventory()
	if (!inventory) then return end

	-- El inventario de equipo (armadura/mochila puestas) es un inventario aparte
	-- que ix.storage.Open no muestra: sin esto, quien registra ni ve ni puede
	-- tocar nada que el sujeto lleve equipado. Se vuelca al inventario principal
	-- ANTES de abrir el registro, así aparece como cualquier otro objeto y se
	-- puede sustraer (la mochila conserva su contenido, solo cambia de sitio).
	local eqInv = ix.GetEquipInventory and ix.GetEquipInventory(character)
	if (eqInv) then
		for _, item in pairs(eqInv:GetItems(true)) do
			item.player = target
			if (item.outfitCategory == "model" and item:GetData("equip")) then
				item:RemoveOutfit(target)
			end
			item:Transfer(inventory:GetID(), nil, nil, target)
			item.player = nil
		end
	end

	client:EmitSound(SEARCH_SOUND, 75, 100, 1)

	-- ix.storage.CreateContext solo se ejecuta la PRIMERA vez que se abre este
	-- inventario como storage; a partir de ahí "storageInfo" es el mismo objeto
	-- para siempre y el "info" que le pasemos a ix.storage.Open en llamadas
	-- posteriores se IGNORA por completo. Si este jugador ya fue cacheado antes
	-- (aunque fuera con una versión anterior de este código, con searchTime=4),
	-- ese valor viejo queda pegado y nuestro searchTime=0 de abajo nunca se
	-- aplicaría, disparando un segundo stare oculto con la distancia estricta
	-- de 96 que fallaba en silencio. Se fuerzan aquí los campos relevantes cada
	-- vez, igual que bMultipleUsers (mismo remedio que plugins/strongbox).
	if (inventory.storageInfo) then
		inventory.storageInfo.bMultipleUsers = true
		inventory.storageInfo.searchTime = 0
		inventory.storageInfo.entity = target
		inventory.storageInfo.name = "Registrando a " .. target:Name()
	end

	local SEARCH_TIME = 4
	-- ix.storage.Open delega el "mantener la mirada" en DoStaredAction con su
	-- distancia por defecto (96 unidades) y exige un trace-hit EXACTO sobre el
	-- hitbox del objetivo en cada tick de 0.1s durante los 4s: cualquier
	-- microdesvío del ratón lo cancela a medio llenar. Se envuelve la apertura
	-- en nuestro propio DoStaredAction con más margen (200u) en vez de dejar
	-- que ix.storage.Open use el suyo; searchTime=0 hace que abra al instante
	-- una vez completado, sin duplicar la espera.
	client:SetAction("Registrando...", SEARCH_TIME)

	client:DoStaredAction(target, function()
		if (!IsValid(client) or !IsValid(target)) then return end

		ix.storage.Open(client, inventory, {
			-- ixRobFrisk se propaga al storageInfo del inventario y de sus bolsas
			-- (CreateContext lo copia); CanTransferItem lo usa para bloquear los
			-- ítems noLoot mientras dura el registro.
			ixRobFrisk = true,
			bMultipleUsers = true,
			name = "Registrando a " .. target:Name(),
			entity = target,
			searchTime = 0,
			OnPlayerClose = function()
				if (IsValid(client)) then
					client:StopSound(SEARCH_SOUND)
				end
			end
		})
	end, SEARCH_TIME, function()
		if (IsValid(client)) then
			client:SetAction()
			client:StopSound(SEARCH_SOUND)
		end
	end, 200)
end

-- Los ítems marcados ITEM.noLoot no se pueden sustraer del inventario de un
-- jugador durante un registro (igual que no caen al cadáver al morir). El dueño
-- SÍ puede seguir moviéndolos/soltándolos por su cuenta: el bloqueo solo aplica
-- mientras hay un registro activo (storageInfo.ixRobFrisk) sobre ese inventario.
function PLUGIN:CanTransferItem(item, currentInv, targetInv)
	if (!item.noLoot) then return end
	if (!currentInv or currentInv == targetInv) then return end

	if (currentInv.storageInfo and currentInv.storageInfo.ixRobFrisk) then
		return false
	end
end
