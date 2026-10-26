PLUGIN.name = "Extra Commands"
PLUGIN.author = "Luna"
PLUGIN.desc = "A few useful commands."

/*
nut.command.add("nickset", {
	syntax = "[String Nickname]",
	onRun = function(client, arguments)
		if (arguments[1]) then
			if (!string.find(client:Name(), "'")) then
				local name = string.Split(client:getChar():getName(), " ")
				local newName = name[1].." '"..arguments[1].."' "..name[2]

				client:getChar():setName(newName)
				client:ChatPrint("Your name is now "..newName..".")
			else
				local name = string.Split(client:getChar():getName(), " ")
				string.Split(client:getChar():getName(), " ")
				local newName = name[1].." '"..arguments[1].."' "..name[3]

				client:getChar():setName(newName)
				client:ChatPrint("Your name is now "..newName..".")
			end;
		else
			client:ChatPrint("You need to enter a nickname.")
		end;
	end;
})

nut.command.add("nickremove", {
	syntax = "[No Input]",
	onRun = function(client, arguments)
		if (!string.find(client:Name(), "'")) then
			client:ChatPrint("No nickname was detected.")
		else
			local name = string.Split(client:getChar():getName(), " ")
			string.Split(client:getChar():getName(), " ")
			local newName = name[1].." "..name[3]

			client:getChar():setName(newName)
			client:ChatPrint("Your name is now "..newName..".")
		end;
	end;
})
*/

ix.command.Add("Event", {
	description = "@cmdEvent",
	arguments = ix.type.text,
	adminOnly = true,
	OnRun = function(self, client, text)
		ix.chat.Send(client, "event", text)
	end
})

ix.command.Add("clearitems", {
	description = "Elimina todos los ítems del mapa.",
	adminOnly = true,
	alias = {"removeitems", "cleanitems"},
	OnRun = function(self, client, arguments)

		for k, v in pairs(ents.FindByClass("ix_item")) do
			v:Remove()
		end

		client:Notify("All items have been cleaned up from the map.")
	end
})

ix.command.Add("clearnpcs", {
	description = "Elimina todos los NPCs y nextbots del mapa.",
	adminOnly = true,
	alias = {"removenpcs", "cleannpcs"},
	OnRun = function(self, client, arguments)

	for k, v in pairs( ents.GetAll( ) ) do
	if IsValid( v ) and ( v:IsNPC() or baseclass.Get( v:GetClass() ).Base == 'base_nextbot' or baseclass.Get( v:GetClass() ).Base == 'nz_base' or  baseclass.Get( v:GetClass() ).Base == 'nz_risen' ) and !IsFriendEntityName( v:GetClass() ) then

		  v:Remove()

	   end
    end
	client:Notify("All NPCs and Nextbots have been cleaned up from the map.")

	end
})

ix.command.Add("clearragdolls", {
	description = "Elimina los cadáveres (ragdolls) de NPCs del mapa.",
	adminOnly = true,
	alias = {"removeragdolls", "cleanragdolls"},
	OnRun = function(self, client, arguments)
		local count = 0

		-- No toca los cadáveres de JUGADORES (ver persistent_corpses.lua):
		-- esos llevan botín real dentro (ixInventory) y quedan marcados con
		-- ixCorpseOwnerSID al crearse — solo se eliminan los prop_ragdoll
		-- "sueltos" que deja un NPC al morir.
		for _, v in ipairs(ents.FindByClass("prop_ragdoll")) do
			if (IsValid(v) and !v.ixCorpseOwnerSID) then
				v:Remove()
				count = count + 1
			end
		end

		client:Notify("Se han eliminado " .. count .. " cadáveres de NPCs del mapa.")
	end
})

ix.command.Add("spawnitem", {
	description = "Spawns an item where you look",
	adminOnly = true,
	arguments = {
		ix.type.string,
	},
	OnRun = function(self, client, itemIDToSpawn)

		if (IsValid(client) and client:GetChar()) then
			local uniqueID = itemIDToSpawn:lower()
			if (!ix.item.list[uniqueID]) then
				for k, v in SortedPairs(ix.item.list) do
					if (ix.util.StringMatches(v.name, uniqueID)) then
						uniqueID = k
						break
					end
				end
			end

			if(!ix.item.list[uniqueID]) then
				client:Notify("No item exists with this unique ID.")
				return
			end

            local aimPos = client:GetEyeTraceNoCursor().HitPos

            aimPos:Add(Vector(0, 0, 10))

            ix.item.Spawn(uniqueID, aimPos)

		end
	end
})

