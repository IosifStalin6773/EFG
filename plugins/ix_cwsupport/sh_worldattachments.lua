-- ═══════════════════════════════════════════════════════════════
--  Accesorios visibles en el MODELO DE MUNDO (los que ven los demás).
--
--  CW2 solo dibuja los modelos de accesorio sobre el VIEWMODEL del dueño
--  (self.AttachmentModelsVM, dibujado en _drawViewModel → drawAttachments);
--  su DrawWorldModel nunca los dibuja, así que ningún otro jugador — ni el
--  propio dueño en 3ª persona — ve los accesorios puestos. Esto lo reproduce
--  aquí desde cero: el servidor sincroniza a TODOS los clientes qué accesorios
--  lleva cada arma (weapon:SetNWString), y cada cliente dibuja los props de
--  accesorio sobre el hueso del modelo de mundo, igual que CW2 hace sobre el
--  viewmodel (mismo cálculo bone-matrix + offset que su _drawAttachmentModel).
--
--  Las posiciones/ángulos de AttachmentModelsVM están calibradas para el
--  VIEWMODEL (v_metro_ak.mdl), NO para el modelo de mundo (w_m2k33_ak.mdl),
--  que tiene otra geometría/huesos — así que aquí hacen falta valores propios
--  por arma+accesorio. Se calibran en vivo con el comando cw_watt (ver abajo)
--  mirándote en 3ª persona, y se pegan los valores finales en esta tabla.
-- ═══════════════════════════════════════════════════════════════

ix.cwsupport = ix.cwsupport or {}

