ITEM.name = "Permiso de Trabajo"
ITEM.weight = 0.05
ITEM.description = "Obligatorio para extranjeros que buscan empleo."
ITEM.category = "Documentos"
ITEM.model = "models/props_lab/clipboard.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.uniqueID = "work_pass"

-- Campos guardados en item.data.workpass:
--   holderName (str), employer (str), occupation (str),
--   issuedWhen (os.time), expiresAt (os.time)

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
        local d = item:GetData("workpass", {})
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
                net.WriteTable(item:GetData("workpass", {}))
            net.Send(item.player)
        end
        return false
    end,
    OnCanRun = function(item)
        return IsValid(item.player)
    end
}

function ITEM:GetDescription()
    local d = self:GetData("workpass", {})
    local name = d.holderName or "—"
    local emp  = d.employer or "—"
    local occ  = d.occupation or "—"
    local exp  = d.expiresAt and os.date("%d/%m/%Y", d.expiresAt) or "—"
    return string.format("%s\nTitular: %s\nEmpleador: %s\nPuesto: %s\nCaduca: %s",
        self.description, name, emp, occ, exp)
end