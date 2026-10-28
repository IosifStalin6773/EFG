--[[ Funciones Necesarias ]]--

function PLUGIN:PopulateCharacterInfo(client, character, tooltip)
	if (client:IsRestricted()) then
		local panel = tooltip:AddRowAfter("name", "handcuffs")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("bridasRestrictedTooltip"))
		panel:SizeToContents()
	elseif (client:GetNetVar("tying")) then
		local panel = tooltip:AddRowAfter("name", "handcuffs")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("bridasTyingTooltip"))
		panel:SizeToContents()
	elseif (client:GetNetVar("untying")) then
		local panel = tooltip:AddRowAfter("name", "handcuffs")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("bridasUntyingTooltip"))
		panel:SizeToContents()
	end

	if (IsValid(client:GetNetVar("bridasDraggedBy"))) then
		local panel = tooltip:AddRowAfter("name", "handcuffsDrag")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("bridasDraggedTooltip"))
		panel:SizeToContents()
	end

	if (client:GetNetVar("bagged")) then
		local panel = tooltip:AddRowAfter("name", "handcuffsSaco")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("sacoBaggedTooltip"))
		panel:SizeToContents()
	end
end

-- ============================================================
--  MODELO DEL SACO — sigue la cabeza de quien lo lleve puesto, para que
--  el resto de jugadores vean que lo tiene sin depender del tooltip.
--  Puramente cosmético: no hay entidad en servidor, cada cliente
--  crea/quita su propio prop en base al NetVar "bagged".
--
--  Se ancla al hueso real de la cabeza (SACO_HEAD_BONE) en vez de a
--  GetPos() (los pies): anclado al cuerpo entero, el saco se quedaba
--  perfectamente rígido mientras la animación idle mueve la cabeza un
--  poco (respiración/balanceo), así que la cara asomaba a ratos. Las
--  pruebas de pose de brazos confirmaron que este esqueleto SÍ usa los
--  nombres ValveBiped estándar, así que debería encontrarlo; si algún
--  playermodel no lo tuviera, cae de vuelta a GetPos() sin romperse.
-- ============================================================

local SACO_MODEL = "models/willardnetworks/m1nt/burlap_bag_male.mdl"
local SACO_HEAD_BONE = "ValveBiped.Bip01_Head1"
-- Confirmados en juego con ix_saco_offset, anclado al hueso de la cabeza.
local SACO_LIFT = -60
local SACO_FORWARD = 1
local sacoProps = {}

local function RemoveSacoProp(client)
	local prop = sacoProps[client]
	if (IsValid(prop)) then
		prop:Remove()
	end
	sacoProps[client] = nil
end

local function CreateSacoProp(client)
	if (IsValid(sacoProps[client])) then return end

	local prop = ClientsideModel(SACO_MODEL, RENDERGROUP_OTHER)
	if (!IsValid(prop)) then return end

	prop:SetMoveType(MOVETYPE_NONE)
	prop:SetSolid(SOLID_NONE)
	prop:SetNotSolid(true)
	prop:SetPos(client:GetPos())

	sacoProps[client] = prop
end

-- [client] = índice del hueso de la cabeza escalado a 0, o false si este
-- modelo no tiene ese hueso (para no repetir LookupBone cada frame).
local hiddenHeadBone = {}

local function HideHead(client)
	if (hiddenHeadBone[client] != nil) then return end

	local boneIndex = client:LookupBone(SACO_HEAD_BONE)
	hiddenHeadBone[client] = boneIndex or false

	if (boneIndex) then
		client:ManipulateBoneScale(boneIndex, vector_origin)
	end
end

local function ShowHead(client)
	local boneIndex = hiddenHeadBone[client]
	if (boneIndex) then
		client:ManipulateBoneScale(boneIndex, Vector(1, 1, 1))
	end
	hiddenHeadBone[client] = nil
end

hook.Add("Think", "ixSacoPropSync", function()
	for _, client in ipairs(player.GetAll()) do
		if (client:GetNetVar("bagged")) then
			CreateSacoProp(client)
			HideHead(client)

			local prop = sacoProps[client]
			if (IsValid(prop)) then
				-- Solo yaw: con pitch/roll de la cámara el saco se inclinaría hacia
				-- delante/atrás cada vez que el jugador mira arriba o abajo.
				local ang = Angle(0, client:EyeAngles().y, 0)

				local boneIndex = client:LookupBone(SACO_HEAD_BONE)
				local anchor = boneIndex and client:GetBonePosition(boneIndex) or client:GetPos()

				prop:SetPos(anchor + Vector(0, 0, SACO_LIFT) + ang:Forward() * SACO_FORWARD)
				prop:SetAngles(ang)
			end
		else
			RemoveSacoProp(client)

			if (hiddenHeadBone[client] != nil) then
				ShowHead(client)
			end
		end
	end
end)

hook.Add("EntityRemoved", "ixSacoPropCleanup", function(entity)
	if (entity:IsPlayer()) then
		RemoveSacoProp(entity)
		hiddenHeadBone[entity] = nil
	end
end)

