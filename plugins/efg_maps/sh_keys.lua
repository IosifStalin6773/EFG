-- ─── Llaves y puertas cerradas (Keys) ───────────────────────────────────────
-- Los admins cierran una puerta del mapa con /PuertaLlave <llave> mirándola.
-- Se abre si llevas la llave (en el inventario o en el llavero); cada apertura
-- gasta un uso. Las tarjetas de Laboratorio funcionan igual.
local MAPS = ix.efg.maps

-- id = {nombre, usos, precio, mapa}. [VERIFICAR wiki: Keys] selección de memoria.
MAPS.keys = {
	dorms_314 = {"Llave de la habitación 314 de los dormitorios", 15, 60000, "customs"},
	dorms_214 = {"Llave de la habitación 214 de los dormitorios", 15, 15000, "customs"},
	dorms_220 = {"Llave de la habitación 220 de los dormitorios", 15, 10000, "customs"},
	dorms_308 = {"Llave de la habitación 308 de los dormitorios", 15, 15000, "customs"},
	marked_room = {"Llave de la habitación marcada (dormitorios)", 25, 1200000, "customs"},
	tarcone = {"Llave del despacho del director de Tarcone", 10, 70000, "customs"},
	gas_station = {"Llave del almacén de la gasolinera", 10, 15000, "customs"},
	portable_bunkhouse = {"Llave de la caseta portátil", 15, 20000, "customs"},
	factory_exit = {"Llave de la salida de la fábrica", 40, 25000, "factory"},
	pumping_station = {"Llave de la estación de bombeo", 10, 15000, "factory"},
	woods_zb014 = {"Llave del búnker ZB-014", 10, 60000, "woods"},
	woods_yotota = {"Llave del coche abandonado", 10, 30000, "woods"},
	shoreline_east_218 = {"Llave del ala este, habitación 218", 15, 40000, "shoreline"},
	shoreline_west_301 = {"Llave del ala oeste, habitación 301", 15, 40000, "shoreline"},
	shoreline_cottage = {"Llave de la cabaña", 15, 30000, "shoreline"},
	interchange_kiba = {"Llave exterior de KIBA Arms", 10, 120000, "interchange"},
	interchange_kiba_inner = {"Llave interior de KIBA Arms", 10, 120000, "interchange"},
	interchange_ultra = {"Llave del almacén de ULTRA", 15, 40000, "interchange"},
	reserve_rb_bk = {"Llave de la sala RB-BK", 15, 90000, "reserve"},
	reserve_rb_vo = {"Llave de la sala RB-VO", 15, 90000, "reserve"},
	reserve_rb_ok = {"Llave de la sala RB-OK", 15, 90000, "reserve"},
	lighthouse_conference = {"Llave de la sala de conferencias del faro", 10, 50000, "lighthouse"},
	streets_concordia = {"Llave del apartamento de Concordia", 10, 80000, "streets"},
	-- Laboratorio
	labs_access = {"Tarjeta de acceso al Laboratorio", 1, 120000, "labs", true},
	labs_red = {"Tarjeta roja del Laboratorio", 10, 3500000, "labs", true},
	labs_blue = {"Tarjeta azul del Laboratorio", 10, 700000, "labs", true},
	labs_green = {"Tarjeta verde del Laboratorio", 10, 300000, "labs", true},
	labs_violet = {"Tarjeta violeta del Laboratorio", 10, 1200000, "labs", true},
	labs_yellow = {"Tarjeta amarilla del Laboratorio", 10, 600000, "labs", true},
	labs_black = {"Tarjeta negra del Laboratorio", 10, 2000000, "labs", true}
}

function MAPS.KeyItemID(keyID)
	return "key_" .. keyID
end

