local PLUGIN = PLUGIN

PLUGIN.name = "T-Pose Fixer"
PLUGIN.author = "EFG Project" -- original: DoopieWop
PLUGIN.description = "Attempts to fix T-Posing for models."
PLUGIN.cached = PLUGIN.cached or {}

local translations = {
	male_shared = "citizen_male",
	female_shared = "citizen_female",
	police_animations = "metrocop",
	combine_soldier_anims = "overwatch",
	vortigaunt_anims = "vortigaunt",
	m_anm = "player",
	f_anm = "player",
}

local og = ix.anim.SetModelClass
function ix.anim.SetModelClass(model, class)
	if (!ix.anim[class]) then return end

	PLUGIN.cached[model] = class

	og(model, class)
end

local function UpdateAnimationTable(client)
	local baseTable = ix.anim[client.ixAnimModelClass] or {}

	client.ixAnimTable = baseTable[client.ixAnimHoldType]
	client.ixAnimGlide = baseTable["glide"]
end

-- Checks bodygroup names AND the submodel paths within each bodygroup.
local function detectAnimClass(ply)
	for _, group in pairs(ply:GetSubModels()) do
		-- Some models store the submodel path directly in group.name
		local name = tostring(group.name or "")
		local class = name:gsub(".*/([^/]+)%.%w+$", "%1"):lower()
		if (class != name and translations[class]) then
			return translations[class]
		end

		-- Standard path: submodel file paths are stored in group.submodels
		for _, submodel in pairs(group.submodels or {}) do
			local subclass = tostring(submodel):gsub(".*/([^/]+)%.%w+$", "%1"):lower()
			if (translations[subclass]) then
				return translations[subclass]
			end
		end
	end

	return nil
end

function PLUGIN:PlayerModelChanged(ply, model)
	if (!IsValid(ply)) then return end

	-- timer since the model is not fully set yet when the hook fires
	timer.Simple(0, function()
		if (!IsValid(ply)) then return end

		if (!self.cached[model]) then
			local class = detectAnimClass(ply)

			if (class) then
				ix.anim.SetModelClass(model, class)
			elseif (ply:LookupSequence("walk_lower") != -1) then
				-- fallback: model has player animation sequences but no matching bodygroup
				ix.anim.SetModelClass(model, "player")
			end
		end

		ply.ixAnimModelClass = ix.anim.GetModelClass(model)

		UpdateAnimationTable(ply)
	end)
end

if (SERVER) then
	util.AddNetworkString("TPoseFixerSync")

	function PLUGIN:PlayerInitialSpawn(client)
		net.Start("TPoseFixerSync")
			net.WriteTable(self.cached)
		net.Send(client)
	end
else
	net.Receive("TPoseFixerSync", function()
		for k, v in pairs(net.ReadTable()) do
			ix.anim.SetModelClass(k, v)
		end
	end)
end
