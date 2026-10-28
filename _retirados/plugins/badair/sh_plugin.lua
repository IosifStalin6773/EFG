local PLUGIN = PLUGIN
PLUGIN.name = "Bad Air Remastered"
PLUGIN.author = "Black Tea | Ported by JohnyReaper"
PLUGIN.description = "Remasted Bad Air Plugin"
PLUGIN.toxicAreas = PLUGIN.toxicAreas or {}

DEFAULT_GASMASK_HEALTH = 240
DEFAULT_GASMASK_FILTER = 240

ix.badair = ix.badair or {}

-- Fuente de verdad ÚNICA para los tramos de radiación (antes duplicados de
-- forma independiente en sv_plugin.lua, cl_plugin.lua y hud/cl_plugin.lua,
-- cada uno con sus propios "if rad >= X"). El jugador nunca ve el número
-- crudo como protagonista: se le comunica por el NOMBRE del estado (ver
-- hud/cl_plugin.lua, DrawGeigerPanel). El número de fondo sigue existiendo y
-- acumulando igual que antes (char:GetRadiation()), pero es un detalle interno.
ix.badair.radStates = {
	{id = "sano",        min = 0,   name = "Sano",        color = Color(70, 200, 70),
	 desc = "Sin síntomas."},
	{id = "irradiado",   min = 240, name = "Irradiado",   color = Color(210, 200, 40),
	 desc = "Náuseas leves. Busca protección."},
	{id = "contaminado", min = 400, name = "Contaminado", color = Color(210, 130, 30),
	 desc = "El cuerpo empieza a fallar. Necesitas tratamiento."},
	{id = "critico",     min = 600, name = "Crítico",     color = Color(210, 40, 40),
	 desc = "Vas a morir sin tratamiento inmediato."},
}
ix.badair.RAD_DEATH = 800

-- Devuelve la fila de ix.badair.radStates correspondiente a "rad".
function ix.badair.GetRadiationState(rad)
	local current = ix.badair.radStates[1]

	for _, s in ipairs(ix.badair.radStates) do
		if (rad >= s.min) then
			current = s
		end
	end

	return current
end

-- Igual que GetRadiationState pero como índice (0 = sano .. 3 = crítico), para
-- poder reusar directamente tierFX[1..3] en cl_plugin.lua.
function ix.badair.GetRadiationStateIndex(rad)
	for i = #ix.badair.radStates, 1, -1 do
		if (rad >= ix.badair.radStates[i].min) then
			return i - 1
		end
	end

	return 0
end

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("sh_commands.lua")

ix.char.RegisterVar("radiation", {
	field = "radiation",
	fieldType = ix.type.number,
	default = 0,
	isLocal = true,
	bNoDisplay = true,
})

if (SERVER) then
	resource.AddFile("sound/gasmaskon.wav")
	resource.AddFile("sound/gasmaskoff.wav")
	resource.AddFile("sound/gmsk_in.wav")
	resource.AddFile("sound/gmsk_out.wav")
	resource.AddFile("materials/gasmask_fnl.vmt")
	resource.AddFile("materials/gasmask3.vtf")
	resource.AddFile("materials/gasmask3_n.vtf")
	resource.AddFile("materials/shtr_01.vmt")
	resource.AddFile("materials/shtr.vtf")
	resource.AddFile("materials/shtr_n.vtf")
	resource.AddFile("sound/gasmask/watch_timer_alarm_1.wav")
	resource.AddFile("sound/gasmask/watch_timer_alarm_3.wav")
end

-- Duración +60% respecto a los valores originales (150→240 salud, 240→384s
-- de filtro): el max del filtro estaba topado justo en el valor antiguo, así
-- que había que subirlo también o el config lo habría recortado de vuelta.
ix.config.Add("gasmask_health", 240, "Gas mask default health" , nil, {
	data = {min = 10, max = 500},
	category = "Badair"
})

ix.config.Add("gasmask_repair", 50, "How much health a mask recovers per tape (Cinta Americana)" , nil, {
	data = {min = 5, max = 500},
	category = "Badair"
})

-- Base fija en 4 minutos: la habilidad "Técnico de radiación" (ver
-- ix.perks.GetFilterMultiplier en plugins/habilidades/sh_plugin.lua) ya
-- alarga esto hasta ix.perks.filtroMaxDuracion (600s) según el nivel de la
-- habilidad — subir la base aquí directamente reduciría el margen de esa
-- progresión en vez de ser un bonus aparte.
ix.config.Add("gasmask_filter", 240, "How long will the filter last? (In seconds)" , nil, {
	data = {min = 100, max = 240},
	category = "Badair"
})

