-- libs/sv_inspection.lua
-- Lógica de servidor del control de frontera "Papers, Please":
--   * Autoridad de firma por facción (solo facciones de control + Staff).
--   * Motor de validación de documentos contra el boletín del día.
--   * Sellado automático con el sello de la facción del inspector.
--   * Citaciones/multas al inspector cuando su decisión contradice las reglas.
--
-- MODELO RP: los documentos que se inspeccionan son los que el inspector coloca en
-- la mesa (los que ha recibido del viajero o lleva consigo). La validación y las
-- multas se calculan sobre esos documentos.
local PLUGIN = PLUGIN

-- uniqueID del ítem -> clave bajo la que guarda sus datos.
local DOC_DATAKEY = {
    passport          = "passport",
    entry_permit      = "permit",
    work_pass         = "workpass",
    id_card           = "idcard",
    diplomatic_id     = "diplomatic",
    transit_permit    = "transit",
    access_ticket     = "ticket",
    vaccine_documents = "vaccine",
}
PLUGIN.DocDataKey = DOC_DATAKEY

local MAX_DESK_DOCS = 12
local MAX_REASONS = 16

-----------------------------------------------------------------
-- Autoridad del inspector según su facción
-----------------------------------------------------------------
function PLUGIN:GetInspectorInfo(client)
    if (not IsValid(client)) then return { canInspect = false } end

    local char = client:GetCharacter()
    if (not char) then return { canInspect = false } end

    local faction = ix.faction.indices[client:Team()]
    local uid = faction and faction.uniqueID or ""

    local stamp = self.InspectorStamps[uid]
    if (stamp) then
        return {
            canInspect = true,
            stamp = stamp,
            faction = uid,
            nation = self.FactionNations[uid]
        }
    end

    if (uid == "staff") then
        return { canInspect = true, stamp = self.StaffStamp, faction = "staff" }
    end

    return { canInspect = false }
end

-----------------------------------------------------------------
-- Recolección de documentos
-----------------------------------------------------------------
-- Construye el contexto (ctx.passport, ctx.permit, ctx.workpass, ...) a partir de
-- una lista de itemIDs, validando que el inspector pueda manipularlos.
local function GatherDocuments(ids, client)
    local ctx, items = {}, {}

    for _, id in ipairs(ids or {}) do
        local it = ix.item.instances[id]
        if (it) then
            local key = DOC_DATAKEY[it.uniqueID]
            -- Solo se aceptan documentos que pertenezcan al inspector (se los han
            -- entregado / los lleva), para evitar sellar ítems arbitrarios.
            if (key and not ctx[key] and it:GetOwner() == client) then
                ctx[key] = it:GetData(key, {}) or {}
                items[key] = it
            end
        end
    end

    return ctx, items
end

