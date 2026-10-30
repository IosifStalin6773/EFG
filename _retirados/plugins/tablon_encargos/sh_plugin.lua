local PLUGIN = PLUGIN

PLUGIN.name = "Tablón de Encargos"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Tablón donde los jugadores publican encargos de ítems. Pagan RUB como garantía y un artesano los cumple entregando los ítems."

ix.encargos = ix.encargos or {}

ix.encargos.config = {
	maxOrdersPerPlayer = 5,
	maxReward = 5000000,
	minReward = 1,
	taxRate = 0.10,
}

ix.encargos.STATUS_PENDING = 0

-- Net strings
PLUGIN.netOpen = "Encargos.Open"
PLUGIN.netCreate = "Encargos.Create"
PLUGIN.netCancel = "Encargos.Cancel"
PLUGIN.netFulfill = "Encargos.Fulfill"
PLUGIN.netPickup = "Encargos.Pickup"
PLUGIN.netClose = "Encargos.Close"

-- Devuelve todos los ítems registrados en el juego (sin restricción).
function ix.encargos.GetAllItems()
	local items = {}

	for uniqueID, itemTable in pairs(ix.item.list) do
		if (itemTable.name) then
			items[uniqueID] = {
				id = uniqueID,
				name = itemTable.name,
				category = itemTable.category or "Otros",
			}
		end
	end

	return items
end

-- Comandos admin
ix.command.Add("ColocarTablon", {
	description = "Coloca un Tablón de Encargos. Opcional: ruta de un modelo custom (ej. models/mi_addon/tablon.mdl).",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.string, ix.type.optional),
	},
	OnRun = function(self, client, model)
		if (SERVER) then
			if (model and model != "" and not util.IsValidModel(model)) then
				return client:Notify("Modelo no válido: " .. model)
			end

			local trace = client:GetEyeTraceNoCursor()
			local pos = trace.HitPos + trace.HitNormal * 5
			local ang = (client:GetPos() - pos):Angle()
			ang.pitch = 0
			ang.roll = 0

			local ent = ents.Create("metro_tablon_encargos")
			if (not IsValid(ent)) then
				return client:Notify("No se pudo crear la entidad.")
			end

			if (model and model != "") then
				ent.tablonModel = model
			end

			ent:SetPos(pos)
			ent:SetAngles(ang)
			ent:Spawn()
			ent:Activate()

			ix.encargos.SaveTablones()
			client:Notify("Tablón de Encargos colocado.")
		end
	end
})

ix.command.Add("QuitarTablon", {
	description = "Elimina el Tablón de Encargos al que estás mirando.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local ent = client:GetEyeTrace().Entity
			if (not IsValid(ent) or ent:GetClass() != "metro_tablon_encargos") then
				return client:Notify("No estás mirando a ningún Tablón de Encargos.")
			end

			ix.encargos.RemoveTablon(ent)
			ent:Remove()
			client:Notify("Tablón de Encargos eliminado.")
		end
	end
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
