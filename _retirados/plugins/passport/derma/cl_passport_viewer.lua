local PLUGIN = PLUGIN
local templateMat

-- IMPORTANTE: las dimensiones base del pasaporte (PassportBaseW/H) y las
-- coordenadas de los campos viven en libs/sh_config.lua (800x534). NO las
-- redefinas aquí: al cargarse libs/ antes que derma/, sobrescribir estos valores
-- aquí descuadraría todos los campos sobre el PNG.

local function scaleXY(x, y, w, h)
    return x * w / PLUGIN.PassportBaseW, y * h / PLUGIN.PassportBaseH
end

local function scaleRect(r, w, h)
    local x, y = scaleXY(r.x, r.y, w, h)
    local rw = r.w * w / PLUGIN.PassportBaseW
    local rh = r.h * h / PLUGIN.PassportBaseH
    return x, y, rw, rh
end

-- === CÁMARA DE LA CARA (igual que ya tenías) ===
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

    local upOff    = PLUGIN.FaceUpOffset or 2
    local rightOff = PLUGIN.FaceRightOffset or 0
    local fwdOff   = PLUGIN.FaceForwardOffset or 0

    -- La cámara se coloca DELANTE de la cara (forward positivo); antes usaba -(dist)
    -- y por eso la foto mostraba la nuca.
    local ang = lookAng or Angle(0,0,0)
    local camPos = lookPos
        + ang:Forward() * (dist + fwdOff)
        + ang:Up()      * (upOff)
        + ang:Right()   * (rightOff)

    panel:SetLookAt(lookPos)
    panel:SetCamPos(camPos)
    panel:SetFOV(PLUGIN.FaceFOV or 14)
end

-- =======================
-- PANEL “COVER” COMPLETO
-- =======================
local PANEL = {}

