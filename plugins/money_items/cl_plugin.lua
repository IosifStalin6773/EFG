local CHAR = ix.meta.character

-- GetMoney en cliente: suma el count de TODOS los stacks de balas del inventario.
function CHAR:GetMoney()
    local inventory = self:GetInventory()
    if not inventory then return 0 end
    local items = inventory:GetItemsByUniqueID("bala")
    local total = 0
    for _, stack in ipairs(items) do
        total = total + stack:GetData("count", 1)
    end
    return total
end
