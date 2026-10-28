-- "Querida alma perdida, si estas leyendo esto querria decirte lo siguiente;
-- Cuando escribi este código, solo Dios y yo sabíamos cómo funcionaba.
-- Ahora, solo Dios lo sabe!
-- Por lo tanto, si estás intentando optimizar
-- este script y falla (seguramente),
-- por favor incrementa este contador como una
-- advertencia para la siguiente persona:
-- total_horas_desperdiciadas_aqui = 51

local PLUGIN = PLUGIN
PLUGIN.name = "Sistema de Pasaportes"
PLUGIN.author = "IosifStalin#6773"
PLUGIN.description = "Pasaporte con impresión/sello, visor, mesa de inspección y soportes de documentos."

-- NOTA DE ORDEN DE CARGA:
-- Helix incluye automáticamente las subcarpetas libs/ y derma/ (en ese orden) ANTES
-- de ejecutar este archivo (ver ix.plugin.Load). Por eso la config y las fuentes viven
-- ahora en libs/ (libs/sh_config.lua, libs/cl_fonts.lua): así existen cuando derma/ se
-- carga. No vuelvas a incluir derma/ a mano aquí o se cargaría dos veces.

-----------------------------------------------------------------
-- NETWORK STRINGS
-----------------------------------------------------------------
if (SERVER) then
    -- Núcleo pasaporte
    util.AddNetworkString("ix.passport.OpenEditor")
    util.AddNetworkString("ix.passport.RequestPrint")
    util.AddNetworkString("ix.passport.OpenViewer")
    util.AddNetworkString("ix.passport.ShowToTarget")
    util.AddNetworkString("ix.passport.SendStamps")

    -- Mesa de inspección
    util.AddNetworkString("ix.passport.OpenDesk")
    util.AddNetworkString("ix.passport.FetchPassportForDesk")
    util.AddNetworkString("ix.passport.DeskPassportData")
    util.AddNetworkString("ix.passport.SubmitDesk")
    util.AddNetworkString("ix.passport.ToggleLamp")

    -- Abrir editores/visores de documentos desde el servidor
    util.AddNetworkString("ix.pp.OpenDocEditor")
    util.AddNetworkString("ix.pp.OpenDocViewer")

    -- Docs extra + confiscar + sellar
    util.AddNetworkString("ix.pp.SaveEntryPermit")
    util.AddNetworkString("ix.pp.SaveWorkPass")
    util.AddNetworkString("ix.pp.SaveIDCard")
    util.AddNetworkString("ix.pp.SaveDiplomaticID")
    util.AddNetworkString("ix.pp.SaveTransitPermit")
    util.AddNetworkString("ix.pp.SaveAccessTicket")
    util.AddNetworkString("ix.pp.SaveVaccineDocuments")
    util.AddNetworkString("ix.pp.ConfiscateDoc")
    util.AddNetworkString("ix.pp.ConfiscateResult")
    util.AddNetworkString("ix.pp.StampDoc")
    util.AddNetworkString("ix.pp.StampResult")
    
    -- Multi-page passport system
    util.AddNetworkString("ix.pp.AddStationStamp")
    util.AddNetworkString("ix.pp.StationStampResult")
    util.AddNetworkString("ix.pp.GetPassportPages")
    util.AddNetworkString("ix.pp.PassportPagesData")
    
    -- Document context menu functions
    util.AddNetworkString("ix.pp.ReturnDocument")
    util.AddNetworkString("ix.pp.ClearPassportStamps")

    -- Control de frontera "Papers, Please" (libs/sv_inspection.lua)
    util.AddNetworkString("ix.pp.DeskDecision")
    util.AddNetworkString("ix.pp.DeskResult")
    util.AddNetworkString("ix.pp.RequestVerdict")
    util.AddNetworkString("ix.pp.AssistVerdict")

    -- Editor de boletines (libs/sv_bulletin_editor.lua)
    util.AddNetworkString("ix.pp.OpenBulletinEditor")
    util.AddNetworkString("ix.pp.RequestBulletins")
    util.AddNetworkString("ix.pp.BulletinsData")
    util.AddNetworkString("ix.pp.SaveBulletin")
    util.AddNetworkString("ix.pp.DeleteBulletin")
