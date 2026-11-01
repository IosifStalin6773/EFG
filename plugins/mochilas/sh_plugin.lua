local PLUGIN = PLUGIN
PLUGIN.name = 'Mochilas'
PLUGIN.description = 'Mochilas extendidas de EFG'
PLUGIN.author = "EFG Project" -- original: Metro Wars RP

do
    local CHAR = ix.meta.character
    function CHAR:GetPrimaryBag()
        local inv = self:GetInventory()
        local hasItem = inv:HasItemOfBase('base_mochilas')
        if (hasItem) then return hasItem end

        -- también buscar en el inventario de equipo (mochila equipada en su slot)
        local eqID = self:GetData("equipInvID")
        local eqInv = eqID and ix.item.inventories[eqID]
        if (eqInv and eqInv.HasItemOfBase) then
            return eqInv:HasItemOfBase('base_mochilas')
        end
        return false
    end
end

ix.util.Include('sv_plugin.lua')