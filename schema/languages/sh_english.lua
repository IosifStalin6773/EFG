
-- Here is where you can define your own phrases to use with the language system. You can define phrases in different languages
-- by creating a file called sh_<language name>.lua (e.g sh_french.lua) in the languages/ folder.

-- You are encouraged to avoid using hardcoded strings when displaying any sort of text on the client. You should instead define
-- these phrases here, and use the L() function to return the text in the proper language. For example, L("serverWelcome") would
-- return a string with the text "Welcome to the server, <name>!" as defined below.

-- You can also use formatted strings in phrases. This will make the phrase require additional parameters to display correctly.
-- In the case of serverWelcome, it requires another string which should be the character's name. An example:
-- L("serverWelcome", "John Lua") would return a string with the text "Welcome to the server, John Lua!".

LANGUAGE = {
	serverWelcome = "Bienvenido a Escape from Gmod, %s.",
	rublosSplit = "Dividir",
	rublosSplitTitle = "Dividir rublos",
	rublosSplitPrompt = "¿Cuántos rublos quieres separar? (1 - %s)",
	flashlightNoItem = "No tienes una linterna.",
	flashlightNoCharge = "Tu linterna no tiene batería. Recárgala con la dinamo.",
	flashlightDepleted = "Tu linterna se ha quedado sin batería.",
	flashlightForcedOff = "Algo ha apagado tu linterna.",
	strongboxNoOpen = "Necesitas tener una taquilla abierta para usar esto.",
	strongboxMaxExpanded = "Esta taquilla ya está al máximo de su capacidad.",
	strongboxExpanded = "Has ampliado el espacio de la taquilla.",
	youreDead = "Estás inconsciente.",
	respawning = "Inconsciente...",
}