-- [clase de arma] = { atts = { [nombre accesorio] = { models = { {model, pos, angle, size}, ... } } } }
-- pos/angle de cada pieza son relativos al attachment "anim_attachment_RH" del
-- jugador (donde el motor monta el arma). Se calibran en vivo con cw_wsel +
-- cw_wnudge mirándote en 3ª persona (ver más abajo).
ix.cwsupport.worldAttachments = {
	["cw_kry_metro_2k33_ak"] = {
		atts = {
			-- Cada accesorio es una LISTA de modelos (models): un accesorio puede
			-- necesitar varias piezas (p. ej. el colimador + su soporte de riel).
			-- Cada pieza tiene su propio offset, así se calibran por separado
			-- (cw_wsel <accesorio> <índice>).
			["kry_metro_kollimator"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/att/kollimator.mdl", pos = Vector(0.7, 1.3, 6.49), angle = Angle(5, 0, -5), size = Vector(1, 1, 1) },
				{ model = "models/attachments/other/planka_1/planka_1.mdl",      pos = Vector(1.2, 1.3, 4.49), angle = Angle(5, 0, -10), size = Vector(1, 1, 1) },
			}},
			["kry_metro_optika1"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/att/pricel.mdl", pos = Vector(1.2, 1.3, 6.49), angle = Angle(5, 0, -5), size = Vector(1, 1, 1) },
				{ model = "models/attachments/other/planka_1/planka_1.mdl", pos = Vector(1.2, 1.3, 4.49), angle = Angle(5, 0, -10), size = Vector(1, 1, 1) },
			}},
			["kry_metro_glushak"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/att/glushak.mdl", pos = Vector(25.1, 0.9, 5.5), angle = Angle(5, 0, 5), size = Vector(1, 1, 1) },
			}},
			["kry_metro_laser"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/weapon_laser_sight.mdl", pos = Vector(19.5, -0.4, 4.5), angle = Angle(5, 0, -15), size = Vector(1, 1, 1) },
			}},
		},
	},

	-- ── Padonak ──────────────────────────────────────────────────────────
	-- Sin calibrar (semilla = valores del Kalash como punto de partida).
	["cw_metro2033_padonak"] = {
		atts = {
			["kry_metro_glushak_revolver"] = { models = {
				{ model = "models/attachments/suppressors/padonak_suppressor/padonak_suppressor.mdl", pos = Vector(19.5, -0.4, 4.5), angle = Angle(5, 0, -15), size = Vector(1, 1, 1) },
			}},
		},
	},

	-- ── Hellsing ─────────────────────────────────────────────────────────
	["cw_metro2033_hellsing"] = {
		atts = {
			["metro2033_hellsing_sight"] = { models = {
				{ model = "models/attachments/scopes/tihar_scope/tihar_scope.mdl", pos = Vector(0.7, 1.3, 6.49), angle = Angle(5, 0, -5), size = Vector(1, 1, 1) },
			}},
		},
	},

	-- ── Bastarda (Ubludok) ───────────────────────────────────────────────
	-- Mismos modelos de mira/cañón/láser que el Kalash (misma vía), pero el
	-- arma es distinta → seguramente hace falta recalibrar cada uno igual.
	["cw_kry_metro_2k33_ubludok"] = {
		atts = {
			["kry_metro_kollimator"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/att/kollimator.mdl", pos = Vector(0.2, 1.3, 5.49), angle = Angle(5, 0, -5), size = Vector(1, 1, 1) },
				{ model = "models/attachments/other/planka_2/planka_2.mdl", pos = Vector(1.2, 1.3, 4.49), angle = Angle(5, 0, -10), size = Vector(1, 1, 1) },
			}},
			["kry_metro_optika1"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/att/pricel.mdl", pos = Vector(1.2, 1.3, 6.49), angle = Angle(5, 0, -5), size = Vector(1, 1, 1) },
				{ model = "models/attachments/other/planka_2/planka_2.mdl", pos = Vector(1.2, 1.3, 4.49), angle = Angle(5, 0, -10), size = Vector(1, 1, 1) },
			}},
			["kry_metro_optika_ir"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/att/pricel_ir.mdl", pos = Vector(1.2, 1.3, 6.49), angle = Angle(5, 0, -5), size = Vector(1, 1, 1) },
				{ model = "models/attachments/other/planka_2/planka_2.mdl", pos = Vector(1.2, 1.3, 4.49), angle = Angle(5, 0, -10), size = Vector(1, 1, 1) },
			}},
			["kry_metro_glushak"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/att/glushak.mdl", pos = Vector(23.1, 0.9, 6), angle = Angle(5, 0, 5), size = Vector(1, 1, 1) },
			}},
			["kry_metro_laser"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/weapon_laser_sight.mdl", pos = Vector(19.5, -0.4, 5.5), angle = Angle(5, 0, -10), size = Vector(1, 1, 1) },
			}},
		},
	},

	-- ── Tikhar ───────────────────────────────────────────────────────────
	["cw_kry_metro_tikhar"] = {
		atts = {
			["kry_metro_kollimator"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/att/kollimator.mdl", pos = Vector(0.7, 1.3, 6.49), angle = Angle(5, 0, -5), size = Vector(1, 1, 1) },
			}},
		},
	},

	-- ── VSV ──────────────────────────────────────────────────────────────
	["cw_metro2033_vsv"] = {
		atts = {
			["metro2033_sight_collimator"] = { models = {
				{ model = "models/attachments/scopes/kollim/kollim.mdl", pos = Vector(0.7, 1.3, 6.49), angle = Angle(5, 0, -5), size = Vector(1, 1, 1) },
			}},
			["metro2033_silencer"] = { models = {
				{ model = "models/attachments/suppressors/vsv_suppressor/vsv_suppressor.mdl", pos = Vector(25.1, 0.9, 5.5), angle = Angle(5, 0, 5), size = Vector(1, 1, 1) },
			}},
			["metro2033_laser"] = { models = {
				{ model = "models/attachments/other/default_laser/default_laser.mdl", pos = Vector(19.5, -0.4, 4.5), angle = Angle(5, 0, -15), size = Vector(1, 1, 1) },
			}},
		},
	},

	-- ── Saiga ────────────────────────────────────────────────────────────
	["cw_kry_metro_2k33_saiga"] = {
		atts = {
			["kry_metro_glushak"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/att/glushak.mdl", pos = Vector(25.1, 0.9, 5.5), angle = Angle(5, 0, 5), size = Vector(1, 1, 1) },
			}},
			["kry_metro_laser"] = { models = {
				{ model = "models/weapons/krycek/metro_2k33/weapon_laser_sight.mdl", pos = Vector(19.5, -0.4, 4.5), angle = Angle(5, 0, -15), size = Vector(1, 1, 1) },
			}},
		},
	},
}

-- Devuelve la config de un accesorio concreto (o nil), tolerando mayúsculas en
-- el classname del arma.
function ix.cwsupport.GetWorldAtt(weaponClass, attName)
	local cfg = ix.cwsupport.worldAttachments[string.lower(weaponClass or "")]
	if (!cfg or !cfg.atts) then return nil, cfg end
	return cfg.atts[attName], cfg
end