-- TEMPORAL: ajuste en vivo de LIFT/FORWARD sin reconectar, igual que
-- ix_restrain_setangle. Quitar cuando el ajuste esté bien.
concommand.Add("ix_saco_offset", function(_, _, args)
	local lift, forward = tonumber(args[1]), tonumber(args[2])

	if (!lift or !forward) then
		print("Uso: ix_saco_offset <lift> <forward>")
		print("Valores actuales: lift=" .. SACO_LIFT .. " forward=" .. SACO_FORWARD)
		return
	end

	SACO_LIFT = lift
	SACO_FORWARD = forward
	print("[Saco] lift=" .. SACO_LIFT .. " forward=" .. SACO_FORWARD)
end)

-- TEMPORAL: diagnóstico para ver qué posición se está calculando de verdad
-- en vez de seguir ajustando números a ciegas. Quitar cuando esté resuelto.
concommand.Add("ix_saco_debug", function()
	local found = false

	for _, client in ipairs(player.GetAll()) do
		if (client:GetNetVar("bagged")) then
			found = true
			local prop = sacoProps[client]

			print("[SacoDebug] " .. client:Name())
			print("  client:GetPos()   = " .. tostring(client:GetPos()))
			print("  client:EyePos()   = " .. tostring(client:EyePos()))
			print("  client:GetModel() = " .. tostring(client:GetModel()))
			print("  SACO_LIFT         = " .. tostring(SACO_LIFT))

			if (IsValid(prop)) then
				print("  prop existe, prop:GetPos() = " .. tostring(prop:GetPos()))
				print("  prop:GetModel()             = " .. tostring(prop:GetModel()))
			else
				print("  prop NO es válido (sacoProps[client] = " .. tostring(sacoProps[client]) .. ")")
			end
		end
	end

	if (!found) then
		print("[SacoDebug] Ningún jugador tiene 'bagged' activo ahora mismo.")
	end
end)

-- ============================================================
--  POSE DE MANOS ATADAS — mientras un jugador esté "restricted"
--  (esposado), se le fuerzan los brazos a una pose de manos cruzadas
--  tras la espalda mediante ManipulateBoneAngles. Puramente visual y
--  cliente-only (igual que el saco): cada cliente manipula los huesos
--  de cualquier jugador restringido que vea, sin tocar el servidor.
--
--  Los nombres de hueso son el esqueleto ValveBiped estándar (ya usado
--  en plugins/legs.lua para ocultar el cuerpo en primera persona), así
--  que deberían existir en cualquier playermodel de Metro RP. Los
--  ángulos son un punto de partida razonable, no un cálculo exacto —
--  como con el saco, seguramente haga falta afinarlos viendo capturas.
-- ============================================================

local ARM_BONE_ANGLES = {
	-- Confirmados en juego con ix_restrain_setangle. El resto sigue en 0 a
	-- falta de probarlo (antebrazos/manos).
	["ValveBiped.Bip01_R_Upperarm"] = Angle(-25, 25, 0),
	["ValveBiped.Bip01_L_Upperarm"] = Angle(25, 15, 0),
	["ValveBiped.Bip01_R_Forearm"]  = Angle(0, 0, 0),
	["ValveBiped.Bip01_L_Forearm"]  = Angle(0, 0, 0),
	["ValveBiped.Bip01_R_Hand"]     = Angle(0, 0, 0),
	["ValveBiped.Bip01_L_Hand"]     = Angle(0, 0, 0),
}

-- [client] = {[nombreHueso] = índice o false si no existe en su esqueleto}
local restrainedBones = {}

local function ApplyRestrainPose(client)
	local bones = restrainedBones[client]

	if (!bones) then
		bones = {}
		for name in pairs(ARM_BONE_ANGLES) do
			bones[name] = client:LookupBone(name) or false
		end
		restrainedBones[client] = bones
	end

	for name, ang in pairs(ARM_BONE_ANGLES) do
		local boneIndex = bones[name]
		if (boneIndex) then
			client:ManipulateBoneAngles(boneIndex, ang)
		end
	end
end

local function ClearRestrainPose(client)
	local bones = restrainedBones[client]
	if (!bones) then return end

	for name, boneIndex in pairs(bones) do
		if (boneIndex) then
			client:ManipulateBoneAngles(boneIndex, angle_zero)
		end
	end

	restrainedBones[client] = nil
end

-- TEMPORAL: ajuste en vivo sin tener que editar el archivo y reconectar cada
-- vez. El Think de abajo relee ARM_BONE_ANGLES cada frame, así que cambiar
-- una entrada aquí se ve al instante en cualquier jugador ya restringido.
-- Quitar cuando la pose esté bien.
local RESTRAIN_BONE_KEYS = {
	rupper = "ValveBiped.Bip01_R_Upperarm",
	lupper = "ValveBiped.Bip01_L_Upperarm",
	rfore  = "ValveBiped.Bip01_R_Forearm",
	lfore  = "ValveBiped.Bip01_L_Forearm",
	rhand  = "ValveBiped.Bip01_R_Hand",
	lhand  = "ValveBiped.Bip01_L_Hand",
}