ALWAYS_RAISED["badair_gasmask_deploy"] = true
ALWAYS_RAISED["badair_gasmask_holster"] = true
ALWAYS_RAISED["badair_gasmask_changefilter"] = true

if (SERVER) then
	local blockedGasMaskClasses = {
		["badair_gasmask_deploy"] = true,
		["badair_gasmask_holster"] = true,
		["badair_gasmask_changefilter"] = true,
	}

	hook.Add("PlayerSwitchWeapon", "ixBadAir_BlockSwitch", function(ply, oldWep, newWep)
		if (IsValid(oldWep) and blockedGasMaskClasses[oldWep:GetClass()]) then
			return true
		end
	end)
end
local PLAYER = FindMetaTable("Player")

function PLAYER:getGasMask()
	return self.ixGasMaskItem 
end

if (CLIENT) then
	local gasmaskTexture2 = Material("gasmask_fnl")
	local gasmaskTexture = Material("shtr_01")
	local w, h, gw, gh, margin, move, healthFactor, ft
	local nextBreath = CurTime()
	local exhale = false

	-- Local function for condition.
	local function canEffect(client)
		return (
			client:GetCharacter() and
			client:getGasMask() and
			!client:ShouldDrawLocalPlayer() and
			(!ix.gui.char or !ix.gui.char:IsVisible())
		)
	end

	shtrPos = {}

	-- El overlay de la máscara va en RenderScreenspaceEffects (antes del HUD)
	-- para que DrawMaterialOverlay no corrompa surface.SetMaterial en HUDPaint.
	hook.Add("RenderScreenspaceEffects", "BadAir_GasMaskOverlay", function()
		if (not canEffect(LocalPlayer())) then return end
		render.UpdateScreenEffectTexture()
		DrawMaterialOverlay("morganicism/metroredux/gasmask/metromask2.vmt", 0.1)
	end)

	-- Solo las grietas (surface 2D puro) permanecen en HUDPaintBackground.
	function PLUGIN:HUDPaintBackground()
		if (canEffect(LocalPlayer())) then
			w, h = ScrW(), ScrH()
			gw, gh = h/3*4, h

			surface.SetMaterial(gasmaskTexture)
			for k, v in ipairs(shtrPos) do
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRectRotated(v[1], v[2], 512*v[3], 512*v[3], v[4])
			end
		end
	end

	function PLUGIN:Think()
		local client = LocalPlayer()
		local item = client:getGasMask()

		if (client:GetCharacter() and client:Alive() and item) then
			healthFactor = math.Clamp(client:Health()/client:GetMaxHealth(), 0, 1)

			if (!client.nextBreath or client.nextBreath < CurTime()) then
				client:EmitSound(!exhale and "metromod/breath_1.wav" or "metromod/breath_1.wav", 
				(LocalPlayer() == client and client:ShouldDrawLocalPlayer() or item:getHealth() <= 0) and 20 or 50, math.random(90, 100) + 15*(1 - healthFactor))
				
				local f = healthFactor*.5
				client.nextBreath = CurTime() + 10 + f + (exhale and f or 0)
				exhale = !exhale
			end
		end
	end

	-- Local functions for the Visibility of the crack.
	local function addCrack()
		table.insert(shtrPos, {math.random(0, ScrW()), math.random(0, ScrH()), math.Rand(.9, 2), math.random(0, 360)})
	end

	local function initCracks(crackNums)
		for i = 1, math.max(crackNums, 1) do
			addCrack()
		end
	end

	netstream.Hook("ixMaskOn", function(id, health)
		local client = LocalPlayer()
		local item = ix.item.instances[id]

		if (item) then
			local crackNums = math.Round((1 - health/item:getMaxHealth())*6)

			shtrPos = {}
			if (crackNums > 1) then
				initCracks(crackNums)
			end

			client.ixGasMaskItem = item
		end
	end)

	netstream.Hook("ixMaskOff", function()
		local client = LocalPlayer()

		client.ixGasMaskItem = nil
	end)

	netstream.Hook("mskAdd", function()
		LocalPlayer():EmitSound("gasmask/gasmask_crack1.wav")

		addCrack()
	end)

	netstream.Hook("badair_filterWarning", function()
		surface.PlaySound("gasmask/watch_timer_alarm_1.wav")
	end)