ix.command.Add("setdata", {
	description = "sets data on the items you look at",
	adminOnly = true,
	arguments = {
		ix.type.string,
		ix.type.number
	},
	OnRun = function(self, client, key, data)
		local trace = client:GetEyeTraceNoCursor()
		local hitpos = trace.HitPos + trace.HitNormal*5
		local stasheditem = ix.item.instances

		if (!data or !isnumber(data) or data < 0) then
			return "@invalidArg", 2
		end

		for k, v in pairs( stasheditem ) do
			if v:GetEntity() then
			local dist = hitpos:Distance(client:GetPos())
			local distance = v:GetEntity():GetPos():Distance( hitpos )
				if distance <= 32 then
					v:SetData(key, data)

					client:Notify( "Data set successfully.")
				end
			end
		end
	end
})

ix.command.Add("CharResetValues", {
    adminOnly = true,
    description = "Resets the specified characters values such as hunger, thirst, psyhealth, hp, etc.",
    arguments = {bit.bor(ix.type.string, ix.type.optional)},
    OnRun = function(self, client, target)
        if not target or target == "" then
            target = client:GetCharacter():GetName()
        end

        local target = ix.util.FindPlayer(target)

        if not target then
            client:Notify("Invalid Target!")

            return
        end

        target:SetPsyHealth(100)
        target:SetHunger(100)
        target:SetThirst(100)
        target:setRadiation(0)
        target:SetHealth(100)
        target:SetLocalVar("stm", 100)
        target:ResetDrunkLevel()

        if client == target then
            client:Notify("You have reset your character values")
        else
            client:Notify("You have reset " .. target:Name() .. "'s character values")
            target:Notify(client:Name() .. " has reset your character values")
        end

        target:UpdatePsyHealthState(target)
        target:UpdateHungerState(target)
        target:UpdateThirstState(target)
    end
})

-- Credit goes to SmithyStanley
ix.command.Add("clearinv", {
	description = "Removes all the items in the target characters inventory.",
	adminOnly = true,
	arguments = {
		ix.type.character
	},
	OnRun = function (self, client, character)
		local target = character

		if (target) then
			for k, v in pairs(target:GetInventory():GetItems()) do
				v:Remove()
			end
			client:Notify("The inventory of "..target:GetName().." has been cleared.")
			ix.weight.Recalculate(target)
			client:Notify("Weight of "..target:GetName().."has been set to 0.")
		end
	end
})

ix.command.Add("plytogglehidden", {
	description = "Hides the given player from being displayed on the scoreboard.",
	adminOnly = true,
	arguments = {
		ix.type.player
	},
	OnRun = function (self, client, target)
		if (target) then
			if target:GetNetVar("scoreboardhidden", false) then
				target:SetNetVar("scoreboardhidden", false)
				client:Notify(target:GetName().." is now displayed on the scoreboard.")
			else
				target:SetNetVar("scoreboardhidden", true)
				client:Notify(target:GetName().." has been hidden on the scoreboard.")
			end
		end
	end
})

function PLUGIN:ShouldShowPlayerOnScoreboard(client)
	if client:GetNetVar("scoreboardhidden", false) == true then
		return false
	end
end

ix.command.Add("coinflip", {
	description = "Lanza una moneda al aire.",
	OnRun = function(self, client, arguments)
		local coinSide = math.random(0, 1)
		if (coinSide > 0) then
			ix.chat.Send(client, "iteminternal", "flips a coin, and it lands on heads.")
		else
			ix.chat.Send(client, "iteminternal", "flips a coin, and it lands on tails.")
		end
	end,
})

