local PLUGIN = PLUGIN

PLUGIN.name = "Primary Needs (legacy)"
PLUGIN.author = "firehellrain"
PLUGIN.description = "Comandos legacy redirigidos al sistema needs (satiety/saturation)."

ix.util.Include("cl_hooks.lua")
ix.util.Include("sv_hooks.lua")

ix.command.Add("CharSetHunger", {
	description = "Ajusta el hambre (satiety) de un jugador.",
	privilege = "Manage Character Attributes",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.number
	},
	OnRun = function(self, client, target, amount)
		local clamped = math.Clamp(math.Round(amount), 0, 100)
		target:SetSatiety(clamped)

		client:NotifyLocalized("setHunger", client:GetName(), target:GetName(), clamped)
	end
})

ix.command.Add("CharSetThirst", {
	description = "Ajusta la sed (saturation) de un jugador.",
	privilege = "Manage Character Attributes",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.number
	},
	OnRun = function(self, client, target, amount)
		local clamped = math.Clamp(math.Round(amount), 0, 100)
		target:SetSaturation(clamped)

		client:NotifyLocalized("setThirst", client:GetName(), target:GetName(), clamped)
	end
})
