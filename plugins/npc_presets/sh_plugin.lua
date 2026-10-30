PLUGIN.name        = "NPC Presets"
PLUGIN.author      = "EFG Project"
PLUGIN.description = "Sistema de spawns de NPCs en puntos específicos del mapa con presets configurables."

-- Inicializar namespace compartido para que el cliente también lo tenga
ix.npcpresets                 = ix.npcpresets or {}
ix.npcpresets.presets         = ix.npcpresets.presets         or {}
ix.npcpresets.points          = ix.npcpresets.points          or {}
ix.npcpresets.alarmPoints     = ix.npcpresets.alarmPoints     or {}
ix.npcpresets.hordeTargets    = ix.npcpresets.hordeTargets    or {}
ix.npcpresets.patrolWaypoints = ix.npcpresets.patrolWaypoints or {}

-- ── Helpers de red (JSON + compress) ─────────────────────────

function ix.npcpresets.WriteCompressed(tbl)
	local json = util.TableToJSON(tbl)
	local compressed = util.Compress(json)
	local len = #compressed
	net.WriteUInt(len, 32)
	net.WriteData(compressed, len)
end

function ix.npcpresets.ReadCompressed()
	local len = net.ReadUInt(32)
	if (len == 0) then return {} end
	local compressed = net.ReadData(len)
	local json = util.Decompress(compressed)
	if (!json) then return {} end
	return util.JSONToTable(json) or {}
end

ix.util.Include("sh_commands.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")
