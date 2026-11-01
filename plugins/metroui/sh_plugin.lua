
local PLUGIN = PLUGIN
PLUGIN.name = 'Metro UI'
PLUGIN.author = "EFG Project" -- original: Bilwin
PLUGIN.defaultFaction = FACTION_USEC
PLUGIN.menuMusic = "efg/ui/menu_music.mp3" -- música del menú de EFT
PLUGIN.modelOptions = {
    ['models/exodus/sailors/sailor_01.mdl'] = {
        bodygroups = {
            [1] = {0, 1},   -- Gasmask
            [2] = {0, 1},   -- Hat
            [3] = {0, 1},   -- Ropes
            [4] = {0, 1}    -- Body
        },
        skins = {
            0, 1, 2, 3, 4,
            5, 6, 7, 8, 9,
            10, 11, 12, 13,
            14
        }
    },
    ['models/exodus/secta/secta_civilian_01.mdl'] = {
        bodygroups = {
            [1] = {0, 1},       -- Respirator
            [2] = {0, 1, 2},    -- Hat
            [3] = {0, 1},       -- Beard
            [4] = {0, 1, 2, 3}, -- Body
            [5] = {0, 1, 2, 3}  -- Legs
        },
        skins = {
            0, 1, 2, 3, 4,
            5, 6, 7, 8, 9,
            10, 11, 12, 13
        }
    }
}
PLUGIN.bonuses = {
    {
        name = 'Recluta',
        img = Material('efgui/bonuses/conscript.png', 'noclamp smooth'),
        items = {
            'water',
            'canned',
            'helmet_ssh68',
        }
    },
    {
        name = 'Médico',
        img = Material('efgui/bonuses/medic.png', 'noclamp smooth'),
        items = {
            'ai2',
            'vendas',
            'analgin',
        }
    },
    {
        name = 'Mecánico',
        img = Material('efgui/bonuses/mechanic.png', 'noclamp smooth'),
        items = {
            'kit_reparacion_armadura',
            'flashlight',
            'water',
        }
    }
}
PLUGIN.spawns = {
    { -- aduanas
        icon = ix.util.GetMaterial('efgui/spawnmenu/4Reich/latest.jpg', 'noclamp smooth'),
        img = ix.util.GetMaterial('efgui/spawnmenu/reich.jpg', 'noclamp smooth'),
        color = Color(90, 96, 92),
        name = 'ZONA INDUSTRIAL',
        desc = 'Naves industriales, un patio de carga y bloques de viviendas a las afueras. Despliegue disponible cuando se monte el mapa de raid.',
        disabled = true,
        screen_pos = {CLIENT and SScale(180) or 0, CLIENT and SScale(172) or 0},
        spawn_poses = {
            Vector(0, 0, 2777),
            Vector(1, 1, 3777),
            Vector(2, 2, 5777)
        }
    },
    { -- escondite (único punto de aparición activo)
        icon = ix.util.GetMaterial('efgui/spawnmenu/Hanza/latest.jpg', 'noclamp smooth'),
        img = ix.util.GetMaterial('efgui/spawnmenu/hanza.jpg', 'noclamp smooth'),
        color = Color(145, 148, 108),
        name = 'ESCONDITE',
        desc = 'Tu refugio bajo tierra. Aquí guardas el alijo, mejoras los módulos del escondite, comercias con los traders y preparas el próximo raid.',
        screen_pos = {CLIENT and SScale(190) or 0, CLIENT and SScale(110) or 0},
        spawn_poses = {
            Vector(6247.929688, 2174.053223, -856.968750),
            Vector(6278.570801, 2381.313721, -856.968750),
            Vector(6367.980469, 2299.228760, -856.968750)
        }
    },
    { -- bosque
        icon = ix.util.GetMaterial('efgui/spawnmenu/Rangers/latest.jpg', 'noclamp smooth'),
        img = ix.util.GetMaterial('efgui/spawnmenu/rangers.jpg', 'noclamp smooth'),
        color = Color(80, 96, 80),
        name = 'BOSQUE',
        desc = 'Monte cerrado con caminos de tierra y cabañas. Despliegue disponible cuando se monte el mapa de raid.',
        disabled = true,
        screen_pos = {CLIENT and SScale(231.5/2) or 0, CLIENT and SScale(213) or 0},
        spawn_poses = {
            Vector(0, 0, 2777),
            Vector(1, 1, 3777),
            Vector(2, 2, 5777)
        }
    },
    { -- fabrica
        icon = ix.util.GetMaterial('efgui/spawnmenu/RedLine/latest.jpg', 'noclamp smooth'),
        img = ix.util.GetMaterial('efgui/spawnmenu/redline.jpg', 'noclamp smooth'),
        color = Color(103, 105, 86),
        name = 'COMPLEJO QUÍMICO',
        desc = 'Complejo químico abandonado, pasillos estrechos y combate a corta distancia. Despliegue disponible cuando se monte el mapa de raid.',
        disabled = true,
        screen_pos = {CLIENT and SScale(155) or 0, CLIENT and SScale(261.5) or 0},
        spawn_poses = {
            Vector(0, 0, 2777),
            Vector(1, 1, 3777),
            Vector(2, 2, 5777)
        }
    },
    { -- litoral
        icon = ix.util.GetMaterial('efgui/spawnmenu/Bandit/bandit.jpg', 'noclamp smooth'),
        img = ix.util.GetMaterial('efgui/spawnmenu/bandit.jpg', 'noclamp smooth'),
        color = Color(96, 100, 110),
        name = 'COSTA',
        desc = 'Acantilados, un balneario abandonado y casas de veraneo. Despliegue disponible cuando se monte el mapa de raid.',
        disabled = true,
        screen_pos = {CLIENT and SScale(207) or 0, CLIENT and SScale(220) or 0},
        spawn_poses = {
            Vector(0, 0, 2777),
            Vector(1, 1, 3777),
            Vector(2, 2, 5777)
        }
    }
}