-----------------------------------------------------------------
-- Motor de validación contra el boletín del día
-----------------------------------------------------------------
-- Devuelve: verdict ("approve"|"deny"), reasons (lista de strings)
-- Informativa: lista qué documentos del boletín faltan en la mesa. No juzga la
-- decisión del inspector (ni naciones, ni multas). El inspector decide libremente.
function PLUGIN:CheckMissingDocs(ctx, rules)
    rules = rules or self:GetTodayRules()
    local missing = {}

    local docNames = {
        passport          = "Pasaporte",
        entry_permit      = "Permiso de Entrada",
        work_pass         = "Pase de Trabajo",
        id_card           = "Tarjeta de Identidad",
        diplomatic_id     = "ID Diplomático",
        transit_permit    = "Permiso de Tránsito",
        access_ticket     = "Boleto de Acceso",
        vaccine_documents = "Doc. Vacunas"
    }

    for docType, req in pairs(rules.requireDocs or {}) do
        local needed = req
        if (isfunction(req)) then needed = req(ctx) end

        if (needed) then
            local key = DOC_DATAKEY[docType]
            if (key and not ctx[key]) then
                missing[#missing + 1] = "Falta: " .. (docNames[docType] or docType)
            end
        end
    end

    return missing
end

-- Lee una lista de itemIDs de la red (uint8 count + N uint32).
local function ReadItemIDs()
    local ids = {}
    local n = math.min(net.ReadUInt(8), MAX_DESK_DOCS)
    for i = 1, n do
        ids[#ids + 1] = net.ReadUInt(32)
    end
    return ids
end

local function WriteReasons(reasons)
    local n = math.min(#reasons, MAX_REASONS)
    net.WriteUInt(n, 5)
    for i = 1, n do
        net.WriteString(reasons[i])
    end
end

-----------------------------------------------------------------
-- Cercanía a una mesa de inspección válida
-----------------------------------------------------------------
local function NearDesk(client, ent)
    local maxSqr = (PLUGIN.InspectionUseDistance or 200) ^ 2
    if (IsValid(ent) and ent:GetClass() == "ix_inspection_desk"
        and ent:GetPos():DistToSqr(client:GetPos()) <= maxSqr) then
        return true
    end

    for _, desk in ipairs(ents.FindByClass("ix_inspection_desk")) do
        if (IsValid(desk) and desk:GetPos():DistToSqr(client:GetPos()) <= maxSqr) then
            return true
        end
    end

    return false
end

-----------------------------------------------------------------
-- Veredicto de asistencia (no sella ni multa, solo informa)
-----------------------------------------------------------------
net.Receive("ix.pp.RequestVerdict", function(_, client)
    local ent = net.ReadEntity()
    local ids = ReadItemIDs()

    if (not NearDesk(client, ent)) then return end

    local ctx = GatherDocuments(ids, client)
    local missing = PLUGIN:CheckMissingDocs(ctx)

    net.Start("ix.pp.AssistVerdict")
        net.WriteString(#missing > 0 and "info" or "ok")
        WriteReasons(missing)
    net.Send(client)
end)

-----------------------------------------------------------------
-- Decisión del inspector: sella por facción + valida + multa
-----------------------------------------------------------------
net.Receive("ix.pp.DeskDecision", function(_, client)
    local ent       = net.ReadEntity()
    local action    = net.ReadString()           -- "approve" | "deny"
    local targetID  = net.ReadUInt(32)
    local pageNum   = net.ReadUInt(8)
    local ids       = ReadItemIDs()

    if (action != "approve" and action != "deny") then return end
    if (not NearDesk(client, ent)) then
        client:Notify("Acércate a una mesa de inspección.")
        return
    end

    local info = PLUGIN:GetInspectorInfo(client)
    if (not info.canInspect) then
        client:Notify("Tu facción no tiene autoridad para sellar documentos de frontera.")
        return
    end

    local char = client:GetCharacter()
    if (not char) then return end

    -- Documento concreto a sellar (o el primer pasaporte de la lista)
    local ctx, items = GatherDocuments(ids, client)

    local target = ix.item.instances[targetID]
    if (not target or target:GetOwner() != client or not DOC_DATAKEY[target.uniqueID]) then
        target = items.passport
    end
    if (not target) then
        client:Notify("No hay ningún documento válido en la mesa para sellar.")
        return
    end

    -- Sello según facción del inspector (aprobar) o sello de denegado.
    local stampName = (action == "approve") and info.stamp or PLUGIN.DeniedStamp
    local dataKey = DOC_DATAKEY[target.uniqueID]
    local d = target:GetData(dataKey, {}) or {}
    d.decisionBy = client:Name()
    d.decisionFaction = info.faction
    d.decisionWhen = os.time()

    if (target.uniqueID == "passport") then
        -- Página 1 (datos): d.stamp es el sello de la facción que EMITIÓ el
        -- pasaporte. Se fija al imprimir y NUNCA se toca aquí.
        -- Las aprobaciones/denegaciones van en páginas de viajes.
        d.pages = d.pages or { { pageNumber = 1, stationStamps = {}, notes = "" } }

        local maxPerPage = (PLUGIN.MultiPagePassport and PLUGIN.MultiPagePassport.MaxStampsPerPage) or 2

        local page
        for i = #d.pages, 1, -1 do
            local p = d.pages[i]
            if (p.pageNumber and p.pageNumber > 1 and #(p.stationStamps or {}) < maxPerPage) then
                page = p
                break
            end
        end
        if (not page) then
            page = { pageNumber = #d.pages + 1, stationStamps = {}, notes = "" }
            d.pages[#d.pages + 1] = page
        end

        -- Nombre de la estación: del entity de la mesa, o si no, la facción.
        local stationLabel = info.nation or info.faction or "Control"
        if (IsValid(ent) and ent.GetStationName) then
            local deskName = ent:GetStationName()
            if (deskName and deskName != "" and deskName != "Sin definir") then
                stationLabel = deskName
            end
        end

        local travelStamp = (action == "approve") and PLUGIN.StaffStamp or PLUGIN.DeniedStamp

        page.stationStamps = page.stationStamps or {}
        page.stationStamps[#page.stationStamps + 1] = {
            stationName = stationLabel,
            stampType = (action == "approve") and "entry" or "deny",
            stampImage = travelStamp,
            timestamp = os.time(),
            stampedBy = client:Name(),
            stampPosition = { x = math.random(40, 220), y = math.random(20, 60) }
        }
    else
        -- Documentos sin páginas: el sello va directamente sobre el documento.
        d.stamp = stampName
    end

    target:SetData(dataKey, d)

    -- Enviar resultado con las páginas actualizadas incluidas (sin round-trip extra).
    net.Start("ix.pp.DeskResult")
        net.WriteString(action)
        net.WriteUInt(target.id or 0, 32)
        net.WriteString(stampName)
        net.WriteString(target.uniqueID)
        net.WriteTable(d.pages or {})
    net.Send(client)
end)