else
	function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
		if (character) then
			local inv = character:GetInventory()
			local items = inv:GetItems()

			if (items) then
				local gasItem 
				for k, v in pairs(items) do
					if (v.isGasMask) then
						if (v:isEquipped()) then
							gasItem = v
							
							break
						end
					end	
				end

				if (gasItem) then
					client.ixGasMaskItem = gasItem
					netstream.Start(client, "ixMaskOn", gasItem:GetID(), gasItem:getHealth())
				else
					-- Mismo typo que en sh_gasmask.lua: esto dejaba
					-- "ixGasMaskItem" con la referencia de un personaje
					-- anterior si se cambiaba de personaje sin reconectar.
					client.ixGasMaskItem = nil
					netstream.Start(client, "ixMaskOff")
				end
			end
		end
	end

	function PLUGIN:PlayerDeath(client)
		local item = client:getGasMask()

		if (item and item.isGasMask) then
			if (item:isEquipped()) then
				client.ixGasMaskItem = nil
				client:RemovePart(item.uniqueID)
				item:SetData("equip", false)

				netstream.Start(client, "ixMaskOff")
			end
		end
	end

	-- gets two vector and gives min and max vector for Vector:WithinAA(min, max)
	local function sortVector(vector1, vector2)
		local minVector = Vector(0, 0, 0)
		local maxVector = Vector(0, 0, 0)

		for i = 1, 3 do
			if (vector1[i] >= vector2[i]) then
				maxVector[i] = vector1[i]
				minVector[i] = vector2[i]
			else
				maxVector[i] = vector2[i]
				minVector[i] = vector1[i]
			end
		end

		return minVector, maxVector
	end

	-- get all bad air area.
	function ix.badair.getAll()
		return PLUGIN.toxicAreas
	end

	-- Add toxic bad air area.
	function ix.badair.addArea(vMin, vMax)
		vMin, vMax = sortVector(vMin, vMax)

		if (vMin and vMax) then
			table.insert(PLUGIN.toxicAreas, {vMin, vMax})
		end
	end

	-- This hook simulates the damage of the Gas Mask.
	function PLUGIN:EntityTakeDamage(client, dmgInfo)
		if (client and client:IsPlayer()) then
			local item = client:getGasMask()
			local char = client:GetCharacter()

			if (item and item.isGasMask) then
				local damage = dmgInfo:GetDamage() * .35
				item:damageHealth(damage)

				local crackNums = math.Round((1 - item:getHealth()/item:getMaxHealth())*6)

				if (item.curCracks and item.curCracks < crackNums) then
					netstream.Start(client, "mskAdd")
				end

				item.curCracks = crackNums
			end
		end
	end

	function PLUGIN:SaveData()
		if (ix.shuttingDown) then return end

		self:SetData(ix.badair.getAll())
	end
	
	function PLUGIN:LoadData()
		PLUGIN.toxicAreas = self:GetData()
	end

	-- This timer does the effect of bad air.
	timer.Create("badairTick", 1, 0, function()
		for _, client in ipairs(player.GetAll()) do
			local char = client:GetCharacter()
			local clientPos = client:GetPos() + client:OBBCenter()
			client.currentArea = nil

			for index, vec in ipairs((ix.badair.getAll() or {})) do
				if (clientPos:WithinAABox(vec[1], vec[2])) then
					if (client:IsAdmin()) then
						client.currentArea = index
					end

					if (client:Alive() and char and client:GetMoveType() != MOVETYPE_NOCLIP) then
						local item = client:getGasMask()
						local bool

						if (item and item.isGasMask) then
							if (item:getHealth() <= 0) then
								bool = false
							else
								if (item:getFilter() <= 0) then
									bool = false
								else
									bool = true
								end
							end
						else
							bool = false
						end

						if (bool) then
							item:damageFilter(hook.Run("AdjustFilterDrain", client, char) or 1)
							local filterNow = item:getFilter()
							if (filterNow <= 60 and !client.ixFilterWarned) then
								client.ixFilterWarned = true
								netstream.Start(client, "badair_filterWarning")
							end
						else
							client:TakeDamage(3)
							-- Antes ScreenFade blanco crudo; ahora un pulso temático (ver
							-- cl_plugin.lua, "badair_radDamageFlash") coherente con el resto
							-- de efectos visuales de radiación.
							netstream.Start(client, "badair_radDamageFlash")
						end

						break
					end
				end
			end
		end
	end)

	netstream.Start("addArea", function(client, v1, v2)
		if (!client:IsAdmin()) then
			client:Notify(L("notAllowed", client))
		end

		client:notify(L("badairAdded", client))
		ix.badair.addArea(v1, v2)
	end)
end

-- -- This hook is for my other plugin, "Grenade" Plugin.
-- function PLUGIN:CanPlayerTearGassed(client)
-- 	local item = client:getGasMask()

