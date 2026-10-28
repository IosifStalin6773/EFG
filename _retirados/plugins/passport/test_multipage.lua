-- test_multipage.lua
-- Test script for multi-page passport functionality
-- This file can be used to test the multi-page passport system

local PLUGIN = PLUGIN

if (SERVER) then
    -- Admin command to create test passport with multiple pages
    ix.command.Add("testpassport", {
        description = "Crea un pasaporte de prueba con páginas múltiples",
        adminOnly = true,
        arguments = {},
        OnRun = function(self, client)
            local char = client:GetCharacter()
            if not char then
                client:Notify("No tienes un personaje cargado.")
                return
            end
            
            local inv = char:GetInventory()
            if not inv then
                client:Notify("Inventario no disponible.")
                return
            end
            
            -- Create test passport data with multiple pages
            local testPassportData = {
                fields = {
                    fullName = "TEST USER",
                    nationality = "METRO",
                    citizenship = "CIUDADANO METRO",
                    residence = "ESTACIÓN POLIS",
                    issuedBy = "ADMIN TEST",
                    issuedWhere = "TEST STATION",
                    issuedWhen = os.time(),
                    birth = "01/01/2000"
                },
                stamp = "metro/stamp/polis.png",
                ownerSteamID64 = client:SteamID64(),
                ownerName = client:Name(),
                issuedBy = client:Name(),
                issuedWhen = os.time(),
                model = client:GetModel() or "",
                skin = client:GetSkin() or 0,
                bodygroups = {},
                pages = {
                    {
                        pageNumber = 1,
                        stationStamps = {},
                        notes = ""
                    },
                    {
                        pageNumber = 2,
                        stationStamps = {
                            {
                                stationName = "POLIS",
                                stampType = "entry",
                                timestamp = os.time() - 3600,
                                stampedBy = "GUARDIA POLIS",
                                stampPosition = {x = 100, y = 150}
                            }
                        },
                        notes = "Primera entrada a Polis"
                    },
                    {
                        pageNumber = 3,
                        stationStamps = {
                            {
                                stationName = "HANZA",
                                stampType = "transit",
                                timestamp = os.time() - 1800,
                                stampedBy = "OFICIAL HANZA",
                                stampPosition = {x = 200, y = 120}
                            },
                            {
                                stationName = "VDNKH",
                                stampType = "exit",
                                timestamp = os.time() - 900,
                                stampedBy = "PATRULLA VDNKH",
                                stampPosition = {x = 150, y = 200}
                            }
                        },
                        notes = "Tránsito por varias estaciones"
                    }
                }
            }
            
            -- Create the passport item
            local item = inv:Add("passport", 1, {
                passport = testPassportData
            })
            
            if item then
                client:Notify("Pasaporte de prueba con múltiples páginas creado exitosamente.")
                client:Notify("Usa el menú contextual del ítem para ver las opciones multi-página.")
            else
                client:Notify("Error al crear el pasaporte de prueba.")
            end
        end
    })
    
    -- Command to add test station stamp
    ix.command.Add("teststamp", {
        description = "Añade un sello de estación de prueba al pasaporte actual",
        adminOnly = true,
        arguments = {
            bit.bor(ix.type.string, ix.type.optional)
        },
        OnRun = function(self, client, stationName)
            stationName = stationName or "TEST_STATION"
            
            local char = client:GetCharacter()
            if not char then return end
            
            local inv = char:GetInventory()
            if not inv then return end
            
            -- Find passport
            local passport = nil
            for _, item in pairs(inv:GetItems(true) or {}) do
                if item.uniqueID == "passport" then
                    passport = item
                    break
                end
            end
            
            if not passport then
                client:Notify("No tienes un pasaporte en tu inventario.")
                return
            end
            
            -- Initialize pages if needed
            local passportData = passport:GetData("passport", {})
            if not passportData.pages then
                passportData.pages = {
                    {
                        pageNumber = 1,
                        stationStamps = {},
                        notes = ""
                    }
                }
            end
            
            -- Add stamp to page 2 (or create page 2 if it doesn't exist)
            local page2 = nil
            for _, page in ipairs(passportData.pages) do
                if page.pageNumber == 2 then
                    page2 = page
                    break
                end
            end
            
            if not page2 then
                page2 = {
                    pageNumber = 2,
                    stationStamps = {},
                    notes = ""
                }
                table.insert(passportData.pages, page2)
            end
            
            -- Add new stamp
            local newStamp = {
                stationName = stationName,
                stampType = "entry",
                timestamp = os.time(),
                stampedBy = client:Name(),
                stampPosition = {x = math.random(50, 400), y = math.random(100, 250)}
            }
            
            table.insert(page2.stationStamps, newStamp)
            passport:SetData("passport", passportData)
            
            client:Notify(string.format("Sello de estación '%s' añadido a la página 2", stationName))
        end
    })
end

if (CLIENT) then
    -- Client-side test command to open multi-page passport viewer
    ix.command.Add("testmultipage", {
        description = "Abre el visor de pasaporte multi-página de prueba",
        adminOnly = true,
        arguments = {},
        OnRun = function()
            -- Create test data
            local testData = {
                fields = {
                    fullName = "USUARIO DE PRUEBA",
                    nationality = "METRO",
                    citizenship = "CIUDADANO",
                    residence = "POLIS"
                },
                pages = {
                    {
                        pageNumber = 1,
                        stationStamps = {},
                        notes = "Página principal"
                    },
                    {
                        pageNumber = 2,
                        stationStamps = {
                            {
                                stationName = "POLIS",
                                stampType = "entry",
                                timestamp = os.time(),
                                stampedBy = "GUARDIA",
                                stampPosition = {x = 100, y = 150}
                            }
                        },
                        notes = "Registro de viajes"
                    }
                }
            }
            
            -- Open multi-page viewer
            if vgui.GetControlTable("ixMultiPagePassport") and PLUGIN.OpenMultiPagePassport then
                PLUGIN:OpenMultiPagePassport(999999, testData) -- Use test ID
                chat.AddText(Color(100, 255, 100), "[Test] ", color_white, "Visor multi-página abierto con datos de prueba.")
            else
                chat.AddText(Color(255, 100, 100), "[Error] ", color_white, "El visor multi-página no está disponible.")
            end
        end
    })
end
