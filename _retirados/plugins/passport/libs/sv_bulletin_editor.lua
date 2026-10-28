-- libs/sv_bulletin_editor.lua
-- Persistencia y edición in-game de boletines de frontera.
-- Los boletines por defecto viven en sh_rules.lua; los editados por admin se
-- guardan con ix.data y sobreescriben los de código al cargar.
local PLUGIN = PLUGIN

local function LoadCustomBulletins()
	local saved = ix.data.Get("passport_bulletins", nil)
	if (saved and istable(saved) and next(saved)) then
		PLUGIN.Bulletins = saved
	end
end

local function SaveCustomBulletins()
	ix.data.Set("passport_bulletins", PLUGIN.Bulletins)
end

hook.Add("InitPostEntity", "ixPassportLoadBulletins", function()
	LoadCustomBulletins()
end)

local function SendBulletins(client)
	local data = {}
	for idx, b in pairs(PLUGIN.Bulletins) do
		local docs = {}
		for docType, req in pairs(b.requireDocs or {}) do
			docs[docType] = isfunction(req) and "conditional" or "required"
		end
		data[idx] = {
			name = b.name or "",
			docs = docs,
			maxPermitDays = b.maxPermitDays or 30,
			stationRules = b.stationRules or {}
		}
	end

	net.Start("ix.pp.BulletinsData")
		net.WriteTable(data)
	net.Send(client)
end

net.Receive("ix.pp.RequestBulletins", function(_, client)
	if (not client:IsAdmin()) then return end
	SendBulletins(client)
end)

net.Receive("ix.pp.SaveBulletin", function(_, client)
	if (not client:IsAdmin()) then return end

	local idx = net.ReadUInt(8)
	local data = net.ReadTable() or {}

	if (idx < 1 or idx > 20) then return end

	local name = string.sub(tostring(data.name or "Sin nombre"), 1, 48)
	local maxDays = math.Clamp(math.floor(tonumber(data.maxPermitDays or 30) or 30), 1, 365)

	local requireDocs = {}
	for docType, mode in pairs(data.docs or {}) do
		docType = tostring(docType)
		if (mode == "conditional") then
			requireDocs[docType] = function(ctx)
				return (ctx.permit and ctx.permit.purpose == "Trabajo")
			end
		elseif (mode == "required") then
			requireDocs[docType] = true
		end
	end

	local stationRules = {}
	for stKey, sr in pairs(data.stationRules or {}) do
		stKey = tostring(stKey)
		local allowed = {}
		for _, f in ipairs(sr.allowed or {}) do allowed[#allowed + 1] = tostring(f) end
		local banned = {}
		for _, f in ipairs(sr.banned or {}) do banned[#banned + 1] = tostring(f) end
		stationRules[stKey] = { allowed = allowed, banned = banned }
	end

	PLUGIN.Bulletins[idx] = {
		name = name,
		requireDocs = requireDocs,
		maxPermitDays = maxDays,
		stationRules = stationRules
	}

	SaveCustomBulletins()
	PLUGIN:BroadcastDay()

	client:Notify(string.format("Boletín %d (%s) guardado.", idx, name))
	SendBulletins(client)
end)

net.Receive("ix.pp.DeleteBulletin", function(_, client)
	if (not client:IsAdmin()) then return end

	local idx = net.ReadUInt(8)
	if (idx < 1 or not PLUGIN.Bulletins[idx]) then return end

	if (idx == 1 and not PLUGIN.Bulletins[2]) then
		client:Notify("No puedes borrar el único boletín que queda.")
		return
	end

	local name = PLUGIN.Bulletins[idx] and PLUGIN.Bulletins[idx].name or ""
	PLUGIN.Bulletins[idx] = nil

	if (PLUGIN.CurrentDay == idx) then
		local first = next(PLUGIN.Bulletins)
		PLUGIN:SetCurrentDay(first or 1)
	end

	SaveCustomBulletins()
	client:Notify(string.format("Boletín %d (%s) eliminado.", idx, name))
	SendBulletins(client)
end)
