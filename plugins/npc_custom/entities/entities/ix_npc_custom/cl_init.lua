include("shared.lua")

function ENT:Initialize()
	self._lastAnim = nil
end

function ENT:Think()
	local anim = self:GetNetVar("npcAnim", "")
	if (anim != self._lastAnim) then
		self._lastAnim = anim
		if (anim != "") then
			local seq = self:LookupSequence(anim)
			if (seq and seq > 0) then
				self:ResetSequence(seq)
				self:SetPlaybackRate(1)
			end
		end
	end

	if (self._lastAnim and self._lastAnim != "") then
		self:FrameAdvance()
	end

	self:NextThink(CurTime())
	return true
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawEntityInfo()
	local client = LocalPlayer()
	if (not IsValid(client) or not client:GetCharacter()) then return end

	local pos = self:GetPos() + Vector(0, 0, 78)
	local dist = client:GetPos():DistToSqr(self:GetPos())

	if (dist > 200 * 200) then return end

	local screenPos = pos:ToScreen()
	if (not screenPos.visible) then return end

	local name = self:GetNetVar("npcName", "NPC")
	local desc = self:GetNetVar("npcDescription", "")

	cam.Start2D()
		local x, y = screenPos.x, screenPos.y

		draw.SimpleText(name, "ixMediumFont", x, y,
			Color(220, 200, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

		if (desc != "") then
			draw.SimpleText(desc, "ixSmallFont", x, y + 4,
				Color(160, 160, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end

		if (dist < 100 * 100) then
			local promptY = desc != "" and y + 22 or y + 4
			draw.SimpleText("Presiona E para hablar", "ixSmallFont", x, promptY,
				Color(199, 197, 179, 180 + math.sin(CurTime() * 3) * 60),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	cam.End2D()
end