-- 	if (!item) then 
-- 		return true
-- 	else
-- 		if (!item.isGasMask) then
-- 			return true
-- 		elseif (item:getHealth() <= 0) then
-- 			return true
-- 		elseif (item:getFilter() <= 0) then
-- 			return true
-- 		end
-- 	end

-- 	return false
-- end

-- If the player is wearing Gas Mask, His some voice should be muffled a bit.
function PLUGIN:EntityEmitSound(sndTable)
	local client = sndTable.Entity
	if (client and IsValid(client) and client:IsPlayer()) then
		local item = client:getGasMask()

		if (item and item.isGasMask) then
			local sndName = sndTable.SoundName:lower()

			if (sndName:find("male") or sndName:find("voice")) then
				sndTable.DSP = 15
			end
		
			return true
		end
	end
end

ix.command.Add("badairadd", {
	description = "Add an area",
	adminOnly = true,
	OnRun = function(self, client, arguments)
		local pos = client:GetEyeTraceNoCursor().HitPos

		if (!client:GetNetVar("badairMin")) then

			client:SetNetVar("badairMin", pos, client)
			client:Notify(L("badairCommand", client))
		else
			local vMin = client:GetNetVar("badairMin")
			local vMax = pos

			ix.badair.addArea(vMin, vMax)

			client:SetNetVar("badairMin", nil, client)
			client:Notify(L("badairAdded", client))
		end
	end
})

ix.command.Add("badairremove", {
	description = "Remove an area",
	adminOnly = true,
	OnRun = function(self, client, arguments)
		if (client.currentArea) then
			client:Notify(L("badairRemoved", client))

			table.remove(PLUGIN.toxicAreas, client.currentArea)	
		else
			client:Notify(L("badairBeArea", client))
		end
	end
})


// Equip like in metro style

if (SERVER) then

	netstream.Hook("ixGasMask_anim", function(client)
		if (!client:Alive()) then return end

			local character = client:GetCharacter()
				if (!character) then return end
				local inv = character:GetInventory()
				local items = inv:GetItems()

				-- con varias máscaras en el inventario, hay que buscar primero la que
				-- YA está puesta (para quitársela); solo si ninguna está equipada se
				-- coge cualquiera para ponérsela.
				local gasItem
				for k, v in pairs(items) do
					if (v.isGasMask and v:isEquipped()) then
						gasItem = v
						break
					end
				end

				if (!gasItem) then
					for k, v in pairs(items) do
						if (v.isGasMask) then
							gasItem = v
							break
						end
					end
				end

			
			if (gasItem) then
				if (gasItem:isEquipped()) then
					gasItem:EquipMask(client, gasItem, false)
				else
					local activeWep = client:GetActiveWeapon()
					client.previousWep = IsValid(activeWep) and activeWep:GetClass() or "ix_hands"
					client:Give( "badair_gasmask_deploy" )
					client:SelectWeapon("badair_gasmask_deploy")
					client:SetWepRaised(true)
					client:EmitSound("gasmaskon.wav", 80)
					timer.Simple( 1.2, function()
						if (!IsValid(client) or !client:Alive()) then return end
						gasItem:EquipMask(client, gasItem, true)
						client:StripWeapon("badair_gasmask_deploy")
						client:SelectWeapon(client.previousWep or "ix_hands")
						client.previousWep = nil
					end )
					
				end	

			end

	end)

	netstream.Hook("ixGasMask_swapfilter", function(client)
		if (!client:Alive()) then return end

			local character = client:GetCharacter()
				if (!character) then return end
				local inv = character:GetInventory()
				local items = inv:GetItems()

				-- con varias máscaras en el inventario, pairs() no las recorre en orden:
				-- si la primera que tocaba no era la puesta, esto abortaba la función
				-- entera en vez de seguir buscando la que sí está equipada.
				local gasItem
				local filtre
			for k, v in pairs(items) do
				if (v.isGasMask and v:isEquipped()) then
					gasItem = v
					break
				end
			end

			for k, invItem in pairs(items) do
				if (invItem.isFilter) then
					filtre = invItem
					
					break
				end
			end

			
			if (gasItem and filtre and gasItem:canChangeFilter()) then

				local activeWep = client:GetActiveWeapon()
				client.previousWep = IsValid(activeWep) and activeWep:GetClass() or "ix_hands"
				client:Give( "badair_gasmask_changefilter" )
				client:SelectWeapon("badair_gasmask_changefilter")
				client:SetWepRaised(true)
				client:EmitSound("gasmask/change_filter.wav", 80)
				timer.Simple( 1.2, function()
					if (!IsValid(client) or !client:Alive()) then return end
					gasItem:changeFilter(client, gasItem, filtre)
					filtre:Remove()
					client.ixFilterWarned = false
					client:EmitSound("gasmask/watch_timer_alarm_3.wav", 80)
					client:StripWeapon("badair_gasmask_changefilter")
					client:SelectWeapon(client.previousWep or "ix_hands")
					client.previousWep = nil
				end )


			end

	end)

