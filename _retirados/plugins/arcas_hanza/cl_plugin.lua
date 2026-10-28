local PLUGIN = PLUGIN

ix.util.IncludeDir(("%s/plugins/%s/derma"):format(Schema.folder, PLUGIN.uniqueID), true)

net.Receive(PLUGIN.netOpen, function()
	local ent = net.ReadEntity()
	local balance = net.ReadUInt(32)

	if (not IsValid(ent)) then return end

	if (IsValid(ix.gui.arcasHanza)) then
		ix.gui.arcasHanza:SetData(ent, balance)
	else
		local panel = vgui.Create("metroArcasHanza")
		panel:SetData(ent, balance)
	end
end)
