ITEM.name = "Passport"
ITEM.weight = 0.05
ITEM.description = "Documento de identidad con datos impresos y sello."
ITEM.category = "Documentos"
ITEM.model = "models/epangelmatikes/metro/pass_world.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.uniqueID = "passport"

ITEM.functions = ITEM.functions or {}

ITEM.functions.view = {
    name = "Ver",
    icon = "icon16/page_white_magnify.png",
    OnRun = function(item)
        local data = item:GetData("passport", {})
        if (SERVER) then
            -- For multi-page passports, we'll handle this client-side
            net.Start("ix.passport.OpenViewer")
                net.WriteTable(data)
                net.WriteUInt(0, 8) -- 0 = sin autocierre
                net.WriteString("")
            net.Send(item.player)
        else
            -- Client-side: try to open multi-page viewer
            if vgui.GetControlTable("ixMultiPagePassport") and PLUGIN.OpenMultiPagePassport then
                PLUGIN:OpenMultiPagePassport(item.id, data)
            end
        end
        return false
    end
}

ITEM.functions.viewMulti = {
    name = "Ver Multi-Página",
    icon = "icon16/book_open.png",
    OnRun = function(item)
        local data = item:GetData("passport", {})
        if (CLIENT) then
            if vgui.GetControlTable("ixMultiPagePassport") and PLUGIN.OpenMultiPagePassport then
                PLUGIN:OpenMultiPagePassport(item.id, data)
            else
                item.player:Notify("El visor multi-página no está disponible.")
            end
        end
        return false
    end
}

ITEM.functions.show = {
    name = "Mostrar",
    icon = "icon16/monitor.png",
    OnRun = function(item)
        if (SERVER) then
            net.Start("ix.passport.ShowToTarget")
                net.WriteUInt(item.id or 0, 32)
            net.Send(item.player)
        end
        return false
    end
}