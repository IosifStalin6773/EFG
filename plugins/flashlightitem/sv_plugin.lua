-- Distribuye la textura del flashlight directamente desde el schema, sin depender de la workshop.
resource.AddFile("materials/metrorp/flashlight001.vtf")

-- El addon "metro_2033_flashlight_rechargable" registra "d_dynamo_flash" que devuelve
-- false bloqueando la linterna nativa. Lo quitamos para que la nuestra funcione.
hook.Remove("PlayerSwitchFlashlight", "d_dynamo_flash")

hook.Add("PlayerSwitchFlashlight", "metrorp_flashlight_item", function(client, enabled)
	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	-- Ignoramos "enabled" porque siempre llega true: al devolver false el engine nunca
	-- cambia el estado nativo, así que cada pulsación de F envía enabled=true de nuevo.
	local newState = !client:GetNW2Bool("flashlight_active", false)

	-- El ítem solo hace falta para ENCENDERLA. Si el requisito se comprobara
	-- también al apagar, un jugador que se quedó sin linterna (murió, se la
	-- robaron...) mientras estaba encendida no podría apagarla nunca: cada
	-- pulsación de F fallaría aquí antes de llegar a poner newState en false.
	if (newState and (!inventory or !inventory:HasItem("flashlight"))) then
		client:NotifyLocalized("flashlightNoItem")
		return false
	end

	if (newState and client:GetNW2Int("chargeAmount", 0) <= 0) then
		client:NotifyLocalized("flashlightNoCharge")
		return false
	end

	client:EmitSound("items/flashlight1.wav", 70, 100, 1, CHAN_ITEM)
	client:SetNW2Bool("flashlight_active", newState)
	return false -- Bloqueamos la linterna nativa; el cliente usa ProjectedTexture
end)

-- Algunas SNPCs (ej. las arañas eléctricas de Metro 2033 Spiderbugs) apagan la linterna
-- del jugador llamando a Player:Flashlight(false) directamente. Como nuestro sistema no usa
-- el estado nativo, hay que interceptar esa llamada para apagar también flashlight_active.
local PLAYER = FindMetaTable("Player")
local BaseFlashlight = PLAYER.Flashlight

function PLAYER:Flashlight(state)
	BaseFlashlight(self, state)

	if (state == false and self:GetNW2Bool("flashlight_active", false)) then
		self:SetNW2Bool("flashlight_active", false)
		self:NotifyLocalized("flashlightForcedOff")
	end
end

function PLUGIN:PlayerLoadedCharacter(client, character)
	client:SetNW2Int("chargeAmount", character:GetFlashlightCharge())
	client:SetNW2Bool("flashlight_active", false)
end

function PLUGIN:PlayerDeath(client)
	client:SetNW2Bool("flashlight_active", false)
	client:Flashlight(false)
end

-- Drena 1 punto de carga cada 90 segundos mientras la linterna esté encendida (15 min con carga completa).
timer.Create("metrorp_flashlight_drain", 90, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local char = client:GetCharacter()
		if (!char or !client:Alive()) then continue end
		if (!client:GetNW2Bool("flashlight_active", false)) then continue end

		local charge = math.max(0, client:GetNW2Int("chargeAmount", 0) - 1)
		client:SetNW2Int("chargeAmount", charge)

		if (charge <= 0) then
			client:SetNW2Bool("flashlight_active", false)
			client:NotifyLocalized("flashlightDepleted")
		end
	end
end)

-- Sincroniza la carga con la variable persistente del personaje.
timer.Create("metrorp_flashlight_sync", 15, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local char = client:GetCharacter()
		if (!char) then continue end
		char:SetFlashlightCharge(client:GetNW2Int("chargeAmount", 0))
	end
end)
