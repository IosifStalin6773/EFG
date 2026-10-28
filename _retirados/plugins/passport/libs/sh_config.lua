local PLUGIN = PLUGIN

-- IMPORTANTE: este archivo vive en libs/ a propósito. Helix incluye libs/ ANTES
-- que derma/ (ver ix.plugin.Load), de modo que estos valores ya existen cuando se
-- cargan los paneles de derma/ (mesa de inspección, visor, editor, etc.).

PLUGIN.PassportBaseW = 800
PLUGIN.PassportBaseH = 534

PLUGIN.PassportTemplate = "metro/Pasaporte_Metro.png"

PLUGIN.UsePlayerModelPhoto = true

PLUGIN.PassportPhotoRect = { x = 30, y = 300, w = 100, h = 200 }     -- Foto/Modelo
PLUGIN.PassportStampRect = { x = 220, y = 30, w = 128, h = 128 }    -- Sello

PLUGIN.PassportFields = {
    { key = "fullName",     label = "Nombre completo",     x = 115, y = 180 },
    { key = "nationality",  label = "Nacionalidad",        x = 170, y = 205 },
    { key = "citizenship",  label = "Ciudadanía",          x = 145, y = 226 },
    { key = "residence",    label = "Lugar de residencia", x = 224, y = 270 },
    { key = "issuedBy",     label = "Emitido por",         x = 180, y = 473 },
    { key = "issuedWhere",  label = "Lugar de emisión",    x = 190, y = 290 },
    { key = "issuedWhen",   label = "Fecha de emisión",    x = 35, y = 335 },
    { key = "birth",        label = "Fecha de nacimiento", x = 190, y = 365 },
}

PLUGIN.PassportFont = "ixPassportFont"

PLUGIN.StampsFolder = "metro/stamp/"


PLUGIN.Stamps = {
    "metro/stamp/alliance.png",
    "metro/stamp/bylvar.png",
    "metro/stamp/terra_nova.png",
    "metro/stamp/cult.png",
    "metro/stamp/factory.png",
    "metro/stamp/hanza.png",
    "metro/stamp/kitau.png",
    "metro/stamp/kyzna.png",
    "metro/stamp/laboratory.png",
    "metro/stamp/nnig.png",
    "metro/stamp/polis.png",
    "metro/stamp/redline.png",
    "metro/stamp/reich.png",
    "metro/stamp/trotskyists.png",
    "metro/stamp/vdnh.png"
}

PLUGIN.ShowDuration = 10
PLUGIN.LookDistance = 128

-- Radio en el que la impresora de pasaportes puede elegir a otra persona
-- (delante o cerca del emisor) como destinataria del pasaporte impreso.
PLUGIN.PrintTargetRadius = 200

-- El servidor calcula las caducidades con os.time() (hora real), pero la trama
-- se ambienta en 2028. Se suman estos años a toda fecha de caducidad emitida
-- para que los documentos reflejen el año en el que se rolea.
PLUGIN.RoleplayYearOffset = 2

-----------------------------------------------------------------
-- INSPECCIÓN: firma automática por facción y control de acceso
-----------------------------------------------------------------
-- Solo estas facciones (por uniqueID) pueden aprobar/denegar en la mesa de
-- inspección, y cada una sella con SU propio sello. El uniqueID es el nombre del
-- archivo de facción sin prefijo: schema/factions/sh_<uniqueID>.lua.
PLUGIN.InspectorStamps = {
    polis       = "polis.png",
    hanza       = "hanza.png",
    linearoja   = "redline.png",
    cuartoreich = "reich.png",
    ranger      = "polis.png",
}

-- El Staff también puede firmar; usa este sello neutral de aprobación.
PLUGIN.StaffStamp = "aprobado.png"

-- Sello de rechazo (denegado) común a todas las facciones.
PLUGIN.DeniedStamp = "denegado.png"

-- Nación asociada a cada facción de control (la usa el motor de reglas para
-- comprobar naciones permitidas/vetadas y ciudades emisoras válidas).
PLUGIN.FactionNations = {
    polis       = "Polis",
    hanza       = "Hanza",
    linearoja   = "Redline",
    cuartoreich = "Reich",
    ranger      = "Polis",
}

-- ¿El jugador pertenece a una facción autorizada para rellenar documentos?
function PLUGIN:CanEditDocument(ply)
	if (not IsValid(ply)) then return false end
	local faction = ix.faction.indices[ply:Team()]
	local uid = faction and faction.uniqueID or ""
	if (self.InspectorStamps[uid]) then return true end
	if (uid == "staff") then return true end
	return false
end

-- Multas por una decisión equivocada del inspector (en Balas). Se puede ajustar
-- por boletín en sh_rules.lua; estos son los valores por defecto.
PLUGIN.CitationFine = { minor = 5, major = 15 }

-- Multi-page passport configuration
PLUGIN.MultiPagePassport = {
    MaxPages = 50, -- Maximum number of pages allowed
    DefaultPages = 3, -- Default pages when creating new passport
    AllowCustomStamps = true, -- Allow custom station stamps
    MaxStampsPerPage = 2, -- Maximum number of entry/exit stamps per page
    StampTypes = {
        "entry", -- Entry stamp
        "exit",  -- Exit stamp
        "transit" -- Transit stamp
    },
    StationStampTemplate = "metro/stamp/entry.png", -- Default station stamp texture
    PageBackground = "metro/passport_page.png" -- Background texture for additional pages
}

PLUGIN.FaceFOV = 16
PLUGIN.FaceDistanceScale = 1
PLUGIN.FaceUpOffset    = 0
PLUGIN.FaceRightOffset = 0
PLUGIN.FaceForwardOffset = 0

-- Document validation system
PLUGIN.DocumentValidation = {
    -- Required documents by nationality
    RequiredDocuments = {
        ["Arstotzka"] = {"passport", "id_card"},
        ["Foreign"] = {"passport", "entry_permit"}
    },

    -- Additional requirements based on purpose
    PurposeRequirements = {
        ["Work"] = {"work_pass"},
        ["Diplomatic"] = {"diplomatic_id"},
        ["Transit"] = {"transit_permit"},
        ["HighSecurity"] = {"access_ticket"},
        ["Outbreak"] = {"vaccine_documents"}
    },

    -- Document expiration checks
    CheckExpiration = true,
    ExpirationWarningDays = 7,

    -- Validation rules
    Rules = {
        RequireValidID = true,
        RequireValidPassport = true,
        CheckDocumentConsistency = true,
        RequireRecentPhoto = true
    }
}
