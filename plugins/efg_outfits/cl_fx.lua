local PLUGIN = PLUGIN
local outfits = ix.efg.outfits

-- ─── Chalecos y cascos sin PAC ───────────────────────────────────────────────
-- Mismo principio que cl_armor.lua de JMod (sin instalar JMod): cada pieza es un
-- modelo de cliente sin padre que se dibuja a mano cada frame, puesto con la
-- matriz de su hueso y el offset de outfits.jmodOffsets (pos en el marco del
-- hueso, ángulos p/y/r y escala). El servidor solo manda los uniqueID en la
-- netvar efgArmorFx; el cliente sabe el modelo y el offset de cada uno.

local HIDE_DIST_SQR = 2500 * 2500
local tracked = {} -- [entity] = {sig = "...", parts = {{off =, model =, matrix =}}}
local nextScan = 0

local function clearParts(entry)
	for _, part in ipairs(entry.parts) do
		if (IsValid(part.model)) then part.model:Remove() end
	end
end

local function clear(entity)
	local entry = tracked[entity]
	if (!entry) then return end

	clearParts(entry)
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
	if (entry) then clearParts(entry) end

	entry = {sig = sig, parts = {}}

	for _, uniqueID in ipairs(list or {}) do
		local item = ix.item.list[uniqueID]
		local off = outfits.jmodOffsets[uniqueID]

		if (item and isstring(item.model) and off) then
			local model = ClientsideModel(item.model, RENDERGROUP_OPAQUE)

			if (IsValid(model)) then
				-- sin posición el modelo queda en el origen del mapa y el motor lo descarta
				model:SetNoDraw(true)
				model:SetPos(entity:GetPos())

				local matrix = Matrix()
				matrix:Scale(scale(off.scale))
				model:EnableMatrix("RenderMultiply", matrix)

				entry.parts[#entry.parts + 1] = {off = off, model = model}
			end
		end
	end

	tracked[entity] = entry
end

local function drawParts(entity, entry)
	for _, part in ipairs(entry.parts) do
		local off = part.off
		local index = entity:LookupBone(off.bon)

		if (index) then
			local matrix = entity:GetBoneMatrix(index)

			if (matrix) then
				local pos, ang = matrix:GetTranslation(), matrix:GetAngles()
				local right, forward, up = ang:Right(), ang:Forward(), ang:Up()

				pos = pos + right * off.pos.x + forward * off.pos.y + up * off.pos.z
				ang:RotateAroundAxis(right, off.ang.p)
				ang:RotateAroundAxis(up, off.ang.y)
				ang:RotateAroundAxis(forward, off.ang.r)

				part.model:SetPos(entity:GetPos())
				part.model:SetRenderOrigin(pos)
				part.model:SetRenderAngles(ang)
				part.model:DrawModel()
			end
		end
	end
end

hook.Add("PostDrawOpaqueRenderables", "efgOutfitFx", function(bDepth, bSky)
	if (bSky) then return end

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

	local eye = client:EyePos()

	for entity, entry in pairs(tracked) do
		if (IsValid(entity) and !entity:IsDormant() and !entity:GetNoDraw()) then
			local isLocal = entity == client
			local hide = (entity:IsPlayer() and !entity:Alive())
				or (isLocal and !client:ShouldDrawLocalPlayer())
				or (!isLocal and entity:GetPos():DistToSqr(eye) > HIDE_DIST_SQR)

			if (!hide) then drawParts(entity, entry) end
		end
	end
end)

hook.Add("EntityRemoved", "efgOutfitFx", function(entity)
	if (tracked[entity]) then clear(entity) end
end)
