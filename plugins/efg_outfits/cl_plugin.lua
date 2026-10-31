local PLUGIN = PLUGIN
local outfits = ix.efg.outfits

-- ─── Ropa y equipo con bonemerge ─────────────────────────────────────────────
-- Para cada jugador o cadáver con la netvar efgOutfit/efgAttach se crean
-- modelos de cliente pegados a su esqueleto. Se rehacen cuando cambian.

local attached = {} -- [entity] = {sig =, models = {}}
local HIDE_DIST_SQR = 2500 * 2500

local function clear(entity)
	local entry = attached[entity]
	if (!entry) then return end

	for _, model in ipairs(entry.models) do
		if (IsValid(model)) then model:Remove() end
	end

	attached[entity] = nil
end

local function bonemerge(entity, path, bodygroup)
	local model = ClientsideModel(path, RENDERGROUP_OPAQUE)
	if (!IsValid(model)) then return end

	model:SetParent(entity)
	model:AddEffects(EF_BONEMERGE)
	model:AddEffects(EF_BONEMERGE_FASTCULL)
	model:SetupBones()

	if (bodygroup) then model:SetBodygroup(0, bodygroup) end

	return model
end

local function wanted(entity)
	local set = outfits.GetSet(entity:GetModel())
	local outfit = set and entity:GetNetVar("efgOutfit")
	local attach = entity:GetNetVar("efgAttach")
	local sig = entity:GetModel() .. "|" .. (outfit and (outfit[1] .. "," .. outfit[2]) or "-") .. "|" .. (attach and table.concat(attach, ";") or "")

	return sig, set, outfit, attach
end

