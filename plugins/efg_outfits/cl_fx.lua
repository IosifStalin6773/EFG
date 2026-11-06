local PLUGIN = PLUGIN
local outfits = ix.efg.outfits

-- ─── Chalecos y cascos sin PAC ───────────────────────────────────────────────
-- Mismo dato que cl_armor.lua de JMod (sin instalar JMod): cada pieza es un
-- modelo de cliente que sigue a un hueso del jugador (FollowBone), con el offset
-- de montaje (pos y ángulos en el marco del hueso) y la escala. El motor la dibuja
-- como al resto del equipo; aquí solo se oculta en primera persona, en muerte y lejos.
-- El servidor manda los uniqueID en la netvar efgArmorFx.

local HIDE_DIST_SQR = 2500 * 2500
local BODY_BONE = "ValveBiped.Bip01_Spine4"
local tracked = {} -- [entity] = {sig = "...", parts = {{uid =, model =}}}
local nextScan = 0

-- ─── Ajuste en vivo (cvars) ──────────────────────────────────────────────────
-- Un solo juego de valores para el cuerpo y otro para la cabeza, porque todas
-- las piezas comparten jmodBody y jmodHead. Se ajustan con la consola y
-- `efg_fx_print` escribe los valores finales para pegarlos en sh_pac.lua.
local function tuneSet(prefix, def)
	return {
		x = CreateClientConVar(prefix .. "_x", def.pos.x, true, false),
		y = CreateClientConVar(prefix .. "_y", def.pos.y, true, false),
		z = CreateClientConVar(prefix .. "_z", def.pos.z, true, false),
		pitch = CreateClientConVar(prefix .. "_pitch", def.ang.p, true, false),
		yaw = CreateClientConVar(prefix .. "_yaw", def.ang.y, true, false),
		roll = CreateClientConVar(prefix .. "_roll", def.ang.r, true, false),
		scale = CreateClientConVar(prefix .. "_scale", def.scale, true, false)
	}
end

local tune = {
	body = tuneSet("efg_fx_body", outfits.jmodOffsets.armor_6b13),
	head = tuneSet("efg_fx_head", outfits.jmodOffsets.helmet_6b47)
}

local function current(off)
	local set = off.bon == BODY_BONE and tune.body or tune.head

	return {
		bon = off.bon,
		pos = Vector(set.x:GetFloat(), set.y:GetFloat(), set.z:GetFloat()),
		ang = Angle(set.pitch:GetFloat(), set.yaw:GetFloat(), set.roll:GetFloat()),
		scale = set.scale:GetFloat()
	}
end

concommand.Add("efg_fx_print", function()
	local b, h = tune.body, tune.head
	print(("[EFG] cuerpo: pos = Vector(%g, %g, %g), ang = Angle(%g, %g, %g), scale = %g"):format(
		b.x:GetFloat(), b.y:GetFloat(), b.z:GetFloat(), b.pitch:GetFloat(), b.yaw:GetFloat(), b.roll:GetFloat(), b.scale:GetFloat()))
	print(("[EFG] cabeza: pos = Vector(%g, %g, %g), ang = Angle(%g, %g, %g), scale = %g"):format(
		h.x:GetFloat(), h.y:GetFloat(), h.z:GetFloat(), h.pitch:GetFloat(), h.yaw:GetFloat(), h.roll:GetFloat(), h.scale:GetFloat()))
end)

-- ─── Piezas por entidad ──────────────────────────────────────────────────────
local function clear(entity)
	local entry = tracked[entity]
	if (!entry) then return end

	for _, part in ipairs(entry.parts) do
		if (IsValid(part.model)) then part.model:Remove() end
	end

	tracked[entity] = nil
end

local function refresh(entity)
	local list = entity:GetNetVar("efgArmorFx")
	local sig = list and table.concat(list, ";") or ""
	local entry = tracked[entity]

	if (entry and entry.sig == sig) then return end
	if (entry) then clear(entity) end

	entry = {sig = sig, parts = {}}

	for _, uniqueID in ipairs(list or {}) do
		local item = ix.item.list[uniqueID]
		local off = outfits.jmodOffsets[uniqueID]
		local index = off and entity:LookupBone(off.bon)

		if (item and isstring(item.model) and index) then
			local model = ClientsideModel(item.model, RENDERGROUP_OPAQUE)

			if (IsValid(model)) then
				model:FollowBone(entity, index)
				entry.parts[#entry.parts + 1] = {uid = uniqueID, model = model}
			end
		end
	end

	tracked[entity] = entry
end

hook.Add("Think", "efgOutfitFx", function()
	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	-- ¿quién lleva chaleco o casco? cada medio segundo (jugadores y cadáveres)
	if (nextScan < CurTime()) then
		nextScan = CurTime() + 0.5

		local candidates = player.GetAll()
		for _, ragdoll in ipairs(ents.FindByClass("prop_ragdoll")) do candidates[#candidates + 1] = ragdoll end

		for _, entity in ipairs(candidates) do
			if (entity:GetNetVar("efgArmorFx") and !entity:IsDormant()) then
				refresh(entity)
			elseif (tracked[entity]) then
				clear(entity)
			end
		end

		for entity in pairs(tracked) do
			if (!IsValid(entity)) then clear(entity) end
		end
	end

	-- posición con las cvars (en vivo), y ocultar en primera persona, muertos o lejos
	local eye = client:EyePos()

	for entity, entry in pairs(tracked) do
		if (IsValid(entity)) then
			local isLocal = entity == client
			local hide = entity:GetNoDraw()
				or (entity:IsPlayer() and !entity:Alive())
				or (isLocal and !client:ShouldDrawLocalPlayer())
				or (!isLocal and entity:GetPos():DistToSqr(eye) > HIDE_DIST_SQR)

			for _, part in ipairs(entry.parts) do
				if (IsValid(part.model)) then
					local off = current(outfits.jmodOffsets[part.uid])

					part.model:SetLocalPos(off.pos)
					part.model:SetLocalAngles(off.ang)
					part.model:SetModelScale(off.scale)
					part.model:SetNoDraw(hide)
				end
			end
		end
	end
end)

hook.Add("EntityRemoved", "efgOutfitFx", function(entity)
	if (tracked[entity]) then clear(entity) end
end)
