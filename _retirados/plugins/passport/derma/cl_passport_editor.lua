local PLUGIN = PLUGIN

local function scaleXY(x, y, drawW, drawH)
    return x * drawW / PLUGIN.PassportBaseW, y * drawH / PLUGIN.PassportBaseH
end

local function scaleRect(r, drawW, drawH)
    local x, y = scaleXY(r.x, r.y, drawW, drawH)
    local w = r.w * drawW / PLUGIN.PassportBaseW
    local h = r.h * drawH / PLUGIN.PassportBaseH
    return x, y, w, h
end

-- Cámara clavada a ojos/cabeza para que SOLO se vea la cara.
local function ApplyFaceCamera(panel, ent)
    if not IsValid(panel) or not IsValid(ent) then return end

    local lookPos, lookAng

    local attId = ent:LookupAttachment("eyes") or -1
    if attId > 0 then
        local t = ent:GetAttachment(attId)
        if t and t.Pos then
            lookPos = t.Pos
            lookAng = t.Ang or Angle(0,0,0)
        end
    end

    if not lookPos then
        local headBone = ent:LookupBone("ValveBiped.Bip01_Head1") or ent:LookupBone("Head")
        if headBone then
            local p = ent:GetBonePosition(headBone)
            lookPos = p or Vector(0,0,60)
            lookAng = Angle(0,0,0)
        end
    end

    if not lookPos then
        local mn, mx = ent:GetModelBounds()
        lookPos = Vector(0, 0, (mn.z + mx.z) * 0.6)
        lookAng = Angle(0,0,0)
    end

    local mn, mx = ent:GetModelBounds()
    local height = math.max(1, (mx.z - mn.z))
    local dist = height * (PLUGIN.FaceDistanceScale or 0.18)

    local upOff    = PLUGIN.FaceUpOffset or 0
    local rightOff = PLUGIN.FaceRightOffset or 0
    local fwdOff   = PLUGIN.FaceForwardOffset or 0

    -- La cámara se coloca DELANTE de la cara (forward positivo): el "forward" del
    -- attachment "eyes" apunta hacia donde mira el personaje, así que sumamos para
    -- mirar la cara. (Antes usaba -(dist), que dejaba la cámara detrás de la cabeza
    -- y por eso se veía de espaldas.)
    local ang = lookAng or Angle(0,0,0)
    local camPos = lookPos
        + ang:Forward() * (dist + fwdOff)
        + ang:Up()      * (upOff)
        + ang:Right()   * (rightOff)

    panel:SetLookAt(lookPos)
    panel:SetCamPos(camPos)
    panel:SetFOV(PLUGIN.FaceFOV or 16)
end

