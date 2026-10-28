-- Fuentes del sistema de pasaportes (estilo "Papers, Please").
-- IMPORTANTE: este archivo vive en libs/ a propósito. Helix incluye libs/ ANTES
-- que derma/ (ver ix.plugin.Load), de modo que estas fuentes ya existen cuando se
-- cargan los paneles de derma/. Si se moviera fuera de libs/, la mesa de inspección
-- fallaría con "'ixPassportFont' isn't a valid font".

surface.CreateFont("ixPassportFont", {
    font = "Courier New",
    size = 18,
    weight = 400,
    extended = true,
    antialias = false
})

surface.CreateFont("ixPassportUI", {
    font = "Courier New",
    size = 16,
    weight = 400,
    extended = true,
    antialias = false
})

-- Fuentes pixeladas adicionales para el estilo Papers, Please
surface.CreateFont("ixPapersTitle", {
    font = "Courier New",
    size = 24,
    weight = 700,
    extended = true,
    antialias = false
})

surface.CreateFont("ixPapersSmall", {
    font = "Courier New",
    size = 14,
    weight = 400,
    extended = true,
    antialias = false
})

surface.CreateFont("ixPapersButton", {
    font = "Courier New",
    size = 16,
    weight = 600,
    extended = true,
    antialias = false
})

-- Fuente de título para documentos
surface.CreateFont("FONT_TITLE", {
    font = "Courier New",
    size = 28,
    weight = 700,
    extended = true,
    antialias = false
})
