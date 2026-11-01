-- Animaciones de las medicinas en primera persona (modelos del addon «EFT Medical
-- Items» de Craft_Pig, incluidos en el contenido del schema: content/models/
-- weapons/sweps/eft, content/materials/models/weapons/sweps/eft y content/sound/
-- weapons/eft). Se descargan con el servidor, no hace falta ningún addon.
--
-- Una sola arma (efg_med) cambia de modelo según el objeto. La animación se
-- estira o se repite hasta durar lo mismo que el useTime del objeto, que es el
-- tiempo de uso de EFT; la curación la sigue haciendo el objeto (sh_efgmed).

ix.efg = ix.efg or {}
ix.efg.medAnim = ix.efg.medAnim or {}

local MA = ix.efg.medAnim

MA.class = "efg_med"

ix.config.Add("efgMedAnimations", true, "Animación en primera persona al usar medicinas y estimulantes.", nil, {
	category = "EFG Salud"
})

-- ─── Sonidos (los nombres los usan los eventos de los modelos) ──────────────
local sounds = {
	{"MedsGrizzly.Draw", CHAN_ITEM, "grizzly/item_medkit_grizzly_00_draw"},
	{"MedsGrizzly.Open", CHAN_WEAPON, "grizzly/item_medkit_grizzly_01_open"},
	{"MedsGrizzly.Take", CHAN_ITEM, "grizzly/item_medkit_grizzly_02_medtake"},
	{"MedsBandage.Open", CHAN_ITEM, "bandage/item_bandage_01_open"},
	{"MedsBandage.Take", CHAN_WEAPON, "bandage/item_bandage_02_bandagetake"},
	{"MedsBandage.Use", CHAN_WEAPON, "bandage/item_bandage_03_use"},
	{"MedsBandage.End", CHAN_WEAPON, "bandage/item_bandage_04_end"},
	{"MedsMedkit.Draw", CHAN_ITEM, "medkit/item_medkit_ai_00_draw"},
	{"MedsMedkit.Open", CHAN_WEAPON, "medkit/item_medkit_ai_01_open"},
	{"MedsMedkit.Take", CHAN_WEAPON, "medkit/item_medkit_ai_02_takesyringe"},
	{"MedsMedkit.Kolpa", CHAN_WEAPON, "medkit/item_medkit_ai_03_kolpachok"},
	{"MedsMedkit.Injection", CHAN_WEAPON, "medkit/item_medkit_ai_04_injection"},
	{"MedsMedkit.Throw", CHAN_WEAPON, "medkit/item_medkit_ai_05_throwsyringe"},
	{"MedsMedkit.Putaway", CHAN_WEAPON, "medkit/item_medkit_ai_06_putaway"},
	{"MedsBlister.Draw", CHAN_BODY, "pills/item_pillsblister_00_draw"},
	{"MedsBlister.Open", CHAN_WEAPON, "pills/item_pillsblister_01_open"},
	{"MedsPillsBottle.Draw", CHAN_WEAPON, "pills/item_pillsbottle_00_draw"},
	{"MedsPillsBottle.Open", CHAN_WEAPON, "pills/item_pillsbottle_01_open"},
	{"MedsPillsBottle.Pilltake", CHAN_ITEM, "pills/item_pillsbottle_02_pilltake"},
	{"MedsPillsBottle.Use", CHAN_WEAPON, "pills/item_pillsbottle_03_use"},
	{"MedsPillsBottle.Close", CHAN_WEAPON, "pills/item_pillsbottle_04_close"},
	{"MedsPillsBottle.Putaway", CHAN_WEAPON, "pills/item_pillsbottle_05_putaway"},
	{"MedsSalewa.Draw", CHAN_ITEM, "salewa/item_medkit_salewa_00_draw"},
	{"MedsSalewa.Open", CHAN_WEAPON, "salewa/item_medkit_salewa_01_open"},
	{"MedsSalewa.Bandage", CHAN_WEAPON, "salewa/item_medkit_salewa_02_bandagetake"},
	{"MedsSalewa.Use", CHAN_WEAPON, "salewa/item_medkit_salewa_03_use"},
	{"MedsSalewa.End", CHAN_WEAPON, "salewa/item_medkit_salewa_04_end"},
	{"MedsCat.Draw", CHAN_WEAPON, "cat/item_cat_00_draw"},
	{"MedsCat.Use", CHAN_WEAPON, "cat/item_cat_01_use"},
	{"MedsCat.Fasten", CHAN_WEAPON, "cat/item_cat_02_fasten"},
	{"MedsCat.Putaway", CHAN_WEAPON, "cat/item_cat_03_putaway"},
	{"MedsSurgical.Draw", CHAN_WEAPON, "surgicalkit/item_surgicalkit_00_draw"},
	{"MedsSurgical.SicDraw", CHAN_WEAPON, "surgicalkit/item_surgicalkit_01_scissors_draw"},
	{"MedsSurgical.SciUse", CHAN_WEAPON, "surgicalkit/item_surgicalkit_02_scissors_use"},
	{"MedsSurgical.SciPutaway", CHAN_WEAPON, "surgicalkit/item_surgicalkit_03_scissors_putaway"},
	{"MedsSurgical.PickDraw", CHAN_WEAPON, "surgicalkit/item_surgicalkit_04_picker_draw"},
	{"MedsSurgical.PickUse", CHAN_WEAPON, "surgicalkit/item_surgicalkit_05_picker_use"},
	{"MedsSurgical.PickPutaway", CHAN_WEAPON, "surgicalkit/item_surgicalkit_06_picker_putaway"},
	{"MedsSurgical.StaplerDraw", CHAN_WEAPON, "surgicalkit/item_surgicalkit_07_stapler_draw"},
	{"MedsSurgical.StaperUse", CHAN_WEAPON, "surgicalkit/item_surgicalkit_08_stapler_use"},
	{"MedsSurgical.StaplerPutaway", CHAN_WEAPON, "surgicalkit/item_surgicalkit_09_stapler_putaway"},
	{"MedsSurgical.Close", CHAN_WEAPON, "surgicalkit/item_surgicalkit_10_close"},
	{"MedsSurgical.Button1", CHAN_WEAPON, "surgicalkit/item_surgicalkit_11_close_button"},
	{"MedsSurgical.Button2", CHAN_WEAPON, "surgicalkit/item_surgicalkit_12_close_button"},
	{"MedsSurgical.Putaway", CHAN_WEAPON, "surgicalkit/item_surgicalkit_13_putaway"},
	{"MedsSplint.Start", CHAN_WEAPON, "splint/item_splint_00_start"},
	{"MedsSplint.Middle", CHAN_WEAPON, "splint/item_splint_01_middle"},
	{"MedsSplint.End", CHAN_WEAPON, "splint/item_splint_02_end"},
	{"MedsInjector.Draw", CHAN_WEAPON, "injector/item_injector_00_draw"},
	{"MedsInjector.Open", CHAN_WEAPON, "injector/item_injector_01_kolpachok"},
	{"MedsInjector.Use", CHAN_WEAPON, "injector/item_injector_02_injection"},
	{"MedsInjector.End", CHAN_WEAPON, "injector/item_injector_03_putaway"}
}