ix.util.Include('sv_plugin.lua')

ix.anim.SetModelClass('models/exodus/sailors/sailor_01.mdl', 'player')

function PLUGIN:InitializedConfig()
    -- Color de acento global de Helix (título de tooltips de entidad, flecha,
    -- divisor del menú de objetos, etc.). Por defecto es azul. Helix ya deja
    -- ".value" en azul al hacer su propio ix.config.Add ANTES de que esto se
    -- ejecute, así que SetDefault (que solo toca ".default", el valor de
    -- reserva) no cambia nada visualmente: hay que forzar el valor activo.
    ix.config.Set('color', Color(206, 116, 36, 255))

    ix.config.Add('discordURL', 'https://discord.gg', '', nil, {
        category = 'appearance'
    })
end

ix.char.RegisterVar('creationBonus', {
    field       = 'creationBonus',
    fieldType   = ix.type.number,
    default     = 0,
    isLocal     = true
})

ix.char.RegisterVar('spawnPoint', {
    field       = 'spawnPoint',
    fieldType   = ix.type.number,
    default     = 0,
    isLocal     = true
})

ix.char.RegisterVar('chosenFaction', {
    field       = 'chosenFaction',
    fieldType   = ix.type.string,
    default     = 'DEFAULT',
    isLocal     = true
})

ix.char.RegisterVar('chosenFactionId', {
    field       = 'chosenFactionId',
    fieldType   = ix.type.number,
    default     = 0,
    isLocal     = true
})

ix.char.RegisterVar('chosenBodygroups', {
    field       = 'chosenBodygroups',
    fieldType   = ix.type.string,
    default     = '[}',
    isLocal     = true
})

ix.char.RegisterVar('chosenSkin', {
    field       = 'chosenSkin',
    fieldType   = ix.type.number,
    default     = 0,
    isLocal     = true
})

ix.char.RegisterVar('chosenModel', {
    field       = 'chosenModel',
    fieldType   = ix.type.string,
    default     = 'models/error.mdl',
    isLocal     = true
})

