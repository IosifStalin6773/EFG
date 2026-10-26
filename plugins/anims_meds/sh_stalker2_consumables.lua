
-- sh_stalker2_consumables.lua
-- Registro de ammo types + sonidos para consumibles Stalker2 portados a Helix/ixtarkov
-- Debes incluir este archivo desde tu sh_plugin.lua:
-- ix.util.Include("sh_stalker2_consumables.lua")

AddCSLuaFile()

-- =========================================================
-- AMMO TYPES
-- =========================================================
-- Puedes llamar game.AddAmmoType varias veces sin problema.
-- (Si el gamemode lo llama también, no pasa nada grave.)

local ammoTypes = {
    "water",
    "vodka",
    "energy",
    "milk",
    "bread",
    "sausage",
    "canned",

    -- si más adelante portas más:
    "bandage",
    "antirad",
    "medkit_general",
    "medkit_army",
    "medkit_scientific",
    "blockers",
    "enhancers",
    "regenerator",
}

for _, name in ipairs(ammoTypes) do
    game.AddAmmoType({ name = name })
end

-- =========================================================
-- SONIDOS (mínimos + útiles)
-- =========================================================
-- Si no tienes esos archivos en /sound/, no sonará pero tampoco debería crashear.
-- Ajusta rutas si tu addon las tiene en otra carpeta.

-- Común: beber
sound.Add({
    name = "Stalker2.Drink",
    channel = CHAN_WEAPON,
    volume = 1.0,
    level = 65,
    pitch = {95, 105},
    sound = {
        "weapons/stalker2/drink/SFX_Consumables_Common_Drink_02.mp3",
        "weapons/stalker2/drink/SFX_Consumables_Common_Drink_03.mp3",
        "weapons/stalker2/drink/SFX_Consumables_Common_Drink_04.mp3",
        "weapons/stalker2/drink/SFX_Consumables_Common_Drink_05.mp3",
        "weapons/stalker2/drink/SFX_Consumables_Common_Drink_06.mp3",
        "weapons/stalker2/drink/SFX_Consumables_Common_Drink_07.mp3",
        "weapons/stalker2/drink/SFX_Consumables_Common_Drink_08.mp3"
    }
})

-- Pan: mordisco
sound.Add({
    name = "Stalker2.Bread",
    channel = CHAN_WEAPON,
    volume = 0.5,
    level = 65,
    pitch = {95, 105},
    sound = {
        "weapons/stalker2/bread/SFX_Consumables_Bread_Bite_01.mp3",
        "weapons/stalker2/bread/SFX_Consumables_Bread_Bite_02.mp3",
        "weapons/stalker2/bread/SFX_Consumables_Bread_Bite_03.mp3",
        "weapons/stalker2/bread/SFX_Consumables_Bread_Bite_04.mp3",
        "weapons/stalker2/bread/SFX_Consumables_Bread_Bite_05.mp3",
        "weapons/stalker2/bread/SFX_Consumables_Bread_Bite_06.mp3"
    }
})

-- Lata: abrir
sound.Add({
    name = "Stalker2.CannedOpen",
    channel = CHAN_BODY,
    volume = 1.0,
    level = 65,
    pitch = {95, 105},
    sound = {
        "weapons/stalker2/canned/SFX_Canned_Open.ogg"
    }
})

-- Lata: tapa/ruidos (opcionales)
sound.Add({
    name = "Stalker2.CannedLid",
    channel = CHAN_BODY,
    volume = 1.0,
    level = 65,
    pitch = {95, 105},
    sound = {
        "weapons/stalker2/canned/SFX_Canned_Lid.ogg"
    }
})

-- Energy: abrir + agitar (opcionales)
sound.Add({
    name = "Stalker2.EnergyOpen",
    channel = CHAN_WEAPON,
    volume = 1.0,
    level = 65,
    pitch = {95, 105},
    sound = {
        "weapons/stalker2/energy/SFX_CA_Energy_Open_1.ogg",
        "weapons/stalker2/energy/SFX_CA_Energy_Open_2.ogg",
        "weapons/stalker2/energy/SFX_CA_Energy_Open_3.ogg"
    }
})

sound.Add({
    name = "Stalker2.EnergyShake",
    channel = CHAN_WEAPON,
    volume = 0.2,
    level = 65,
    pitch = {95, 105},
    sound = {
        "weapons/stalker2/energy/SFX_CA_Energy_Shake_1.ogg",
        "weapons/stalker2/energy/SFX_CA_Energy_Shake_2.ogg",
        "weapons/stalker2/energy/SFX_CA_Energy_Shake_3.ogg"
    }
})

-- Milk: (si tienes sonidos de leche en tu pack)
sound.Add({
    name = "Stalker2.Milk",
    channel = CHAN_WEAPON,
    volume = 1.0,
    level = 65,
    pitch = {95, 105},
    sound = {
        "weapons/stalker2/milk/SFX_Milk_Knife_1.ogg",
        "weapons/stalker2/milk/SFX_Milk_Knife_2.ogg",
        "weapons/stalker2/milk/SFX_Milk_Knife_3.ogg"
    }
})

-- Salchicha: (si tu addon trae sonidos; si no, puedes borrar este bloque)
sound.Add({
    name = "Stalker2.Sausage",
    channel = CHAN_WEAPON,
    volume = 0.4,
    level = 65,
    pitch = {95, 105},
    sound = {
        "weapons/stalker2/sausage/SFX_Sausage_1.ogg",
        "weapons/stalker2/sausage/SFX_Sausage_2.ogg",
        "weapons/stalker2/sausage/SFX_Sausage_3.ogg",
        "weapons/stalker2/sausage/SFX_Sausage_4.ogg"
    }
})
