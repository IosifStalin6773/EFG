-- Diálogo de flujo en el cliente (fase 4c). Se abre desde la opción del menú de comerciante.
-- El servidor lleva el recorrido; aquí solo se muestra el nodo y se manda la opción elegida.

ix.flujo = ix.flujo or {}
ix.flujo.branchTraders = ix.flujo.branchTraders or {}

net.Receive("flujo_Branches", function()
	local list = net.ReadTable() or {}
	ix.flujo.branchTraders = {}
	for _, key in ipairs(list) do ix.flujo.branchTraders[key] = true end
end)

function ix.flujo.HasBranchGraph(key)
	return ix.flujo.branchTraders[key] == true
end

local frame, currentTrader

local function closeFrame()
	if (IsValid(frame)) then frame:Remove() end
	frame = nil
end

local function chooseOption(index)
	if (!IsValid(currentTrader)) then closeFrame() return end

	net.Start("flujo_Choose")
		net.WriteEntity(currentTrader)
		net.WriteUInt(index, 4)
	net.SendToServer()
end

local function showNode(payload)
	closeFrame()
	if (payload.type == "fin") then return end

	frame = vgui.Create("DFrame")
	frame:SetSize(640, 260)
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:MakePopup()

	local text = frame:Add("DLabel")
	text:SetPos(16, 16)
	text:SetSize(608, 110)
	text:SetWrap(true)
	text:SetFont("efgui.Normal")
	text:SetText(payload.text or "")

	local y = 136
	for i, label in ipairs(payload.options or {}) do
		local btn = frame:Add("DButton")
		btn:SetPos(16, y)
		btn:SetSize(608, 26)
		btn:SetText(label)
		btn:SetFont("efgui.Normal")
		if (ix.efgui and ix.efgui.StyleButton) then
			ix.efgui.StyleButton(btn, "efgui.Normal")
		end
		btn.DoClick = function() chooseOption(i) end
		y = y + 30
	end

	local close = frame:Add("DButton")
	close:SetPos(16, 226)
	close:SetSize(608, 24)
	close:SetText("Cerrar")
	close:SetFont("efgui.Normal")
	close.DoClick = function() closeFrame() end
end

net.Receive("flujo_Node", function()
	local ok = net.ReadBool()
	if (!ok) then
		local msg = net.ReadString()
		closeFrame()
		if (IsValid(LocalPlayer())) then LocalPlayer():ChatPrint(msg) end
		return
	end

	showNode(net.ReadTable() or {})
end)

-- El menú de comerciante llama a esta acción al elegir "Tengo algo que preguntarte."
hook.Add("TraderDialogueAction", "flujo_npc_dialogue", function(action, ent, closeAll)
	if (action != "flujo") then return end

	currentTrader = ent
	if (closeAll) then closeAll() end

	net.Start("flujo_Start")
		net.WriteEntity(ent)
	net.SendToServer()

	return true
end)
