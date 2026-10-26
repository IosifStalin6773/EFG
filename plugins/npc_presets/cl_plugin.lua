-- ============================================================
--  npc_presets  |  cl_plugin.lua  (CLIENT)
--  Panel de administración de presets, selector de spawn y
--  visualización de puntos de spawn. Estética MetroUI.
-- ============================================================

if (not CLIENT) then return end

ix.npcpresets                  = ix.npcpresets or {}
ix.npcpresets._adminData       = ix.npcpresets._adminData or {}
ix.npcpresets._showPoints      = false
ix.npcpresets._pointsData      = {}
ix.npcpresets._alarmData       = {}
ix.npcpresets._hordeTargetData = {}
ix.npcpresets._patrolWPData    = {}

-- ── Polyfill SetBounds ────────────────────────────────────────
local _PNL = FindMetaTable("Panel")
if (_PNL and not _PNL.SetBounds) then
	_PNL.SetBounds = function(self, x, y, w, h)
		self:SetPos(x, y); self:SetSize(w, h); return self
	end
end

-- ── Fuentes ───────────────────────────────────────────────────
local function registerFonts()
	surface.CreateFont("Metro UI.Button", {
		font = "EFGX Body", extended = true, size = SScale(10), weight = 500, antialias = true,
	})
	surface.CreateFont("Metro UI.CharFields", {
		font = "EFGX Body", extended = true, size = SScale(8), weight = 500, antialias = true,
	})
	surface.CreateFont("ixSmallFont", {
		font = "EFGX Body", extended = true, size = SScale(8), weight = 500, antialias = true,
	})
end
registerFonts()
hook.Add("OnScreenSizeChanged", "npcpresets.Fonts", registerFonts)

-- ── Helpers de estilo (misma estética que missions) ───────────
local PAD = 8
local GAP = 6

local function paintFrame(self, w, h)
	ix.util.DrawBlur(self, 5)
	surface.SetDrawColor(28, 28, 28, 240)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(154, 136, 102, 200)
	surface.DrawRect(0, 0, w, SScale(3))
	surface.SetDrawColor(66, 66, 66, 88)
	surface.DrawOutlinedRect(0, 0, w, h, 2)
end

local function paintDarkEntry(self, w, h)
	surface.SetDrawColor(44, 44, 44, 220)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(88, 88, 88, 160)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	self:DrawTextEntryText(Color(220, 220, 220), Color(112, 128, 130, 180), Color(220, 220, 220))
end

local function makeBtn(parent, text, r, g, b, cb)
	local btn = parent:Add("DButton")
	btn:SetText(text)
	btn:SetFont("Metro UI.CharFields")
	btn:SetTextColor(Color(math.min(r + 120, 255), math.min(g + 120, 255), math.min(b + 120, 255)))
	btn.Paint = function(s, w, h)
		surface.SetDrawColor(r, g, b, s:IsHovered() and 30 or 14)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(r, g, b, s:IsHovered() and 80 or 30)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	btn.DoClick = cb or function() end
	return btn
end

local function makeLabel(parent, text, font, col)
	local l = parent:Add("DLabel")
	l:SetText(text)
	l:SetFont(font or "Metro UI.CharFields")
	l:SetTextColor(col or Color(200, 200, 200))
	return l
end

local function makeEntry(parent, value)
	local e = parent:Add("DTextEntry")
	e:SetFont("Metro UI.CharFields")
	e:SetText(tostring(value or ""))
	e.Paint = paintDarkEntry
	return e
end

-- ============================================================
--  PANEL DE ADMINISTRACIÓN DE PRESETS
-- ============================================================

-- Forward declarations para que buildPresetList pueda referenciar buildEditor
local buildPresetList, buildEditor

