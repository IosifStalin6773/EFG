local PLUGIN = PLUGIN

PLUGIN.name = "Oficios"
PLUGIN.author = "Metro RP By Cono y Manperra"
PLUGIN.description = "Sistema de oficios para Metro RP 2033. Cada personaje elige un oficio que desbloquea recetas de crafteo por tiers."

ix.oficios = ix.oficios or {}

-- Oficios ELEGIBLES en la creación de personaje (chatarrero NO está aquí: es transversal).
ix.oficios.lista = {
	armero     = "Armero",
	medico     = "Médico",
	quimico    = "Químico",
	sastre     = "Sastre",
}

-- Comprueba si un personaje puede craftear una receta de cierto oficio y tier.
function ix.oficios.CanCraft(character, oficio, tier)
	if (!character) then return false end

	-- Chatarrero es TRANSVERSAL: todos los personajes lo tienen, con su propio tier.
	if (oficio == "chatarrero") then
		return (character:GetChatarreroTier() or 0) >= tier
	end

	return character:GetOficio() == oficio and (character:GetOficioTier() or 0) >= tier
end

-- Oficio principal elegido en la creación del personaje.
ix.char.RegisterVar("oficio", {
	field = "oficio",
	fieldType = ix.type.string,
	default = "ninguno",
	index = 2.5,

	OnDisplay = function(self, container, payload)
		local OPCIONES = {
			{id = "armero",     nombre = "Armero",     color = Color(140, 100, 60)},
			{id = "medico",     nombre = "Médico",     color = Color(60, 140, 100)},
			{id = "quimico",    nombre = "Químico",    color = Color(100, 60, 140)},
			{id = "sastre",     nombre = "Sastre",     color = Color(160, 110, 80)},
		}

		local panel = container:Add("DPanel")
		panel:Dock(TOP)
		panel.Paint = function() end

		local btnList = {}
		local totalH = 0

		-- el panel se repuebla cada vez que el jugador avanza/retrocede entre subpaneles
		-- (Populate() en cl_charcreate.lua), así que hay que conservar la elección previa
		-- en vez de forzar siempre "Armero": si no, elegir Químico y volver atrás lo
		-- reseteaba en silencio a Armero sin que el jugador se diera cuenta.
		local lastSelected = payload.oficio

		local bValid = false
		for _, opcion in ipairs(OPCIONES) do
			if (opcion.id == lastSelected) then bValid = true break end
		end
		if (!bValid) then lastSelected = OPCIONES[1].id end

		payload:Set("oficio", lastSelected)

		for i, opcion in ipairs(OPCIONES) do
			local btn = panel:Add("ixMenuSelectionButton")
			btn:SetText(opcion.nombre, true)
			btn:SetBackgroundColor(opcion.color)
			btn:SizeToContents()
			btn:Dock(TOP)

			if (i > 1) then
				btn:DockMargin(0, 4, 0, 0)
			end

			btn.oficioID = opcion.id
			btn:SetButtonList(btnList)
			btn.OnSelected = function(this)
				payload:Set("oficio", this.oficioID)
			end

			if (opcion.id == lastSelected) then
				btn:SetSelected(true)
			end

			totalH = totalH + btn:GetTall() + (i > 1 and 4 or 0)
		end

		panel:SetTall(totalH)
		return panel
	end,

	OnValidate = function(self, value, payload, client)
		for id, _ in pairs(ix.oficios.lista) do
			if (id == value) then return value end
		end
		return false, "invalid", "oficio"
	end
})

-- Tier actual del oficio principal (0–3). Se gestiona programáticamente.
-- Key camelCase para que Helix genere GetOficioTier / SetOficioTier correctamente.
ix.char.RegisterVar("oficioTier", {
	field = "oficio_tier",
	fieldType = ix.type.number,
	default = 0,
	bNoDisplay = true,
})

-- Tier del oficio transversal Chatarrero (1–3). Todos los personajes empiezan en 1.
ix.char.RegisterVar("chatarreroTier", {
	field = "chatarrero_tier",
	fieldType = ix.type.number,
	default = 1,
	bNoDisplay = true,
})

-- Stubs de cliente para que los comandos aparezcan en el autocompletado del chat
if (CLIENT) then
	ix.command.Add("SetOficio", { adminOnly=true, arguments={ix.type.player, ix.type.string, ix.type.number}, description="Establece el oficio y tier de un personaje.", OnRun=function(self, client, target, oficio, tier) end })
	ix.command.Add("SetChatarrero", { adminOnly=true, arguments={ix.type.player, ix.type.number}, description="Establece el tier de Chatarrero (transversal) de un personaje.", OnRun=function(self, client, target, tier) end })
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
