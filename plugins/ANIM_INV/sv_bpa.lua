-- gamemodes/helix/plugins/stalker2_bpa/sv_bpa.lua
if not SERVER then return end

util.AddNetworkString("network_backpack_changestatus")
util.AddNetworkString("ixBPAForceCloseInv")

local SWEP_CLASS = "weapon_stalker2_bpa"

-- Armas de animación de consumibles/medicinas. Cuando el jugador usa uno de
-- estos ítems con el inventario abierto, hay que soltar la mochila para que el
-- arma pueda hacer Deploy y reproducir su animación (antes el switch quedaba
-- bloqueado y solo se veía la mochila).
local ANIM_WEAPONS = {
	["efg_med"]                        = true,
	["weapon_eft_afak"]                = true,
	["weapon_eft_ibuprofen"]           = true,
	["weapon_eft_injectoradrenaline"]  = true,
	["weapon_eft_injectormorphine"]    = true,
	["weapon_eft_augmentin"]           = true,
	["weapon_stalker2_water"]          = true,
	["weapon_stalker2_bread"]          = true,
	["weapon_stalker2_canned"]         = true,
	["weapon_stalker2_vodka"]          = true,
	["weapon_stalker2_energy"]         = true,
	["weapon_stalker2_milk"]           = true,
	["weapon_stalker2_sausage"]        = true,
}

-- Timer unificado para cierres desde sv_bpa.lua; sh_swep_bpa.lua usa
-- "TimerSecondaryHolster_N" — también se cancela en CancelAllBPATimers.
local function GetCloseTimer(ply)
    return "BPA_CloseHolster_" .. ply:EntIndex()
end

-- Con spam rápido se creaban timers con 3 nombres distintos (SecondaryHolster,
-- RemoveBackpack, FallbackBackpack). El open solo cancelaba uno → los demás
-- disparaban y tiraban BPA mientras el inventario seguía abierto.
local function CancelAllBPATimers(ply)
    local idx = ply:EntIndex()
    timer.Remove("TimerSecondaryHolster_" .. idx)
    timer.Remove("TimerRemoveBackpack_"   .. idx)
    timer.Remove("TimerFallbackBackpack_" .. idx)
    timer.Remove(GetCloseTimer(ply))
end

-- Bloquear cambio de arma mientras la mochila está abierta:
-- al equipar un arma desde el inventario, Helix llama SelectWeapon,
-- lo que sacaría al jugador de la BPA. Solo permitimos cambiar A la BPA.
hook.Add("PlayerSwitchWeapon", "BPA_BlockEquipSwitch", function(ply, oldWep, newWep)
	if (not ply.BPAIsOpen or not IsValid(newWep)) then return end

	local class = newWep:GetClass()
	if (class == SWEP_CLASS) then return end -- permitir cambiar A la mochila

	-- Arma de animación (comida/medicina): soltar la mochila y cerrar el
	-- inventario para que el arma pueda desplegarse y reproducir su animación.
	if (ANIM_WEAPONS[class]) then
		ply.BPAIsOpen = false
		ply.StalkerBPPrevWeapon = nil
		CancelAllBPATimers(ply)
		ply:SetNWBool("ixAnimInvOpen", false)

		-- Stripear la mochila en el siguiente frame para no interrumpir este switch.
		timer.Simple(0, function()
			if (IsValid(ply) and ply:HasWeapon(SWEP_CLASS)) then
				ply:StripWeapon(SWEP_CLASS)
			end
		end)

		net.Start("ixBPAForceCloseInv")
		net.Send(ply)
		return -- no bloquear el switch
	end

	return true -- bloquear cualquier otro cambio mientras la mochila está abierta
end)

net.Receive("network_backpack_changestatus", function(_, ply)
    if not (IsValid(ply) and ply:Alive()) then return end

    local isopen = net.ReadBool()
    local wpn = ply:GetActiveWeapon()
    local vm = ply:GetViewModel()

    -- NW var: cada cliente la lee para reproducir el gesto en bucle
    -- mientras el jugador tenga el inventario/mochila abiertos.
    ply:SetNWBool("ixAnimInvOpen", isopen)

    -- Guarda el arma previa la primera vez
    if ply.StalkerBPPrevWeapon == nil and IsValid(wpn) and wpn:GetClass() != SWEP_CLASS then
        ply.StalkerBPPrevWeapon = wpn:GetClass()
    end

    if isopen == true then
        -- Abrir: cancelar TODOS los timers de cierre pendientes (4 nombres posibles).
        ply.BPAIsOpen = true
        CancelAllBPATimers(ply)

        if IsValid(wpn) and wpn:GetClass() == SWEP_CLASS then
            if wpn.Deploy then wpn:Deploy() end
        else
            ply:Give(SWEP_CLASS)
            ply:SelectWeapon(SWEP_CLASS)
        end
        return
    end

    -- Cerrar: marcar estado antes de llamar a PrimaryAttack
    ply.BPAIsOpen = false

    if IsValid(wpn) and wpn:GetClass() == SWEP_CLASS then
        if wpn.PrimaryAttack then
            wpn:PrimaryAttack() -- animación + strip + restore via timer en sh_swep_bpa.lua
        else
            -- Fallback sin animación
            local prev = ply.StalkerBPPrevWeapon
            ply.StalkerBPPrevWeapon = nil
            CancelAllBPATimers(ply)
            if not IsValid(ply:GetWeapon("ix_hands")) then ply:Give("ix_hands") end
            ply:SelectWeapon(prev or "ix_hands")
            timer.Simple(0, function()
                if IsValid(ply) then ply:StripWeapon(SWEP_CLASS) end
            end)
        end
        return
    end

    -- SelectWeapon al abrir es asíncrono: el arma activa puede no ser BPA aún.
    -- Usamos GetCloseTimer para que el siguiente open lo cancele con certeza.
    -- Guard BPAIsOpen impide que dispare si el jugador re-abrió antes.
    local seqDur = 0.5
    if IsValid(vm) then
        local d = vm:SequenceDuration(vm:GetSequence())
        if d and d > 0 then seqDur = d end
    end

    timer.Create(GetCloseTimer(ply), seqDur, 1, function()
        if not (IsValid(ply) and ply:Alive()) then return end
        if ply.BPAIsOpen then return end
        local prev = ply.StalkerBPPrevWeapon
        ply.StalkerBPPrevWeapon = nil

        -- Strip la mochila si aún la tiene
        if ply:HasWeapon(SWEP_CLASS) then
            ply:StripWeapon(SWEP_CLASS)
        end

        -- Solo restaurar el arma previa si el jugador no cambió manualmente
        local activeWep = ply:GetActiveWeapon()
        local needsRestore = not IsValid(activeWep) or activeWep:GetClass() == SWEP_CLASS or activeWep:GetClass() == "ix_hands"
        if (needsRestore and prev and IsValid(ply:GetWeapon(prev))) then
            ply:SelectWeapon(prev)
        end
    end)
end)