ix.command.Add("content", {
	description = "Abre el enlace de contenido del servidor en el navegador.",
	alias = {"workshop", "help"},
	OnRun = function(self, client, arguments)
	client:SendLua([[gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=2290918731")]])
	client:ChatPrint("If you encounter any human NPCs such as Old Timer and they are T-posing, this is caused by model animation overrides, especially pirated CSS content, and is not something we can fix with the workshop.")
	client:ChatPrint("To fix this, head to the official Call of the Zone discord by typing /discord in-game. Head to the #information channel and follow the instructions on how to fix the T-posing Human NPCs.")
	end
})

ix.command.Add("discord", {
	description = "Abre el Discord de la comunidad en el navegador.",
	OnRun = function(self, client, arguments)
	local url = ix.config.Get("communityURL")
	client:SendLua("gui.OpenURL(\"".. url.. "\")")
	end
})

ix.command.Add("suicide", {
	alias = {"unstuck", "respawn"},
	description = "Kill yourself, use if stuck somewhere.",
	OnRun = function(self, client)
		client:Kill()
	end
})

-- ============================================================
--  Comandos de debug / admin para el sistema de balas físicas
-- ============================================================

local function GetBalaStack(inv)
	if not inv then return nil end
	local items = inv:GetItemsByUniqueID("bala")
	return items[1]
end

-- /checkbalas [jugador] — muestra cuántas balas tiene el inventario
ix.command.Add("checkbalas", {
	description = "Muestra cuántas balas (dinero físico) tiene tu personaje o el objetivo.",
	adminOnly = false,
	arguments = {bit.bor(ix.type.player, ix.type.optional)},
	OnRun = function(self, client, target)
		target = target or client
		local char = target:GetCharacter()
		if not char then client:Notify("El jugador no tiene personaje activo.") return end

		local count = char:GetMoney()

		if client == target then
			client:ChatPrint("[Balas] Tienes " .. count .. " balas en total.")
		else
			client:ChatPrint("[Balas] " .. target:Name() .. " tiene " .. count .. " balas.")
		end

		local storedVar = char.vars and char.vars.money or 0
		if storedVar > 0 then
			client:ChatPrint("[Balas] ADVERTENCIA: hay " .. storedVar .. " en var 'money' sin convertir. Reconecta para solucionarlo.")
		end
	end
})

-- /givebala [cantidad] [jugador] — admin: da X balas usando GiveMoney
ix.command.Add("givebala", {
	description = "Admin: da balas al stack del inventario de un jugador.",
	adminOnly = true,
	arguments = {
		ix.type.number,
		bit.bor(ix.type.player, ix.type.optional),
	},
	OnRun = function(self, client, amount, target)
		target = target or client
		local char = target:GetCharacter()
		if not char then client:Notify("El jugador no tiene personaje activo.") return end

		amount = math.floor(math.abs(amount))
		if amount <= 0 then client:Notify("La cantidad debe ser mayor que 0.") return end

		char:GiveMoney(amount)
		local newCount = char:GetMoney()

		if client == target then
			client:ChatPrint("[Balas] Te diste " .. amount .. " balas. Total: " .. newCount)
		else
			client:ChatPrint("[Balas] Diste " .. amount .. " balas a " .. target:Name() .. ". Tiene ahora: " .. newCount)
			target:ChatPrint("[Balas] Un admin te dio " .. amount .. " balas.")
		end
	end
})

-- /takebala [cantidad] [jugador] — admin: quita X balas del stack
ix.command.Add("takebala", {
	description = "Admin: quita balas del stack del inventario de un jugador.",
	adminOnly = true,
	arguments = {
		ix.type.number,
		bit.bor(ix.type.player, ix.type.optional),
	},
	OnRun = function(self, client, amount, target)
		target = target or client
		local char = target:GetCharacter()
		if not char then client:Notify("El jugador no tiene personaje activo.") return end

		amount = math.floor(math.abs(amount))
		if amount <= 0 then client:Notify("La cantidad debe ser mayor que 0.") return end

		local before = char:GetMoney()
		char:TakeMoney(amount)
		local removed = before - char:GetMoney()

		if client == target then
			client:ChatPrint("[Balas] Te quitaste " .. removed .. " balas. Quedan: " .. char:GetMoney())
		else
			client:ChatPrint("[Balas] Quitaste " .. removed .. " balas a " .. target:Name() .. ". Le quedan: " .. char:GetMoney())
			target:ChatPrint("[Balas] Un admin te quitó " .. removed .. " balas.")
		end
	end
})

-- /moneyinfo — muestra el estado completo del sistema para debug
ix.command.Add("CharDelete", {
	description = "Elimina un personaje por nombre (conectado u offline).",
	adminOnly = true,
	arguments = ix.type.text,
	OnRun = function(self, client, name)
		if (!name or name == "") then
			client:Notify("Debes especificar el nombre del personaje.")
			return
		end

		local nameLower = name:lower()

		for id, character in pairs(ix.char.loaded) do
			if (character:GetName():lower() == nameLower) then
				local owner = character:GetPlayer()

				hook.Run("PreCharacterDeleted", IsValid(owner) and owner or client, character)

				local isCurrentChar = IsValid(owner) and owner:GetCharacter() and owner:GetCharacter():GetID() == id

				if (IsValid(owner)) then
					for k, v in ipairs(owner.ixCharList or {}) do
						if (v == id) then
							table.remove(owner.ixCharList, k)
							break
						end
					end
				end

				ix.char.loaded[id] = nil

				net.Start("ixCharacterDelete")
					net.WriteUInt(id, 32)
				net.Broadcast()

				local query = mysql:Delete("ix_characters")
					query:Where("id", id)
				query:Execute()

				local invQuery = mysql:Select("ix_inventories")
					invQuery:Select("inventory_id")
					invQuery:Where("character_id", id)
					invQuery:Callback(function(result)
						if (istable(result)) then
							for _, v in ipairs(result) do
								local itemQuery = mysql:Delete("ix_items")
									itemQuery:Where("inventory_id", v.inventory_id)
								itemQuery:Execute()

								ix.item.inventories[tonumber(v.inventory_id)] = nil
							end
						end

						local delInv = mysql:Delete("ix_inventories")
							delInv:Where("character_id", id)
						delInv:Execute()
					end)
				invQuery:Execute()

				hook.Run("CharacterDeleted", IsValid(owner) and owner or client, id, isCurrentChar)

				if (isCurrentChar and IsValid(owner)) then
					owner:SetNetVar("char", nil)
					owner:KillSilent()
					owner:StripAmmo()
				end

				client:Notify("Personaje '" .. character:GetName() .. "' (ID: " .. id .. ") eliminado.")
				return
			end
		end

		-- No se encontró conectado, buscar en la DB
		local dbQuery = mysql:Select("ix_characters")
			dbQuery:Select("id")
			dbQuery:Select("name")
			dbQuery:Where("name", name)
			dbQuery:Limit(1)
			dbQuery:Callback(function(result)
				if (!istable(result) or #result == 0) then
					if (IsValid(client)) then
						client:Notify("No se encontró ningún personaje con el nombre '" .. name .. "'.")
					end
					return
				end

				local charID = tonumber(result[1].id)
				local charName = result[1].name

				local delChar = mysql:Delete("ix_characters")
					delChar:Where("id", charID)
				delChar:Execute()

				local invSearch = mysql:Select("ix_inventories")
					invSearch:Select("inventory_id")
					invSearch:Where("character_id", charID)
					invSearch:Callback(function(invResult)
						if (istable(invResult)) then
							for _, v in ipairs(invResult) do
								local itemDel = mysql:Delete("ix_items")
									itemDel:Where("inventory_id", v.inventory_id)
								itemDel:Execute()
							end
						end

						local invDel = mysql:Delete("ix_inventories")
							invDel:Where("character_id", charID)
						invDel:Execute()
					end)
				invSearch:Execute()

				if (IsValid(client)) then
					client:Notify("Personaje offline '" .. charName .. "' (ID: " .. charID .. ") eliminado de la base de datos.")
				end
			end)
		dbQuery:Execute()
	end
})

ix.command.Add("moneyinfo", {
	description = "Debug: muestra info completa del sistema de dinero físico.",
	adminOnly = true,
	OnRun = function(self, client)
		local char = client:GetCharacter()
		if not char then client:Notify("Sin personaje.") return end

		local inv      = char:GetInventory()
		local stack    = GetBalaStack(inv)
		local numItems = inv and #inv:GetItemsByUniqueID("bala") or 0
		local count    = stack and stack:GetData("count", 1) or 0
		local varMoney = char.vars and char.vars.money or 0
		local getMoney = char:GetMoney()

		client:ChatPrint("=== Money Info ===")
		client:ChatPrint("Stacks de bala en inventario: " .. numItems)
		client:ChatPrint("count del stack: " .. count)
		client:ChatPrint("char:GetMoney(): " .. getMoney)
		client:ChatPrint("char.vars.money (var DB): " .. varMoney)

		if varMoney > 0 then
			client:ChatPrint("ACCION: reconecta para convertir el var a items.")
		elseif numItems == 1 and count == getMoney then
			client:ChatPrint("Sistema OK.")
		elseif numItems > 1 then
			client:ChatPrint("AVISO: hay " .. numItems .. " stacks. Reconecta para consolidar.")
		end
	end
})
