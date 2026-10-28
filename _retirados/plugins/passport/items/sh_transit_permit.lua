ITEM.name = "Permiso de Tránsito"
ITEM.weight = 0.05
ITEM.description = "Autorización para personas en tránsito rápido por el territorio."
ITEM.category = "Documentos"
ITEM.model = "models/props_lab/clipboard.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.uniqueID = "transit_permit"

-- Campos guardados en item.data.transit:
--   holderName (str), origin (str), destination (str), purpose (str),
--   issuedWhen (os.time), expiresAt (os.time), transitNumber (str)

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
        local d = item:GetData("transit", {})
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
                net.WriteTable(item:GetData("transit", {}))
            net.Send(item.player)
        end
        return false
    end,
    OnCanRun = function(item)
        return IsValid(item.player)
    end
}

function ITEM:GetDescription()
    local d = self:GetData("transit", {})
    local name = d.holderName or "—"
    local origin = d.origin or "—"
    local dest = d.destination or "—"
    local purpose = d.purpose or "—"
    local transnum = d.transitNumber or "—"
    local exp = d.expiresAt and os.date("%d/%m/%Y %H:%M", d.expiresAt) or "—"
    return string.format("%s\nTitular: %s\nOrigen: %s\nDestino: %s\nMotivo: %s\nTránsito #: %s\nVálido hasta: %s",
        self.description, name, origin, dest, purpose, transnum, exp)
end
