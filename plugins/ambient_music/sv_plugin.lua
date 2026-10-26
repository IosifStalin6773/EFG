local PLUGIN = PLUGIN

util.AddNetworkString("AmbientMusic_Sync")
util.AddNetworkString("AmbientMusic_Stop")

PLUGIN.points = {}
PLUGIN.soundPath = ""
PLUGIN.radius = 1500
PLUGIN.maxVolume = 1.0

-- Cargar en LoadData (no en Initialize): es el hook que Helix corre cuando el
-- sistema de datos ya está listo, igual que el resto del schema (p.ej. badair).
-- En Initialize la carga podía correr demasiado pronto y quedarse con los
-- valores por defecto, dando la sensación de que "no se guardaba".
-- self:GetData() usa la clave "ambient_music" (mismo archivo que antes).
function PLUGIN:LoadData()
	local data = self:GetData()

	self.points = data.points or {}
	self.soundPath = data.soundPath or ""
	self.radius = data.radius or 1500
	self.maxVolume = data.maxVolume or 1.0
end

-- Guardado inmediato a disco en cada cambio (no esperamos al SaveData periódico),
-- así la música y los puntos sobreviven a un crash o reinicio del servidor.
function PLUGIN:SaveConfig()
	self:SetData({
		points = self.points,
		soundPath = self.soundPath,
		radius = self.radius,
		maxVolume = self.maxVolume,
	})
end

function PLUGIN:SyncToPlayer(client)
	net.Start("AmbientMusic_Sync")
		net.WriteString(self.soundPath)
		net.WriteFloat(self.radius)
		net.WriteFloat(self.maxVolume)
		net.WriteUInt(#self.points, 8)

		for _, p in ipairs(self.points) do
			net.WriteVector(Vector(p[1], p[2], p[3]))
		end
	net.Send(client)
end

function PLUGIN:SyncAll()
	net.Start("AmbientMusic_Sync")
		net.WriteString(self.soundPath)
		net.WriteFloat(self.radius)
		net.WriteFloat(self.maxVolume)
		net.WriteUInt(#self.points, 8)

		for _, p in ipairs(self.points) do
			net.WriteVector(Vector(p[1], p[2], p[3]))
		end
	net.Broadcast()
end

function PLUGIN:StopAll()
	net.Start("AmbientMusic_Stop")
	net.Broadcast()
end

function PLUGIN:CharacterLoaded(character)
	local client = character:GetPlayer()

	if (IsValid(client)) then
		timer.Simple(1, function()
			if (IsValid(client)) then
				self:SyncToPlayer(client)
			end
		end)
	end
end