if CLIENT then
    hook.Add("Think", "MetroUI_MusicStopCheck", function()
        if not IsValid(PLUGIN.ambientMusic) then return end
        if PLUGIN.ambientMusic:GetState() != GMOD_CHANNEL_PLAYING then return end
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if not isfunction(lp.GetCharacter) then return end
        if not lp:GetCharacter() then return end
        if timer.Exists("MetroUI_MusicFadeOut") then return end
        PLUGIN:FadeOutMusic(1.5)
    end)

    -- Evita que el sistema de música de Helix toque su canción por defecto.
    hook.Add("OnCharacterMenuCreated", "MetroUI_SuppressHelixMusic", function(panel)
        if IsValid(panel) and isfunction(panel.PlayMusic) then
            panel.PlayMusic = function() end
        end
        if IsValid(panel) and IsValid(panel.channel) then
            panel.channel:Stop()
        end
    end)

    function PLUGIN:FadeOutMusic(duration)
        local ch = self.ambientMusic
        if not IsValid(ch) then return end
        timer.Remove("MetroUI_MusicFadeIn")
        local steps = 20
        local interval = duration / steps
        local startVol = ch:GetVolume()
        local step = 0
        timer.Create("MetroUI_MusicFadeOut", interval, steps, function()
            if not IsValid(ch) then return end
            step = step + 1
            ch:SetVolume(math.max(startVol * (1 - step / steps), 0))
            if step >= steps then ch:Stop() end
        end)
    end

    function VerticalScale(size)
        return size * (ScrH() / 480.0)
    end; VScale = VerticalScale; vscale = VerticalScale
    
    function ScreenScaleMin(size)
        return math.min(SScale(size), VScale(size))
    end; SScaleMin = ScreenScaleMin; sscalemin = SScaleMin

    function LerpColor(frac, from, to)
		local col = Color(
			Lerp(frac,from.r,to.r),
			Lerp(frac,from.g,to.g),
			Lerp(frac,from.b,to.b),
			Lerp(frac,from.a,to.a)
		)

		return col
	end

    PLUGIN.TitleText = 'Escape from Gmod'
    PLUGIN.PostScriptum = [[]]
    PLUGIN.MainMenuButtons = {
        {
            name = 'Nuevo PMC',
            weight = 1,
            callback = function(pnl)
                -- creador de PMC estilo EFT (plugin efg_pmc)
                local _pnl = vgui.Create(vgui.GetControlTable('efgPMCCreator') and 'efgPMCCreator' or 'metroCharacterCreation')
                pnl:DoModal()
                pnl:AlphaTo(0, .3, 0, function()
                    pnl:Remove()
                end)
            end
        },
        {
            name = 'Cargar Personaje',
            weight = 2,
            callback = function(pnl)
                local _pnl = vgui.Create('metroCharLoad')
                pnl:DoModal()
                pnl:AlphaTo(0, .3, 0, function()
                    pnl:Remove()
                end)
            end
        },
        {
            name = 'Discord',
            weight = 3,
            callback = function()
                gui.OpenURL(ix.config.Get('discordURL', 'https://example.com'))
            end
        },
        {
            name = 'Desconectar',
            weight = 4,
            callback = function()
                vgui.Create('metroModal'):Setup('¿ESTÁS SEGURO?', 'No olvides terminar el RP antes de salir.', nil, function()
                    RunConsoleCommand('disconnect')
                end)
            end,
            filter = function()
                return isfunction(LocalPlayer().GetCharacter) && LocalPlayer():GetCharacter()
            end
        }
    }

    function PLUGIN:GetFontInternal(id)
        return ('%s.%s'):format(self.name, id)
    end

    function PLUGIN:LoadFonts()
       surface.CreateFont(self:GetFontInternal('Title'), {
            font        = 'MBender',
            extended    = true,
            size        = SScale(20),
            weight      = 500,
            antialias   = true
       })

       surface.CreateFont(self:GetFontInternal('PostScriptum'), {
            font        = 'MBender',
            extended    = true,
            size        = SScale(6),
            weight      = 500,
            antialias   = true
        })

        surface.CreateFont(self:GetFontInternal('CharFields'), {
            font        = 'MBender',
            extended    = true,
            size        = SScale(8),
            weight      = 500,
            antialias   = true
        })

        surface.CreateFont(self:GetFontInternal('CharFieldsInk'), {
            font        = 'MBender',
            extended    = true,
            size        = SScale(10),
            weight      = 500,
            antialias   = true
        })

        surface.CreateFont(self:GetFontInternal('Button'), {
            font        = 'MBender',
            extended    = true,
            size        = SScale(10),
            weight      = 500,
            antialias   = true
        })

        surface.CreateFont(self:GetFontInternal('Button2'), {
            font        = 'MBender',
            extended    = true,
            size        = SScale(15),
            weight      = 500,
            antialias   = true
        })

        surface.CreateFont('tls.Modal.Title', {
            font        = 'MBender',
            extended    = true,
            antialias   = true,
            weight      = 800,
            size        = SScaleMin(26/2)
        })

        surface.CreateFont('tls.Modal.Desc', {
            font        = 'MBender',
            extended    = true,
            antialias   = true,
            weight      = 400,
            size        = SScaleMin(16/2)
        })
    end
end