local PLUGIN = PLUGIN
PLUGIN.name = "VManip Port"
PLUGIN.author = "Iosif_Stalin"
PLUGIN.description = "Sistema de animaciones de manos/piernas (VManip) disponible como plugin para Helix."

ix.util.Include("sv_vmanip.lua")
ix.util.Include("sv_dooranim.lua")
ix.util.Include("cl_vmanip.lua")
ix.util.Include("cl_anims.lua")

ix.command.Add("VManipPlay", {
    description = "Reproduce una animación de VManip en tu cliente (p. ej. 'use', 'vault').",
    arguments = { ix.type.string },
    OnRun = function(self, ply, anim)
        if (!IsValid(ply)) then return end
        net.Start("VManip_SimplePlay")
        net.WriteString(anim)
        net.Send(ply)
        return "Reproduciendo animación: " .. anim
    end
})

ix.command.Add("VManipStopHold", {
    description = "Suelta el 'hold' de la anim actual o de una concreta.",
    arguments = { bit.bor(ix.type.string, ix.type.optional) },
    OnRun = function(self, ply, anim)
        if (!IsValid(ply)) then return end
        net.Start("VManip_StopHold")
        net.WriteString(anim or "")
        net.Send(ply)
    end
})