if (SERVER) then
	-- Precache de todos los modelos de accesorio (sin esto, un dibujado a un
	-- modelo nunca registrado puede fallar en silencio en algún cliente).
	for _, cfg in pairs(ix.cwsupport.worldAttachments) do
		for _, att in pairs(cfg.atts or {}) do
			for _, piece in ipairs(att.models or {}) do
				util.PrecacheModel(piece.model)
			end
		end
	end

	-- Sincroniza a TODOS los clientes qué accesorios lleva `weapon` ahora mismo.
	-- attNames: array de nombres (los mismos que attData[2] / las claves de la
	-- tabla de arriba, ej. "kry_metro_kollimator"). Se guarda en una NWString del
	-- arma, que se replica a todo el que tenga el arma en su PVS.
	function ix.cwsupport.SyncWorldAtts(weapon, attNames)
		if (!IsValid(weapon)) then return end
		weapon:SetNWString("ixWorldAtts", table.concat(attNames or {}, ","))
	end

	-- Aplica la sincronización a TODAS las armas de esa clase en el inventario
	-- del jugador (equipadas o no da igual: solo las equipadas existen como
	-- entidad, pero recorrerlas todas es inocuo). Se llama desde los 3 puntos
	-- donde cambian los accesorios (equipar/quitar/desplegar).
	function ix.cwsupport.SyncWorldAttsForPlayer(client, weaponClass, attNames)
		if (!IsValid(client)) then return end
		for _, wep in pairs(client:GetWeapons()) do
			if (IsValid(wep) and wep:GetClass():lower() == weaponClass:lower()) then
				ix.cwsupport.SyncWorldAtts(wep, attNames)
			end
		end
	end

	return
end

-- ─── CLIENTE ──────────────────────────────────────────────────────────────

-- weapon.ixWAttModels[attName] = { CSM_pieza1, CSM_pieza2, ... } — una entidad
-- ClientsideModel por cada pieza (models[i]) del accesorio.

-- Crea los ClientsideModels de todas las piezas del accesorio `attName`.
local function EnsureAttModels(weapon, attName, attCfg)
	weapon.ixWAttModels = weapon.ixWAttModels or {}

	if (weapon.ixWAttModels[attName]) then return weapon.ixWAttModels[attName] end

	local list = {}
	for _, piece in ipairs(attCfg.models or {}) do
		local csm = ClientsideModel(piece.model, RENDERGROUP_OPAQUE)
		if (IsValid(csm)) then
			csm:SetNoDraw(true) -- se dibuja a mano en el hook de render
			csm:SetModelScale(piece.size and piece.size.x or 1, 0)
			table.insert(list, csm)
		end
	end

	weapon.ixWAttModels[attName] = list
	return list
end

-- Elimina todos los ClientsideModels de accesorio de un arma.
local function ClearAttModels(weapon)
	if (!weapon.ixWAttModels) then return end
	for _, list in pairs(weapon.ixWAttModels) do
		for _, csm in ipairs(list) do
			if (IsValid(csm)) then csm:Remove() end
		end
	end
	weapon.ixWAttModels = nil
	weapon.ixWAttHashCL = nil
end

-- Reconcilia los ClientsideModels con la lista sincronizada del servidor.
-- Solo recrea si la lista cambió (ixWAttHashCL), para no reconstruir cada frame.
local function UpdateAttModels(weapon)
	local hash = weapon:GetNWString("ixWorldAtts", "")

	if (weapon.ixWAttHashCL == hash) then return end
	weapon.ixWAttHashCL = hash

	-- Reconstrucción total: es barato (pocos accesorios) y evita llevar el
	-- estado incremental de qué había antes.
	ClearAttModels(weapon)
	weapon.ixWAttModels = {}
	weapon.ixWAttHashCL = hash

	if (hash == "") then return end

	local class = weapon:GetClass()
	for _, attName in ipairs(string.Explode(",", hash)) do
		if (attName != "") then
			local attCfg = ix.cwsupport.GetWorldAtt(class, attName)
			if (attCfg) then
				EnsureAttModels(weapon, attName, attCfg)
			end
		end
	end
end