elseif (CLIENT) then
local g_down = 0
local t_down = 0
local maskdelay = CurTime()
local tPrevDown = false
local gPrevDown = false

local function IsMenuOpen()
	local g = ix and ix.gui
	if (g) then
		if (IsValid(g.menu) and not g.menu.bClosing) then return true end
		if (IsValid(g.characterMenu) and not g.characterMenu.bClosing) then return true end
		if (IsValid(g.vendor)) then return true end
		if (IsValid(g.metroInventory)) then return true end
		if (IsValid(g.descEditor)) then return true end
		if (IsValid(g.crafting)) then return true end
		if (IsValid(g.chat) and g.chat:GetActive()) then return true end
	end
	local t = ix and ix.traders
	if (t) then
		if (IsValid(t._dialogueFrame)) then return true end
		if (IsValid(t._tradeFrame)) then return true end
		if (IsValid(t._loreFrame)) then return true end
		if (IsValid(t._adminFrame)) then return true end
	end
	local focus = vgui.GetKeyboardFocus()
	if (IsValid(focus) and focus:GetName() == "DTextEntry") then return true end
	return false
end

	function PLUGIN:Tick()
		if (IsMenuOpen()) then
			g_down = 0
			gPrevDown = false
			t_down = 0
			tPrevDown = false
			return
		end

		if input.IsKeyDown(KEY_G) then

			if (maskdelay < CurTime()) then
			g_down = g_down + 1
			end

			if (g_down > 25) then
				if (!LocalPlayer():Alive()) then return end
				g_down = 0
				maskdelay = CurTime() + 3.2

				netstream.Start("ixGasMask_anim", LocalPlayer())
			end
			gPrevDown = true
		elseif (gPrevDown) then
			if (g_down > 0 and g_down <= 25 and LocalPlayer():Alive()) then
				local char = LocalPlayer():GetCharacter()
				if (char) then
					local inv = char:GetInventory()
					if (inv) then
						for _, itm in pairs(inv:GetItems()) do
							if (itm.uniqueID == "contador_geiger") then
								PLUGIN.geigerHUDEnd = CurTime() + 5
								break
							end
						end
					end
				end
			end
			g_down = 0
			gPrevDown = false
		end

		if input.IsKeyDown(KEY_T) then
			if (maskdelay < CurTime()) then
				t_down = t_down + 1
			end

			if (t_down > 25) then
				if (!LocalPlayer():Alive()) then
					tPrevDown = true
					return
				end
				t_down = 0
				maskdelay = CurTime() + 3.2
				netstream.Start("ixGasMask_swapfilter", LocalPlayer())
			end
			tPrevDown = true
		elseif (tPrevDown) then
			if (t_down > 0 and t_down <= 25) then
				PLUGIN.filterHUDEnd = CurTime() + 5
			end
			t_down = 0
			tPrevDown = false
		end
	end
end

-- Penalización de velocidad por radiación (componible, sin cachear velocidad).
-- SetupMove corre en cliente y servidor para que la predicción coincida con la
-- autoridad, igual que plugins/temperatura/sh_plugin.lua y plugins/handcuffs/
-- sh_plugin.lua. Usa SetMaxClientSpeed en vez de SetWalkSpeed/SetRunSpeed:
-- guardar la velocidad "original" y restaurarla al bajar de 120 era el mismo
-- patrón frágil que causó el bug de las bridas de esta sesión (si otro sistema
-- ya había tocado la velocidad cuando se guardaba, el "original" quedaba mal
-- para siempre). Curva suave (Lerp) en vez de un corte seco: de rad 160 (sin
-- penalización) a rad 500 (-25% de velocidad máxima) — proporcional al tope
-- de muerte de 800 (antes 80→250 sobre un tope de 400).
hook.Add("SetupMove", "ixBadair_speed", function(client, mv)
	local char = client:GetCharacter()
	if (not char) then return end

	local rad = char:GetRadiation()
	if (rad < 160) then return end

	local mult = Lerp(math.Clamp((rad - 160) / 340, 0, 1), 1, 0.75)
	mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
end)
