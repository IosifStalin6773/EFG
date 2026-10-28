-- libs/sh_rules.lua
-- Sistema de reglas "Papers, Please" del Metro: boletines por día con naciones
-- admitidas/vetadas, documentos exigidos, validez de sellos, caducidades y multas.
-- Vive en libs/ para que esté disponible cuando se cargan la mesa de inspección
-- (derma/) y la lógica de servidor (libs/sv_inspection.lua).
local PLUGIN = PLUGIN

-- Día actual (lo cambia un admin con /fronteradia, se persiste y se sincroniza).
PLUGIN.CurrentDay = PLUGIN.CurrentDay or 1

-- Ciudades emisoras válidas por nación (ajústalo a tu lore).
PLUGIN.ValidIssuingCities = {
    Polis   = { "Arbatskaya", "Borovitskaya", "Biblioteka" },
    Hanza   = { "Prospekt", "Kurskaya" },
    Redline = { "Lubyanka", "Tetral'naya", "Ploshchad' Revolyutsii" },
    Reich   = { "Tverskaya", "Pushkinskaya", "Checkhovskaya" }
}

-- Boletines (reglas por día). Amplíalo como quieras.
--   allowedNations : si la lista no está vacía, SOLO se admiten esas naciones.
--   bannedNations  : naciones vetadas (rechazo inmediato).
--   requireDocs    : documentos obligatorios. El valor puede ser true o una
--                    función function(ctx) que decide según el resto de documentos.
--   requireValidStamp : el pasaporte debe llevar sello de emisión.
--   requireNameMatch  : el nombre debe coincidir en todos los documentos.
--   checkIssuingCity  : la ciudad emisora del permiso debe ser válida para la nación.
--   checkExpiry       : comprueba caducidades (permiso / pase de trabajo).
--   maxPermitDays     : duración máxima permitida en el permiso de entrada.
--   fines             : multa al inspector si se equivoca { minor=, major= }.
-- Lista de facciones conocidas del schema (para el editor de boletines).
PLUGIN.KnownFactions = {
    "Polis", "Hanza", "Linea Roja", "Cuarto Reich",
    "Rangers", "Bandidos", "Sindicato", "Civil"
}

-- stationRules: reglas POR FACCIÓN de estación. Cada facción propietaria de una
-- mesa define quién tiene permitido/vetado entrar en SU estación.
-- Si una estación no tiene facción asignada, usa las reglas de "_default".
PLUGIN.Bulletins = {
    [1] = {
        name = "Apertura de Frontera",
        requireDocs = {
            passport     = true,
            entry_permit = true,
            work_pass    = function(ctx)
                return (ctx.permit and ctx.permit.purpose == "Trabajo")
            end
        },
        maxPermitDays = 30,
        stationRules = {
            ["Hanza"]        = { allowed = { "Polis", "Civil" },          banned = { "Cuarto Reich", "Linea Roja" } },
            ["Polis"]        = { allowed = { "Hanza", "Civil" },          banned = { "Cuarto Reich" } },
            ["Linea Roja"]   = { allowed = { "Polis", "Civil" },          banned = { "Cuarto Reich" } },
            ["Cuarto Reich"] = { allowed = { "Polis" },                   banned = { "Linea Roja" } },
            ["_default"]     = { allowed = {},                            banned = {} },
        }
    },

    [2] = {
        name = "Alerta Roja",
        requireDocs = { passport = true, entry_permit = true, work_pass = true },
        maxPermitDays = 14,
        stationRules = {
            ["Hanza"]        = { allowed = { "Polis" },                   banned = { "Cuarto Reich", "Linea Roja" } },
            ["Polis"]        = { allowed = {},                            banned = { "Cuarto Reich", "Linea Roja" } },
            ["Linea Roja"]   = { allowed = {},                            banned = { "Cuarto Reich" } },
            ["Cuarto Reich"] = { allowed = {},                            banned = { "Linea Roja" } },
            ["_default"]     = { allowed = {},                            banned = {} },
        }
    },

    [3] = {
        name = "Cuarentena Sanitaria",
        requireDocs = {
            passport          = true,
            entry_permit      = true,
            vaccine_documents = true
        },
        maxPermitDays = 21,
        stationRules = {
            ["_default"] = { allowed = {}, banned = {} },
        }
    }
}

