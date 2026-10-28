ITEM.name = "Filtro"
ITEM.weight = 0.1
ITEM.description = "Un filtro para la máscara de gas. Las máscaras no serán funcionales sin el."
ITEM.model = Model("models/teebeutel/metro/objects/gasmask_filter.mdl")
ITEM.price = 15
ITEM.isFilter = true
ITEM.filterHealth = ix.config.Get("gasmask_filter", 240)
ITEM.bDropOnDeath = true
ITEM.iconCam = {
	pos = Vector(0, 11.863277435303, 1.6156034469604),
	ang = Angle(0, 270, 0),
	fov = 45,
}
ITEM.exRender = true

function ITEM:getFilterHealth()
    return self:GetData("health", self.filterHealth)
end

function ITEM:onChangeFilter(gasMask, filter)
    -- if filter does matters. (like high density shit)
end


-- ITEM.functions.combine = {
--     OnCanRun = function(item, data)
--         local targetItem = ix.item.instances[data]
        
--         if (data and targetItem) then
--             -- Yeah, You can't see me when item is dropped on the ground!
--             if (IsValid(item.entity)) then
--                 return false
--             end
--         end
--     end,
--     OnRun = function(item, data)
--         local client = item.player

--         if (IsValid(client)) then
--             local targetItem = ix.item.instances[data]

--             if (targetItem) then
--                 if (targetItem.isGasMask) then
--                     return targetItem:changeFilter(client, targetItem, item)
--                 else
--                     client:NotifyLocalized("notGasMask")
--                 end
--             end
--         end

--         return false
--     end,
-- }