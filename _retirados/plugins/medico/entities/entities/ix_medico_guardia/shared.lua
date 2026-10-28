-- ============================================================
--  ix_medico_guardia  |  shared.lua
--  NPC médico de guardia: cura vida y heridas si no hay
--  ningún jugador médico cerca.
-- ============================================================
AddCSLuaFile()

ENT.Type           = "anim"
ENT.PrintName      = "Médico de Guardia"
ENT.Author         = "Metro RP By Cono y Manperra"
ENT.Category       = "Helix - Metro RP"
ENT.Spawnable      = false
ENT.AdminSpawnable = false
ENT.bNoPersist     = true
