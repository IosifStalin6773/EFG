PLUGIN.name = "EFG Prueba del ciclo"
PLUGIN.author = "EFG Project"
PLUGIN.description = "Registro de eventos raid → extracción/muerte/MIA/abandono → alijo con hora, y /EFGTestCiclo que lleva un bot por el ciclo completo."

ix.efg = ix.efg or {}
ix.efg.testcycle = ix.efg.testcycle or {}

ix.config.Add("efgCycleLog", true, "Registrar los eventos del ciclo de raid (despliegue, extracción, muerte, MIA, abandono, alijo, XP, seguro).", nil, {
	category = "EFG Pruebas"
})

ix.config.Add("efgCycleLogFile", true, "Guardar el registro del ciclo en data/efg/ciclo/<fecha>.txt.", nil, {
	category = "EFG Pruebas"
})

ix.config.Add("efgCycleStepDelay", 2, "Segundos entre pasos de /EFGTestCiclo.", nil, {
	data = {min = 1, max = 10, decimals = 1},
	category = "EFG Pruebas"
})

ix.config.Add("efgCycleTestItem", "analgin", "uniqueID del objeto que usa /EFGTestCiclo como botín de prueba.", nil, {
	category = "EFG Pruebas"
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("sh_commands.lua")
