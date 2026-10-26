local PLUGIN = PLUGIN
local hideout = ix.efg.hideout

local colorText   = Color(199, 197, 179)
local colorQuiet  = Color(130, 128, 116)
local colorGood   = Color(106, 150, 64)
local colorBad    = Color(196, 60, 51)

local function buildPanel(state)
	if (IsValid(ix.gui.efgHideout)) then
		ix.gui.efgHideout:Remove()
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(math.min(ScrW() - 40, 760), math.min(ScrH() - 40, 640))
	frame:Center()
	frame:SetTitle("Escondite")
	frame:MakePopup()
	frame:DockPadding(8, ix.efgui.Scale(30) + 6, 8, 8)
	ix.efgui.StyleFrame(frame, "ESCONDITE")
	ix.gui.efgHideout = frame

	local scroll = frame:Add("DScrollPanel")
	scroll:Dock(FILL)

	for _, entry in ipairs(state) do
		local module = hideout.byID[entry.id]

		if (module) then
			local row = scroll:Add("DPanel")
			row:Dock(TOP)
			row:DockMargin(0, 0, 0, 6)
			row:DockPadding(10, 8, 10, 8)
			row.Paint = function(_, w, h)
				ix.efgui.DrawPanel(0, 0, w, h, 255)
				surface.SetDrawColor(ix.efgui.color.accent)
				surface.DrawRect(0, 0, 2, h)
			end

			local title = row:Add("DLabel")
			title:Dock(TOP)
			title:SetFont("efgui.Header")
			title:SetTextColor(colorText)
			title:SetText(("%s  ·  nivel %d/%d"):format(module.name, entry.level, entry.maxLevel))
			title:SizeToContents()

			local description = row:Add("DLabel")
			description:Dock(TOP)
			description:SetFont("efgui.Small")
			description:SetTextColor(colorQuiet)
			description:SetText(module.description)
			description:SetWrap(true)
			description:SetAutoStretchVertical(true)

			local height = 60

			if (entry.level < entry.maxLevel) then
				local header = row:Add("DLabel")
				header:Dock(TOP)
				header:DockMargin(0, 6, 0, 0)
				header:SetFont("efgui.Small")
				header:SetTextColor(colorText)
				header:SetText(("Para el nivel %d:"):format(entry.level + 1))
				header:SizeToContents()

				for _, requirement in ipairs(entry.requirements) do
					local line = row:Add("DLabel")
					line:Dock(TOP)
					line:SetFont("efgui.Small")
					line:SetTextColor(requirement.met and colorGood or colorBad)
					line:SetText("  • " .. requirement.text)
					line:SizeToContents()
					height = height + line:GetTall()
				end

				local button = row:Add("DButton")
				button:Dock(TOP)
				button:DockMargin(0, 6, 0, 0)
				button:SetTall(26)
				button:SetText(entry.canUpgrade and "Mejorar" or "Faltan requisitos")
				button:SetEnabled(entry.canUpgrade)
				ix.efgui.StyleButton(button)
				button.DoClick = function()
					net.Start("ixEFGHideoutUpgrade")
						net.WriteString(entry.id)
					net.SendToServer()
				end

				height = height + 60
			else
				local maxed = row:Add("DLabel")
				maxed:Dock(TOP)
				maxed:DockMargin(0, 6, 0, 0)
				maxed:SetFont("efgui.Small")
				maxed:SetTextColor(colorGood)
				maxed:SetText("Nivel máximo")
				maxed:SizeToContents()
			end

			-- el alto de la fila se ajusta a lo que contiene
			row:SetTall(height + 20)
			row.PerformLayout = function(me)
				local bottom = 0

				for _, child in ipairs(me:GetChildren()) do
					local _, y = child:GetPos()
					bottom = math.max(bottom, y + child:GetTall())
				end

				if (bottom > 0 and me:GetTall() != bottom + 8) then
					me:SetTall(bottom + 8)
				end
			end
		end
	end
end

net.Receive("ixEFGHideoutState", function()
	buildPanel(net.ReadTable())
end)