for _, s in ipairs(sounds) do
	sound.Add({
		name = s[1], channel = s[2], volume = 1, level = 65, pitch = {95, 110},
		sound = "weapons/eft/" .. s[3] .. ".wav"
	})
end

-- ─── Modelos ────────────────────────────────────────────────────────────────
local function model(name, kind)
	return "models/weapons/sweps/eft/" .. name .. "/" .. kind .. "_meds_" .. name .. ".mdl"
end

MA.Model = model

-- Inyector: un modelo con 16 aspectos (familia de skins del .mdl)
MA.injectorSkins = {
	morphine = 1, mule = 2, meldonin = 3, l1 = 4, etgc = 5, ahf1m = 6, adrenaline = 7, p22 = 8,
	propital = 9, sj1 = 10, sj6 = 11, sj9 = 12, xtg12 = 13, zagustin = 14, ["3btg"] = 15,
	-- sin aspecto propio en el addon
	obdolbos = 15, perfotoran = 13, trimadol = 4
}

-- Perfiles: entrada, bucle (se repite mientras sobre tiempo) y salida.
-- Los nombres de actividad son los de los .mdl (leídos con tools/mdlinfo).
MA.profiles = {
	afak = {vm = "afak", enter = "ACT_VM_RECOIL1", loop = {"ACT_VM_RECOIL2", "ACT_VM_HITRIGHT"}, exit = "ACT_VM_RECOIL3"},
	salewa_bandage = {vm = "salewa", enter = "ACT_VM_MISSRIGHT", loop = {"ACT_VM_MISSRIGHT2", "ACT_VM_MISSCENTER"}, exit = "ACT_VM_MISSCENTER2"},
	salewa_syringe = {vm = "salewa", enter = "ACT_VM_PULLBACK_HIGH", loop = {"ACT_VM_PULLBACK"}, exit = "ACT_VM_PULLBACK_LOW"},
	car_bandage = {vm = "automedkit", enter = "ACT_VM_MISSRIGHT", loop = {"ACT_VM_MISSRIGHT2", "ACT_VM_MISSCENTER"}, exit = "ACT_VM_MISSCENTER2"},
	car_syringe = {vm = "automedkit", enter = "ACT_VM_PULLBACK_HIGH", loop = {"ACT_VM_PULLBACK"}, exit = "ACT_VM_PULLBACK_LOW"},
	car_pills = {vm = "automedkit", enter = "ACT_VM_RECOIL1", loop = {"ACT_VM_RECOIL3", "ACT_VM_RECOIL2"}, exit = "ACT_VM_PICKUP"},
	grizzly_bandage = {vm = "grizzly", enter = "ACT_VM_MISSRIGHT", loop = {"ACT_VM_MISSRIGHT2"}, exit = "ACT_VM_MISSCENTER2"},
	grizzly_syringe = {vm = "grizzly", enter = "ACT_VM_PULLBACK_HIGH", loop = {"ACT_VM_PULLBACK", "ACT_VM_PICKUP"}, exit = "ACT_VM_PULLBACK_LOW"},
	tourniquet = {vm = "cat", enter = "ACT_VM_RECOIL1", loop = {"ACT_VM_RECOIL2"}, exit = "ACT_VM_RECOIL3"},
	splint = {vm = "alusplint", enter = "ACT_VM_RECOIL1"},
	blister = {vm = "anaglin", enter = "ACT_VM_RECOIL1"},
	bottle = {vm = "augmentin", enter = "ACT_VM_RECOIL1"},
	surgery = {vm = "surgicalkit", enter = "ACT_VM_RECOIL1"},
	injector = {vm = "injector", enter = "ACT_VM_RECOIL1"}
}

