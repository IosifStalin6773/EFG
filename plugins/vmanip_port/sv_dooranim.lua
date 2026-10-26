
local PLUGIN = PLUGIN


if not ConVarExists("vmanip_dooranim_hybridanim") then
    CreateConVar("vmanip_dooranim_hybridanim", "1", FCVAR_ARCHIVE)
end
if not ConVarExists("vmanip_dooranim_screenbob") then
    CreateConVar("vmanip_dooranim_screenbob", "1", FCVAR_ARCHIVE)
end

function PLUGIN:PlayerUse(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end

    local class = ent:GetClass()
    if class ~= "prop_door_rotating" and class ~= "func_door_rotating" then return end
    if ent:GetInternalVariable("m_bLocked") then return end 

    local usedoorcooldown = ply.usedoorcooldown or 0
    if not ply:KeyPressed(IN_USE) then return end
    if CurTime() <= usedoorcooldown or ent.LFS then return end 

    ply.usecooldown     = CurTime() + 1
    ply.usedoorcooldown = CurTime() + 0.5

    -- Sonido opcional (asegúrate de tener estos wav)
    ply:EmitSound("weapons/vmanip_usedoor" .. tostring(math.random(1, 2)) .. ".wav")

    -- Lógica "híbrida": decide anim según lado del jugador y estado de puerta
    local anim = "usedoor"
    if GetConVar("vmanip_dooranim_hybridanim"):GetBool() then
        local doorState   = ent:GetSaveTable().m_eDoorState -- 1/2 = cerrando (según script original)
        local doorToLocal = ent:WorldToLocal(ply:GetPos())

        -- Mantenemos el criterio del script: en el lado "derecho" y cerrando => "vault"
        if doorToLocal.y <= 0 and (doorState == 1 or doorState == 2) then
            anim = "vault"
        else
            anim = "usedoor"
        end
    end

    -- Dispara la anim en el cliente del jugador
    self:VManipPlay(ply, anim)

    -- Bob de cámara opcional
    if IsValid(ply:GetActiveWeapon()) and GetConVar("vmanip_dooranim_screenbob"):GetBool() then
        local wpn = ply:GetActiveWeapon():GetClass()
        if string.find(wpn, "mg_") then
            ply:ViewPunch(Angle(1.5, 0, -3.3))
        else
            ply:ViewPunch(Angle(0.5, 0, -2))
        end
    end
end