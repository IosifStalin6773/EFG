
ITEM.name = "Inyector de morfina"
ITEM.weight = 0.1
ITEM.description = "Alivia el dolor e incrementa la resistencia temporalmente."
-- modelo del addon de medicinas si está instalado; si no, uno de HL2
ITEM.model = file.Exists("models/weapons/sweps/eft/injector/w_meds_injector.mdl", "GAME") and "models/weapons/sweps/eft/injector/w_meds_injector.mdl" or "models/healthvial.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Medicamentos"
ITEM.maxUses = 1

function ITEM:GetUses() return self:GetData("uses", self.maxUses) end
function ITEM:SetUses(n) self:SetData("uses", math.max(n, 0)) end

ITEM.functions.Use = {
    name = "Inyectar",
    icon = "icon16/pill_go.png",
    OnRun = function(item)
        local ply = item.player
        if not IsValid(ply) then return false end

        local uses = item:GetUses()
        if uses <= 0 then
            if ply.Notify then ply:Notify("El inyector está vacío.") end
            return false
        end

        local medId = "morphine"
        local cfg = ix.eftMeds.Get(medId) or {
            swepClass = "weapon_eft_injectormorphine",
            ammoType = "morphine",
            startFunc = "StartInjectorSequence"
        }

        local wep = ix.eftMeds.GiveAndSelectMedWep(ply, cfg.swepClass, item)
        if SERVER then ply:GiveAmmo(1, cfg.ammoType, true) end

        local duration = (PLUGIN and PLUGIN.ActionDuration) or 10.0 -- fallback si el plugin no expone el valor
        ix.eftMeds.StartMedSequence(wep, cfg.startFunc, duration)
        ply:SetAction("Inyectando morfina...", duration)

        timer.Simple(duration, function()
            if not IsValid(ply) then return end
            item:SetUses(uses - 1)
            ix.eftMeds.CleanupMedUse(ply, cfg.swepClass, cfg.ammoType, item)
        end)

        return item:GetUses() <= 0
    end
}