end
-- (Estas cadenas ya existían en tu versión y son las que usa la mesa/UI.) [3](https://kardanuniversityorg-my.sharepoint.com/personal/e71523_365a3_top/Documents/Archivos%20de%20Microsoft%C2%A0Copilot%20Chat/cl_fonts.lua)

-----------------------------------------------------------------
-- RECURSOS (SERVER)
-----------------------------------------------------------------
if (SERVER) then
    if (PLUGIN.PassportTemplate and PLUGIN.PassportTemplate ~= "") then
        resource.AddFile("materials/" .. PLUGIN.PassportTemplate)
    end
    for _, rel in ipairs(PLUGIN.Stamps or {}) do
        resource.AddFile("materials/" .. rel)
    end
end

-----------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------
local function GetPlayerBodygroupsTable(ply)
    local t = {}
    if not IsValid(ply) then return t end
    local bgs = ply:GetBodyGroups() or {}
    for _, bg in ipairs(bgs) do
        t[bg.id] = ply:GetBodygroup(bg.id) or 0
    end
    return t
end

local MAX_FIELD_LEN = 64
local function SanitizeFields(fields)
    local out = {}
    fields = fields or {}
    for _, f in ipairs(PLUGIN.PassportFields or {}) do
        local v = tostring(fields[f.key] or "")
        if (#v > MAX_FIELD_LEN) then
            v = string.sub(v, 1, MAX_FIELD_LEN)
        end
        out[f.key] = v
    end
    return out
end

local function FindFirstPassportItem(inv)
    if not inv then return end
    for _, it in pairs(inv:GetItems(true) or {}) do
        if it.uniqueID == "passport" then
            return it
        end
    end
end

-----------------------------------------------------------------
-- DOCUMENT VALIDATION HELPERS
-----------------------------------------------------------------
local function IsDocumentExpired(documentData, currentTime)
    if not documentData then return false end
    
    -- Check different expiration field names
    local expiryTime = documentData.expiresAt or documentData.validUntil
    if not expiryTime then return false end
    
    return currentTime > expiryTime
end

local function GetDocumentExpiryStatus(documentData, currentTime, warningDays)
    if not documentData then return "valid" end
    
    local expiryTime = documentData.expiresAt or documentData.validUntil
    if not expiryTime then return "valid" end
    
    local timeUntilExpiry = expiryTime - currentTime
    local warningSeconds = (warningDays or 7) * 24 * 60 * 60
    
    if currentTime > expiryTime then
        return "expired"
    elseif timeUntilExpiry <= warningSeconds then
        return "expiring_soon"
    else
        return "valid"
    end
end

local function ValidateDocumentConsistency(documents)
    if not documents or type(documents) ~= "table" then return true end
    
    -- Check if all documents have the same holder name
    local holderName = nil
    for docType, docData in pairs(documents) do
        if docData and docData.holderName then
            if holderName and holderName ~= docData.holderName then
                return false
            end
            holderName = docData.holderName
        end
    end
    
    return true
end

-- Export validation functions for use by other systems
if SERVER then
    function PLUGIN:IsDocumentExpired(documentData, currentTime)
        return IsDocumentExpired(documentData, currentTime or CurTime())
    end
    
    function PLUGIN:GetDocumentExpiryStatus(documentData, currentTime, warningDays)
        return GetDocumentExpiryStatus(documentData, currentTime or CurTime(), warningDays)
    end
    
    function PLUGIN:ValidateDocumentConsistency(documents)
        return ValidateDocumentConsistency(documents)
    end
    
    function PLUGIN:GetRequiredDocuments(nationality, purpose)
        local required = {}
        
        -- Base requirements by nationality
        if nationality and self.DocumentValidation.RequiredDocuments[nationality] then
            for _, doc in ipairs(self.DocumentValidation.RequiredDocuments[nationality]) do
                table.insert(required, doc)
            end
        end
        
        -- Additional requirements by purpose
        if purpose and self.DocumentValidation.PurposeRequirements[purpose] then
            for _, doc in ipairs(self.DocumentValidation.PurposeRequirements[purpose]) do
                if not table.HasValue(required, doc) then
                    table.insert(required, doc)
                end
            end
        end
        
        return required
    end
end

-----------------------------------------------------------------
-- ENVÍO DE LISTA DE SELLOS
-----------------------------------------------------------------
if (SERVER) then
    function PLUGIN:GetStampList()
        return table.Copy(self.Stamps or {})
    end

    hook.Add("PlayerInitialSpawn", "ix.passport.SendStamps", function(ply)
        local list = PLUGIN:GetStampList() or {}
        net.Start("ix.passport.SendStamps")
            net.WriteUInt(#list, 12)
            for _, rel in ipairs(list) do
                net.WriteString(rel)
            end
        net.Send(ply)
    end)
end

if (CLIENT) then
    local stamps = {}
    net.Receive("ix.passport.SendStamps", function()
        stamps = {}
        local n = net.ReadUInt(12)
        for i = 1, n do
            stamps[#stamps+1] = net.ReadString()
        end
        PLUGIN.StampList = stamps
    end)

    function PLUGIN:GetStampMaterials()
        local out = {}
        if (self.StampList) then
            for _, rel in ipairs(self.StampList) do
                local ok = file.Exists("materials/" .. rel, "GAME")
                if ok then
                    local fname = string.GetFileFromFilename(rel)
                    out[#out+1] = { name = fname, rel = rel, mat = Material(rel, "smooth") }
                end
            end
        end
        return out
    end

    -----------------------------------------------------------------
    -- ABRIR EDITORES/VISORES DE DOCUMENTOS DESDE EL SERVIDOR
    -----------------------------------------------------------------
    local DOC_EDITORS = {
        entry_permit     = "ixEntryPermitEditor",
        work_pass        = "ixWorkPassEditor",
        id_card          = "ixIDCardEditor",
        diplomatic_id    = "ixDiplomaticIDEditor",
        transit_permit   = "ixTransitPermitEditor",
        vaccine_documents = "ixVaccineDocumentsEditor",
        access_ticket    = "ixAccessTicketEditor",
    }

    local DOC_VIEWERS = {
        entry_permit     = { panel = "ixEntryPermitViewer",     setter = "SetPermitData" },
        work_pass        = { panel = "ixWorkPassViewer",        setter = "SetWorkPassData" },
        id_card          = { panel = "ixIDCardViewer",          setter = "SetIDCardData" },
        diplomatic_id    = { panel = "ixDiplomaticIDViewer",    setter = "SetDiplomaticData" },
        transit_permit   = { panel = "ixTransitPermitViewer",   setter = "SetTransitData" },
        vaccine_documents = { panel = "ixVaccineDocumentsViewer", setter = "SetVaccineData" },
        access_ticket    = { panel = "ixAccessTicketViewer",    setter = "SetTicketData" },
    }

    net.Receive("ix.pp.OpenDocEditor", function()
        local itemID = net.ReadUInt(32)
        local uniqueID = net.ReadString()

        local item = ix.item.instances[itemID]
        local editorName = DOC_EDITORS[uniqueID]
        if (not editorName) then return end

        local pnl = vgui.Create(editorName)
        if (IsValid(pnl)) then
            pnl:SetItem(item)
        end
    end)

    net.Receive("ix.pp.OpenDocViewer", function()
        local uniqueID = net.ReadString()
        local data = net.ReadTable()

        local info = DOC_VIEWERS[uniqueID]
        if (not info) then return end

        local pnl = vgui.Create(info.panel)
        if (IsValid(pnl) and pnl[info.setter]) then
            pnl[info.setter](pnl, data)
        end
    end)
end

-----------------------------------------------------------------
-- IMPRESIÓN DE PASAPORTE (SERVER)
-----------------------------------------------------------------
if (SERVER) then
    PLUGIN._printCooldown = PLUGIN._printCooldown or {}
    net.Receive("ix.passport.RequestPrint", function(_, client)
        local data = net.ReadTable() or {}
        local entity = net.ReadEntity()
        local target = net.ReadEntity()
        if (not IsValid(entity) or entity:GetClass() ~= "ix_passport_printer") then
            client:Notify("Impresora no disponible.")
            return
        end
        if (entity:GetPos():DistToSqr(client:GetPos()) > (200*200)) then
            client:Notify("Debes estar más cerca de la impresora.")
            return
        end

        local sid, now = client:SteamID64(), CurTime()
        if (PLUGIN._printCooldown[sid] and PLUGIN._printCooldown[sid] > now) then
            client:Notify("Estás usando la impresora demasiado rápido.")
            return
        end
        PLUGIN._printCooldown[sid] = now + 3

        local issuerChar = client:GetCharacter()
        if (not issuerChar) then client:Notify("Tu personaje no está cargado.") return end

        -- Destinatario del pasaporte: la persona elegida delante/cerca del emisor,
        -- o uno mismo si no se eligió a nadie más (no se confía ciegamente en el cliente).
        local recipient = client
        if (IsValid(target) and target:IsPlayer() and target ~= client) then
            if (not target:Alive() or not target:GetCharacter()) then
                client:Notify("La persona seleccionada no es válida.")
                return
            end
            if (client:GetPos():DistToSqr(target:GetPos()) > ((PLUGIN.PrintTargetRadius or 200) ^ 2)) then
                client:Notify("La persona seleccionada está demasiado lejos.")
                return
            end
            recipient = target
        end

        local recipientChar = recipient:GetCharacter()
        local inv = recipientChar:GetInventory()
        if (not inv) then client:Notify("Inventario no disponible.") return end
        if (not ix.item.list or not ix.item.list["passport"]) then
            client:Notify("Falta el ítem 'passport'.")
            return
        end

        -- Sello forzado por facción del emisor (no se confía en el cliente)
        local faction = ix.faction.indices[client:Team()]
        local factionUID = faction and faction.uniqueID or ""
        local factionStamp = PLUGIN.InspectorStamps and PLUGIN.InspectorStamps[factionUID] or ""

        local item, err = inv:Add("passport", 1, {
            passport = {
                fields = SanitizeFields(data.fields),
                stamp = factionStamp,
                ownerSteamID64 = recipient:SteamID64(),
                ownerName = recipientChar:GetName() or recipient:Name(),
                issuedBy = issuerChar:GetName() or client:Name(),
                issuedWhen = os.time(),
                model = recipient:GetModel() or "",
                skin = recipient:GetSkin() or 0,
                bodygroups = GetPlayerBodygroupsTable(recipient)
            }
        })
        if (not item) then
            client:Notify("No se pudo imprimir el pasaporte: " .. tostring(err or "inventario lleno"))
            return
        end

        if (recipient == client) then
            client:Notify("Pasaporte impreso y añadido a tu inventario.")
        else
            client:Notify("Pasaporte impreso y añadido al inventario de " .. (recipientChar:GetName() or recipient:Name()) .. ".")
            recipient:Notify(client:Name() .. " te ha emitido un pasaporte.")
        end
    end)
end

-----------------------------------------------------------------
-- “MOSTRAR A OTRO JUGADOR”
-----------------------------------------------------------------
if (SERVER) then
    net.Receive("ix.passport.ShowToTarget", function(_, client)
        local itemID = net.ReadUInt(32)
        local item = ix.item.instances[itemID]
        if (not item or (item.uniqueID and item.uniqueID ~= "passport")) then return end

        local char = client:GetCharacter()
        if (not char or item:GetOwner() ~= client) then return end

        local tr = client:GetEyeTraceNoCursor()
        local target = IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity or nil
        if (not IsValid(target) or client:GetPos():DistToSqr(target:GetPos()) > ((PLUGIN.LookDistance or 128)^2)) then
            client:Notify("No estás mirando a un jugador cercano.")
            return
        end
        if (not target:Alive() or not target:GetCharacter()) then
            client:Notify("Debes mirar a un jugador válido.")
            return
        end

        net.Start("ix.passport.OpenViewer")
            net.WriteTable(item:GetData("passport", {}))
            net.WriteUInt(PLUGIN.ShowDuration or 10, 8)
            net.WriteString(client:Name())
        net.Send(target)

        client:Notify("Has mostrado tu pasaporte.")
        target:Notify(client:Name() .. " te muestra un pasaporte.")
    end)
end

if (CLIENT) then
    net.Receive("ix.passport.ShowToTarget", function()
        local itemID = net.ReadUInt(32)
        net.Start("ix.passport.ShowToTarget")
            net.WriteUInt(itemID or 0, 32)
        net.SendToServer()
    end)
end

-----------------------------------------------------------------
-- MESA DE INSPECCIÓN (MVP)  (config por defecto)
-----------------------------------------------------------------
PLUGIN.DeskApprovedStamp = PLUGIN.DeskApprovedStamp or "metro/stamp/polis.png"
PLUGIN.DeskRejectedStamp = PLUGIN.DeskRejectedStamp or "metro/stamp/cross.png"
PLUGIN.InspectionUseDistance = PLUGIN.InspectionUseDistance or 200

if (SERVER) then
    net.Receive("ix.passport.FetchPassportForDesk", function(_, client)
        local ent = net.ReadEntity()
        if not IsValid(ent) or ent:GetClass() ~= "ix_inspection_desk" then return end
        if ent:GetPos():DistToSqr(client:GetPos()) > (PLUGIN.InspectionUseDistance ^ 2) then return end

        local char = client:GetCharacter()
        if not char then return end
        local inv = char:GetInventory()
        local item = FindFirstPassportItem(inv)
        if not item then
            client:Notify("No tienes un pasaporte en tu inventario.")
            return
        end

        net.Start("ix.passport.DeskPassportData")
            net.WriteTable(item:GetData("passport", {}))
            net.WriteUInt(item.id or 0, 32)
        net.Send(client)
    end)

    net.Receive("ix.passport.SubmitDesk", function(_, client)
        local ent = net.ReadEntity()
        local action = net.ReadString() -- "approve" | "reject"
        local itemID = net.ReadUInt(32) or 0

        if not IsValid(ent) or ent:GetClass() ~= "ix_inspection_desk" then return end
        if ent:GetPos():DistToSqr(client:GetPos()) > (PLUGIN.InspectionUseDistance ^ 2) then
            client:Notify("Acércate a la mesa.")
            return
        end

        local char = client:GetCharacter()
        if not char then return end
        local inv = char:GetInventory()
        if not inv then return end

        local item = ix.item.instances[itemID]
        if not item or item:GetOwner() ~= client or item.uniqueID ~= "passport" then
            item = FindFirstPassportItem(inv)
            if not item then
                client:Notify("No se encontró pasaporte para inspeccionar.")
                return
            end
        end

        local pdata = item:GetData("passport", {})
        pdata.fields = pdata.fields or {}
        pdata.stamp = string.GetFileFromFilename(
            (action == "approve") and (PLUGIN.DeskApprovedStamp or "metro/stamp/polis.png")
            or (PLUGIN.DeskRejectedStamp or "metro/stamp/cross.png")
        )
        item:SetData("passport", pdata)

        client:Notify(action == "approve" and "Pasaporte APROBADO." or "Pasaporte RECHAZADO.")
    end)

    net.Receive("ix.passport.ToggleLamp", function(_, client)
        local ent = net.ReadEntity()
        if not IsValid(ent) or ent:GetClass() ~= "ix_inspection_desk" then return end
        if ent:GetPos():DistToSqr(client:GetPos()) > (PLUGIN.InspectionUseDistance ^ 2) then return end
        ent:SetLampOn(not ent:GetLampOn())
    end)
end
-- (Bloque anterior: coincide con tu mesa y redes; sólo reorganizado) [3](https://kardanuniversityorg-my.sharepoint.com/personal/e71523_365a3_top/Documents/Archivos%20de%20Microsoft%C2%A0Copilot%20Chat/cl_fonts.lua)

-----------------------------------------------------------------
-- HANDLERS: ENTRY PERMIT / WORK PASS (SERVER)
-----------------------------------------------------------------
if (SERVER) then
    local function Str(val, max) val = tostring(val or ""); max = max or 64; if #val > max then val = string.sub(val, 1, max) end; return val end
    local function Num(val, minv, maxv, def) val = tonumber(val or def or 0) or (def or 0); if minv then val = math.max(minv, val) end; if maxv then val = math.min(maxv, val) end; return val end

    -- Se rolea en 2028 pero el reloj del servidor va en tiempo real: sumamos estos
    -- años a toda fecha de caducidad emitida (ver libs/sh_config.lua).
    local EXPIRY_OFFSET = (PLUGIN.RoleplayYearOffset or 0) * 365 * 24 * 60 * 60

    local function CanEditDoc(client)
        return PLUGIN:CanEditDocument(client)
    end

    local function DocAlreadyFilled(item, dataKey)
        local d = item:GetData(dataKey, {})
        return d.holderName and d.holderName ~= ""
    end

    local function GetIssuerStamp(client)
        local info = PLUGIN:GetInspectorInfo(client)
        return info and info.stamp or ""
    end

    net.Receive("ix.pp.SaveEntryPermit", function(_, client)
        local itemID = net.ReadUInt(32)
        local data   = net.ReadTable() or {}
        local item   = ix.item.instances[itemID]
        if not item or item.uniqueID ~= "entry_permit" or item:GetOwner() ~= client then return end
        if not CanEditDoc(client) then client:Notify("No tienes autoridad para rellenar documentos.") return end
        if DocAlreadyFilled(item, "permit") then client:Notify("Este documento ya está rellenado.") return end

        local duration = Num(data.durationDays, 1, 180, 7)
        local issued = os.time()
        local expires = issued + duration * 24 * 60 * 60 + EXPIRY_OFFSET
        local saved = {
            holderName = Str(data.holderName, 64),
            nationality = Str(data.nationality, 48),
            purpose = Str(data.purpose, 24),
            durationDays = duration,
            issuingCity = Str(data.issuingCity, 48),
            issuedWhen = issued,
            expiresAt = expires,
            stamp = GetIssuerStamp(client)
        }
        item:SetData("permit", saved)
        client:Notify("Permiso de Entrada emitido.")
    end)

    net.Receive("ix.pp.SaveWorkPass", function(_, client)
        local itemID = net.ReadUInt(32)
        local data   = net.ReadTable() or {}
        local item   = ix.item.instances[itemID]
        if not item or item.uniqueID ~= "work_pass" or item:GetOwner() ~= client then return end
        if not CanEditDoc(client) then client:Notify("No tienes autoridad para rellenar documentos.") return end
        if DocAlreadyFilled(item, "workpass") then client:Notify("Este documento ya está rellenado.") return end

        local days = Num(data.durationDays or 30, 1, 365, 30)
        local issued = os.time()
        local expires = issued + days * 24 * 60 * 60 + EXPIRY_OFFSET
        local saved = {
            holderName = Str(data.holderName, 64),
            employer   = Str(data.employer, 64),
            occupation = Str(data.occupation, 48),
            issuedWhen = issued,
            expiresAt  = expires,
            stamp = GetIssuerStamp(client)
        }
        item:SetData("workpass", saved)
        client:Notify("Pase de Trabajo emitido.")
    end)

    net.Receive("ix.pp.SaveIDCard", function(_, client)
        local itemID = net.ReadUInt(32)
        local data   = net.ReadTable() or {}
        local item   = ix.item.instances[itemID]
        if not item or item.uniqueID ~= "id_card" or item:GetOwner() ~= client then return end
        if not CanEditDoc(client) then client:Notify("No tienes autoridad para rellenar documentos.") return end
        if DocAlreadyFilled(item, "idcard") then client:Notify("Este documento ya está rellenado.") return end

        local issued = os.time()
        local expires = issued + 365 * 24 * 60 * 60 + EXPIRY_OFFSET
        local saved = {
            holderName = Str(data.holderName, 64),
            citizenship = Str(data.citizenship, 48),
            birthDate = Str(data.birthDate, 32),
            issuedWhen = issued,
            expiresAt = expires,
            idNumber = Str(data.idNumber, 16),
            stamp = GetIssuerStamp(client)
        }
        item:SetData("idcard", saved)
        client:Notify("Tarjeta de Identidad emitida.")
    end)

    net.Receive("ix.pp.SaveDiplomaticID", function(_, client)
        local itemID = net.ReadUInt(32)
        local data   = net.ReadTable() or {}
        local item   = ix.item.instances[itemID]
        if not item or item.uniqueID ~= "diplomatic_id" or item:GetOwner() ~= client then return end
        if not CanEditDoc(client) then client:Notify("No tienes autoridad para rellenar documentos.") return end
        if DocAlreadyFilled(item, "diplomatic") then client:Notify("Este documento ya está rellenado.") return end

        local issued = os.time()
        local expires = issued + 730 * 24 * 60 * 60 + EXPIRY_OFFSET
        local saved = {
            holderName = Str(data.holderName, 64),
            position = Str(data.position, 64),
            embassy = Str(data.embassy, 64),
            issuedWhen = issued,
            expiresAt = expires,
            accreditationNumber = Str(data.accreditationNumber, 20),
            stamp = GetIssuerStamp(client)
        }
        item:SetData("diplomatic", saved)
        client:Notify("ID Diplomático emitido.")
    end)

    net.Receive("ix.pp.SaveTransitPermit", function(_, client)
        local itemID = net.ReadUInt(32)
        local data   = net.ReadTable() or {}
        local item   = ix.item.instances[itemID]
        if not item or item.uniqueID ~= "transit_permit" or item:GetOwner() ~= client then return end
        if not CanEditDoc(client) then client:Notify("No tienes autoridad para rellenar documentos.") return end
        if DocAlreadyFilled(item, "transit") then client:Notify("Este documento ya está rellenado.") return end

        local hours = Num(data.validHours or 24, 1, 168, 24)
        local issued = os.time()
        local expires = issued + hours * 60 * 60 + EXPIRY_OFFSET
        local saved = {
            holderName = Str(data.holderName, 64),
            origin = Str(data.origin, 48),
            destination = Str(data.destination, 48),
            purpose = Str(data.purpose, 32),
            issuedWhen = issued,
            expiresAt = expires,
            transitNumber = Str(data.transitNumber, 16),
            stamp = GetIssuerStamp(client)
        }
        item:SetData("transit", saved)
        client:Notify("Permiso de Tránsito emitido.")
    end)

    net.Receive("ix.pp.SaveAccessTicket", function(_, client)
        local itemID = net.ReadUInt(32)
        local data   = net.ReadTable() or {}
        local item   = ix.item.instances[itemID]
        if not item or item.uniqueID ~= "access_ticket" or item:GetOwner() ~= client then return end
        if not CanEditDoc(client) then client:Notify("No tienes autoridad para rellenar documentos.") return end
        if DocAlreadyFilled(item, "ticket") then client:Notify("Este documento ya está rellenado.") return end

        local issued = os.time()
        local saved = {
            holderName = Str(data.holderName, 64),
            accessLevel = Str(data.accessLevel, 32),
            validDate = Str(data.validDate, 16),
            issuedWhen = issued,
            purpose = Str(data.purpose, 64),
            ticketNumber = Str(data.ticketNumber, 16),
            stamp = GetIssuerStamp(client)
        }
        item:SetData("ticket", saved)
        client:Notify("Boleto de Acceso emitido.")
    end)

    net.Receive("ix.pp.SaveVaccineDocuments", function(_, client)
        local itemID = net.ReadUInt(32)
        local data   = net.ReadTable() or {}
        local item   = ix.item.instances[itemID]
        if not item or item.uniqueID ~= "vaccine_documents" or item:GetOwner() ~= client then return end
        if not CanEditDoc(client) then client:Notify("No tienes autoridad para rellenar documentos.") return end
        if DocAlreadyFilled(item, "vaccine") then client:Notify("Este documento ya está rellenado.") return end

        local years = Num(data.validYears or 5, 1, 10, 5)
        local issued = os.time()
        local validUntil = issued + years * 365 * 24 * 60 * 60 + EXPIRY_OFFSET
        local saved = {
            holderName = Str(data.holderName, 64),
            vaccines = data.vaccines or {},
            issuedWhen = issued,
            validUntil = validUntil,
            certificateNumber = Str(data.certificateNumber, 20),
            stamp = GetIssuerStamp(client)
        }
        item:SetData("vaccine", saved)
        client:Notify("Documentos de Vacunas emitidos.")
    end)
end

-----------------------------------------------------------------
-- NUEVO: SISTEMA DE PÁGINAS MÚLTIPLES Y SELLOS DE ESTACIÓN
-----------------------------------------------------------------
if (SERVER) then
    -- Función helper para inicializar páginas de pasaporte
    local function InitializePassportPages(passportData)
        if not passportData.pages then
            passportData.pages = {
                {
                    pageNumber = 1,
                    stationStamps = {},
                    notes = ""
                }
            }
        end
        return passportData.pages
    end

    -- Añadir sello de estación a una página específica
    net.Receive("ix.pp.AddStationStamp", function(_, client)
        local itemID = net.ReadUInt(32) or 0
        local stationName = net.ReadString() or ""
        local stampType = net.ReadString() or "entry" -- entry, exit, transit
        local pageNumber = net.ReadUInt(8) or 1
        
        if not (client and client:IsPlayer() and client:Alive()) then return end
        
        local item = ix.item.instances[itemID]
        if not item or item.uniqueID ~= "passport" or item:GetOwner() ~= client then
            net.Start("ix.pp.StationStampResult")
                net.WriteBool(false)
                net.WriteString("Pasaporte no válido o no te pertenece.")
            net.Send(client)
            return
        end

        -- Verificar proximity a mesa de inspección
        local nearDesk = false
        for _, ent in ipairs(ents.FindByClass("ix_inspection_desk")) do
            if IsValid(ent) and ent:GetPos():DistToSqr(client:GetPos()) <= ((PLUGIN.InspectionUseDistance or 200)^2) then
                nearDesk = true
                break
            end
        end
        
        if not nearDesk then
            net.Start("ix.pp.StationStampResult")
                net.WriteBool(false)
                net.WriteString("Debes estar cerca de una mesa de inspección para sellar.")
            net.Send(client)
            return
        end

        local passportData = item:GetData("passport", {})
        local pages = InitializePassportPages(passportData)
        
        -- Encontrar o crear la página solicitada
        local targetPage = nil
        for _, page in ipairs(pages) do
            if page.pageNumber == pageNumber then
                targetPage = page
                break
            end
        end
        
        if not targetPage then
            -- Crear nueva página si no existe
            targetPage = {
                pageNumber = pageNumber,
                stationStamps = {},
                notes = ""
            }
            table.insert(pages, targetPage)
        end

        -- Verificar límite de sellos por página
        local maxStampsPerPage = PLUGIN.MultiPagePassport.MaxStampsPerPage or 2
        local currentStamps = #targetPage.stationStamps or 0
        
        if currentStamps >= maxStampsPerPage then
            net.Start("ix.pp.StationStampResult")
                net.WriteBool(false)
                net.WriteString(string.format("Esta página ya tiene el máximo de %d sellos permitidos", maxStampsPerPage))
            net.Send(client)
            return
        end

        -- Añadir nuevo sello de estación
        local newStamp = {
            stationName = stationName,
            stampType = stampType,
            timestamp = os.time(),
            stampedBy = client:Name(),
            stampPosition = {x = math.random(50, 300), y = math.random(100, 200)} -- Adjusted for 140x60 stamps
        }
        
        table.insert(targetPage.stationStamps, newStamp)
        
        -- Actualizar datos del pasaporte
        passportData.pages = pages
        item:SetData("passport", passportData)

        -- Enviar resultado exitoso
        net.Start("ix.pp.StationStampResult")
            net.WriteBool(true)
            net.WriteString(string.format("Sello de estación '%s' añadido a la página %d", stationName, pageNumber))
        net.Send(client)
    end)

    -- Obtener datos de páginas del pasaporte
    net.Receive("ix.pp.GetPassportPages", function(_, client)
        local itemID = net.ReadUInt(32) or 0
        
        local item = ix.item.instances[itemID]
        if not item or item.uniqueID ~= "passport" then
            net.Start("ix.pp.PassportPagesData")
                net.WriteTable({})
            net.Send(client)
            return
        end

        local passportData = item:GetData("passport", {})
        local pages = InitializePassportPages(passportData)
        
        net.Start("ix.pp.PassportPagesData")
            net.WriteTable(pages)
        net.Send(client)
    end)

    -- Devolver documento al inventario
    net.Receive("ix.pp.ReturnDocument", function(_, client)
        local itemID = net.ReadUInt(32) or 0
        local docType = net.ReadString() or ""
        
        local item = ix.item.instances[itemID]
        if not item then
            client:Notify("Documento no encontrado", NOTIFY_ERROR)
            return
        end
        
        -- Verificar que el cliente tenga permisos para manipular este documento
        local char = client:GetCharacter()
        if not char or item:GetOwner() ~= char:GetID() then
            client:Notify("No tienes permiso para devolver este documento", NOTIFY_ERROR)
            return
        end
        
        -- El documento ya debería estar en el inventario, solo necesitamos actualizar la UI
        client:Notify("Documento devuelto al inventario", NOTIFY_SUCCESS)
    end)

    -- Limpiar sellos del pasaporte
    net.Receive("ix.pp.ClearPassportStamps", function(_, client)
        local itemID = net.ReadUInt(32) or 0
        
        local item = ix.item.instances[itemID]
        if not item or item.uniqueID ~= "passport" then
            client:Notify("Pasaporte no encontrado", NOTIFY_ERROR)
            return
        end
        
        if (item:GetOwner() != client) then
            client:Notify("No tienes permiso para modificar este pasaporte.")
            return
        end

        local passportData = item:GetData("passport", {})

        -- Limpiar sellos de estación en páginas de viajes (NO tocar stamp de emisión)
        if (passportData.pages) then
            for _, page in ipairs(passportData.pages) do
                page.stationStamps = {}
            end
        end

        item:SetData("passport", passportData)
        client:Notify("Sellos de viaje limpiados.")
    end)
end
if (SERVER) then
    local function NormalizeStampName(stampRelOrName)
        stampRelOrName = tostring(stampRelOrName or "")
        if stampRelOrName == "" then return "" end
        local fname = string.GetFileFromFilename(stampRelOrName)
        return fname or ""
    end

    net.Receive("ix.pp.StampDoc", function(_, client)
        local itemID  = net.ReadUInt(32) or 0
        local stampIn = net.ReadString() or ""
        local docType = net.ReadString() or "" -- "passport" | "entry_permit" | "work_pass"

        if not (client and client:IsPlayer() and client:Alive()) then return end
        local char = client:GetCharacter(); if not char then return end
        local inv = char:GetInventory(); if not inv then return end

        local item = ix.item.instances[itemID]
        if not item then
            net.Start("ix.pp.StampResult")
                net.WriteBool(false)
                net.WriteString("Documento no encontrado.")
                net.WriteUInt(itemID, 32)
                net.WriteString("")
                net.WriteString(docType)
            net.Send(client)
            return
        end

        -- Debe estar cerca de una mesa de inspección
        local nearDesk = false
        for _, ent in ipairs(ents.FindByClass("ix_inspection_desk")) do
            if IsValid(ent) and ent:GetPos():DistToSqr(client:GetPos()) <= ((PLUGIN.InspectionUseDistance or 200)^2) then
                nearDesk = true
                break
            end
        end
        if not nearDesk then
            net.Start("ix.pp.StampResult")
                net.WriteBool(false)
                net.WriteString("Acércate a una mesa de inspección para sellar.")
                net.WriteUInt(itemID, 32)
                net.WriteString("")
                net.WriteString(docType)
            net.Send(client)
            return
        end

        -- Firma automática por facción: solo se acepta el sello de la facción del
        -- inspector o el sello de denegado (impide falsificar aprobaciones con
        -- sellos de otras facciones). Coherente con la mesa de inspección.
        local info = PLUGIN.GetInspectorInfo and PLUGIN:GetInspectorInfo(client) or { canInspect = false }
        if not info.canInspect then
            net.Start("ix.pp.StampResult")
                net.WriteBool(false)
                net.WriteString("Tu facción no tiene autoridad para sellar documentos.")
                net.WriteUInt(itemID, 32)
                net.WriteString("")
                net.WriteString(docType)
            net.Send(client)
            return
        end

        local stampName = NormalizeStampName(stampIn)
        if (stampName != info.stamp and stampName != PLUGIN.DeniedStamp) then
            stampName = info.stamp -- fuerza el sello válido de su facción
        end

        if (docType == "passport" and item.uniqueID == "passport") then
            local d = item:GetData("passport", {}) or {}
            d.stamp = stampName
            item:SetData("passport", d)
        elseif (docType == "entry_permit" and item.uniqueID == "entry_permit") then
            local d = item:GetData("permit", {}) or {}
            d.stamp = stampName
            item:SetData("permit", d)
        elseif (docType == "work_pass" and item.uniqueID == "work_pass") then
            local d = item:GetData("workpass", {}) or {}
            d.stamp = stampName
            item:SetData("workpass", d)
        elseif (docType == "id_card" and item.uniqueID == "id_card") then
            local d = item:GetData("idcard", {}) or {}
            d.stamp = stampName
            item:SetData("idcard", d)
        elseif (docType == "diplomatic_id" and item.uniqueID == "diplomatic_id") then
            local d = item:GetData("diplomatic", {}) or {}
            d.stamp = stampName
            item:SetData("diplomatic", d)
        elseif (docType == "transit_permit" and item.uniqueID == "transit_permit") then
            local d = item:GetData("transit", {}) or {}
            d.stamp = stampName
            item:SetData("transit", d)
        elseif (docType == "access_ticket" and item.uniqueID == "access_ticket") then
            local d = item:GetData("ticket", {}) or {}
            d.stamp = stampName
            item:SetData("ticket", d)
        elseif (docType == "vaccine_documents" and item.uniqueID == "vaccine_documents") then
            local d = item:GetData("vaccine", {}) or {}
            d.stamp = stampName
            item:SetData("vaccine", d)
        else
            net.Start("ix.pp.StampResult")
                net.WriteBool(false)
                net.WriteString("Tipo de documento inválido para este ítem.")
                net.WriteUInt(itemID, 32)
                net.WriteString("")
                net.WriteString(docType)
            net.Send(client)
            return
        end

        net.Start("ix.pp.StampResult")
            net.WriteBool(true)
            net.WriteString(stampName == "" and "Sello eliminado." or ("Sello aplicado: " .. stampName))
            net.WriteUInt(itemID, 32)
            net.WriteString(stampName)
            net.WriteString(docType)
        net.Send(client)
    end)
end

-----------------------------------------------------------------
-- CONFISCAR: mover al CONTENEDOR (inventario) cercano
-----------------------------------------------------------------
if (SERVER) then
    local function FindNearestBox(ply, maxDist)
        maxDist = maxDist or (PLUGIN.InspectionUseDistance or 200)
        local maxSqr = (maxDist * maxDist)
        local best, bestD = nil, math.huge

        for _, ent in ipairs(ents.FindByClass("ix_confiscation_box")) do
            if IsValid(ent) then
                local d = ent:GetPos():DistToSqr(ply:GetPos())
                if d < bestD and d <= maxSqr then
                    bestD = d
                    best = ent
                end
            end
        end

        return best
    end

    net.Receive("ix.pp.ConfiscateDoc", function(_, client)
        local itemID = net.ReadUInt(32) or 0
        local item = ix.item.instances[itemID]
        if not item then
            net.Start("ix.pp.ConfiscateResult")
                net.WriteBool(false)
                net.WriteString("Documento no encontrado.")
            net.Send(client)
            return
        end

        -- Reglas básicas: solo confiscar tus propios docs (como ya tenías)
        local owner = item:GetOwner()
        if owner ~= client then
            net.Start("ix.pp.ConfiscateResult")
                net.WriteBool(false)
                net.WriteString("No puedes confiscar documentos de otro jugador.")
            net.Send(client)
            return
        end

        -- Comprobar distancia a una mesa cercana (tu lógica original)
        local desk = nil
        for _, ent in ipairs(ents.FindByClass("ix_inspection_desk")) do
            if IsValid(ent) and ent:GetPos():DistToSqr(client:GetPos()) <= (200*200) then
                desk = ent
                break
            end
        end
        if not desk then
            net.Start("ix.pp.ConfiscateResult")
                net.WriteBool(false)
                net.WriteString("Acércate a una mesa de inspección para confiscar.")
            net.Send(client)
            return
        end

        -- Buscar contenedor cercano
        local box = FindNearestBox(client)
        if not box then
            net.Start("ix.pp.ConfiscateResult")
                net.WriteBool(false)
                net.WriteString("No hay contenedor de documentos cerca.")
            net.Send(client)
            return
        end

        local inv = box.GetInventory and box:GetInventory() or nil
        if not inv then
            net.Start("ix.pp.ConfiscateResult")
                net.WriteBool(false)
                net.WriteString("El contenedor no tiene inventario disponible.")
            net.Send(client)
            return
        end

        local uid = item.uniqueID
        local dataKey = (uid == "passport" and "passport")
                     or (uid == "entry_permit" and "permit")
                     or (uid == "work_pass" and "workpass")
                     or (uid == "id_card" and "idcard")
                     or (uid == "diplomatic_id" and "diplomatic")
                     or (uid == "transit_permit" and "transit")
                     or (uid == "access_ticket" and "ticket")
                     or (uid == "vaccine_documents" and "vaccine")

        if not dataKey then
            net.Start("ix.pp.ConfiscateResult")
                net.WriteBool(false)
                net.WriteString("Tipo de documento no soportado por el contenedor.")
            net.Send(client)
            return
        end

        local dataBlock = {}
        dataBlock[dataKey] = item:GetData(dataKey, {}) or {}

        -- Temporarily set inventory owner to client to prevent logging errors
        local originalOwner = inv:GetOwner()
        inv:SetOwner(client)
        
        local added, err = inv:Add(uid, 1, dataBlock)
        
        -- Restore original owner
        inv:SetOwner(originalOwner)
        
        if not added then
            net.Start("ix.pp.ConfiscateResult")
                net.WriteBool(false)
                net.WriteString("Contenedor lleno: " .. tostring(err or "sin espacio"))
            net.Send(client)
            return
        end

        item:Remove()

        net.Start("ix.pp.ConfiscateResult")
            net.WriteBool(true)
            net.WriteString("Documento confiscado y guardado en el contenedor.")
        net.Send(client)
    end)
end
-- (El bloque anterior reemplaza el borrado por mover al contenedor) [3](https://kardanuniversityorg-my.sharepoint.com/personal/e71523_365a3_top/Documents/Archivos%20de%20Microsoft%C2%A0Copilot%20Chat/cl_fonts.lua)

-----------------------------------------------------------------
-- PERSISTENCIA de CONTENEDORES
-----------------------------------------------------------------
-- sh_plugin.lua (SERVER) — Container persistence
if (SERVER) then
    function PLUGIN:SaveData()
        if (ix.shuttingDown) then return end

        local data = {}

        for _, ent in ipairs(ents.FindByClass("ix_confiscation_box")) do
            if IsValid(ent) then
                data[#data + 1] = {
                    pos = ent:GetPos(),
                    ang = ent:GetAngles(),
                    inv = (ent.GetInventoryID and ent:GetInventoryID()) or 0
                }
            end
        end

        ix.data.Set("confiscation_boxes", data)

        -- Mesas de inspección
        local desks = {}
        for _, ent in ipairs(ents.FindByClass("ix_inspection_desk")) do
            if IsValid(ent) then
                desks[#desks + 1] = {
                    pos = ent:GetPos(),
                    ang = ent:GetAngles(),
                    station = ent.GetStationName and ent:GetStationName() or "",
                    faction = ent.GetStationFaction and ent:GetStationFaction() or ""
                }
            end
        end
        ix.data.Set("inspection_desks", desks)
    end

    function PLUGIN:LoadData()
        -- Mesas de inspección
        for _, v in ipairs(ix.data.Get("inspection_desks", {})) do
            local ent = ents.Create("ix_inspection_desk")
            ent:SetPos(v.pos)
            ent:SetAngles(v.ang)
            ent:Spawn()
            if (v.station and v.station != "" and ent.SetStationName) then
                ent:SetStationName(v.station)
            end
            if (v.faction and v.faction != "" and ent.SetStationFaction) then
                ent:SetStationFaction(v.faction)
            end
        end

        local data = ix.data.Get("confiscation_boxes", {})

        for _, v in ipairs(data) do
            local ent = ents.Create("ix_confiscation_box")
            ent:SetPos(v.pos)
            ent:SetAngles(v.ang)
            ent:Spawn()

            local invID = tonumber(v.inv or 0) or 0
            if invID > 0 then
                -- Restaurar inventario y asociarlo a la caja
                if ix.inventory and ix.inventory.Restore then
                    ix.inventory.Restore(invID, function(inv)
                        if IsValid(ent) and inv then
                            ent:SetInventory(inv)
                        end
                    end)
                end

                -- Redundante pero útil si se abre antes de restaurar:
                if ent.SetInventoryID then ent:SetInventoryID(invID) end
                if ent.SetNetVar then ent:SetNetVar("inv", invID) end
            end
        end
    end
end

-- Comandos fuera de if(SERVER) para que Helix los registre en cliente (autocompletado).
-- OnRun solo se ejecuta en servidor igualmente.
ix.command.Add("ConfBoxSpawn", {
    description = "Spawnea un Contenedor de Documentos frente a ti.",
    adminOnly = true,
    arguments = {
        bit.bor(ix.type.number, ix.type.optional),
        bit.bor(ix.type.number, ix.type.optional)
    },
    OnRun = function(self, client, w, h)
        local tr = client:GetEyeTraceNoCursor()
        local pos = tr.HitPos + tr.HitNormal * 8
        local ent = ents.Create("ix_confiscation_box")
        ent:SetPos(pos)
        ent:SetAngles(Angle(0, client:EyeAngles().y, 0))
        ent:Spawn()

        if isnumber(w) and isnumber(h) and w > 0 and h > 0 then
            ent.invWidth = math.floor(w)
            ent.invHeight = math.floor(h)
        end

        client:Notify(string.format(
            "Contenedor creado (%dx%d). Usa /schema save para persistir.",
            ent.invWidth or 8, ent.invHeight or 6
        ))
        return "Hecho."
    end
})

ix.command.Add("EstacionNombre", {
    description = "Cambia el nombre de la estación de la mesa de inspección que estés mirando.",
    adminOnly = true,
    arguments = { ix.type.text },
    OnRun = function(self, client, name)
        local tr = client:GetEyeTraceNoCursor()
        local ent = tr.Entity

        if (not IsValid(ent) or ent:GetClass() != "ix_inspection_desk") then
            return "Debes mirar una mesa de inspección."
        end

        if (ent:GetPos():DistToSqr(client:GetPos()) > 200 * 200) then
            return "Estás demasiado lejos de la mesa."
        end

        name = string.sub(string.Trim(name), 1, 48)
        if (name == "") then
            return "El nombre no puede estar vacío."
        end

        ent:SetStationName(name)
        return string.format("Estación renombrada a: %s", name)
    end
})

ix.command.Add("EstacionFaccion", {
    description = "Asigna facciones a la mesa. Acepta varias separadas por coma: /EstacionFaccion Polis, Hanza",
    adminOnly = true,
    arguments = { ix.type.text },
    OnRun = function(self, client, factionName)
        local tr = client:GetEyeTraceNoCursor()
        local ent = tr.Entity

        if (not IsValid(ent) or ent:GetClass() != "ix_inspection_desk") then
            return "Debes mirar una mesa de inspección."
        end

        if (ent:GetPos():DistToSqr(client:GetPos()) > 200 * 200) then
            return "Estás demasiado lejos de la mesa."
        end

        factionName = string.Trim(factionName)
        if (factionName == "") then
            return "El nombre de facción no puede estar vacío."
        end

        -- Normalizar: limpiar espacios alrededor de comas
        local factions = PLUGIN:ParseFactions(factionName)
        if (#factions == 0) then
            return "No se detectaron facciones válidas."
        end

        local normalized = table.concat(factions, ",")
        if (#normalized > 128) then
            normalized = string.sub(normalized, 1, 128)
        end

        ent:SetStationFaction(normalized)
        return string.format("Facciones de la estación: %s", table.concat(factions, ", "))
    end
})

ix.command.Add("EstacionFaccionAdd", {
    description = "Añade una facción a la mesa de inspección sin borrar las existentes.",
    adminOnly = true,
    arguments = { ix.type.text },
    OnRun = function(self, client, factionName)
        local tr = client:GetEyeTraceNoCursor()
        local ent = tr.Entity

        if (not IsValid(ent) or ent:GetClass() != "ix_inspection_desk") then
            return "Debes mirar una mesa de inspección."
        end

        if (ent:GetPos():DistToSqr(client:GetPos()) > 200 * 200) then
            return "Estás demasiado lejos de la mesa."
        end

        factionName = string.Trim(factionName)
        if (factionName == "") then
            return "El nombre de facción no puede estar vacío."
        end

        local current = ent:GetStationFaction() or ""
        local factions = PLUGIN:ParseFactions(current)

        -- Comprobar si ya existe
        for _, f in ipairs(factions) do
            if (string.lower(f) == string.lower(factionName)) then
                return string.format("'%s' ya está asignada a esta mesa.", factionName)
            end
        end

        factions[#factions + 1] = factionName
        local normalized = table.concat(factions, ",")
        if (#normalized > 128) then
            return "Demasiadas facciones asignadas."
        end

        ent:SetStationFaction(normalized)
        return string.format("Facciones de la estación: %s", table.concat(factions, ", "))
    end
})

ix.command.Add("EstacionFaccionQuitar", {
    description = "Quita una facción de la mesa de inspección.",
    adminOnly = true,
    arguments = { ix.type.text },
    OnRun = function(self, client, factionName)
        local tr = client:GetEyeTraceNoCursor()
        local ent = tr.Entity

        if (not IsValid(ent) or ent:GetClass() != "ix_inspection_desk") then
            return "Debes mirar una mesa de inspección."
        end

        if (ent:GetPos():DistToSqr(client:GetPos()) > 200 * 200) then
            return "Estás demasiado lejos de la mesa."
        end

        factionName = string.Trim(factionName)
        if (factionName == "") then
            return "El nombre de facción no puede estar vacío."
        end

        local current = ent:GetStationFaction() or ""
        local factions = PLUGIN:ParseFactions(current)
        local found = false

        for i = #factions, 1, -1 do
            if (string.lower(factions[i]) == string.lower(factionName)) then
                table.remove(factions, i)
                found = true
            end
        end

        if (not found) then
            return string.format("'%s' no está asignada a esta mesa.", factionName)
        end

        ent:SetStationFaction(table.concat(factions, ","))

        if (#factions == 0) then
            return "Se han eliminado todas las facciones de la mesa."
        end

        return string.format("Facciones de la estación: %s", table.concat(factions, ", "))
    end
})