-- Dibuja los accesorios de `weapon` sobre su modelo de mundo. `boneEnt` es la
-- entidad cuyo hueso se usa como anclaje: para un arma sostenida es el propio
-- arma (su world model sigue la mano). Mismo cálculo que _drawAttachmentModel
-- de CW2, pero sobre el world model en vez del viewmodel.
local function DrawWeaponAtts(weapon, owner)
	if (!IsValid(weapon)) then return end

	UpdateAttModels(weapon)

	local hash = weapon.ixWAttHashCL
	if (!weapon.ixWAttModels or !hash or hash == "") then return end

	-- Anclaje: el modelo de mundo de un arma SOSTENIDA lo dibuja el motor pegado
	-- a la mano del jugador (el bone del arma NO está en la mano — por eso anclar
	-- al arma dejaba el accesorio en el origen/pies). Se usa el attachment
	-- "anim_attachment_RH" del jugador, que es el punto exacto donde el motor
	-- monta el arma (igual criterio que el DrawWorldModel no-tradicional de CW2,
	-- que usa el hueso de la mano). Fallback: hueso de la mano derecha.
	if (!IsValid(owner)) then owner = weapon:GetOwner() end
	if (!IsValid(owner)) then owner = weapon.Owner end
	if (!IsValid(owner)) then return end

	local basePos, baseAng

	local attachId = owner:LookupAttachment("anim_attachment_RH")
	if (attachId and attachId > 0) then
		local att = owner:GetAttachment(attachId)
		if (att) then
			basePos, baseAng = att.Pos, att.Ang
		end
	end

	if (!basePos) then
		local handBone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
		if (handBone) then
			local m = owner:GetBoneMatrix(handBone)
			if (m) then
				basePos, baseAng = m:GetTranslation(), m:GetAngles()
			end
		end
	end

	if (!basePos) then return end

	for attName, list in pairs(weapon.ixWAttModels) do
		local attCfg = ix.cwsupport.GetWorldAtt(weapon:GetClass(), attName)
		if (attCfg and attCfg.models) then
			for i, csm in ipairs(list) do
				local piece = attCfg.models[i]
				if (IsValid(csm) and piece) then
					local ang = Angle(baseAng.p, baseAng.y, baseAng.r)
					local pos = basePos
						+ ang:Forward() * piece.pos.x
						+ ang:Right()   * piece.pos.y
						+ ang:Up()      * piece.pos.z

					ang:RotateAroundAxis(ang:Up(),      piece.angle.y)
					ang:RotateAroundAxis(ang:Right(),   piece.angle.p)
					ang:RotateAroundAxis(ang:Forward(), piece.angle.r)

					csm:SetPos(pos)
					csm:SetAngles(ang)
					csm:SetModelScale(piece.size and piece.size.x or 1, 0)
					csm:SetupBones()
					csm:DrawModel()
				end
			end
		end
	end
end

-- Render: por cada jugador, dibuja los accesorios de su arma activa sobre el
-- modelo de mundo. PostPlayerDraw corre en la pasada opaca, ya con los huesos
-- del jugador (y por tanto del arma sostenida) colocados este frame. Cubre a
-- los demás jugadores Y al propio dueño en 3ª persona; en 1ª persona no hace
-- falta (el viewmodel ya los dibuja por su cuenta).
hook.Add("PostPlayerDraw", "ixCWSupport_WorldAttachments", function(ply)
	if (!IsValid(ply) or !ply:Alive()) then return end

	local wep = ply:GetActiveWeapon()
	if (!IsValid(wep)) then return end

	-- Solo armas con config registrada (evita trabajo para cualquier otra SWEP).
	if (ix.cwsupport.worldAttachments[wep:GetClass():lower()]) then
		DrawWeaponAtts(wep, ply)
	end
end)

-- Limpieza: al eliminarse el arma (drop, muerte, cambio de personaje), quita
-- sus ClientsideModels para no dejarlos huérfanos.
hook.Add("EntityRemoved", "ixCWSupport_WorldAttachments_Cleanup", function(ent)
	if (ent.ixWAttModels) then
		ClearAttModels(ent)
	end
end)


