net.Receive("ixHarvestOpen", function()
	local entity = net.ReadEntity()
	local harvestType = net.ReadString()

	local data = ix.harvest.types[harvestType]

	if (!IsValid(entity) or !data) then
		return
	end

	if (IsValid(ix.gui.harvestMinigame)) then
		ix.gui.harvestMinigame:Remove()
	end

	local panel = vgui.Create("ixHarvestMinigame")
	panel:Setup(entity, harvestType)
end)

function PLUGIN:HUDPaint()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:GetCharacter()) then
		return
	end

	local entity = client:GetEyeTrace().Entity

	if (!IsValid(entity) or entity:GetClass() != "ix_harvestable") then
		return
	end

	local data = ix.harvest.types[entity:GetNetVar("type", "")]

	if (!data) then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > ix.harvest.range) then
		return
	end

	local x = ScrW() * 0.5
	local ready = entity:GetNetVar("nextHarvest", 0) < os.time()

	surface.SetFont("ixGenericFont")
	ix.util.DrawText(data.label, x, 12, ix.config.Get("color"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, nil, 255)

	surface.SetFont("ixItemDescFont")

	if (ready) then
		ix.util.DrawText(data.hint, x, 32, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, nil, 255)
	else
		ix.util.DrawText("Necesita tiempo para volver a estar disponible.", x, 32,
			Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, nil, 255)
	end
end
