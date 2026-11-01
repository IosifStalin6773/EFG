net.Receive("ixOpenHelixMenu", function()
	local lp = LocalPlayer()
	if (not IsValid(lp) or not lp:GetCharacter()) then return end
	if (IsValid(ix.gui.efgInventory)) then ix.gui.efgInventory:Remove() end
	vgui.Create("ixMenu")
end)
