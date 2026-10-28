ITEM.name = "Documentos de Vacunas"
ITEM.weight = 0.05
ITEM.description = "Certificado de vacunación requerido ante brotes."
ITEM.category = "Documentos"
ITEM.model = "models/props_lab/clipboard.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.uniqueID = "vaccine_documents"

-- Campos guardados en item.data.vaccine:
--   holderName (str), vaccines (table), issuedWhen (os.time),
--   validUntil (os.time), certificateNumber (str)

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
        local d = item:GetData("vaccine", {})
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
                net.WriteTable(item:GetData("vaccine", {}))
            net.Send(item.player)
        end
        return false
    end,
    OnCanRun = function(item)
        return IsValid(item.player)
    end
}

function ITEM:GetDescription()
    local d = self:GetData("vaccine", {})
    local name = d.holderName or "—"
    local cert = d.certificateNumber or "—"
    local valid = d.validUntil and os.date("%d/%m/%Y", d.validUntil) or "—"
    
    -- Count vaccines
    local vaccineCount = 0
    if d.vaccines and type(d.vaccines) == "table" then
        vaccineCount = #d.vaccines
    end
    
    return string.format("%s\nTitular: %s\nVacunas: %d\nCertificado: %s\nVálido hasta: %s",
        self.description, name, vaccineCount, cert, valid)
end
