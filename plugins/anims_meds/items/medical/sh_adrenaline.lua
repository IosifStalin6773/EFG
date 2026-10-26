
ITEM.name = "Inyector de adrenalina"
ITEM.weight = 0.1
ITEM.description = "Inyección que acelera el cuerpo y aplica curación temporal."
ITEM.model = "models/weapons/sweps/eft/injector/w_meds_injector.mdl"
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

        local medId = "adrenaline"
        local cfg = ix.eftMeds.Get(medId) or {
            swepClass = "weapon_eft_injectoradrenaline",
            ammoType = "injectoradrenaline",
            startFunc = "StartInjectorSequence"
        }

        local wep = ix.eftMeds.GiveAndSelectMedWep(ply, cfg.swepClass, item)
        if SERVER then ply:GiveAmmo(1, cfg.ammoType, true) end

        local duration = (PLUGIN and PLUGIN.ActionDuration) or 10.0
        ix.eftMeds.StartMedSequence(wep, cfg.startFunc, duration)
        ply:SetAction("Inyectando adrenalina...", duration)

        timer.Simple(duration, function()
            if not IsValid(ply) then return end
            item:SetUses(uses - 1)
            ix.eftMeds.CleanupMedUse(ply, cfg.swepClass, cfg.ammoType, item)
        end)

        return item:GetUses() <= 0
    end
}
