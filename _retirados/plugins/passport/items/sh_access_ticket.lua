ITEM.name = "Boleto de Acceso"
ITEM.weight = 0.05
ITEM.description = "Autorización especial requerida en días con mayor seguridad."
ITEM.category = "Documentos"
ITEM.model = "models/props_lab/clipboard.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.uniqueID = "access_ticket"

-- Campos guardados en item.data.ticket:
--   holderName (str), accessLevel (str), validDate (str),
--   issuedWhen (os.time), purpose (str), ticketNumber (str)

ITEM.functions = ITEM.functions or {}

ITEM.functions.Edit = {
    name = "Editar",
    icon = "icon16/page_white_edit.png",
    OnRun = function(item)
        if (SERVER) then
            net.Start("ix.pp.OpenDocEditor")
                net.WriteUInt(item.id, 32)
                net.WriteString(item.uniqueID)
            net.Send(item.player)
        end
        return false
    end,
    OnCanRun = function(item)
        if (not IsValid(item.player)) then return false end
        local d = item:GetData("ticket", {})
        if (d.holderName and d.holderName != "") then return false end
        local pp = ix.plugin.list["passport"]
        return pp and pp:CanEditDocument(item.player)
    end
}

ITEM.functions.View = {
    name = "Ver",
    icon = "icon16/page_white_magnify.png",
    OnRun = function(item)
        if (SERVER) then
            net.Start("ix.pp.OpenDocViewer")
                net.WriteString(item.uniqueID)
                net.WriteTable(item:GetData("ticket", {}))
            net.Send(item.player)
        end
        return false
    end,
    OnCanRun = function(item)
        return IsValid(item.player)
    end
}

function ITEM:GetDescription()
    local d = self:GetData("ticket", {})
    local name = d.holderName or "—"
    local level = d.accessLevel or "—"
    local date = d.validDate or "—"
    local purpose = d.purpose or "—"
    local ticketnum = d.ticketNumber or "—"
    return string.format("%s\nTitular: %s\nNivel: %s\nFecha válida: %s\nMotivo: %s\nBoleto #: %s",
        self.description, name, level, date, purpose, ticketnum)
end
