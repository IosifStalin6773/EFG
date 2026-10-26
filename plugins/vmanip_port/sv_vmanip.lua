

util.AddNetworkString("VManip_SimplePlay")
util.AddNetworkString("VManip_StopHold")

function PLUGIN:VManipPlay(ply, anim)
    if IsValid(ply) and isstring(anim) then
        net.Start("VManip_SimplePlay")
        net.WriteString(anim)
        net.Send(ply)
    end
end

function PLUGIN:VManipStopHold(ply, anim)
    if IsValid(ply) then
        net.Start("VManip_StopHold")
        net.WriteString(anim or "")
        net.Send(ply)
    end
end