-- Parsea un string de facciones separadas por coma en una tabla.
-- "Polis,Hanza" -> {"Polis", "Hanza"}; "" -> {}
function PLUGIN:ParseFactions(str)
    if (not str or str == "") then return {} end
    local result = {}
    for faction in string.gmatch(str, "[^,]+") do
        faction = string.Trim(faction)
        if (faction != "") then
            result[#result + 1] = faction
        end
    end
    return result
end

-- Devuelve las reglas de facción para una estación concreta dentro de un boletín.
-- Si la estación tiene varias facciones (separadas por coma), fusiona las reglas:
--   allowed = unión de todas las listas allowed
--   banned  = unión de todas las listas banned
function PLUGIN:GetStationRules(rules, stationFaction)
    local factions = self:ParseFactions(stationFaction)

    if (#factions <= 1) then
        local single = factions[1] or ""
        rules = rules or self:GetRulesForFaction(single)
        local sr = rules.stationRules or {}
        if (single != "" and sr[single]) then
            return sr[single]
        end
        return sr["_default"] or { allowed = {}, banned = {} }
    end

    -- Múltiples facciones: fusionar reglas
    rules = rules or self:GetRulesForFaction(factions[1])
    local sr = rules.stationRules or {}
    local mergedAllowed, mergedBanned = {}, {}
    local seenA, seenB = {}, {}

    for _, fac in ipairs(factions) do
        local facRules = sr[fac] or sr["_default"] or { allowed = {}, banned = {} }
        for _, v in ipairs(facRules.allowed or {}) do
            if (not seenA[v]) then
                seenA[v] = true
                mergedAllowed[#mergedAllowed + 1] = v
            end
        end
        for _, v in ipairs(facRules.banned or {}) do
            if (not seenB[v]) then
                seenB[v] = true
                mergedBanned[#mergedBanned + 1] = v
            end
        end
    end

    return { allowed = mergedAllowed, banned = mergedBanned }
end

-- Día activo POR FACCIÓN. Cada facción propietaria de estación puede tener su
-- propio boletín activo. Facciones sin día asignado usan CurrentDay (global).
PLUGIN.FactionDay = PLUGIN.FactionDay or {}

function PLUGIN:GetDayForFaction(stationFaction)
    local factions = self:ParseFactions(stationFaction)

    for _, fac in ipairs(factions) do
        if (self.FactionDay[fac]) then
            return self.FactionDay[fac]
        end
    end

    return self.CurrentDay or 1
end

function PLUGIN:GetRulesForFaction(stationFaction)
    local day = self:GetDayForFaction(stationFaction)
    return self.Bulletins[day] or self.Bulletins[1] or {}
end

-- Compatibilidad: devuelve las reglas globales (sin facción).
function PLUGIN:GetTodayRules()
    return self.Bulletins[self.CurrentDay] or self.Bulletins[1]
end

-- Resumen en texto del boletín del día (para mostrar en la mesa). Solo strings,
-- así que es seguro construirlo en cliente o servidor.
-- stationFaction: facción de la estación (para mostrar reglas específicas).
function PLUGIN:GetBulletinSummary(day, stationFaction)
    local effectiveDay = day or self:GetDayForFaction(stationFaction)
    local rules = self.Bulletins[effectiveDay] or self.Bulletins[1]
    local lines = {}

    lines[#lines + 1] = rules.name or "Sin nombre"

    -- Mostrar facciones propietarias si hay varias
    local factions = self:ParseFactions(stationFaction)
    if (#factions > 1) then
        lines[#lines + 1] = "Facciones: " .. table.concat(factions, ", ")
    end

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

    -- Reglas de facción específicas para esta estación (fusionadas si hay varias)
    local sr = self:GetStationRules(rules, stationFaction)
    if (sr.allowed and #sr.allowed > 0) then
        lines[#lines + 1] = "Permitidos: " .. table.concat(sr.allowed, ", ")
    end
    if (sr.banned and #sr.banned > 0) then
        lines[#lines + 1] = "Vetados: " .. table.concat(sr.banned, ", ")
    end

    local docs = {}
    for docType, req in pairs(rules.requireDocs or {}) do
        local label = docNames[docType] or docType
        docs[#docs + 1] = isfunction(req) and (label .. "*") or label
    end
    if (#docs > 0) then
        lines[#lines + 1] = "Documentos: " .. table.concat(docs, ", ")
    end

    if (rules.maxPermitDays) then
        lines[#lines + 1] = "Permiso máx.: " .. rules.maxPermitDays .. " días"
    end

    return lines
end

-----------------------------------------------------------------
-- Sincronización del día vigente (global + por facción)
-----------------------------------------------------------------
if (SERVER) then
    util.AddNetworkString("ix.pp.SetDay")

    function PLUGIN:BroadcastDays(target)
        net.Start("ix.pp.SetDay")
            net.WriteUInt(self.CurrentDay, 16)
            net.WriteTable(self.FactionDay or {})
        if (IsValid(target)) then net.Send(target) else net.Broadcast() end
    end

    function PLUGIN:SetCurrentDay(day)
        self.CurrentDay = math.max(1, math.floor(tonumber(day) or 1))
        self:SaveDays()
        self:BroadcastDays()
    end

    function PLUGIN:SetFactionDay(faction, day)
        self.FactionDay[faction] = math.max(1, math.floor(tonumber(day) or 1))
        self:SaveDays()
        self:BroadcastDays()
    end

    function PLUGIN:SaveDays()
        ix.data.Set("passport_day", self.CurrentDay)
        ix.data.Set("passport_faction_days", self.FactionDay)
    end

    hook.Add("InitPostEntity", "ixPassportLoadDay", function()
        PLUGIN.CurrentDay = math.max(1, math.floor(tonumber(ix.data.Get("passport_day", 1)) or 1))
        PLUGIN.FactionDay = ix.data.Get("passport_faction_days", {}) or {}
    end)

    hook.Add("PlayerInitialSpawn", "ixPassportSendDay", function(ply)
        timer.Simple(1, function()
            if (IsValid(ply)) then PLUGIN:BroadcastDays(ply) end
        end)
    end)
else
    net.Receive("ix.pp.SetDay", function()
        PLUGIN.CurrentDay = net.ReadUInt(16)
        PLUGIN.FactionDay = net.ReadTable() or {}
    end)
end

-----------------------------------------------------------------
-- Comandos admin para cambiar el día de frontera
-----------------------------------------------------------------
-- /FronteraDia <facción> <número> — asigna un boletín a una facción.
-- /FronteraDia <número> — cambia el boletín global (para estaciones sin facción).
ix.command.Add("FronteraDia", {
    description = "Cambia el boletín de una facción (o global). Uso: /FronteraDia Hanza 2 o /FronteraDia 1",
    adminOnly = true,
    arguments = { ix.type.text },
    OnRun = function(self, client, args)
        local parts = string.Explode(" ", string.Trim(args))

        -- Si es solo un número: día global
        if (#parts == 1 and tonumber(parts[1])) then
            local day = math.max(1, math.floor(tonumber(parts[1])))
            if (not PLUGIN.Bulletins[day]) then
                return "No existe un boletín para el día " .. day .. "."
            end
            PLUGIN:SetCurrentDay(day)
            return string.format("Boletín global fijado a %d (%s).", day, PLUGIN.Bulletins[day].name or "")
        end

        -- Facción + número
        if (#parts >= 2 and tonumber(parts[#parts])) then
            local day = math.max(1, math.floor(tonumber(table.remove(parts))))
            local faction = table.concat(parts, " ")

            if (not PLUGIN.Bulletins[day]) then
                return "No existe un boletín para el día " .. day .. "."
            end

            PLUGIN:SetFactionDay(faction, day)
            return string.format("Boletín de %s fijado a %d (%s).", faction, day, PLUGIN.Bulletins[day].name or "")
        end

        return "Uso: /FronteraDia <facción> <número> o /FronteraDia <número>"
    end
})

ix.command.Add("FronteraEditor", {
    description = "Abre el editor de boletines de frontera.",
    adminOnly = true,
    OnRun = function(self, client)
        net.Start("ix.pp.OpenBulletinEditor")
        net.Send(client)
    end
})
