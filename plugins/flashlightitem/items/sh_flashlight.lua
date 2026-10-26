
ITEM.name = "Linterna"
ITEM.weight = 0.3
ITEM.model = Model("models/lostsignalproject/items/devices/flashlight.mdl")
ITEM.width = 1
ITEM.height = 1
ITEM.price = 25
ITEM.description = "Linterna utilaria en el metro."
ITEM.category = "Equipamiento"

ITEM:Hook("drop", function(item)
	if (!SERVER) then return end
	local client = item.player
	if (IsValid(client)) then
		client:SetNW2Bool("flashlight_active", false)
	end
end)
