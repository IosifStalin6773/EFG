local PLUGIN = PLUGIN

local function ReadOffer()
	local offer = {}
	local count = net.ReadUInt(8)
	for _ = 1, count do
		offer[#offer + 1] = {
			id = net.ReadUInt(32),
			name = net.ReadString(),
			model = net.ReadString(),
			amount = net.ReadUInt(16),
		}
	end
	return offer
end

net.Receive(PLUGIN.netRequest, function()
	local requester = net.ReadEntity()
	local name = net.ReadString()

	if (ix.intercambio.ShowRequest) then
		ix.intercambio.ShowRequest(name)
	end
end)

net.Receive(PLUGIN.netState, function()
	local data = {}
	data.otherName = net.ReadString()
	data.myOffer = ReadOffer()
	data.theirOffer = ReadOffer()
	data.myConfirm = net.ReadBool()
	data.theirConfirm = net.ReadBool()

	if (IsValid(ix.gui.intercambio)) then
		ix.gui.intercambio:SetState(data)
	else
		local panel = vgui.Create("metroIntercambio")
		panel:SetState(data)
	end
end)

net.Receive(PLUGIN.netClose, function()
	local reason = net.ReadString()

	if (IsValid(ix.gui.intercambio)) then
		ix.gui.intercambio:Close(reason)
	end

	if (reason and reason != "") then
		notification.AddLegacy(reason, NOTIFY_GENERIC, 4)
		surface.PlaySound("buttons/button14.wav")
	end
end)