-- Sonidos de cada secuencia (ciclo 0-1, sonido). El dueño los oye por los
-- eventos del modelo; al resto se los manda el servidor a la vez.
MA.events = {
	afak = {
		ACT_VM_RECOIL1 = {{0, "MedsGrizzly.Draw"}, {0.606, "MedsGrizzly.Take"}, {0.682, "MedsBandage.Take"}},
		ACT_VM_RECOIL2 = {{0, "MedsBandage.Use"}},
		ACT_VM_HITRIGHT = {{0, "MedsBandage.Use"}},
		ACT_VM_RECOIL3 = {{0.278, "MedsBandage.End"}}
	},
	alusplint = {
		ACT_VM_RECOIL1 = {{0, "MedsCat.Draw"}}
	},
	anaglin = {
		ACT_VM_RECOIL1 = {{0.13, "MedsBlister.Draw"}, {0.261, "MedsBlister.Open"}, {0.522, "MedsPillsBottle.Use"}}
	},
	augmentin = {
		ACT_VM_RECOIL1 = {{0.081, "MedsPillsBottle.Draw"}, {0.215, "MedsPillsBottle.Open"}, {0.43, "MedsPillsBottle.Pilltake"},
			{0.538, "MedsPillsBottle.Use"}, {0.672, "MedsPillsBottle.Close"}, {0.887, "MedsPillsBottle.Putaway"}}
	},
	automedkit = {
		ACT_VM_RECOIL1 = {{0, "MedsGrizzly.Draw"}, {0.548, "MedsGrizzly.Take"}},
		ACT_VM_RECOIL2 = {{0, "MedsBlister.Open"}, {0.51, "MedsPillsBottle.Use"}},
		ACT_VM_RECOIL3 = {{0, "MedsBlister.Open"}, {0.51, "MedsPillsBottle.Use"}},
		ACT_VM_PICKUP = {{0.278, "MedsGrizzly.Draw"}},
		ACT_VM_PULLBACK_HIGH = {{0, "MedsGrizzly.Draw"}, {0.43, "MedsGrizzly.Take"}, {0.645, "MedsMedkit.Kolpa"}, {0.882, "MedsMedkit.Injection"}},
		ACT_VM_PULLBACK_LOW = {{0.161, "MedsMedkit.Throw"}},
		ACT_VM_MISSRIGHT = {{0, "MedsGrizzly.Draw"}, {0.625, "MedsGrizzly.Take"}},
		ACT_VM_MISSRIGHT2 = {{0, "MedsBandage.Use"}},
		ACT_VM_MISSCENTER = {{0, "MedsBandage.Use"}},
		ACT_VM_MISSCENTER2 = {{0.278, "MedsBandage.End"}}
	},
	cat = {
		ACT_VM_RECOIL1 = {{0, "MedsCat.Draw"}},
		ACT_VM_RECOIL2 = {{0.213, "MedsCat.Use"}, {0.745, "MedsCat.Fasten"}},
		ACT_VM_RECOIL3 = {{0, "MedsCat.Putaway"}}
	},
	grizzly = {
		ACT_VM_PULLBACK_HIGH = {{0, "MedsGrizzly.Draw"}, {0.342, "MedsGrizzly.Take"}, {0.487, "MedsMedkit.Kolpa"}, {0.795, "MedsMedkit.Injection"}},
		ACT_VM_PICKUP = {{0.045, "MedsMedkit.Throw"}, {0.36, "MedsGrizzly.Take"}, {0.676, "MedsMedkit.Kolpa"}, {0.928, "MedsMedkit.Injection"}},
		ACT_VM_PULLBACK_LOW = {{0.238, "MedsMedkit.Throw"}},
		ACT_VM_MISSRIGHT = {{0, "MedsGrizzly.Draw"}, {0.342, "MedsGrizzly.Take"}, {0.598, "MedsBandage.Open"}, {0.769, "MedsBandage.Take"}},
		ACT_VM_MISSRIGHT2 = {{0, "MedsBandage.Use"}},
		ACT_VM_MISSCENTER2 = {{0.238, "MedsBandage.End"}}
	},
	injector = {
		ACT_VM_RECOIL1 = {{0.05, "MedsInjector.Draw"}, {0.217, "MedsInjector.Open"}, {0.417, "MedsInjector.Use"}, {0.667, "MedsInjector.End"}}
	},
	salewa = {
		ACT_VM_PULLBACK_HIGH = {{0, "MedsSalewa.Draw"}, {0.222, "MedsSalewa.Open"}, {0.444, "MedsGrizzly.Take"}, {0.667, "MedsMedkit.Kolpa"}, {0.911, "MedsMedkit.Injection"}},
		ACT_VM_PULLBACK_LOW = {{0.167, "MedsMedkit.Throw"}},
		ACT_VM_MISSRIGHT = {{0, "MedsSalewa.Draw"}, {0.312, "MedsSalewa.Open"}, {0.625, "MedsGrizzly.Take"}},
		ACT_VM_MISSRIGHT2 = {{0, "MedsBandage.Use"}},
		ACT_VM_MISSCENTER = {{0, "MedsBandage.Use"}},
		ACT_VM_MISSCENTER2 = {{0.278, "MedsBandage.End"}}
	},
	surgicalkit = {
		ACT_VM_RECOIL1 = {{0, "MedsSurgical.Draw"}, {0.074, "MedsSurgical.SicDraw"}, {0.148, "MedsSurgical.SciUse"},
			{0.243, "MedsSurgical.SciPutaway"}, {0.285, "MedsSurgical.PickDraw"}, {0.39, "MedsSurgical.PickUse"},
			{0.517, "MedsSurgical.PickPutaway"}, {0.538, "MedsSurgical.StaplerDraw"}, {0.612, "MedsSurgical.StaperUse"},
			{0.759, "MedsSurgical.StaplerPutaway"}, {0.812, "MedsSurgical.Close"}, {0.886, "MedsSurgical.Button1"},
			{0.939, "MedsSurgical.Button2"}, {0.96, "MedsSurgical.Putaway"}}
	}
}

