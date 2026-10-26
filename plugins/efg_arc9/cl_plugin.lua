local PLUGIN = PLUGIN

-- Efecto cliente: tambaleo de mira al disparar en cadera con baja ergonomía.
-- Ergo alta (90) = casi sin efecto; ergo baja (20) = tambaleo notable.

local lastPunch = 0
local lastErgo  = 55

-- Caché de la ergonomía del arma equipada; se actualiza cada segundo para
-- no iterar el inventario en cada frame.
local ergoCache = {}
local nextErgoUpdate = 0

local function refreshErgoCache(client)
	local char = client:GetCharacter()

	if (!char) then
		ergoCache[client:EntIndex()] = 55
		return
	end

	local best = 55

	for _, item in pairs(char:GetInventory():GetItems(true)) do
		if (item.isARC9 and item:GetData("equip") and item.ergonomics) then
			best = item.ergonomics
			break
		end
	end

	ergoCache[client:EntIndex()] = best
end

hook.Add("Think", "efgARC9ErgonomicsSway", function()
	local client = LocalPlayer()
	if (!IsValid(client) or !client:Alive()) then return end

	local now = CurTime()

	if (now >= nextErgoUpdate) then
		refreshErgoCache(client)
		nextErgoUpdate = now + 1
	end

	if (!client:KeyDown(IN_ATTACK)) then return end

	local weapon = client:GetActiveWeapon()
	if (!IsValid(weapon) or !weapon.isARC9) then return end

	-- no añadir tambaleo si está apuntando con la mira
	local bADS = weapon.bADS or (weapon.GetWepVar and weapon:GetWepVar("Aim"))
	if (bADS) then return end

	if (now - lastPunch < 0.08) then return end
	lastPunch = now

	local ergo  = ergoCache[client:EntIndex()] or 55
	local extra = math.Clamp((90 - ergo) / 70, 0, 1) * 0.6

	if (extra > 0.05) then
		client:ViewPunch(Angle(
			math.Rand(-extra, extra * 0.6),
			math.Rand(-extra * 0.35, extra * 0.35),
			0
		))
	end
end)
