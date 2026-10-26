-- ============================================================
--  ix_trader  |  cl_init.lua  (CLIENT)
--  Renderizado del modelo y del HUD de proximidad.
-- ============================================================

function ENT:Initialize()
	self._lastAnim = nil
end

function ENT:Think()
	local anim = self:GetNetVar("traderAnim", "")
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
	if (!IsValid(client) or !client:GetCharacter()) then return end

	local dist = client:GetPos():Distance(self:GetPos())
	if (dist > 200) then return end

	local pos    = self:GetPos() + Vector(0, 0, 80)
	local screen = pos:ToScreen()
	if (!screen.visible) then return end

	local name    = self:GetNetVar("traderName", "Comerciante")
	local faction = self:GetNetVar("factionKey", "prapor")

	-- Nombre del trader centrado sobre su cabeza
	draw.SimpleTextOutlined(name, "ixGenericFont", screen.x, screen.y - 20,
		Color(255, 220, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))

	-- Cargo / facción
	draw.SimpleTextOutlined("[" .. (ix.traders.names[faction] or faction) .. "]",
		"ixSmallFont", screen.x, screen.y,
		Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))

	-- Prompt de interacción cuando el jugador está suficientemente cerca
	if (dist < 100) then
		draw.SimpleTextOutlined("Presiona E para interactuar",
			"ixSmallFont", screen.x, screen.y + 16,
			Color(180, 230, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
	end
end
