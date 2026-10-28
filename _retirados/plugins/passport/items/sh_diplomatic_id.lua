ITEM.name = "Documento de Identidad Diplomático"
ITEM.weight = 0.05
ITEM.description = "Identificación especial para personal diplomático acreditado."
ITEM.category = "Documentos"
ITEM.model = "models/props_lab/clipboard.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.uniqueID = "diplomatic_id"

-- Campos guardados en item.data.diplomatic:
--   holderName (str), position (str), embassy (str),
--   issuedWhen (os.time), expiresAt (os.time), accreditationNumber (str)

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
        local d = item:GetData("diplomatic", {})
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
                net.WriteTable(item:GetData("diplomatic", {}))
            net.Send(item.player)
        end
        return false
    end,
    OnCanRun = function(item)
        return IsValid(item.player)
    end
}

function ITEM:GetDescription()
    local d = self:GetData("diplomatic", {})
    local name = d.holderName or "—"
    local pos = d.position or "—"
    local emb = d.embassy or "—"
    local acc = d.accreditationNumber or "—"
    local exp = d.expiresAt and os.date("%d/%m/%Y", d.expiresAt) or "—"
    return string.format("%s\nTitular: %s\nCargo: %s\nEmbajada: %s\nAcreditación: %s\nCaduca: %s",
        self.description, name, pos, emb, acc, exp)
end