buildPresetList = function(frame)
	if (!IsValid(frame) or !IsValid(frame.listScroll)) then return end
	frame.listScroll:Clear()

	local sorted = {}
	for id, preset in pairs(ix.npcpresets._adminData) do
		table.insert(sorted, preset)
	end
	table.sort(sorted, function(a, b) return (a.name or "") < (b.name or "") end)

	for _, preset in ipairs(sorted) do
		local row = frame.listScroll:Add("DButton")
		row:SetText("")
		row:Dock(TOP)
		row:DockMargin(0, 0, 0, 2)
		row:SetTall(SScale(28))

		local isSelected = frame.selectedId == preset.id
		row.Paint = function(s, w, h)
			local bg = isSelected and Color(80, 50, 20, 200) or Color(38, 38, 38, 200)
			surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(154, 136, 102, isSelected and 180 or 50)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(preset.name or "?", "Metro UI.CharFields",
				PAD, h / 2, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if (preset.isHorde) then
				draw.SimpleText("[HORDA]", "ixSmallFont",
					w - PAD, h / 2, Color(154, 136, 102), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			elseif (preset.isPatrol) then
				draw.SimpleText("[PATRULLA]", "ixSmallFont",
					w - PAD, h / 2, Color(112, 128, 130), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText(#(preset.npcs or {}) .. " NPCs", "ixSmallFont",
					w - PAD, h / 2, Color(140, 140, 140), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
		row.DoClick = function()
			frame.selectedId = preset.id
			frame.working    = table.Copy(preset)
			buildPresetList(frame)
			buildEditor(frame)
		end
	end
end

buildEditor = function(frame)
	if (!IsValid(frame) or !IsValid(frame.editScroll)) then return end
	frame.editScroll:Clear()

	local preset = frame.working
	if (!preset) then
		local lbl = makeLabel(frame.editScroll, "Selecciona o crea un preset.", "Metro UI.CharFields", Color(140, 140, 140))
		lbl:Dock(TOP); lbl:SetTall(SScale(20)); lbl:DockMargin(0, PAD, 0, 0)
		return
	end

	local s = frame.editScroll

	-- Nombre
	local lNombre = makeLabel(s, "Nombre", "Metro UI.CharFields", Color(180, 180, 180))
	lNombre:Dock(TOP); lNombre:SetTall(SScale(16))
	local eName = makeEntry(s, preset.name)
	eName:Dock(TOP); eName:SetTall(SScale(20)); eName:DockMargin(0, 2, 0, GAP)

	-- Cooldown
	local lCooldown = makeLabel(s, "Cooldown (segundos)", "Metro UI.CharFields", Color(180, 180, 180))
	lCooldown:Dock(TOP); lCooldown:SetTall(SScale(16))
	local eCooldown = makeEntry(s, preset.cooldown or 60)
	eCooldown:Dock(TOP); eCooldown:SetTall(SScale(20)); eCooldown:DockMargin(0, 2, 0, GAP)

	-- Radio de proximidad
	local lRadius = makeLabel(s, "Radio sin jugadores (u)", "Metro UI.CharFields", Color(180, 180, 180))
	lRadius:Dock(TOP); lRadius:SetTall(SScale(16))
	local eRadius = makeEntry(s, preset.radius or 800)
	eRadius:Dock(TOP); eRadius:SetTall(SScale(20)); eRadius:DockMargin(0, 2, 0, GAP)

	-- Radio de seguridad (spawn radius)
	local lSpawnRadius = makeLabel(s, "Radio de seguridad / presencia (u)", "Metro UI.CharFields", Color(180, 180, 180))
	lSpawnRadius:Dock(TOP); lSpawnRadius:SetTall(SScale(16))
	local eSpawnRadius = makeEntry(s, preset.spawnRadius or 2500)
	eSpawnRadius:Dock(TOP); eSpawnRadius:SetTall(SScale(20)); eSpawnRadius:DockMargin(0, 2, 0, GAP)

	-- Toggle ¿Es Horda?
	local lHorde = makeLabel(s, "Tipo de preset", "Metro UI.CharFields", Color(180, 180, 180))
	lHorde:Dock(TOP); lHorde:SetTall(SScale(16))

	local btnHorde = s:Add("DButton")
	btnHorde:Dock(TOP); btnHorde:SetTall(SScale(22)); btnHorde:DockMargin(0, 2, 0, GAP)
	btnHorde:SetFont("Metro UI.CharFields")

	local function refreshTypeBtn()
		if (preset.isHorde) then
			btnHorde:SetText("⚑  HORDA  —  clic para cambiar a Patrulla")
			btnHorde:SetTextColor(Color(154, 136, 102))
		elseif (preset.isPatrol) then
			btnHorde:SetText("⟳  PATRULLA  —  clic para cambiar a Normal")
			btnHorde:SetTextColor(Color(112, 128, 130))
		else
			btnHorde:SetText("Normal  —  clic para convertir en Horda")
			btnHorde:SetTextColor(Color(140, 140, 140))
		end
	end

	btnHorde.Paint = function(b, w, h)
		local r, g, bb
		if (preset.isHorde) then
			r, g, bb = 70, 45, 38
		elseif (preset.isPatrol) then
			r, g, bb = 30, 55, 70
		else
			r, g, bb = 38, 38, 38
		end
		surface.SetDrawColor(r, g, bb, 200); surface.DrawRect(0, 0, w, h)

		local br, bg2, bbb
		if (preset.isHorde) then
			br, bg2, bbb = 200, 120, 30
		elseif (preset.isPatrol) then
			br, bg2, bbb = 60, 160, 220
		else
			br, bg2, bbb = 66, 66, 66
		end
		local alpha = (preset.isHorde or preset.isPatrol) and 120 or 60
		surface.SetDrawColor(br, bg2, bbb, alpha)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	btnHorde.DoClick = function()
		if (preset.isHorde) then
			preset.isHorde = false
			preset.isPatrol = true
		elseif (preset.isPatrol) then
			preset.isPatrol = false
		else
			preset.isHorde = true
		end
		refreshTypeBtn()
	end
	refreshTypeBtn()

	-- Separador
	local sep = s:Add("DPanel")
	sep:Dock(TOP); sep:SetTall(SScale(1)); sep:DockMargin(0, 4, 0, 4)
	sep.Paint = function(_, w, h) surface.SetDrawColor(66, 66, 66, 180); surface.DrawRect(0, 0, w, h) end

	local lNpcs = makeLabel(s, "NPCs del preset", "Metro UI.CharFields", Color(200, 200, 200))
	lNpcs:Dock(TOP); lNpcs:SetTall(SScale(16))

	preset.npcs = preset.npcs or {}

	-- Panel contenedor de filas de NPC; se reconstruye con rebuildNpcList
	local npcListPanel = s:Add("DPanel")
	npcListPanel:Dock(TOP)
	npcListPanel:SetTall(0)
	npcListPanel.Paint = function() end

	local ROW_H = SScale(30)

	-- Popup reutilizable para añadir o editar una entrada NPC.
	-- initClass/Count/Weapon son los valores iniciales; onConfirm(class, count, weapon) se llama al aceptar.
	local function openNpcPopup(title, initClass, initCount, initWeapon, onConfirm)
		local pw, ph = SScale(290), SScale(185)
		local pop = vgui.Create("DFrame")
		pop:SetSize(pw, ph); pop:Center()
		pop:SetTitle(""); pop:SetDraggable(true)
		pop:ShowCloseButton(false); pop:MakePopup(); pop:SetDeleteOnClose(true)
		pop.Paint = function(self, w, h)
			paintFrame(self, w, h)
			draw.SimpleText(title, "Metro UI.CharFields", PAD, SScale(6), Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		makeLabel(pop, "Clase NPC", "Metro UI.CharFields", Color(160, 160, 160))
			:SetBounds(PAD, SScale(22), pw - PAD * 2, SScale(14))
		local eClass = makeEntry(pop, initClass or "")
		eClass:SetBounds(PAD, SScale(37), pw - PAD * 2, SScale(20))
		eClass:SetPlaceholderText("ej: npc_combine_s  /  DeformedNosach (variantes del spawnmenu)")

		makeLabel(pop, "Cantidad (1-50)", "Metro UI.CharFields", Color(160, 160, 160))
			:SetBounds(PAD, SScale(63), pw - PAD * 2, SScale(14))
		local eCount = makeEntry(pop, tostring(initCount or 1))
		eCount:SetBounds(PAD, SScale(78), pw - PAD * 2, SScale(20))

		makeLabel(pop, "Arma (vacío = arma por defecto)", "Metro UI.CharFields", Color(160, 160, 160))
			:SetBounds(PAD, SScale(104), pw - PAD * 2, SScale(14))
		local eWeapon = makeEntry(pop, initWeapon or "")
		eWeapon:SetBounds(PAD, SScale(119), pw - PAD * 2, SScale(20))
		eWeapon:SetPlaceholderText("ej: tfa_ak74  /  weapon_smg1")

		local halfW = (pw - PAD * 3) / 2
		makeBtn(pop, "Confirmar", 30, 100, 30, function()
			local class  = eClass:GetValue():Trim()
			local count  = math.Clamp(math.floor(tonumber(eCount:GetValue()) or 1), 1, 50)
			local weapon = eWeapon:GetValue():Trim()
			if (class != "") then
				onConfirm(class, count, weapon)
			end
			pop:Remove()
		end):SetBounds(PAD, ph - SScale(28) - PAD, halfW, SScale(24))

		makeBtn(pop, "Cancelar", 130, 30, 30, function()
			pop:Remove()
		end):SetBounds(PAD * 2 + halfW, ph - SScale(28) - PAD, halfW, SScale(24))
	end

	local function rebuildNpcList()
		npcListPanel:Clear()
		for i, npcEntry in ipairs(preset.npcs) do
			local row = npcListPanel:Add("DPanel")
			row:Dock(TOP); row:DockMargin(0, 2, 0, 0); row:SetTall(ROW_H)
			row.Paint = function(_, w, h)
				surface.SetDrawColor(44, 44, 44, 200); surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(66, 66, 66, 80); surface.DrawOutlinedRect(0, 0, w, h, 1)
			end

			-- × Eliminar (Dock RIGHT primero)
			local btnDel = row:Add("DButton")
			btnDel:SetText("×")
			btnDel:SetFont("Metro UI.CharFields")
			btnDel:SetTextColor(Color(200, 80, 80))
			btnDel:Dock(RIGHT)
			btnDel:SetWide(SScale(22))
			btnDel:DockMargin(2, 1, 1, 1)
			btnDel.Paint = function(bs, w, h)
				surface.SetDrawColor(130, 30, 30, bs:IsHovered() and 40 or 12); surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(160, 50, 50, bs:IsHovered() and 100 or 40); surface.DrawOutlinedRect(0, 0, w, h, 1)
			end
			local capturedIdx = i
			btnDel.DoClick = function()
				table.remove(preset.npcs, capturedIdx)
				rebuildNpcList()
			end

			-- ✎ Editar (Dock RIGHT)
			local btnEdit = row:Add("DButton")
			btnEdit:SetText("✎")
			btnEdit:SetFont("Metro UI.CharFields")
			btnEdit:SetTextColor(Color(120, 180, 255))
			btnEdit:Dock(RIGHT)
			btnEdit:SetWide(SScale(22))
			btnEdit:DockMargin(0, 1, 0, 1)
			btnEdit.Paint = function(bs, w, h)
				surface.SetDrawColor(30, 80, 160, bs:IsHovered() and 40 or 12); surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(60, 120, 220, bs:IsHovered() and 100 or 40); surface.DrawOutlinedRect(0, 0, w, h, 1)
			end
			local capturedEntry = npcEntry
			btnEdit.DoClick = function()
				openNpcPopup(
					"Editar NPC",
					capturedEntry.class,
					capturedEntry.count,
					capturedEntry.weapon,
					function(class, count, weapon)
						capturedEntry.class  = class
						capturedEntry.count  = count
						capturedEntry.weapon = weapon
						rebuildNpcList()
					end
				)
			end

			-- ×N cantidad (Dock RIGHT)
			local lCount = row:Add("DLabel")
			lCount:SetFont("ixSmallFont")
			lCount:SetTextColor(Color(180, 180, 100))
			lCount:SetText("×" .. (npcEntry.count or 1))
			lCount:Dock(RIGHT)
			lCount:SetWide(SScale(28))
			lCount:SetContentAlignment(5)

			-- FILL: clase (arriba) + arma (abajo)
			local infoPanel = row:Add("DPanel")
			infoPanel:Dock(FILL)
			infoPanel:DockMargin(PAD, 0, 0, 0)
			infoPanel.Paint = function(_, w, h)
				local wepLabel = (npcEntry.weapon and npcEntry.weapon != "") and npcEntry.weapon or "arma por defecto"
				draw.SimpleText(npcEntry.class or "?", "ixSmallFont", 0, h * 0.25, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(wepLabel,              "ixSmallFont", 0, h * 0.75, Color(120, 180, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
		npcListPanel:SetTall(math.max(1, #preset.npcs * (ROW_H + 2)))
		npcListPanel:InvalidateLayout(true)
	end

	rebuildNpcList()

	-- Botón añadir NPC
	local btnAddNpc = makeBtn(s, "+ Añadir NPC", 30, 100, 30, function()
		openNpcPopup("Añadir NPC", "", 1, "", function(class, count, weapon)
			table.insert(preset.npcs, { class = class, count = count, weapon = weapon })
			rebuildNpcList()
		end)
	end)
	btnAddNpc:Dock(TOP); btnAddNpc:SetTall(SScale(22)); btnAddNpc:DockMargin(0, GAP, 0, GAP)

	-- Botón guardar
	local btnSave = makeBtn(s, "+ Guardar preset", 30, 120, 30, function()
		preset.name        = eName:GetValue():Trim()
		preset.cooldown    = math.max(0, math.floor(tonumber(eCooldown:GetValue()) or 0))
		preset.radius      = math.max(0, math.floor(tonumber(eRadius:GetValue()) or 800))
		preset.spawnRadius = math.max(0, math.floor(tonumber(eSpawnRadius:GetValue()) or 2500))
		preset.isHorde     = preset.isHorde == true
		preset.isPatrol    = preset.isPatrol == true
		if (preset.name == "") then
			LocalPlayer():Notify("El nombre del preset no puede estar vacío.")
			return
		end
		net.Start("npcpresets_AdminSave")
			ix.npcpresets.WriteCompressed(preset)
		net.SendToServer()
	end)
	btnSave:Dock(TOP); btnSave:SetTall(SScale(24)); btnSave:DockMargin(0, PAD, 0, 0)
end

function ix.npcpresets.OpenAdmin()
	if (!LocalPlayer():IsAdmin()) then return end

	if (IsValid(ix.npcpresets._adminPanel)) then ix.npcpresets._adminPanel:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(760), sw - SScale(40))
	local H = math.min(SScale(520), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:Center()
	frame:SetTitle(""); frame:MakePopup(); frame:ShowCloseButton(false); frame:SetDraggable(true)
	frame.Paint = function(self, w, h) paintFrame(self, w, h) end
	ix.npcpresets._adminPanel = frame

	makeLabel(frame, "Administración de Presets de NPCs", "Metro UI.Button", Color(225, 225, 225))
		:SetBounds(PAD, PAD, W - SScale(80), SScale(20))

	makeBtn(frame, "Cerrar", 130, 30, 30, function() frame:Remove() end)
		:SetBounds(W - SScale(60) - PAD, PAD, SScale(60), SScale(20))

	local listW = SScale(200)
	local topY  = SScale(34)

	-- Columna izquierda: lista de presets
	frame.listScroll = frame:Add("DScrollPanel")
	frame.listScroll:SetPos(PAD, topY)
	frame.listScroll:SetSize(listW, H - topY - SScale(34) - PAD)
	frame.listScroll:GetVBar():SetWide(SScale(3))

	makeBtn(frame, "+ Nuevo", 30, 100, 30, function()
		frame.selectedId = nil
		frame.working    = {
			id       = "",  -- el servidor asignará un ID único al guardar
			name     = "Nuevo preset",
			cooldown = 120,
			radius   = 800,
			npcs     = {},
		}
		buildPresetList(frame)
		buildEditor(frame)
	end):SetBounds(PAD, H - SScale(30) - PAD, listW / 2 - 2, SScale(24))

	makeBtn(frame, "Eliminar", 130, 30, 30, function()
		if (!frame.selectedId) then return end
		Derma_Query("¿Eliminar este preset y todos sus puntos de spawn?", "Confirmar",
			"Sí", function()
				net.Start("npcpresets_AdminDelete")
					net.WriteString(frame.selectedId)
				net.SendToServer()
				frame.selectedId = nil; frame.working = nil
				buildPresetList(frame)
				buildEditor(frame)
			end,
			"No", function() end)
	end):SetBounds(PAD + listW / 2 + 2, H - SScale(30) - PAD, listW / 2 - 2, SScale(24))

	-- Columna derecha: editor
	local editX = PAD + listW + GAP
	frame.editScroll = frame:Add("DScrollPanel")
	frame.editScroll:SetPos(editX, topY)
	frame.editScroll:SetSize(W - editX - PAD, H - topY - PAD)
	frame.editScroll:GetVBar():SetWide(SScale(3))

	buildPresetList(frame)
	buildEditor(frame)

	net.Start("npcpresets_AdminRequest")
	net.SendToServer()
end

-- ============================================================
--  SELECTOR DE PRESET PARA SPAWN
-- ============================================================

function ix.npcpresets.OpenSpawnSelector(presets)
	if (IsValid(ix.npcpresets._spawnPanel)) then ix.npcpresets._spawnPanel:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(340), sw - SScale(40))
	local H = math.min(SScale(320), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:Center()
	frame:SetTitle(""); frame:MakePopup(); frame:ShowCloseButton(false); frame:SetDraggable(true)
	frame.Paint = function(self, w, h) paintFrame(self, w, h) end
	ix.npcpresets._spawnPanel = frame

	makeLabel(frame, "Seleccionar Preset para Spawn", "Metro UI.Button", Color(225, 225, 225))
		:SetBounds(PAD, PAD, W - SScale(70), SScale(20))

	makeBtn(frame, "Cancelar", 130, 30, 30, function() frame:Remove() end)
		:SetBounds(W - SScale(60) - PAD, PAD, SScale(60), SScale(20))

	makeLabel(frame, "El punto se colocará donde mirabas al usar /spawnPreset.", "ixSmallFont", Color(130, 130, 130))
		:SetBounds(PAD, SScale(28), W - PAD * 2, SScale(14))

	local scroll = frame:Add("DScrollPanel")
	scroll:SetBounds(PAD, SScale(46), W - PAD * 2, H - SScale(46) - PAD)
	scroll:GetVBar():SetWide(SScale(3))

	table.sort(presets, function(a, b) return (a.name or "") < (b.name or "") end)

	for _, entry in ipairs(presets) do
		local row = scroll:Add("DButton")
		row:SetText("")
		row:Dock(TOP); row:DockMargin(0, 0, 0, 3); row:SetTall(SScale(42))
		row.Paint = function(s, w, h)
			surface.SetDrawColor(38, 38, 38, 220); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(154, 136, 102, s:IsHovered() and 120 or 40)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(entry.name or "?", "Metro UI.CharFields",
				PAD, SScale(7), Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(
				(entry.npcCount or 0) .. " NPC(s)  •  Cooldown: " .. (entry.cooldown or 0) .. "s",
				"ixSmallFont", PAD, SScale(24), Color(140, 140, 140), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
			)
		end
		local capturedId = entry.id
		row.DoClick = function()
			net.Start("npcpresets_SpawnConfirm")
				net.WriteString(capturedId)
			net.SendToServer()
			frame:Remove()
		end
	end
end

-- ============================================================
--  MARCADORES VISUALES DE PUNTOS DE SPAWN
-- ============================================================

-- Dibuja un círculo plano sobre el suelo usando mesh (no se recorta con el frustum de cámara)
local function drawRadiusCircle(mat, pos, radius, color)
	local STEPS = 64
	local r, g, b, a = color.r, color.g, color.b, color.a
	render.SetMaterial(mat)
	mesh.Begin(MATERIAL_LINE_STRIP, STEPS + 1)
		for i = 0, STEPS do
			local angle = (i / STEPS) * math.pi * 2
			mesh.Color(r, g, b, a)
			mesh.Position(pos + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 4))
			mesh.AdvanceVertex()
		end
	mesh.End()
end

-- Material con vertex color para render.DrawSphere (sin esto aparece textura rosa de error)
local _SPHERE_MAT = CreateMaterial("npcpresets_sphere_mat", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$model"]       = 1,
	["$translucent"] = 1,
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$nocull"]      = 1,
})

hook.Add("PostDrawTranslucentRenderables", "npcpresets.DrawMarkers", function(bDepth, bSkybox)
	if (bSkybox) then return end
	if (!ix.npcpresets._showPoints) then return end

	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	local clientPos = client:GetPos()
	local VIEW_RANGE_SQ = 4000 * 4000

	render.SetMaterial(_SPHERE_MAT)

	-- Esferas de puntos de spawn
	for _, point in ipairs(ix.npcpresets._pointsData) do
		local pos = Vector(point.pos.x, point.pos.y, point.pos.z)
		if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
		local col
		if (point.isHorde) then
			col = Color(255, 160, 30, 200)
		elseif (point.isPatrol) then
			col = Color(112, 128, 130, 200)
		else
			col = Color(255, 80, 80, 200)
		end
		render.DrawSphere(pos + Vector(0, 0, 8), 16, 12, 12, col)
	end

	-- Esferas de puntos de alarma (amarillo)
	for _, ap in ipairs(ix.npcpresets._alarmData) do
		local pos = Vector(ap.pos.x, ap.pos.y, ap.pos.z)
		if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
		render.DrawSphere(pos + Vector(0, 0, 8), 12, 12, 12, Color(255, 220, 0, 200))
	end

	-- Esferas de puntos de objetivo de horda (verde)
	for _, ht in ipairs(ix.npcpresets._hordeTargetData) do
		local pos = Vector(ht.pos.x, ht.pos.y, ht.pos.z)
		if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
		render.DrawSphere(pos + Vector(0, 0, 8), 14, 12, 12, Color(50, 220, 80, 200))
	end

	-- Esferas de waypoints de patrulla (cian) + líneas conectando waypoints del mismo punto de spawn
	local patrolByPoint = {}
	for _, wp in ipairs(ix.npcpresets._patrolWPData) do
		local wpPos = Vector(wp.pos.x, wp.pos.y, wp.pos.z)
		if (clientPos:DistToSqr(wpPos) > VIEW_RANGE_SQ) then continue end
		local pid = wp.pointId
		patrolByPoint[pid] = patrolByPoint[pid] or {}
		patrolByPoint[pid][wp.index] = wpPos
		render.DrawSphere(wpPos + Vector(0, 0, 8), 12, 12, 12, Color(112, 128, 130, 200))
	end

	-- Líneas de ruta de patrulla
	for _, positions in pairs(patrolByPoint) do
		local sorted = {}
		for idx, pos in pairs(positions) do
			table.insert(sorted, { idx = idx, pos = pos })
		end
		table.sort(sorted, function(a, b) return a.idx < b.idx end)

		if (#sorted > 1) then
			render.SetMaterial(_SPHERE_MAT)
			for i = 1, #sorted do
				local from = sorted[i].pos + Vector(0, 0, 8)
				local to   = sorted[(i % #sorted) + 1].pos + Vector(0, 0, 8)
				mesh.Begin(MATERIAL_LINES, 1)
					mesh.Color(112, 128, 130, 180)
					mesh.Position(from)
					mesh.AdvanceVertex()
					mesh.Color(112, 128, 130, 180)
					mesh.Position(to)
					mesh.AdvanceVertex()
				mesh.End()
			end
		end
	end

	-- Círculos de radio de proximidad con detección de solapamiento
	-- Verde = sin solapamiento, Naranja = solapa con otro punto
	local pointCount = #ix.npcpresets._pointsData
	if (pointCount > 0) then
		local overlaps = {}
		for i = 1, pointCount do
			local pA  = ix.npcpresets._pointsData[i]
			local posA = Vector(pA.pos.x, pA.pos.y, pA.pos.z)
			local rA   = pA.radius or 800
			overlaps[i] = false
			for j = 1, pointCount do
				if (i == j) then continue end
				local pB   = ix.npcpresets._pointsData[j]
				local posB = Vector(pB.pos.x, pB.pos.y, pB.pos.z)
				local rB   = pB.radius or 800
				local rSum = rA + rB
				if (posA:DistToSqr(posB) < rSum * rSum) then
					overlaps[i] = true
					break
				end
			end
		end

		for i, point in ipairs(ix.npcpresets._pointsData) do
			local pos  = Vector(point.pos.x, point.pos.y, point.pos.z)
			if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
			local col  = overlaps[i]
				and Color(154, 136, 102, 220)   -- naranja: solapa
				or  Color(60, 220, 80, 220)   -- verde: libre
			drawRadiusCircle(_SPHERE_MAT, pos, point.radius or 800, col)
		end
	end

	-- Círculos de radio de presencia (spawnRadius) — azul
	for _, point in ipairs(ix.npcpresets._pointsData) do
		local pos = Vector(point.pos.x, point.pos.y, point.pos.z)
		if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
		drawRadiusCircle(_SPHERE_MAT, pos, point.spawnRadius or 2500, Color(112, 128, 130, 160))
	end

	cam.Start2D()
		for _, point in ipairs(ix.npcpresets._pointsData) do
			local pos    = Vector(point.pos.x, point.pos.y, point.pos.z)
			if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
			local screen = (pos + Vector(0, 0, 40)):ToScreen()
			if (!screen.visible) then continue end
			local prefix = point.isHorde and "⚑ " or (point.isPatrol and "⟳ " or "")
			local label  = prefix .. (point.presetName or "?")
			local col    = point.isHorde and Color(154, 136, 102, 255) or (point.isPatrol and Color(112, 128, 130, 255) or Color(255, 80, 80, 255))
			local radInfo = "R.prox " .. (point.radius or 800) .. "u  |  R.spawn " .. (point.spawnRadius or 2500) .. "u"
			draw.SimpleText(label,   "BudgetLabel", screen.x + 1, screen.y + 1,  Color(0, 0, 0, 200),       TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(label,   "BudgetLabel", screen.x,     screen.y,       col,                       TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(radInfo, "BudgetLabel", screen.x + 1, screen.y + 15,  Color(0, 0, 0, 200),       TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(radInfo, "BudgetLabel", screen.x,     screen.y + 14,  Color(112, 128, 130, 220),  TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		for _, ap in ipairs(ix.npcpresets._alarmData) do
			local pos    = Vector(ap.pos.x, ap.pos.y, ap.pos.z)
			if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
			local screen = (pos + Vector(0, 0, 40)):ToScreen()
			if (!screen.visible) then continue end
			local label = "ALARMA: " .. (ap.presetName or "?")
			draw.SimpleText(label, "BudgetLabel", screen.x + 1, screen.y + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(label, "BudgetLabel", screen.x,     screen.y,     Color(255, 220, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		for _, ht in ipairs(ix.npcpresets._hordeTargetData) do
			local pos    = Vector(ht.pos.x, ht.pos.y, ht.pos.z)
			if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
			local screen = (pos + Vector(0, 0, 40)):ToScreen()
			if (!screen.visible) then continue end
			local label = "> OBJETIVO: " .. (ht.presetName or "?")
			draw.SimpleText(label, "BudgetLabel", screen.x + 1, screen.y + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(label, "BudgetLabel", screen.x,     screen.y,     Color(80, 255, 100, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		for _, wp in ipairs(ix.npcpresets._patrolWPData) do
			local pos    = Vector(wp.pos.x, wp.pos.y, wp.pos.z)
			if (clientPos:DistToSqr(pos) > VIEW_RANGE_SQ) then continue end
			local screen = (pos + Vector(0, 0, 40)):ToScreen()
			if (!screen.visible) then continue end
			local label = "⟳ WP#" .. wp.index .. "/" .. wp.total .. ": " .. (wp.presetName or "?")
			draw.SimpleText(label, "BudgetLabel", screen.x + 1, screen.y + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(label, "BudgetLabel", screen.x,     screen.y,     Color(112, 128, 130, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	cam.End2D()
end)

-- ============================================================
--  RECEPTORES DE RED
-- ============================================================

net.Receive("npcpresets_AdminOpen", function()
	ix.npcpresets.OpenAdmin()
end)

net.Receive("npcpresets_AdminData", function()
	ix.npcpresets._adminData = ix.npcpresets.ReadCompressed()

	local panel = ix.npcpresets._adminPanel
	if (!IsValid(panel)) then return end

	buildPresetList(panel)

	if (panel.selectedId and ix.npcpresets._adminData[panel.selectedId]) then
		panel.working = table.Copy(ix.npcpresets._adminData[panel.selectedId])
		buildEditor(panel)
	end
end)

net.Receive("npcpresets_SpawnOpen", function()
	local list = ix.npcpresets.ReadCompressed()
	ix.npcpresets.OpenSpawnSelector(list)
end)

net.Receive("npcpresets_PointsData", function()
	local data            = ix.npcpresets.ReadCompressed()
	local points          = data.points          or {}
	local alarmPoints     = data.alarmPoints      or {}
	local hordeTargets    = data.hordeTargets     or {}
	local patrolWaypoints = data.patrolWaypoints  or {}

	-- Push de actualización automática: solo actualizar datos sin cambiar el toggle
	if (data.isUpdate) then
		if (ix.npcpresets._showPoints) then
			ix.npcpresets._pointsData      = points
			ix.npcpresets._alarmData        = alarmPoints
			ix.npcpresets._hordeTargetData  = hordeTargets
			ix.npcpresets._patrolWPData     = patrolWaypoints
		end
		return
	end

	-- Toggle manual (/npcMostrar)
	if (ix.npcpresets._showPoints) then
		ix.npcpresets._showPoints      = false
		ix.npcpresets._pointsData      = {}
		ix.npcpresets._alarmData        = {}
		ix.npcpresets._hordeTargetData  = {}
		ix.npcpresets._patrolWPData     = {}
		LocalPlayer():Notify("[NPC Presets] Puntos ocultos.")
	else
		if (#points == 0 and #alarmPoints == 0 and #hordeTargets == 0 and #patrolWaypoints == 0) then
			LocalPlayer():Notify("[NPC Presets] No hay puntos configurados.")
			return
		end
		ix.npcpresets._showPoints      = true
		ix.npcpresets._pointsData      = points
		ix.npcpresets._alarmData        = alarmPoints
		ix.npcpresets._hordeTargetData  = hordeTargets
		ix.npcpresets._patrolWPData     = patrolWaypoints
		LocalPlayer():Notify("[NPC Presets] Mostrando " .. #points .. " spawn(s), " .. #alarmPoints .. " alarma(s), " .. #hordeTargets .. " objetivo(s) y " .. #patrolWaypoints .. " waypoint(s).")
	end
end)

net.Receive("npcpresets_HordeOpen", function()
	local list = ix.npcpresets.ReadCompressed()
	if (IsValid(ix.npcpresets._hordePanel)) then ix.npcpresets._hordePanel:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(340), sw - SScale(40))
	local H = math.min(SScale(300), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:Center()
	frame:SetTitle(""); frame:MakePopup(); frame:ShowCloseButton(false); frame:SetDraggable(true)
	frame.Paint = function(self, w, h) paintFrame(self, w, h) end
	ix.npcpresets._hordePanel = frame

	makeLabel(frame, "⚑  Activar Horda", "Metro UI.Button", Color(255, 180, 50))
		:SetBounds(PAD, PAD, W - SScale(70), SScale(20))
	makeBtn(frame, "Cancelar", 130, 30, 30, function() frame:Remove() end)
		:SetBounds(W - SScale(60) - PAD, PAD, SScale(60), SScale(20))

	local scroll = frame:Add("DScrollPanel")
	scroll:SetBounds(PAD, SScale(34), W - PAD * 2, H - SScale(34) - PAD)
	scroll:GetVBar():SetWide(SScale(3))

	table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)

	for _, entry in ipairs(list) do
		local row = scroll:Add("DButton")
		row:SetText(""); row:Dock(TOP); row:DockMargin(0, 0, 0, 3); row:SetTall(SScale(40))
		row.Paint = function(s, w, h)
			surface.SetDrawColor(50, 35, 10, 220); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(200, 130, 30, s:IsHovered() and 140 or 50)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText("⚑  " .. (entry.name or "?"), "Metro UI.CharFields",
				PAD, SScale(7), Color(255, 200, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText((entry.npcCount or 0) .. " NPC(s)", "ixSmallFont",
				PAD, SScale(24), Color(160, 140, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
		local capturedId = entry.id
		row.DoClick = function()
			net.Start("npcpresets_HordeActivate")
				net.WriteString(capturedId)
			net.SendToServer()
			frame:Remove()
		end
	end
end)

net.Receive("npcpresets_AlarmOpen", function()
	local list = ix.npcpresets.ReadCompressed()
	if (IsValid(ix.npcpresets._alarmPanel)) then ix.npcpresets._alarmPanel:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(340), sw - SScale(40))
	local H = math.min(SScale(280), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:Center()
	frame:SetTitle(""); frame:MakePopup(); frame:ShowCloseButton(false); frame:SetDraggable(true)
	frame.Paint = function(self, w, h) paintFrame(self, w, h) end
	ix.npcpresets._alarmPanel = frame

	makeLabel(frame, "Asignar punto de alarma a Horda", "Metro UI.Button", Color(255, 220, 50))
		:SetBounds(PAD, PAD, W - SScale(70), SScale(20))
	makeBtn(frame, "Cancelar", 130, 30, 30, function() frame:Remove() end)
		:SetBounds(W - SScale(60) - PAD, PAD, SScale(60), SScale(20))

	local scroll = frame:Add("DScrollPanel")
	scroll:SetBounds(PAD, SScale(34), W - PAD * 2, H - SScale(34) - PAD)
	scroll:GetVBar():SetWide(SScale(3))

	table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)

	for _, entry in ipairs(list) do
		local row = scroll:Add("DButton")
		row:SetText(""); row:Dock(TOP); row:DockMargin(0, 0, 0, 3); row:SetTall(SScale(36))
		row.Paint = function(s, w, h)
			surface.SetDrawColor(40, 40, 10, 220); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(200, 200, 30, s:IsHovered() and 120 or 40)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(entry.name or "?", "Metro UI.CharFields",
				PAD, h / 2, Color(230, 220, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		local capturedId = entry.id
		row.DoClick = function()
			net.Start("npcpresets_AlarmConfirm")
				net.WriteString(capturedId)
			net.SendToServer()
			frame:Remove()
		end
	end
end)

net.Receive("npcpresets_HordeTargetOpen", function()
	local list = ix.npcpresets.ReadCompressed()
	if (IsValid(ix.npcpresets._hordeTargetPanel)) then ix.npcpresets._hordeTargetPanel:Remove() end

	local sw, sh = ScrW(), ScrH()
	local W = math.min(SScale(340), sw - SScale(40))
	local H = math.min(SScale(280), sh - SScale(40))

	local frame = vgui.Create("DFrame")
	frame:SetSize(W, H); frame:Center()
	frame:SetTitle(""); frame:MakePopup(); frame:ShowCloseButton(false); frame:SetDraggable(true)
	frame.Paint = function(self, w, h) paintFrame(self, w, h) end
	ix.npcpresets._hordeTargetPanel = frame

	makeLabel(frame, ">  Asignar objetivo de horda", "Metro UI.Button", Color(80, 255, 100))
		:SetBounds(PAD, PAD, W - SScale(70), SScale(20))
	makeBtn(frame, "Cancelar", 130, 30, 30, function() frame:Remove() end)
		:SetBounds(W - SScale(60) - PAD, PAD, SScale(60), SScale(20))

	local scroll = frame:Add("DScrollPanel")
	scroll:SetBounds(PAD, SScale(34), W - PAD * 2, H - SScale(34) - PAD)
	scroll:GetVBar():SetWide(SScale(3))

	table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)

	for _, entry in ipairs(list) do
		local row = scroll:Add("DButton")
		row:SetText(""); row:Dock(TOP); row:DockMargin(0, 0, 0, 3); row:SetTall(SScale(36))
		row.Paint = function(s, w, h)
			surface.SetDrawColor(10, 40, 20, 220); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(30, 200, 80, s:IsHovered() and 120 or 40)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(">  " .. (entry.name or "?"), "Metro UI.CharFields",
				PAD, h / 2, Color(100, 240, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		local capturedId = entry.id
		row.DoClick = function()
			net.Start("npcpresets_HordeTargetConfirm")
				net.WriteString(capturedId)
			net.SendToServer()
			frame:Remove()
		end
	end
end)

net.Receive("npcpresets_PlayAlarm", function()
	local hasPos = net.ReadBool()
	local pos    = hasPos and net.ReadVector() or nil

	-- ── Sonido de alarma ──────────────────────────────────────────
	-- Cambia "warningbell1" / "warningbell2" por cualquier path de HL2 base.
	-- Otras opciones: "ambient/alarms/klaxon1.wav" / "ambient/alarms/alarm1.wav"
	local B1 = "musikmetro/metroll/bell.wav"
	local B2 = "musikmetro/metroll/bell.wav"

	-- 21 campanas con ritmo irregular que simula llamada urgente al combate
	local ALARM_SOUNDS = {
		B1, B2, B1, B2,          -- ráfaga inicial rápida
		B1, B2, B1,               -- pausa + 3
		B2, B1, B2, B1, B2,       -- subida de intensidad
		B1, B2,                   -- pausa corta
		B1, B2, B1, B2,           -- repique sostenido
		B1, B2, B1,               -- cierre acelerado
	}
	local ALARM_DELAYS = {
		0,    0.35, 0.70, 1.05,   -- ráfaga inicial
		1.70, 2.05, 2.40,         -- tras pausa
		3.00, 3.30, 3.60, 3.90, 4.20,  -- subida
		4.80, 5.10,               -- pausa corta
		5.65, 5.95, 6.25, 6.55,   -- repique
		7.05, 7.30, 7.55,         -- cierre
	}

	local function playBell(snd)
		if (pos) then
			-- Sonido 3D desde el punto de alarma; se atenúa con la distancia
			sound.Play(snd, pos, 110, 100, 1)
		else
			surface.PlaySound(snd)
		end
	end

	for i, snd in ipairs(ALARM_SOUNDS) do
		local delay = ALARM_DELAYS[i]
		local capturedSnd = snd
		if (delay == 0) then
			playBell(capturedSnd)
		else
			timer.Simple(delay, function() playBell(capturedSnd) end)
		end
	end
end)
