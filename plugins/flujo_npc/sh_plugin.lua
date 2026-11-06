local PLUGIN = PLUGIN

PLUGIN.name = "Flujo de NPC"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Grafo por NPC para diálogos, misiones, relaciones y comercio. Fase 1: camino lineal que se compila a ix.missions."

-- Un grafo es {id, traderKey, nodes = {[id] = {type, data}}, edges = {{from, to}}}.
-- Fase 1: solo camino lineal inicio -> dialogo -> mision -> recompensa -> fin.
-- Ver docs del plan: planes/2026-11-06-mapas-de-flujo.md

ix.flujo = ix.flujo or {}
ix.flujo.graphs = ix.flujo.graphs or {}

ix.flujo.nodeTypes = {
	inicio     = {name = "Inicio"},
	dialogo    = {name = "Diálogo"},
	mision     = {name = "Misión"},
	recompensa = {name = "Recompensa"},
	fin        = {name = "Fin"}
}

ix.flujo.linearOrder = {"inicio", "dialogo", "mision", "recompensa", "fin"}

ix.flujo.groups = {"scav", "pmc", "usec", "bear", "boss"}
ix.flujo.stepTypes = {"kill", "deliver"}

ix.util.Include("sh_model.lua")
ix.util.Include("sh_commands.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_editor.lua")
