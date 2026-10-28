
ITEM.name = "Ibuprofeno"
ITEM.weight = 0.05
ITEM.description = "Tabletas antiinflamatorias y analgésicas."
-- modelo del addon de medicinas si está instalado; si no, uno de HL2
ITEM.model = file.Exists("models/weapons/sweps/eft/anaglin/w_meds_anaglin.mdl", "GAME") and "models/weapons/sweps/eft/anaglin/w_meds_anaglin.mdl" or "models/props_lab/jar01b.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Medicamentos"
ITEM.maxUses = 4
-- ITEM.base = "base_medical" -- ⚠️ solo si existe ese base en tu set de plugins

function ITEM:GetUses()
    return self:GetData("uses", self.maxUses)
end

function ITEM:SetUses(n)
    self:SetData("uses", math.max(n, 0))
end

ITEM.functions.Use = {
    name = "Tomar",
    tip = "useTip",
    icon = "icon16/pill.png",
    OnRun = function(item)
        local ply = item.player
        if not IsValid(ply) then return false end

        local uses = item:GetUses()
        if uses <= 0 then
            if ply.Notify then ply:Notify("El ibuprofeno está agotado.") end
            return false
        end

        local class = "weapon_eft_ibuprofen"
        local wep = ply:GetWeapon(class)
        if not IsValid(wep) then
            wep = ply:Give(class)
        end

        local prev = ply:GetActiveWeapon()
        if IsValid(prev) and prev:GetClass() ~= class then
            item:SetData("prevWepClass", prev:GetClass())
        end

        -- Entrega “dosis” como munición
        if SERVER then
            -- cada uso consume 1 “ibuprofen”; damos 1 (o los que quieras por uso)
            ply:GiveAmmo(1, "ibuprofen", true)
        end

        -- Sonidos/ritual simple (opcional)
        local function PlayMedsSequence(ply2, list, gap)
            gap = tonumber(gap) or 0.8
            local t = 0
            for _, snd in ipairs(list) do
                timer.Simple(t, function()
                    if IsValid(ply2) then ply2:EmitSound(snd) end
                end)
                t = t + gap
            end
        end

        PlayMedsSequence(ply, {
            "MedsGrizzly.Open",
            "MedsGeneric.Rustle",
            "MedsGeneric.Close"
        }, 1.0)

        -- Seleccionar el arma y arrancar la secuencia
        ply:SelectWeapon(class)
        if IsValid(wep) and wep.StartPillsSequence then
            wep:StartPillsSequence(10.0) -- ⬅️ animación 10s
        end

        -- Barra de acción Helix sincronizada
        local duration = 10.0
        ply:SetAction("Tomando ibuprofeno...", duration)

        timer.Simple(duration, function()
            if not IsValid(ply) then return end

            item:SetUses(uses - 1)

            -- Restaurar arma previa si existía
            local prevClass = item:GetData("prevWepClass")
            if prevClass then
                local prevW = ply:GetWeapon(prevClass)
                if IsValid(prevW) then ply:SelectWeapon(prevClass) end
            end

            -- Eliminar el SWEP y limpiar munición sobrante
            if SERVER then
                if IsValid(ply:GetWeapon(class)) then
                    ply:StripWeapon(class)
                end
                local left = ply:GetAmmoCount("ibuprofen")
                if left > 0 then ply:RemoveAmmo(left, "ibuprofen") end
            end
        end)

        -- Borrar el ítem si ya no quedan usos
        return item:GetUses() <= 0
    end
}
