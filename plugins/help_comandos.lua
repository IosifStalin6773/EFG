PLUGIN.name = "Ayuda de Comandos"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Comando /comandos que lista todos los comandos disponibles con su sintaxis."

-- Mapa de tipos ix a nombres legibles en español
local TYPE_NAMES = {
	[1]  = "si/no",      -- ix.type.bool
	[2]  = "número",     -- ix.type.number
	[4]  = "texto",      -- ix.type.string
	[8]  = "jugador",    -- ix.type.player
	[16] = "personaje",  -- ix.type.character
	[32] = "texto...",   -- ix.type.text
}

local function argStr(argType)
	local opt = ix.type.optional
	local base = bit.band(argType, bit.bnot(opt))
	local name = TYPE_NAMES[base] or "?"
	if (bit.band(argType, opt) != 0) then
		return "[" .. name .. "]"
	end
	return "<" .. name .. ">"
end

local function buildSyntax(arguments)
	if (!arguments) then return "" end
	if (!istable(arguments)) then return " " .. argStr(arguments) end
	local parts = {}
	for _, a in ipairs(arguments) do
		parts[#parts+1] = argStr(a)
	end
	return (#parts > 0) and (" " .. table.concat(parts, " ")) or ""
end

local function resolveDesc(desc, client)
	if (!desc or desc == "") then return "(sin descripción)" end
	if (desc:sub(1, 1) == "@") then
		local key = desc:sub(2)
		local resolved = L(key, client)
		return (resolved and resolved != key) and resolved or key
	end
	return desc
end

-- Devuelve true si el cliente tiene permisos para ejecutar el comando.
local function canPlayerRun(client, cmd)
	if (cmd.superAdminOnly and !client:IsSuperAdmin()) then return false end
	if (cmd.adminOnly and !client:IsAdmin()) then return false end
	if (cmd.privilege) then
		-- CAMI es el estándar de Helix para permisos entre addons de admin
		if (CAMI and CAMI.PlayerHasAccess) then
			local hasAccess = false
			CAMI.PlayerHasAccess(client, cmd.privilege, function(access) hasAccess = access end)
			if (!hasAccess) then return false end
		else
			if (!client:IsAdmin()) then return false end
		end
	end
	return true
end

ix.command.Add("comandos", {
	description = "Lista todos los comandos disponibles del servidor.",
	alias = {"cmds"},
	OnRun = function(self, client)
		local isSuperAdmin = client:IsSuperAdmin()
		local isAdmin = client:IsAdmin()
		local regularLines = {}
		local adminLines = {}
		local shown = {}

		for name, cmd in SortedPairs(ix.command.list) do
			if (shown[cmd]) then continue end
			shown[cmd] = true
			if (!canPlayerRun(client, cmd)) then continue end

			local desc = resolveDesc(cmd.description, client)
			local line = "/" .. name .. buildSyntax(cmd.arguments) .. " — " .. desc

			if (cmd.superAdminOnly or cmd.adminOnly or cmd.privilege) then
				adminLines[#adminLines+1] = line
			else
				regularLines[#regularLines+1] = line
			end
		end

		local tag = isSuperAdmin and " [superadmin]" or (isAdmin and " [admin]" or "")

		client:ChatPrint("═══ COMANDOS DISPONIBLES" .. tag .. " ═══")

		if (#regularLines > 0) then
			client:ChatPrint("— Generales —")
			for _, line in ipairs(regularLines) do
				client:ChatPrint(line)
			end
		end

		if (#adminLines > 0) then
			client:ChatPrint("— Administración —")
			for _, line in ipairs(adminLines) do
				client:ChatPrint(line)
			end
		end

		client:ChatPrint("═══════════════════════════")
		client:ChatPrint("Total: " .. (#regularLines + #adminLines) .. " comando(s)")
	end
})
