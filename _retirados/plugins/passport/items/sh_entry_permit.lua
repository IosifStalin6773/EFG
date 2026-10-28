ITEM.name = "Permiso de Acceso"
ITEM.weight = 0.05
ITEM.description = "Obligatorio para extranjeros, con fecha de vigencia."
ITEM.category = "Documentos"
ITEM.model = "models/props_lab/clipboard.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.uniqueID = "entry_permit"

-- Campos guardados en item.data.permit:
--   holderName (str), nationality (str), purpose ("Visita"/"Trabajo"/"Tránsito"...),
--   durationDays (num), issuedWhen (os.time), expiresAt (os.time), issuingCity (str)

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
        local d = item:GetData("permit", {})
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
                net.WriteTable(item:GetData("permit", {}))
            net.Send(item.player)
        end
        return false
    end,
    OnCanRun = function(item)
        return IsValid(item.player)
    end
}

-- Descripción dinámica
function ITEM:GetDescription()
    local d = self:GetData("permit", {})
    local name = d.holderName or "—"
    local purp = d.purpose or "—"
    local days = d.durationDays and tostring(d.durationDays) or "—"
    local exp  = d.expiresAt and os.date("%d/%m/%Y", d.expiresAt) or "—"
    return string.format("%s\nTitular: %s\nPropósito: %s\nDuración: %s días\nCaduca: %s",
        self.description, name, purp, days, exp)
end