-- ─── Calibración con teclado (nudge en tiempo real) ───────────────────────
-- El world model tiene otra geometría que el viewmodel, así que los offsets
-- semilla (copiados del VM) no encajan. Con esto seleccionas una PIEZA de un
-- accesorio (cw_wsel <accesorio> [índice]) y la empujas en incrementos con
-- teclas bindeadas (cw_wnudge), viéndola en vivo en 3ª persona. Al acabar,
-- cw_wprint imprime la entrada completa lista para pegar en worldAttachments.
--
--   1) thirdperson
--   2) cw_wsel kry_metro_kollimator 1   (1 = colimador, 2 = soporte/planka)
--   3) Bindea teclas, ej:
--        bind kp_uparrow    "cw_wnudge px 0.5"
--        bind kp_downarrow  "cw_wnudge px -0.5"
--        bind kp_leftarrow  "cw_wnudge py 0.5"
--        bind kp_rightarrow "cw_wnudge py -0.5"
--        bind kp_home       "cw_wnudge pz 0.5"
--        bind kp_end        "cw_wnudge pz -0.5"
--        bind kp_pgup       "cw_wnudge ay 5"
--        bind kp_pgdn       "cw_wnudge ay -5"
--        bind kp_plus       "cw_wnudge ap 5"
--        bind kp_minus      "cw_wnudge ar 5"
--   4) Ajusta cada pieza (cambia de índice con cw_wsel); cw_wprint al final.

local wattSelected -- nombre del accesorio seleccionado
local wattPiece = 1 -- índice de la pieza (models[i]) dentro del accesorio

-- Devuelve la pieza (models[wattPiece]) del accesorio seleccionado, o nil.
local function GetSelectedPiece(ply)
	if (!wattSelected) then return nil end
	local wep = IsValid(ply) and ply:GetActiveWeapon()
	if (!IsValid(wep)) then return nil end
	local attCfg = ix.cwsupport.GetWorldAtt(wep:GetClass(), wattSelected)
	if (!attCfg or !attCfg.models) then return nil, attCfg end
	return attCfg.models[wattPiece], attCfg
end

concommand.Add("cw_wsel", function(ply, _, args)
	wattSelected = args[1]
	wattPiece = math.max(1, math.floor(tonumber(args[2]) or 1))

	local piece, attCfg = GetSelectedPiece(ply)
	if (!attCfg) then
		print("[cw_watt] '" .. tostring(wattSelected) .. "' no está en la config de esta arma.")
		return
	end
	if (!piece) then
		print(("[cw_watt] El accesorio '%s' solo tiene %i pieza(s)."):format(wattSelected, #attCfg.models))
		return
	end
	print(("[cw_watt] Seleccionado: %s pieza %i (%s)"):format(wattSelected, wattPiece, piece.model))
end)

concommand.Add("cw_wnudge", function(ply, _, args)
	local piece = GetSelectedPiece(ply)
	if (!piece) then print("[cw_watt] Primero: cw_wsel <accesorio> [índice]") return end

	local field = args[1]
	local delta = tonumber(args[2]) or 0

	if (field == "px") then piece.pos.x = piece.pos.x + delta
	elseif (field == "py") then piece.pos.y = piece.pos.y + delta
	elseif (field == "pz") then piece.pos.z = piece.pos.z + delta
	elseif (field == "ap") then piece.angle.p = piece.angle.p + delta
	elseif (field == "ay") then piece.angle.y = piece.angle.y + delta
	elseif (field == "ar") then piece.angle.r = piece.angle.r + delta
	elseif (field == "size") then
		local s = (piece.size and piece.size.x or 1) + delta
		piece.size = Vector(s, s, s)
	else
		print("[cw_watt] Campo inválido. Usa: px py pz ap ay ar size")
		return
	end

	print(("[cw_watt] %s#%i → pos(%.2f, %.2f, %.2f) ang(%.1f, %.1f, %.1f) size %.2f"):format(
		wattSelected, wattPiece,
		piece.pos.x, piece.pos.y, piece.pos.z,
		piece.angle.p, piece.angle.y, piece.angle.r,
		piece.size and piece.size.x or 1))
end)

-- Imprime la entrada completa del accesorio seleccionado (todas sus piezas),
-- lista para pegar en la tabla worldAttachments de este archivo.
concommand.Add("cw_wprint", function(ply)
	local _, attCfg = GetSelectedPiece(ply)
	if (!attCfg or !attCfg.models) then print("[cw_watt] Primero: cw_wsel <accesorio>") return end

	print(("\t\t\t[\"%s\"] = { models = {"):format(wattSelected))
	for _, p in ipairs(attCfg.models) do
		local s = p.size and p.size.x or 1
		print(("\t\t\t\t{ model = \"%s\", pos = Vector(%s, %s, %s), angle = Angle(%s, %s, %s), size = Vector(%s, %s, %s) },"):format(
			p.model,
			p.pos.x, p.pos.y, p.pos.z,
			p.angle.p, p.angle.y, p.angle.r,
			s, s, s))
	end
	print("\t\t\t}},")
end)
