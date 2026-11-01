local PLUGIN = PLUGIN
PLUGIN.name = 'Mesa de crafteo'
PLUGIN.author = "EFG Project" -- original: Private

PLUGIN.netNameRecipe = ('%s.CraftRecipe'):format(PLUGIN.name)
PLUGIN.netNameBlueprint = ('%s.CraftBlueprint'):format(PLUGIN.name)

PLUGIN.netNameCraftingGUI = ('%s.CraftingStationGUI'):format(PLUGIN.name)
PLUGIN.netNameStoveGUI = ('%s.StoveGUI'):format(PLUGIN.name)
PLUGIN.netNameDismantle = ('%s.DismantleBlueprint'):format(PLUGIN.name)

PLUGIN.categoriesIcons = {
	--- @field craft
	['Armaduras']   = 'efgui/icons/craft/armor.png',
	['Armas']       = 'efgui/icons/craft/guns.png',
	['Accesorios']  = 'efgui/icons/craft/guns.png',
	['Munición']    = 'efgui/icons/craft/ammo.png',
	['Medicinas']    = 'efgui/icons/craft/medicaments.png',
	['Drogas']      = 'efgui/icons/craft/medicaments.png',
	['Quimicos'] = 'efgui/icons/clay.png',
	['Materiales'] = 'efgui/icons/fragments_icon.png',
	['Aprendizaje'] = 'efgui/icons/skills_icon.png',
	['Mochilas']    = 'efgui/icons/icon_inventory64.png',
	['Comida'] = 'efgui/icons/cooking/bread.png',
	['Bebidas'] = 'efgui/icons/skills_icon.png',

	--- @field cooking
}

ix.util.Include('sv_plugin.lua')
ix.util.IncludeDir( ('%s/plugins/%s/recipe'):format(Schema.folder, PLUGIN.uniqueID), true )

function PLUGIN:IsVowel(letter)
	letter = string.utf8lower(letter)
	return letter == 'a' || letter == 'e' || letter == 'i'
	|| letter == 'o' || letter == 'u'
end

function PLUGIN:Pluralize(text)
	if string.utf8sub(text, -2) ~= 'fe' then
		local lastLetter = string.utf8sub(text, -1)

		if lastLetter == 'y' then
			if self:IsVowel(string.utf8sub(text, string.utf8len(text) - 1, 2)) then
				return string.utf8sub(text, 1, -2) .. 'ies'
			else
				return text .. 's'
			end
		elseif lastLetter == 'h' then
			return text .. 'es'
		elseif lastLetter ~= 's' then
			return text .. 's'
		else
			return text
		end
	else
		return string.utf8sub(text, 1, -3) .. 'ves'
	end
end

function PLUGIN:InitializedPlugins()
	ix.recipe:Init()
	ix.blueprint:Init()
end

local PLAYER = FindMetaTable('Player')
function PLAYER:GetEyeTraceLimited(length)
	local trace = {}
		trace.start = self:GetShootPos()
		trace.endpos = trace.start + self:GetAimVector() * (length || 96)
		trace.filter = self
	return util.TraceLine(trace)
end

if CLIENT then
	net.Receive(PLUGIN.netNameCraftingGUI, function()
		local mesa = net.ReadString()
		local panel = vgui.Create('efgCrafting')
		panel:SetMesa(mesa)
	end)

	net.Receive(PLUGIN.netNameStoveGUI, function()
		vgui.Create('efgCooking')
	end)
end