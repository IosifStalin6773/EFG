
ITEM.name = "Antibiótico"
ITEM.weight = 0.05
ITEM.description = "Antibiótico que otorga tenacidad y reduce el dolor temporalmente."
ITEM.model = "models/weapons/sweps/eft/augmentin/w_meds_augmentin.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Medicamentos"
ITEM.maxUses = 5

function ITEM:GetUses() return self:GetData("uses", self.maxUses) end
function ITEM:SetUses(n) self:SetData("uses", math.max(n, 0)) end

ITEM.functions.Take = {
    name = "Tomar",
    icon = "icon16/pill.png",
    OnRun = function(item)
        local ply = item.player
        if not IsValid(ply) then return false end

        local uses = item:GetUses()
        if uses <= 0 then
            if ply.Notify then ply:Notify("No quedan tabletas.") end
            return false
        end

        local medId = "augmentin"
        local cfg = ix.eftMeds.Get(medId) or {
            swepClass = "weapon_eft_augmentin",
            ammoType = "augmentin",
            startFunc = "StartPillsSequence"
        }

        local wep = ix.eftMeds.GiveAndSelectMedWep(ply, cfg.swepClass, item)
        if SERVER then ply:GiveAmmo(1, cfg.ammoType, true) end

        local duration = (PLUGIN and PLUGIN.ActionDuration) or 10.0
        ix.eftMeds.StartMedSequence(wep, cfg.startFunc, duration)
        ply:SetAction("Tomando antibiótico...", duration)

        timer.Simple(duration, function()
            if not IsValid(ply) then return end
            item:SetUses(uses - 1)
            ix.eftMeds.CleanupMedUse(ply, cfg.swepClass, cfg.ammoType, item)
        end)

        return item:GetUses() <= 0
    end
}
