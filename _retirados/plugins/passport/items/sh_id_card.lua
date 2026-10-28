ITEM.name = "Tarjeta de Identidad"
ITEM.weight = 0.05
ITEM.description = "Documento de identificación obligatorio para ciudadanos de Arstotzka."
ITEM.category = "Documentos"
ITEM.model = "models/props_lab/clipboard.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.uniqueID = "id_card"

-- Campos guardados en item.data.idcard:
--   holderName (str), citizenship (str), birthDate (str),
--   issuedWhen (os.time), expiresAt (os.time), idNumber (str)

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
        local d = item:GetData("idcard", {})
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
                net.WriteTable(item:GetData("idcard", {}))
            net.Send(item.player)
        end
        return false
    end,
    OnCanRun = function(item)
        return IsValid(item.player)
    end
}

function ITEM:GetDescription()
    local d = self:GetData("idcard", {})
    local name = d.holderName or "—"
    local cit = d.citizenship or "—"
    local idnum = d.idNumber or "—"
    local exp = d.expiresAt and os.date("%d/%m/%Y", d.expiresAt) or "—"
    return string.format("%s\nTitular: %s\nCiudadanía: %s\nID: %s\nCaduca: %s",
        self.description, name, cit, idnum, exp)
end
