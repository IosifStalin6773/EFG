local PLUGIN = PLUGIN

local debugMode = false

concommand.Add("descuartizar_debug", function()
	debugMode = !debugMode
	LocalPlayer():ChatPrint("[Descuartizar] Debug " .. (debugMode and "ACTIVADO" or "desactivado"))
end)

net.Receive("ixDescuartizarOpen", function()
	local entity = net.ReadEntity()
	local rounds = net.ReadUInt(4)

	if (!IsValid(entity)) then return end

	if (IsValid(ix.gui.butcherMinigame)) then
		ix.gui.butcherMinigame:Remove()
	end

	local panel = vgui.Create("ixButcherMinigame")
	panel:Setup(entity, rounds)
end)

function PLUGIN:HUDPaint()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:GetCharacter()) then
		return
	end

	local entity = client:GetEyeTrace().Entity

	if (debugMode and IsValid(entity)) then
		local lines = {
			"=== DESCUARTIZAR DEBUG ===",
			"Clase:      " .. entity:GetClass(),
			"Modelo:     " .. (entity:GetModel() or "nil"),
			"Distancia:  " .. math.Round(client:GetPos():Distance(entity:GetPos())) .. " u",
			"IsNPC:      " .. tostring(entity:IsNPC()),
			"IsRagdoll:  " .. tostring(entity:GetClass() == "prop_ragdoll"),
			"carneable:  " .. tostring(entity:GetNetVar("carneable") or false),
			"ixCarneable:" .. tostring(entity.ixCarneable or false),
			"Alive:      " .. tostring(IsValid(entity) and entity.IsNPC and entity:IsNPC() and entity:Alive() or "n/a"),
		}

		surface.SetFont("ixItemDescFont")

		local x, y = 12, 180

		for i, line in ipairs(lines) do
			local color = i == 1 and Color(255, 200, 50) or Color(220, 220, 220)
			draw.SimpleTextOutlined(line, "ixItemDescFont", x, y + (i - 1) * 18, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))
		end
	end

	if (!IsValid(entity) or !entity:GetNetVar("carneable")) then
		return
	end

	local range = self.promptRange or 100

	if (client:GetPos():DistToSqr(entity:GetPos()) > range * range) then
		return
	end

	local text = entity:GetNetVar("descuartizando") and "Descuartizando..." or "Pulsa [E] para descuartizar"

	surface.SetFont("ixGenericFont")
	ix.util.DrawText(text, ScrW() * 0.5, ScrH() * 0.5 + 64, Color(220, 60, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, nil, 255)
end

local nextStart = 0

function PLUGIN:KeyPress(client, key)
	if (key != IN_USE) then return end
	if (client != LocalPlayer()) then return end

	-- KeyPress es un hook predicho: puede dispararse varias veces por una sola
	-- pulsacion. Sin este debounce se envian varios ixDescuartizarStart y el
	-- servidor responde con un Notify por cada uno (ej. "Necesitas un cuchillo").
	if (CurTime() < nextStart) then return end

	local entity = client:GetEyeTrace().Entity

	if (!IsValid(entity) or !entity:GetNetVar("carneable")) then return end

	local range = self.promptRange or 100

	if (client:GetPos():DistToSqr(entity:GetPos()) > range * range) then return end

	nextStart = CurTime() + 0.5

	net.Start("ixDescuartizarStart")
		net.WriteEntity(entity)
	net.SendToServer()
end