-- Jugadores candidatos para fotografiar: al que miras y los que están en un
-- radio cercano (para poder elegir sin tener que apuntar exactamente).
local function FindNearbyTargets()
    local me = LocalPlayer()
    local candidates = {}
    local radius = PLUGIN.PrintTargetRadius or 200

    local tr = me:GetEyeTraceNoCursor()
    if (IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity != me) then
        candidates[#candidates + 1] = tr.Entity
    end

    for _, other in ipairs(player.GetAll()) do
        if (other != me and IsValid(other) and other:Alive() and not table.HasValue(candidates, other)) then
            if (me:GetPos():DistToSqr(other:GetPos()) <= (radius * radius)) then
                candidates[#candidates + 1] = other
            end
        end
    end

    return candidates
end

local templateMat
local PANEL = {}

function PANEL:Init()
    self:SetTitle("Impresora de Pasaportes")
    self:SetSize(880, 560)
    self:Center()
    self:MakePopup()

    self.targetPly = LocalPlayer()
    self.nearbyTargets = FindNearbyTargets()

    templateMat = Material(PLUGIN.PassportTemplate, "smooth")

    -- Preview con la plantilla manteniendo el aspect ratio
    self.left = self:Add("DPanel")
    self.left:Dock(LEFT)
    self.left:SetWide(520)
    self.left.Paint = function(_, w, h)
        surface.SetDrawColor(255,255,255)
        surface.SetMaterial(templateMat)
        surface.DrawTexturedRect(0, 0, w, h)

        -- Sello
        if (self.selectedStamp and self.selectedStamp.mat) then
            local sx, sy, sw, sh = scaleRect(PLUGIN.PassportStampRect, w, h)
            surface.SetMaterial(self.selectedStamp.mat)
            surface.DrawTexturedRect(sx, sy, sw, sh)
        end

        -- Texto
        surface.SetFont(PLUGIN.PassportFont)
        surface.SetTextColor(40, 30, 10, 255)
        for _, f in ipairs(PLUGIN.PassportFields) do
            local tx, ty = scaleXY(f.x, f.y, w, h)
            local v = self.values[f.key] or ""
            surface.SetTextPos(tx, ty)
            surface.DrawText(v)
        end
    end

    function self:PerformLayout(w, h)
        local aspect = PLUGIN.PassportBaseW / PLUGIN.PassportBaseH
        local newLeftW = math.floor(h * aspect)
        newLeftW = math.Clamp(newLeftW, 300, w - 260)
        self.left:SetWide(newLeftW)
    end

    self.values = {}

    -- Panel de controles
    self.right = self:Add("DScrollPanel")
    self.right:Dock(FILL)
    self.right:DockMargin(8, 0, 0, 0)

    local title = self.right:Add("DLabel")
    title:SetText("Rellena los datos:")
    title:SetFont("ixPassportUI")
    title:Dock(TOP)
    title:DockMargin(0, 0, 0, 4)

    -- Elegir a quién se le imprime el pasaporte: uno mismo o alguien delante/cerca.
    self.fieldWidgets = {}

    do
        local targetLabel = self.right:Add("DLabel")
        targetLabel:SetText("Persona a fotografiar/registrar:")
        targetLabel:SetFont("ixPassportUI")
        targetLabel:Dock(TOP)
        targetLabel:DockMargin(0, 0, 0, 0)

        local targetCombo = self.right:Add("DComboBox")
        targetCombo:Dock(TOP)
        targetCombo:SetFont("ixPassportUI")

        local meChar = LocalPlayer():GetCharacter()
        local selfIndex = targetCombo:AddChoice("Yo mismo (" .. (meChar and meChar:GetName() or LocalPlayer():Name()) .. ")", LocalPlayer())
        targetCombo:SetValue(targetCombo:GetOptionText(selfIndex))

        for _, ply in ipairs(self.nearbyTargets) do
            local plyChar = ply:GetCharacter()
            targetCombo:AddChoice(plyChar and plyChar:GetName() or ply:Name(), ply)
        end

        -- Si hay alguien delante mirando, seleccionarlo por defecto en vez de a uno mismo.
        if (self.nearbyTargets[1]) then
            self.targetPly = self.nearbyTargets[1]
            local plyChar = self.targetPly:GetCharacter()
            targetCombo:SetValue(plyChar and plyChar:GetName() or self.targetPly:Name())
        end

        targetCombo.OnSelect = function(_, _, _, data)
            if (not IsValid(data)) then return end
            self.targetPly = data

            local widget = self.fieldWidgets.fullName
            local dataChar = data:GetCharacter()
            if (IsValid(widget)) then
                local name = dataChar and dataChar:GetName() or data:Name()
                widget:SetText(name)
                self.values.fullName = name
            end

            if (IsValid(self.modelPanel)) then
                self.modelPanel:InvalidateLayout(true)
                self.left:InvalidateLayout(true)
            end
        end
    end

    -- Detectar facción del jugador para ofrecer ciudades emisoras
    local myFaction = ix.faction.indices[LocalPlayer():Team()]
    local myFactionUID = myFaction and myFaction.uniqueID or ""
    local myNation = PLUGIN.FactionNations and PLUGIN.FactionNations[myFactionUID] or ""
    local myCities = (myNation != "" and PLUGIN.ValidIssuingCities and PLUGIN.ValidIssuingCities[myNation]) or {}

    for _, f in ipairs(PLUGIN.PassportFields) do
        local label = self.right:Add("DLabel")
        label:SetText(f.label)
        label:SetFont("ixPassportUI")
        label:Dock(TOP)
        label:DockMargin(0, 6, 0, 0)

        if (f.key == "issuedWhere" and #myCities > 0) then
            -- Combo con ciudades de la facción + campo libre
            local combo = self.right:Add("DComboBox")
            combo:Dock(TOP)
            combo:SetFont("ixPassportUI")
            for _, city in ipairs(myCities) do
                combo:AddChoice(city)
            end
            combo:AddChoice("— Escribir manualmente —", "_custom")
            combo.OnSelect = function(_, _, val, data)
                if (data == "_custom") then
                    Derma_StringRequest("Lugar de emisión", "Escribe el lugar:", "", function(text)
                        self.values[f.key] = text
                        combo:SetValue(text)
                    end)
                else
                    self.values[f.key] = val
                end
            end

        elseif (f.key == "nationality") then
            -- Nacionalidades reales
            local combo = self.right:Add("DComboBox")
            combo:Dock(TOP)
            combo:SetFont("ixPassportUI")
            local nations = {
                "Rusa", "Ucraniana", "Bielorrusa", "Kazaja", "Georgiana",
                "Armenia", "Azerbaiyana", "Uzbeka", "Turkmena", "Moldava",
                "Letona", "Lituana", "Estonia", "Polaca", "Alemana",
                "Checa", "Húngara", "Rumana", "Búlgara", "China"
            }
            for _, n in ipairs(nations) do
                combo:AddChoice(n)
            end
            combo:AddChoice("— Escribir manualmente —", "_custom")
            combo:SetValue("Rusa")
            self.values[f.key] = "Rusa"
            combo.OnSelect = function(_, _, val, data)
                if (data == "_custom") then
                    Derma_StringRequest("Nacionalidad", "Escribe la nacionalidad:", "", function(text)
                        self.values[f.key] = text
                        combo:SetValue(text)
                    end)
                else
                    self.values[f.key] = val
                end
            end

        elseif (f.key == "issuedBy") then
            -- Emitido por: autorellenar con nombre del jugador
            local entry = self.right:Add("DTextEntry")
            entry:Dock(TOP)
            entry:SetFont("ixPassportUI")
            local char = LocalPlayer():GetCharacter()
            entry:SetText(char and char:GetName() or LocalPlayer():Name())
            self.values[f.key] = entry:GetText()
            entry.OnChange = function(te)
                self.values[f.key] = te:GetText()
            end

        else
            local entry = self.right:Add("DTextEntry")
            entry:Dock(TOP)
            entry:SetFont("ixPassportUI")
            entry.OnChange = function(te)
                self.values[f.key] = te:GetText()
            end

            if (f.key == "fullName") then
                self.fieldWidgets.fullName = entry
                local targetChar = self.targetPly and self.targetPly:GetCharacter()
                local name = targetChar and targetChar:GetName() or (IsValid(self.targetPly) and self.targetPly:Name() or "")
                entry:SetText(name)
                self.values.fullName = name
            end
        end
    end

    -- Sello asignado automáticamente por facción (no se elige a mano)
    local stampFile = PLUGIN.InspectorStamps and PLUGIN.InspectorStamps[myFactionUID] or ""
    if (stampFile != "") then
        local stampPath = PLUGIN.StampsFolder .. stampFile
        self.selectedStamp = { name = stampFile, rel = stampPath, mat = Material(stampPath, "smooth") }

        local stampLabel = self.right:Add("DLabel")
        stampLabel:SetText("Sello de emisión: " .. string.upper(string.StripExtension(stampFile)))
        stampLabel:SetFont("ixPassportUI")
        stampLabel:Dock(TOP)
        stampLabel:DockMargin(0, 8, 0, 0)
    else
        self.selectedStamp = nil

        local stampLabel = self.right:Add("DLabel")
        stampLabel:SetText("Tu facción no tiene sello asignado.")
        stampLabel:SetFont("ixPassportUI")
        stampLabel:Dock(TOP)
        stampLabel:DockMargin(0, 8, 0, 0)
    end

    local info = self.right:Add("DLabel")
    info:SetText("La foto muestra la CARA de la persona seleccionada arriba.")
    info:SetFont("ixPassportUI")
    info:Dock(TOP)
    info:DockMargin(0, 8, 0, 0)

    local btn = self.right:Add("DButton")
    btn:Dock(TOP)
    btn:DockMargin(0, 12, 0, 0)
    btn:SetText("Imprimir")
    btn:SetFont("ixPassportUI")
    btn.DoClick = function()
        if (not IsValid(self.PrinterEntity)) then
            chat.AddText(Color(255,80,80), "[Pasaporte] ", color_white, "La impresora ya no está disponible.")
            self:Close()
            return
        end

        if (not IsValid(self.targetPly)) then
            chat.AddText(Color(255,80,80), "[Pasaporte] ", color_white, "La persona seleccionada ya no está disponible.")
            return
        end

        local targetChar = self.targetPly:GetCharacter()
        local data = {
            fields = self.values,
            stamp = self.selectedStamp and self.selectedStamp.name or "",
            ownerSteamID64 = self.targetPly:SteamID64(),
            ownerName = targetChar and targetChar:GetName() or self.targetPly:Name(),
            issuedBy = LocalPlayer():Name()
        }

        net.Start("ix.passport.RequestPrint")
            net.WriteTable(data)
            net.WriteEntity(self.PrinterEntity)
            net.WriteEntity(self.targetPly)
        net.SendToServer()

        self:Close()
    end

    -- DModelPanel con CARA de la persona seleccionada
    if PLUGIN.UsePlayerModelPhoto then
        self.modelPanel = self.left:Add("DModelPanel")
        self.modelPanel:SetModel((IsValid(self.targetPly) and self.targetPly:GetModel()) or "")
        self.modelPanel:SetMouseInputEnabled(false)
        self.modelPanel.LayoutEntity = function() end -- sin rotación

        -- Posición exacta en la zona de foto
        self.left.PerformLayout = function(pnl, w, h)
            local px, py, pw, ph = scaleRect(PLUGIN.PassportPhotoRect, w, h)
            self.modelPanel:SetPos(px, py)
            self.modelPanel:SetSize(pw, ph)

            local target = self.targetPly
            if (not IsValid(target)) then return end

            if (self._modelSetFor != target) then
                self.modelPanel:SetModel(target:GetModel() or "")
                self._modelSetFor = target
            end

            local ent = self.modelPanel:GetEntity()
            if IsValid(ent) then
                ent:SetSkin(target:GetSkin() or 0)
                for _, bg in ipairs(target:GetBodyGroups() or {}) do
                    ent:SetBodygroup(bg.id, target:GetBodygroup(bg.id) or 0)
                end
                ApplyFaceCamera(self.modelPanel, ent)
            end
        end
    end
end

-- Registro diferido (ixFrame -> DFrame)
local function registerPassportEditor()
    if vgui.GetControlTable("ixFrame") then
        vgui.Register("ixPassportEditor", PANEL, "ixFrame")
    else
        vgui.Register("ixPassportEditor", PANEL, "DFrame")
    end
end

timer.Simple(0, registerPassportEditor)
hook.Add("LoadedLocalSchema", "passport_register_ixPanels", registerPassportEditor)

net.Receive("ix.passport.OpenEditor", function()
    local ent = net.ReadEntity()
    local frame = vgui.Create("ixPassportEditor")
    frame.PrinterEntity = ent
end)