concommand.Add("ix_restrain_setangle", function(_, _, args)
	local boneName = RESTRAIN_BONE_KEYS[args[1]]
	local p, y, r = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])

	if (!boneName or !p or !y or !r) then
		print("Uso: ix_restrain_setangle <rupper|lupper|rfore|lfore> <pitch> <yaw> <roll>")
		print("Valores actuales:")
		for key, name in pairs(RESTRAIN_BONE_KEYS) do
			print("  " .. key .. " (" .. name .. ") = " .. tostring(ARM_BONE_ANGLES[name]))
		end
		return
	end

	ARM_BONE_ANGLES[boneName] = Angle(p, y, r)
	print("[Restrain] " .. args[1] .. " -> " .. tostring(ARM_BONE_ANGLES[boneName]))
end)

-- Descartado: congelar SetCycle/SetPlaybackRate paraba el ciclo de "andar"
-- entero (brazos Y piernas comparten la misma animación de cuerpo completo),
-- dejando al jugador deslizándose sin animar las piernas al caminar. No hay
-- forma sencilla de congelar solo los brazos sin tocar el resto del ciclo,
-- así que ManipulateBoneAngles se queda como offset aditivo sobre la
-- animación normal (algo de balanceo residual en los brazos al andar, pero
-- las piernas quedan bien).
hook.Add("Think", "ixHandcuffsRestrainPose", function()
	for _, client in ipairs(player.GetAll()) do
		if (client:IsRestricted()) then
			ApplyRestrainPose(client)
		elseif (restrainedBones[client]) then
			ClearRestrainPose(client)
		end
	end
end)

hook.Add("EntityRemoved", "ixHandcuffsRestrainPoseCleanup", function(entity)
	if (entity:IsPlayer()) then
		restrainedBones[entity] = nil
	end
end)

-- ============================================================
--  CEGUERA POR SACO — mientras el propio jugador lleva un saco
--  puesto, la pantalla se queda en negro (no puede ver nada).
-- ============================================================

local HIDDEN_WHILE_BAGGED = {
	CHudCrosshair = true,
	CHudAmmo = true,
	CHudSecondaryAmmo = true,
	CHudHealth = true,
	CHudBattery = true,
	CHudWeaponSelection = true,
}

function PLUGIN:HUDShouldDraw(name)
	local client = LocalPlayer()
	if (IsValid(client) and client:GetNetVar("bagged") and HIDDEN_WHILE_BAGGED[name]) then
		return false
	end
end

-- ============================================================
--  AYUDA EN PANTALLA (crosshair) — como el aviso de loot de
--  "encontraste X" / "no has encontrado nada", pero contextual:
--  se mantiene mientras apuntas a un sujeto atado.
-- ============================================================

local HINT_RANGE = 96

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end

	-- Con el saco puesto no ves nada: pantalla en negro y ni rastro del resto del HUD.
	if (client:GetNetVar("bagged")) then
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, ScrW(), ScrH())
		return
	end

	if (client:IsRestricted()) then
		-- Sustituye el aviso nativo de Helix (suprimido con bNoMessage en
		-- sh_handcuffs.lua) por uno propio en español, con la fuente del HUD
		-- del inventario (ix_invkey) y el mismo ámbar usado en este archivo.
		ix.util.DrawText("Estás esposado", ScrW() * 0.5, ScrH() * 0.33, Color(230, 180, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, "ixInv.Title", 255)
		return
	end

	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity) or entity == client or !entity:IsPlayer()) then return end
	if (!entity:IsRestricted()) then return end
	if (client:GetPos():DistToSqr(entity:GetPos()) > (HINT_RANGE * HINT_RANGE)) then return end

	local lines = {}
	local draggedBy = entity:GetNetVar("bridasDraggedBy")

	if (IsValid(draggedBy) and draggedBy == client) then
		lines[#lines + 1] = "Toca [E] para soltar a " .. entity:Name()
	elseif (IsValid(draggedBy)) then
		lines[#lines + 1] = entity:Name() .. " ya está siendo arrastrado"
	elseif (!entity:GetNetVar("untying")) then
		lines[#lines + 1] = "Mantén [E] para desesposar  ·  Toca [E] para arrastrar"
	end

	if (entity:GetNetVar("bagged")) then
		lines[#lines + 1] = "Usa /QuitarSaco para quitarle el saco"
	end

	lines[#lines + 1] = "Toca [I] para cachear a " .. entity:Name()

	surface.SetFont("ixGenericFont")

	local baseY = ScrH() * 0.5 + 64
	for i, text in ipairs(lines) do
		ix.util.DrawText(text, ScrW() * 0.5, baseY + (i - 1) * 18, Color(230, 180, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, nil, 255)
	end
end

