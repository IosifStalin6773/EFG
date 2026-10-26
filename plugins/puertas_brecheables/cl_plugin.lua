local doorOverlay  = {}
local overlayActive = false

--------------------------------------------------------------------------------
-- Overlay visual de puertas (/MostrarPuertas)
--------------------------------------------------------------------------------

net.Receive("PB_SendDoorList", function()
	doorOverlay = {}
	local count = net.ReadUInt(8)
	for i = 1, count do
		local id           = net.ReadUInt(8)
		local pos          = net.ReadVector()
		local isDestroyed  = net.ReadBool()
		local hasExplosive = net.ReadBool()
		local class        = net.ReadString()
		local hasButton    = net.ReadBool()
		local buttonPos    = hasButton and net.ReadVector() or nil

		table.insert(doorOverlay, {
			id           = id,
			pos          = pos,
			isDestroyed  = isDestroyed,
			hasExplosive = hasExplosive,
			class        = class,
			hasButton    = hasButton,
			buttonPos    = buttonPos,
		})
	end

	overlayActive = !overlayActive
	LocalPlayer():Notify(overlayActive and "Overlay de puertas activado." or "Overlay de puertas desactivado.")
end)

local function DoorStatusColor(door)
	if (door.isDestroyed)  then return Color(220, 50,  50)  end
	if (door.hasExplosive) then return Color(154, 136,  102)  end
	return Color(50, 200, 50)
end

hook.Add("PostDrawTranslucentRenderables", "PB_DoorOverlay3D", function(_, bSkybox)
	if (bSkybox or !overlayActive or #doorOverlay == 0) then return end

	for _, door in ipairs(doorOverlay) do
		local col = DoorStatusColor(door)
		render.DrawWireframeBox(door.pos, angle_zero, Vector(-20, -20, 0), Vector(20, 20, 80), col)

		if (door.hasButton and door.buttonPos) then
			render.DrawWireframeBox(door.buttonPos, angle_zero, Vector(-10, -10, -10), Vector(10, 10, 10), Color(100, 150, 255))
		end
	end

	cam.Start2D()
		for _, door in ipairs(doorOverlay) do
			local screen = (door.pos + Vector(0, 0, 92)):ToScreen()
			if (!screen.visible) then continue end

			local col    = DoorStatusColor(door)
			local status = door.isDestroyed and "DESTRUIDA" or (door.hasExplosive and "EXPLOSIVO ACTIVO" or "ACTIVA")
			local label  = "BRECHA #" .. door.id

			draw.SimpleText(label,    "BudgetLabel", screen.x + 1, screen.y + 1,  Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(label,    "BudgetLabel", screen.x,     screen.y,       col,                 TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(status,   "BudgetLabel", screen.x + 1, screen.y + 13, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(status,   "BudgetLabel", screen.x,     screen.y + 12, col,                 TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(door.class, "BudgetLabel", screen.x + 1, screen.y + 25, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(door.class, "BudgetLabel", screen.x,     screen.y + 24, Color(160, 160, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	cam.End2D()
end)

