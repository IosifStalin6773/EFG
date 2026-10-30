PLUGIN.name = "Bloqueo de Menú de Contexto"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Bloquea el menú de contexto (tecla C) y el menú de objetos (tecla Q) de GMod salvo para personajes con la flag \"z\"."

ix.flag.Add("z", "Acceso al menú de contexto (C) y al menú de objetos (Q) de GMod.")

ix.util.Include("cl_plugin.lua")
