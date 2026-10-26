-- schema/plugins/stalker2_pda_helix/sh_stalker2_pda.lua
AddCSLuaFile()

-- Sonidos STALKER 2 - PDA
sound.Add({
  name = "Stalker2.PDAEquip",
  channel = CHAN_WEAPON,
  volume = 1,
  level = 65,
  pitch = {95, 100},
  sound = {
    "weapons/stalker2/pda/SFX_PDA_Equip_01.mp3",
    "weapons/stalker2/pda/SFX_PDA_Equip_02.mp3",
    "weapons/stalker2/pda/SFX_PDA_Equip_03.mp3",
  }
})

sound.Add({
  name = "Stalker2.PDAUnequip",
  channel = CHAN_WEAPON,
  volume = 1,
  level = 65,
  pitch = {95, 100},
  sound = {
    "weapons/stalker2/pda/SFX_PDA_Unequip_01.mp3",
    "weapons/stalker2/pda/SFX_PDA_Unequip_02.mp3",
    "weapons/stalker2/pda/SFX_PDA_Unequip_03.mp3",
  }
})