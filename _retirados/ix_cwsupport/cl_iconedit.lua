if (not CLIENT) then return end

concommand.Add("ix_iconedit", function()
	local char = LocalPlayer():GetCharacter()
	if (not char) then return end
	local inv = char:GetInventory()
	if (not inv) then return end

	local weapons = {}
	for _, item in pairs(inv:GetItems()) do
		if (item.isCW) then
			weapons[#weapons + 1] = item
		end
	end

	if (#weapons == 0) then
		LocalPlayer():ChatPrint("No tienes armas CW en el inventario.")
		return
	end

	table.sort(weapons, function(a, b) return a.name < b.name end)

	local frame = vgui.Create("DFrame")
	frame:SetSize(500, 520)
	frame:SetTitle("Editor de iconCam")
	frame:Center()
	frame:MakePopup()

	local posX, posY, posZ = 0, 30, 0
	local angP, angY, angR = 0, 270, 0
	local fov = 45

	local combo = frame:Add("DComboBox")
	combo:SetPos(10, 30)
	combo:SetSize(480, 25)

	local mdl = frame:Add("DModelPanel")
	mdl:SetPos(10, 60)
	mdl:SetSize(220, 160)
	mdl.LayoutEntity = function() end

	local output = frame:Add("DLabel")
	output:SetPos(10, 490)
	output:SetSize(480, 20)
	output:SetFont("DermaDefaultBold")
	output:SetTextColor(Color(100, 255, 100))

	local function Refresh()
		if (not IsValid(mdl.Entity)) then return end

		local camPos = Vector(posX, posY, posZ)
		local camAng = Angle(angP, angY, angR)
		local lookAt = camPos + camAng:Forward() * 200

		mdl:SetCamPos(camPos)
		mdl:SetLookAt(lookAt)
		mdl:SetFOV(fov)
		mdl.Entity:SetAngles(Angle(0, 0, 0))
		mdl.Entity:SetPos(Vector(0, 0, 0))

		local txt = string.format("iconCam = { pos = Vector(%g, %g, %g), ang = Angle(%g, %g, %g), fov = %g },", posX, posY, posZ, angP, angY, angR, fov)
		output:SetText(txt)
	end

	local function MakeSlider(label, y, min, max, default, callback)
		local sl = frame:Add("DNumSlider")
		sl:SetPos(240, y)
		sl:SetSize(250, 30)
		sl:SetText(label)
		sl:SetMin(min)
		sl:SetMax(max)
		sl:SetDecimals(1)
		sl:SetValue(default)
		sl.OnValueChanged = function(_, val)
			callback(val)
			Refresh()
		end
		return sl
	end

	local slX = MakeSlider("pos.x", 60, -80, 80, posX, function(v) posX = v end)
	local slY = MakeSlider("pos.y (dist)", 100, 1, 120, posY, function(v) posY = v end)
	local slZ = MakeSlider("pos.z", 140, -80, 80, posZ, function(v) posZ = v end)
	local slAngP = MakeSlider("ang.pitch", 180, -90, 90, angP, function(v) angP = v end)
	local slAngY = MakeSlider("ang.yaw", 220, 0, 360, angY, function(v) angY = v end)
	local slAngR = MakeSlider("ang.roll", 260, -180, 180, angR, function(v) angR = v end)
	local slFov = MakeSlider("fov", 300, 5, 120, fov, function(v) fov = v end)

	local copyBtn = frame:Add("DButton")
	copyBtn:SetPos(240, 340)
	copyBtn:SetSize(250, 30)
	copyBtn:SetText("Copiar al portapapeles")
	copyBtn.DoClick = function()
		local txt = string.format("iconCam = { pos = Vector(%g, %g, %g), ang = Angle(%g, %g, %g), fov = %g },", posX, posY, posZ, angP, angY, angR, fov)
		SetClipboardText(txt)
		LocalPlayer():ChatPrint("Copiado: " .. txt)
	end

	local printAllBtn = frame:Add("DButton")
	printAllBtn:SetPos(240, 380)
	printAllBtn:SetSize(250, 30)
	printAllBtn:SetText("Imprimir en consola")
	printAllBtn.DoClick = function()
		local txt = string.format("iconCam = { pos = Vector(%g, %g, %g), ang = Angle(%g, %g, %g), fov = %g },", posX, posY, posZ, angP, angY, angR, fov)
		print(txt)
		LocalPlayer():ChatPrint("Impreso en consola.")
	end

	for _, item in ipairs(weapons) do
		combo:AddChoice(item.name .. " (" .. item.class .. ")", item)
	end

	combo.OnSelect = function(_, _, _, item)
		mdl:SetModel(item:GetModel())
		local cam = item.iconCam
		if (cam) then
			posX = cam.pos.x
			posY = cam.pos.y
			posZ = cam.pos.z
			angP = cam.ang.p or 0
			angY = cam.ang.y or 270
			angR = cam.ang.r or 0
			fov = cam.fov or 45
		else
			posX = 0
			posY = 30
			posZ = 0
			angP = 0
			angY = 270
			angR = 0
			fov = 45
		end
		slX:SetValue(posX)
		slY:SetValue(posY)
		slZ:SetValue(posZ)
		slAngP:SetValue(angP)
		slAngY:SetValue(angY)
		slAngR:SetValue(angR)
		slFov:SetValue(fov)
		Refresh()
	end

	if (weapons[1]) then
		combo:ChooseOptionID(1)
	end
end)