local function rebuild(entity)
	clear(entity)

	local sig, set, outfit, attach = wanted(entity)
	local entry = {sig = sig, models = {}}

	if (set and outfit) then
		entry.models[#entry.models + 1] = bonemerge(entity, set.top, outfit[1])
		entry.models[#entry.models + 1] = bonemerge(entity, set.legs, outfit[2])
	end

	for _, path in ipairs(attach or {}) do
		entry.models[#entry.models + 1] = bonemerge(entity, path)
	end

	attached[entity] = entry
end

local nextScan = 0

hook.Add("Think", "efgOutfits", function()
	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	-- ¿quién necesita ropa? cada medio segundo
	if (nextScan < CurTime()) then
		nextScan = CurTime() + 0.5

		local candidates = player.GetAll()
		for _, ragdoll in ipairs(ents.FindByClass("prop_ragdoll")) do candidates[#candidates + 1] = ragdoll end

		for _, entity in ipairs(candidates) do
			local has = entity:GetNetVar("efgOutfit") or entity:GetNetVar("efgAttach")
			local entry = attached[entity]

			if (has and !entity:IsDormant()) then
				if (!entry or entry.sig != wanted(entity)) then rebuild(entity) end
			elseif (entry) then
				clear(entity)
			end
		end

		for entity in pairs(attached) do
			if (!IsValid(entity)) then clear(entity) end
		end
	end

	-- ocultar: en primera persona, muertos, invisibles o lejos
	local eye = client:EyePos()

	for entity, entry in pairs(attached) do
		if (IsValid(entity)) then
			local hide = entity:GetNoDraw() or (entity:IsPlayer() and (!entity:Alive() or (entity == client and !client:ShouldDrawLocalPlayer())))
				or (entity != client and entity:GetPos():DistToSqr(eye) > HIDE_DIST_SQR)

			for _, model in ipairs(entry.models) do
				if (IsValid(model)) then model:SetNoDraw(hide) end
			end
		end
	end
end)

hook.Add("EntityRemoved", "efgOutfits", function(entity)
	if (attached[entity]) then clear(entity) end
end)

-- ─── Elegir atuendo (/Atuendo) ───────────────────────────────────────────────
local PANEL = {}

function PANEL:Init()
	local UI = ix.efgui
	local S = UI.Scale
	local client = LocalPlayer()

	self.set = outfits.GetSet(client:GetModel())
	local current = client:GetNetVar("efgOutfit") or {0, 0}
	self.head = table.KeyFromValue(self.set.heads, string.lower(client:GetModel())) or 1
	self.top, self.legs = current[1], current[2]

	self:SetSize(S(520), S(720))
	self:Center()
	self:MakePopup()
	surface.PlaySound("efg/ui/click.wav")

	self.preview = self:Add("DModelPanel")
	self.preview:SetPos(S(20), S(56))
	self.preview:SetSize(S(480), S(470))
	self.preview:SetFOV(32)
	self.preview:SetCamPos(Vector(80, 0, 50))
	self.preview:SetLookAt(Vector(0, 0, 38))
	self.preview.LayoutEntity = function(this, entity)
		entity:SetAngles(Angle(0, RealTime() * 25 % 360, 0))
	end
	self.preview.PostDrawModel = function(this, entity)
		for _, model in ipairs(this.extra or {}) do
			if (IsValid(model)) then model:DrawModel() end
		end
	end
	self.preview.OnRemove = function(this)
		for _, model in ipairs(this.extra or {}) do
			if (IsValid(model)) then model:Remove() end
		end
	end

	local rows = {
		{"CABEZA", function() return self.head end, function(v) self.head = v end, #self.set.heads, 1},
		{"CHAQUETA", function() return self.top end, function(v) self.top = v end, self.set.tops, 0},
		{"PANTALÓN", function() return self.legs end, function(v) self.legs = v end, self.set.legsCount, 0}
	}

	for i, row in ipairs(rows) do
		local y = S(536) + (i - 1) * S(40)
		local label = self:Add("DLabel")
		label:SetPos(S(20), y)
		label:SetSize(S(160), S(34))
		label:SetFont("efgx.Header")
		label:SetTextColor(UI.color.text)
		label:SetText(row[1])

		local value = self:Add("DLabel")
		value:SetPos(S(240), y)
		value:SetSize(S(140), S(34))
		value:SetFont("efgx.Num")
		value:SetContentAlignment(5)
		value:SetTextColor(UI.color.text)
		value.Think = function(this)
			this:SetText(("%d / %d"):format(row[2]() + 1 - row[5], row[4]))
		end

		for j, dir in ipairs({-1, 1}) do
			local btn = self:Add("DButton")
			btn:SetPos(j == 1 and S(196) or S(392), y)
			btn:SetSize(S(40), S(34))
			btn:SetText(dir < 0 and "<" or ">")
			UI.StyleButton(btn, "efgx.Header", "ghost")
			btn.DoClick = function()
				local count = row[4]
				local v = (row[2]() - row[5] + dir) % count + row[5]
				row[3](v)
				surface.PlaySound("efg/ui/hover.wav")
				self:UpdatePreview()
			end
		end
	end

	local save = self:Add("DButton")
	save:SetPos(S(20), S(664))
	save:SetSize(S(230), S(40))
	save:SetText("GUARDAR")
	UI.StyleButton(save, "efgx.Header", "primary")
	save.DoClick = function()
		net.Start("ixEFGOutfitSave")
			net.WriteUInt(self.head, 4)
			net.WriteUInt(self.top, 8)
			net.WriteUInt(self.legs, 8)
		net.SendToServer()
		surface.PlaySound("efg/ui/click.wav")
		self:Remove()
	end

	local close = self:Add("DButton")
	close:SetPos(S(270), S(664))
	close:SetSize(S(230), S(40))
	close:SetText("CANCELAR")
	UI.StyleButton(close, "efgx.Header", "ghost")
	close.DoClick = function()
		surface.PlaySound("efg/ui/return.wav")
		self:Remove()
	end

	self:UpdatePreview()
end

function PANEL:UpdatePreview()
	local preview = self.preview
	preview:SetModel(self.set.heads[self.head])

	for _, model in ipairs(preview.extra or {}) do
		if (IsValid(model)) then model:Remove() end
	end

	preview.extra = {}

	local entity = preview:GetEntity()
	if (!IsValid(entity)) then return end

	for _, part in ipairs({{self.set.top, self.top}, {self.set.legs, self.legs}}) do
		local model = ClientsideModel(part[1], RENDERGROUP_OTHER)

		if (IsValid(model)) then
			model:SetNoDraw(true)
			model:SetParent(entity)
			model:AddEffects(EF_BONEMERGE)
			model:SetBodygroup(0, part[2])
			preview.extra[#preview.extra + 1] = model
		end
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then self:Remove() end
end

function PANEL:Paint(w, h)
	local UI = ix.efgui
	UI.DrawPanel(0, 0, w, h, 245)
	UI.DrawHeader(0, 0, w, UI.Scale(40), "ATUENDO " .. self.set.name)
end

vgui.Register("efgxOutfit", PANEL, "EditablePanel")

net.Receive("ixEFGOutfitMenu", function()
	if (IsValid(ix.gui.efgOutfit)) then ix.gui.efgOutfit:Remove() end
	if (!outfits.GetSet(LocalPlayer():GetModel())) then return end

	ix.gui.efgOutfit = vgui.Create("efgxOutfit")
end)
