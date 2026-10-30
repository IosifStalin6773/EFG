-- Accesorios estéticos del PMC (gorro, máscara, gafas, auriculares) pegados con
-- bonemerge al jugador, a su cadáver y a los modelos de las pantallas de menú.
local PMC = ix.efg.pmc

local function bonemerge(parent, path, bodygroup, option)
	local model = ClientsideModel(path, RENDERGROUP_OPAQUE)
	if (!IsValid(model)) then return end

	model:SetParent(parent)
	model:AddEffects(EF_BONEMERGE)
	model:AddEffects(EF_BONEMERGE_FASTCULL)
	model:SetBodygroup(bodygroup, option)
	model:SetupBones()

	return model
end

-- crea los modelos para una tabla {id = opción}; accs.mdl lleva dos huecos
-- (máscara y auriculares) en un solo modelo
function PMC.BuildCosmeticModels(parent, chosen)
	local byPath, models = {}, {}

	for _, info in ipairs(PMC.cosmetics) do
		local option = tonumber((chosen or {})[info.id])

		if (option and option > 0) then
			local model = byPath[info.model]

			if (IsValid(model)) then
				model:SetBodygroup(info.bodygroup, option)
			else
				model = bonemerge(parent, info.model, info.bodygroup, option)
				byPath[info.model] = model
				models[#models + 1] = model
			end
		end
	end

	return models
end

local function removeAll(models)
	for _, model in ipairs(models or {}) do
		if (IsValid(model)) then model:Remove() end
	end
end

-- ─── En el mundo ─────────────────────────────────────────────────────────────
local attached = {} -- [entity] = {sig =, models =}

local function clear(entity)
	local entry = attached[entity]
	if (!entry) then return end

	removeAll(entry.models)
	attached[entity] = nil
end

local nextScan = 0

hook.Add("Think", "efgPMCCosmetics", function()
	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	if (nextScan < CurTime()) then
		nextScan = CurTime() + 0.5

		local candidates = player.GetAll()
		for _, ragdoll in ipairs(ents.FindByClass("prop_ragdoll")) do candidates[#candidates + 1] = ragdoll end

		for _, entity in ipairs(candidates) do
			local chosen = entity:GetNetVar("efgCosmetic")
			local entry = attached[entity]

			if (chosen and !entity:IsDormant()) then
				local sig = (entity:GetModel() or "") .. util.TableToJSON(chosen)

				if (!entry or entry.sig != sig) then
					clear(entity)
					attached[entity] = {sig = sig, models = PMC.BuildCosmeticModels(entity, chosen)}
				end
			elseif (entry) then
				clear(entity)
			end
		end

		for entity in pairs(attached) do
			if (!IsValid(entity)) then clear(entity) end
		end
	end

	for entity, entry in pairs(attached) do
		if (IsValid(entity)) then
			local hide = entity:GetNoDraw() or (entity:IsPlayer() and (!entity:Alive() or (entity == client and !client:ShouldDrawLocalPlayer())))

			for _, model in ipairs(entry.models) do
				if (IsValid(model)) then model:SetNoDraw(hide) end
			end
		end
	end
end)

hook.Add("EntityRemoved", "efgPMCCosmetics", function(entity)
	if (attached[entity]) then clear(entity) end
end)

-- ─── En paneles de modelo (DModelPanel / ixModelPanel) ───────────────────────
-- Los modelos de cliente no se pintan solos dentro de un panel: se dibujan en
-- PostDrawModel del propio panel.
function PMC.SetPanelCosmetics(panel, chosen)
	removeAll(panel.efgCosmeticModels)
	panel.efgCosmeticModels = nil

	if (!IsValid(panel.Entity)) then return end

	local models = PMC.BuildCosmeticModels(panel.Entity, chosen)

	for _, model in ipairs(models) do model:SetNoDraw(true) end
	panel.efgCosmeticModels = models

	if (!panel.efgCosmeticHooked) then
		panel.efgCosmeticHooked = true

		local postDraw = panel.PostDrawModel
		panel.PostDrawModel = function(this, entity)
			if (postDraw) then postDraw(this, entity) end

			for _, model in ipairs(this.efgCosmeticModels or {}) do
				if (IsValid(model)) then
					model:SetParent(entity)
					model:DrawModel()
				end
			end
		end

		local onRemove = panel.OnRemove
		panel.OnRemove = function(this)
			removeAll(this.efgCosmeticModels)
			if (onRemove) then onRemove(this) end
		end
	end
end
