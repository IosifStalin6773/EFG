PLUGIN.name = "Cleaner"
PLUGIN.author = "ErglazZ"
PLUGIN.desc = "Remove all items on the ground"

local function SafeRemoveGroundItems()
	local count = 0

	for _, v in ipairs(ents.FindByClass("ix_item")) do
		local itemID = v.ixItemID
		local itemTable = itemID and ix.item.instances[itemID]

		if (itemTable and itemTable.invID and itemTable.invID != 0) then
			v.ixIsSafe = true
			v:Remove()
		else
			v:Remove()
			count = count + 1
		end
	end

	return count
end

ix.command.Add("removeitems", {
	description = "Remove all items on the ground.",
	adminOnly = true,
	OnRun = function(self, client)
		local count = SafeRemoveGroundItems()
		client:Notify("Has eliminado " .. count .. " items del suelo.")
	end
})

if (SERVER) then
	function PLUGIN:InitPostEntity()
		timer.Create("ixcleaner_timer", 1800, 0, function()
			local count = SafeRemoveGroundItems()
			print("[Cleaner] Eliminados " .. count .. " items del suelo.")

			for _, v in ipairs(player.GetAll()) do
				v:ConCommand("r_cleardecals")
			end
		end)

		timer.Create("ixcleaner_reminder", 1740, 0, function()
			for _, v in ipairs(player.GetAll()) do
				v:ChatPrint("¡ATENCIÓN! Todos los items del suelo serán eliminados en 60 segundos.")
			end
		end)
	end
end