hook.Add("InitializedPlugins", "efgMaps.Keys", function()
	for keyID, data in pairs(MAPS.keys) do
		local ITEM = ix.item.Register(MAPS.KeyItemID(keyID), nil, nil, nil, true)

		ITEM.name = data[1]
		ITEM.description = (data[5] and "Tarjeta de acceso. " or "Llave. ") .. "Abre una puerta cerrada de " ..
			(MAPS.locations[data[4]] and MAPS.locations[data[4]].name or data[4]) .. "."
		ITEM.model = data[5] and "models/props_lab/clipboard.mdl" or "models/props_c17/TrapPropeller_Lever.mdl"
		ITEM.width = 1
		ITEM.height = 1
		ITEM.weight = 0.05
		ITEM.category = "Llaves"
		ITEM.price = data[3]
		ITEM.isEFGKey = true
		ITEM.efgKeyID = keyID
		ITEM.maxUses = data[2]

		function ITEM:GetDescription()
			return ("%s\n\nUsos: %d/%d"):format(self.description, self:GetData("uses", self.maxUses), self.maxUses)
		end

		if (CLIENT) then
			function ITEM:PaintOver(item, w, h)
				draw.SimpleText(item:GetData("uses", item.maxUses) .. "/" .. item.maxUses, "DermaDefault", w - 3, h - 3,
					color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
			end
		end
	end
end)

ix.command.Add("PuertaLlave", {
	description = "Cierra la puerta que miras para que solo se abra con esa llave (sin llave: quita el cierre).",
	adminOnly = true,
	arguments = bit.bor(ix.type.string, ix.type.optional),
	OnRun = function(self, client, keyID)
		local door = client:GetEyeTrace().Entity

		if (!IsValid(door) or !door:IsDoor()) then
			return "Mira a una puerta."
		end

		if (keyID and !MAPS.keys[keyID]) then
			return "Llave desconocida. Ejemplos: " .. table.concat(table.GetKeys(MAPS.keys), ", ", 1, 6) .. "…"
		end

		return MAPS.SetDoorKey(door, keyID)
	end
})

ix.command.Add("Llaves", {
	description = "Lista las llaves de EFT disponibles para /PuertaLlave.",
	adminOnly = true,
	OnRun = function(self, client)
		local keys = table.GetKeys(MAPS.keys)
		table.sort(keys)

		for _, keyID in ipairs(keys) do
			client:ChatPrint(keyID .. " — " .. MAPS.keys[keyID][1])
		end
	end
})

if (SERVER) then
	-- puertas cerradas: [MapCreationID] = keyID
	MAPS.doors = MAPS.doors or {}

	local function saveDoors()
		ix.data.Set("efg_doors", MAPS.doors)
	end

	hook.Add("InitPostEntity", "efgMaps.LoadDoors", function()
		MAPS.doors = ix.data.Get("efg_doors", {}) or {}

		for id, keyID in pairs(MAPS.doors) do
			local door = ents.GetMapCreatedEntity(tonumber(id))

			if (IsValid(door)) then
				door.efgKey = keyID
				door:Fire("Lock")
			end
		end
	end)

	function MAPS.SetDoorKey(door, keyID)
		local id = door:MapCreationID()
		if (id < 0) then return "Esa puerta no es del mapa." end

		MAPS.doors[tostring(id)] = keyID
		door.efgKey = keyID
		door:Fire(keyID and "Lock" or "Unlock")
		saveDoors()

		return keyID and ("Puerta cerrada con " .. MAPS.keys[keyID][1] .. ".") or "Puerta abierta para todos."
	end

	-- busca la llave en el inventario y en las bolsas/llavero que lleve
	local function findKey(client, keyID)
		local uniqueID = MAPS.KeyItemID(keyID)
		local character = client:GetCharacter()
		if (!character) then return end

		for _, item in pairs(character:GetInventory():GetItems(false)) do
			if (item.uniqueID == uniqueID) then return item end
		end
	end

	hook.Add("PlayerUse", "efgMaps.LockedDoors", function(client, door)
		if (!door.efgKey or door.efgUnlocked) then return end
		if ((client.efgNextDoor or 0) > CurTime()) then return false end
		client.efgNextDoor = CurTime() + 1

		local key = findKey(client, door.efgKey)

		if (!key) then
			door:EmitSound("doors/default_locked.wav", 65)
			client:Notify("Está cerrada. Necesitas: " .. MAPS.keys[door.efgKey][1])
			return false
		end

		local uses = key:GetData("uses", key.maxUses) - 1
		client:SetAction("Abriendo…", 2)

		timer.Simple(2, function()
			if (!IsValid(door) or !IsValid(client)) then return end

			door.efgUnlocked = true
			door:Fire("Unlock")
			door:Fire("Open")
			door:EmitSound("doors/door_latch3.wav", 65)

			if (uses <= 0) then
				key:Remove()
				client:Notify("La llave se ha gastado.")
			else
				key:SetData("uses", uses)
			end
		end)

		return false
	end)

	-- al empezar una nueva raid en el servidor vacío, las puertas se vuelven a cerrar
	hook.Add("EFGRaidEnded", "efgMaps.RelockDoors", function()
		for _, client in ipairs(player.GetAll()) do
			if (client:InRaid()) then return end
		end

		for id in pairs(MAPS.doors) do
			local door = ents.GetMapCreatedEntity(tonumber(id))

			if (IsValid(door)) then
				door.efgUnlocked = nil
				door:Fire("Close")
				door:Fire("Lock")
			end
		end
	end)
end
