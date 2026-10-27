local PLUGIN = PLUGIN

PLUGIN.name = "EFG Tareas"
PLUGIN.author = "EFG"
PLUGIN.description = "Pestaña TAREAS del TAB como la de EFT: comerciante, lista de tareas, descripción, objetivos y recompensas. Usa las misiones del plugin missions."

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

if (SERVER) then
	for _, name in ipairs({
		"loyalty_one", "loyalty_two", "loyalty_three", "loyalty_king_new", "loyalty_level_panel",
		"checkbox", "checkmark", "close_button", "close_window_x", "dialog_icons_askforquest",
		"image_diagonal_trader", "trader_red_warning", "settings_icon", "skill_level_panel", "button_up", "button_back_big",
		"key_big", "key_small", "key_comma", "key_plus", "key_mouse_both", "key_mouse_left", "key_mouse_right", "key_mouse_scroll",
		"sb_game_eft", "notification_icon_alert_green"
	}) do
		resource.AddFile("materials/efg/ui/" .. name .. ".png")
	end

	for _, name in ipairs({"bg2.jpg", "bg3.jpg", "main_art.jpg", "logo.png", "edge_of_darkness.png", "the_unheard.png", "sb_game_eft.png"}) do
		resource.AddFile("materials/efg/menu/" .. name)
	end
end
