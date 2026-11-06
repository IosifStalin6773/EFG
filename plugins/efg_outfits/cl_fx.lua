local PLUGIN = PLUGIN
local outfits = ix.efg.outfits

-- ─── Chalecos y cascos sin PAC ───────────────────────────────────────────────
-- Mismo dato que cl_armor.lua de JMod (sin instalar JMod): cada pieza es un
-- modelo de cliente que sigue a un hueso del jugador (FollowBone), con el offset
-- de outfits.jmodOffsets (pos y ángulos en el marco del hueso) y escala. El motor
-- la dibuja como al resto del equipo; aquí solo se oculta en primera persona,
-- en muerte y lejos. El servidor manda los uniqueID en la netvar efgArmorFx.

local HIDE_DIST_SQR = 2500 * 2500
local tracked = {} -- [entity] = {sig = "...", parts = {{model =}}}
local nextScan = 0

local function clear(entity)
	local entry = tracked[entity]
	if (!entry) then return end

	for _, part in ipairs(entry.parts) do
		if (IsValid(part.model)) then part.model:Remove() end
	end

	tracked[entity] = nil
end

local function scale(value)
	if (isvector(value)) then return value end
	return Vector(value or 1, value or 1, value or 1)
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
				local matrix = Matrix()
				matrix:Scale(scale(off.scale))
				model:EnableMatrix("RenderMultiply", matrix)

				model:FollowBone(entity, index)
				model:SetLocalPos(off.pos)
				model:SetLocalAngles(off.ang)

				entry.parts[#entry.parts + 1] = {model = model}
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

	-- ocultar: en primera persona, muertos o lejos
	local eye = client:EyePos()

	for entity, entry in pairs(tracked) do
		if (IsValid(entity)) then
			local isLocal = entity == client
			local hide = entity:GetNoDraw()
				or (entity:IsPlayer() and !entity:Alive())
				or (isLocal and !client:ShouldDrawLocalPlayer())
				or (!isLocal and entity:GetPos():DistToSqr(eye) > HIDE_DIST_SQR)

			for _, part in ipairs(entry.parts) do
				if (IsValid(part.model)) then part.model:SetNoDraw(hide) end
			end
		end
	end
end)

hook.Add("EntityRemoved", "efgOutfitFx", function(entity)
	if (tracked[entity]) then clear(entity) end
end)