function PANEL:Init()
    self:SetTitle("Pasaporte")

    -- Tamaño inicial del frame (puedes cambiarlo). El contenido se adaptará.
    self:SetSize(900, 600)
    self:Center()
    self:MakePopup()

    templateMat = Material(PLUGIN.PassportTemplate, "smooth")

    -- El contenedor izquierdo ahora será TODO el contenido (sin reserva a la derecha).
    self.left = self:Add("DPanel")
    self.left:Dock(FILL)  -- <<< Llena todo el frame

    -- DModelPanel para la foto
    self.modelPanel = self.left:Add("DModelPanel")
    self.modelPanel:SetMouseInputEnabled(false)
    self.modelPanel.LayoutEntity = function() end
    self.modelPanel:SetPaintedManually(true) -- lo pintamos con scissor en Paint

    -- PINTURA: Fondo en modo COVER + sellos + campos + foto con recorte
    self.left.Paint = function(_, w, h)
        -- 1) Dibujo del fondo del pasaporte en modo COVER (llenar todo el panel sin distorsionar)
        local baseW, baseH = PLUGIN.PassportBaseW, PLUGIN.PassportBaseH
        local panelAspect = w / h
        local imgAspect   = baseW / baseH  -- 621/447

        local drawW, drawH
        if panelAspect > imgAspect then
            -- El panel es "más ancho" que la imagen -> expandir ancho, recortar arriba/abajo
            drawW = w
            drawH = math.floor(w / imgAspect)
        else
            -- El panel es "más alto" que la imagen -> expandir alto, recortar lados
            drawH = h
            drawW = math.floor(h * imgAspect)
        end

        -- Centramos el área dibujada para recortar por ambos lados de forma uniforme
        local ox = math.floor((w - drawW) / 2)
        local oy = math.floor((h - drawH) / 2)

        surface.SetDrawColor(255,255,255)
        surface.SetMaterial(templateMat)
        surface.DrawTexturedRectUV(ox, oy, drawW, drawH, 0, 0, 1, 1)

        -- 2) Sellos y campos (coordenadas relativas a la base 621×447)
        --    Para que caigan en su sitio, necesitamos transformar los rects a la zona “drawn”
        local function drawScaleRect(rect)
            -- Convertimos rect (base) a píxeles en el área dibujada “cover”
            local rx = ox + rect.x * drawW / baseW
            local ry = oy + rect.y * drawH / baseH
            local rw = rect.w * drawW / baseW
            local rh = rect.h * drawH / baseH
            return rx, ry, rw, rh
        end
        local function drawScaleXY(x, y)
            local rx = ox + x * drawW / baseW
            local ry = oy + y * drawH / baseH
            return rx, ry
        end

        -- Sello
        if self.stampMat then
            local sx, sy, sw, sh = drawScaleRect(PLUGIN.PassportStampRect)
            surface.SetMaterial(self.stampMat)
            surface.DrawTexturedRectUV(sx, sy, sw, sh, 0, 0, 1, 1)
        end

        -- Campos
        if self.fields then
            surface.SetFont(PLUGIN.PassportFont)
            surface.SetTextColor(40,30,10,255)
            for _, f in ipairs(PLUGIN.PassportFields) do
                local tx, ty = drawScaleXY(f.x, f.y)
                surface.SetTextPos(tx, ty)
                surface.DrawText(self.fields[f.key] or "")
            end
        end

        -- 3) Foto: colocamos el DModelPanel según el rect escalado y lo recortamos (scissor)
        do
            local px, py, pw, ph = drawScaleRect(PLUGIN.PassportPhotoRect)
            self.modelPanel:SetPos(px, py)
            self.modelPanel:SetSize(pw, ph)

            local sx, sy = self.modelPanel:LocalToScreen(0, 0)
            local ex, ey = self.modelPanel:LocalToScreen(pw, ph)

            render.SetScissorRect(sx, sy, ex, ey, true)
                self.modelPanel:PaintManual()
            render.SetScissorRect(0, 0, 0, 0, false)
        end
    end

    -- Con cover, no necesitamos forzar ancho de la izquierda.
    -- Pero mantenemos PerformLayout por si añades UI adicional.
    function self:PerformLayout(w, h)
        -- Nada especial que hacer: left = FILL y cover en Paint
    end
end

function PANEL:SetPassportData(data)
    self.fields = data.fields or {}

    local stampName = data.stamp or ""
    if stampName ~= "" then
        self.stampMat = Material(PLUGIN.StampsFolder .. stampName, "smooth")
    end

    local mdl  = data.model or LocalPlayer():GetModel() or ""
    local skin = tonumber(data.skin or 0) or 0
    local bgs  = data.bodygroups or {}

    self.modelPanel:SetModel(mdl)
    local ent = self.modelPanel:GetEntity()
    if IsValid(ent) then
        ent:SetSkin(skin)
        for id, val in pairs(bgs) do
            ent:SetBodygroup(tonumber(id) or id, tonumber(val) or 0)
        end
        ApplyFaceCamera(self.modelPanel, ent)
    end
end

-- Registro
local function registerPassportViewer()
    if vgui.GetControlTable("ixFrame") then
        vgui.Register("ixPassportViewer", PANEL, "ixFrame")
    else
        vgui.Register("ixPassportViewer", PANEL, "DFrame")
    end
end

timer.Simple(0, registerPassportViewer)
hook.Add("LoadedLocalSchema", "passport_register_ixPanels_viewer", registerPassportViewer)

net.Receive("ix.passport.OpenViewer", function()
    local data = net.ReadTable() or {}
    local duration = net.ReadUInt(8) or 10
    local fromName = net.ReadString() or "Jugador"

    local frame = vgui.Create("ixPassportViewer")
    frame:SetTitle(duration > 0 and ("Pasaporte mostrado por " .. fromName) or "Pasaporte")
    frame:SetPassportData(data)

    if duration > 0 then
        timer.Simple(duration, function()
            if IsValid(frame) then frame:Close() end
        end)
    end
end)
