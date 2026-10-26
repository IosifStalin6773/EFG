-- gamemodes/skeleton/plugins/tabanim/sv_pda_helix.lua

util.AddNetworkString("PDA_Helix_SetState")

local function IsModdedWeapon(wep)
  if not IsValid(wep) then return false end
  return wep.IsTFAWeapon or wep.CW20Weapon or wep.IsFAS2Weapon or wep.ArcCW or wep.ArcticTacRP or wep.ARC9 or false
end

local function PDA_SelectLastWeapon(ply)
  local class = ply.PDA_LastWeaponClass
  if class and class ~= "pda_spawnmenu" and ply:HasWeapon(class) then
    -- Helix exige string aquí (es donde fallaba): net.WriteString(class) en SelectWeapon. [1](https://github.com/NebulousCloud/helix/blob/master/gamemode/core/libs/sh_player.lua)
    ply:SelectWeapon(class)
  end
end

local function StripPDAInstant(ply)
  timer.Remove("PDASWITCH_" .. ply:EntIndex())

  if ply:HasWeapon("pda_spawnmenu") then
    ply:StripWeapon("pda_spawnmenu")
  end

  ply.PDAEquipped    = false
  ply.PDAAnimStarted = nil

  PDA_SelectLastWeapon(ply)
end

net.Receive("PDA_Helix_SetState", function(_, ply)
  if not IsValid(ply) then return end

  local wantEquip = net.ReadBool()
  local noAnim    = net.ReadBool() or false

  if ply:InVehicle() or ply:IsFlagSet(FL_FROZEN) then return end

  if wantEquip then
    -- Guardar SIEMPRE la clase de arma actual como string
    local cur = ply:GetActiveWeapon()
    ply.PDA_LastWeaponClass = IsValid(cur) and cur:GetClass() or nil

    if not ply:HasWeapon("pda_spawnmenu") then
      ply:Give("pda_spawnmenu")
    end

    -- Si el arma actual NO es de un pack “modded”, seleccionamos la PDA
    cur = ply:GetActiveWeapon()
    if not IsModdedWeapon(cur) then
      ply:SelectWeapon("pda_spawnmenu") -- string correcto
      ply.PDAEquipped = true
    else
      ply.PDAEquipped    = false
      ply.PDAAnimStarted = nil
    end
    return
  end

  -- RETIRAR
  if noAnim then
    -- Inventario: retirar SIN animación/sonido
    StripPDAInstant(ply)
    return
  end

  -- Retiro con animación (holster) para otros casos (cerrar menú, etc.)
  local vmodel = ply:GetViewModel()
  if not IsValid(vmodel) then
    StripPDAInstant(ply)
    return
  end

  local seq = vmodel:SelectWeightedSequence(ACT_VM_HOLSTER)
  if seq > 0 then
    if not ply.PDAAnimStarted then
      vmodel:SendViewModelMatchingSequence(seq)
      ply.PDAAnimStarted = true
      ply:EmitSound("Stalker2.PDAUnequip", 65, math.random(95, 100), 1, CHAN_WEAPON)
    end

    local dur = vmodel:SequenceDuration(seq)
    timer.Create("PDASWITCH_" .. ply:EntIndex(), dur, 1, function()
      if not IsValid(ply) then return end
      StripPDAInstant(ply)
    end)
  else
    StripPDAInstant(ply)
  end
end)

-- Bloquea el cambio de arma mientras la PDA esté activa
hook.Add("PlayerSwitchWeapon", "PDA_Helix_SwitchBlock", function(ply, oldWep, newWep)
  if not ply.PDAEquipped then return end
  return true
end)

-- Cuando el jugador recoge otra arma mientras usa la PDA, recordar la CLASE (string)
hook.Add("WeaponEquip", "PDA_Helix_OverrideLastWeapon", function(wep, ply)
  if ply.PDAEquipped and IsValid(wep) and wep ~= ply:GetActiveWeapon() then
    ply.PDA_LastWeaponClass = wep:GetClass()
  end
end)

-- Comando de rescate
concommand.Add("PDA_unstuck", function(ply)
  StripPDAInstant(ply)
  print("[PDA Helix] " .. ply:Nick() .. " liberado de la PDA.")
end)