-- Sonidos que el modelo no trae: suenan para todos, también para el dueño
MA.extraEvents = {
	alusplint = {
		ACT_VM_RECOIL1 = {{0.35, "MedsSplint.Start"}, {0.6, "MedsSplint.Middle"}, {0.85, "MedsSplint.End"}}
	}
}

-- Perfil para un objeto: ITEM.medAnim es un nombre de perfil, o una lista
-- {con sangrado, sin sangrado...} para los botiquines (venda si sangra, si no
-- jeringuilla o pastillas al azar, como en EFT).
function MA.Choose(item, client)
	local anim = item.medAnim
	if (!anim) then return end

	if (istable(anim)) then
		local bleeding = false
		local health = ix.efg.health

		if (health and health.GetStatus and IsValid(client)) then
			for _, level in pairs(health.GetStatus(client).bleed or {}) do
				if (level) then bleeding = true break end
			end
		end

		if (bleeding or #anim == 1) then return anim[1] end
		return anim[math.random(2, #anim)]
	end

	return anim
end

function MA.SkinFor(item)
	return item.medSkin or (item.efgStim and MA.injectorSkins[item.efgStim]) or 0
end

-- Al curarse se camina despacio y no se corre (EFT)
hook.Add("SetupMove", "ixEFGMedAnimSlow", function(client, mv)
	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon) and weapon:GetClass() == MA.class and weapon:GetMedActive()) then
		mv:SetMaxClientSpeed(math.min(mv:GetMaxClientSpeed(), client:GetWalkSpeed() * 0.75))
	end
end)

ix.util.Include("sh_medweapon.lua")

-- Con el inventario abierto la animación no se ve: se cierra al empezar a curarse
if (CLIENT) then
	net.Receive("efgMedCloseMenus", function()
		for _, key in ipairs({"efgInventory", "efgNewMenu", "menu"}) do
			if (IsValid(ix.gui[key])) then
				ix.gui[key]:Remove()
			end
		end
	end)
end

if (SERVER) then
	util.AddNetworkString("efgMedCloseMenus")

	-- Saca el arma de medicina y la anima. Devuelve el token de uso (se marca
	-- cancelled si el jugador cambia de arma antes de terminar) o nil.
	function MA.Start(client, item, useTime)
		if (!ix.config.Get("efgMedAnimations", true) or !IsValid(client) or !client:Alive() or client:InVehicle()) then return end

		local profileID = MA.Choose(item, client)
		local profile = profileID and MA.profiles[profileID]
		if (!profile) then return end

		-- un uso a la vez
		if (client.efgMedUse and !client.efgMedUse.finished) then
			client.efgMedUse.cancelled = true
		end

		local previous = client:GetActiveWeapon()
		local token = {
			item = item.id, profile = profileID, skin = MA.SkinFor(item),
			duration = useTime, previous = IsValid(previous) and previous:GetClass() != MA.class and previous:GetClass() or nil
		}

		client.efgMedUse = token

		net.Start("efgMedCloseMenus")
		net.Send(client)

		local weapon = client:GetWeapon(MA.class)
		if (!IsValid(weapon)) then weapon = client:Give(MA.class) end
		if (!IsValid(weapon)) then
			MsgC(Color(232, 120, 60), "[efg_med] No se pudo dar el arma de medicina a " .. client:Name() .. "\n")
			client.efgMedUse = nil
			return
		end

		weapon:Begin(token)

		if (client:GetActiveWeapon() == weapon) then
			weapon:Deploy()
		else
			client:SelectWeapon(MA.class)

			-- Las armas ARC9 devuelven false en Holster mientras hacen su animación
			-- de guardar y SelectWeapon no cambia: se fuerza el cambio
			timer.Simple(0.15, function()
				if (!IsValid(client) or !IsValid(weapon) or token.finished or client.efgMedUse != token) then return end
				if (client:GetActiveWeapon() == weapon) then return end

				client:SetActiveWeapon(weapon)
				weapon:Deploy()

				if (client:GetActiveWeapon() != weapon) then
					MsgC(Color(232, 120, 60), "[efg_med] No se pudo sacar el arma de medicina a " .. client:Name() .. "\n")
				end
			end)
		end

		return token
	end

	-- Fin del uso (aplicado o cancelado): quita el arma y vuelve a la anterior
	function MA.Finish(client, token)
		if (!IsValid(client) or !token) then return end

		token.finished = true
		if (client.efgMedUse == token) then client.efgMedUse = nil end

		local weapon = client:GetWeapon(MA.class)
		if (!IsValid(weapon)) then return end

		if (client:GetActiveWeapon() == weapon and token.previous and client:HasWeapon(token.previous)) then
			client:SelectWeapon(token.previous)
		end

		timer.Simple(0, function()
			if (IsValid(client) and IsValid(client:GetWeapon(MA.class)) and !client.efgMedUse) then
				client:StripWeapon(MA.class)
			end
		end)
	end

	-- Sonidos de la animación para los que están cerca (el dueño ya los oye)
	local function schedule(client, list, duration, others)
		for _, e in ipairs(list or {}) do
			timer.Simple(e[1] * duration, function()
				if (!IsValid(client) or !client:Alive()) then return end

				local filter = RecipientFilter()
				filter:AddPAS(client:GetPos())

				if (others) then filter:RemovePlayer(client) end

				client:EmitSound(e[2], 65, 100, 1, CHAN_AUTO, 0, 0, filter)
			end)
		end
	end

	function MA.PlayEvents(client, vmName, act, duration)
		schedule(client, MA.events[vmName] and MA.events[vmName][act], duration, true)
		schedule(client, MA.extraEvents[vmName] and MA.extraEvents[vmName][act], duration, false)
	end
end
