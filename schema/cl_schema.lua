
-- Here is where all of your clientside functions should go.

-- Example client function that will print to the chatbox.
function Schema:ExampleFunction(text, ...)
	if (text:sub(1, 1) == "@") then
		text = L(text:sub(2), ...)
	end

	LocalPlayer():ChatPrint(text)
end

-- Aplica la paleta de color Metro 2033 a los paneles de Helix
-- (inventario, opciones de personaje, menús).
hook.Add("InitPostEntity", "MetroRP_HelixTheme", function()
	ix.color = ix.color or {}

	-- Fondo principal de paneles: negro carbón del metro
	ix.color.base      = Color(12, 12, 12)
	ix.color.background = Color(18, 18, 18)
	ix.color.primary    = Color(22, 22, 22)
	ix.color.secondary  = Color(10, 10, 10)

	-- Acento: rojo oscuro oxidado (señales de peligro del metro)
	ix.color.accent     = Color(130, 20, 20)

	-- Texto: blanco apagado, como papel viejo
	ix.color.foreground = Color(200, 192, 172)
	ix.color.text       = Color(200, 192, 172)

	-- Positivo/negativo (notificaciones)
	ix.color.positive   = Color(60, 140, 60)
	ix.color.negative   = Color(180, 40, 40)

	-- Borde de paneles: casi negro con leve tinte cálido
	ix.color.border     = Color(40, 35, 30)

	-- Diferimos la eliminación al siguiente frame para que GM:InitPostEntity
	-- de Helix haya creado ix.gui.bars y sus paneles antes de quitarlos.
	timer.Simple(0, function()
		ix.bar.Remove("health")
		ix.bar.Remove("armor")
		ix.bar.Remove("stm")
	end)
end)


