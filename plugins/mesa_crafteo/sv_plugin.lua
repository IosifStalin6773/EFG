local PLUGIN = PLUGIN

util.AddNetworkString(PLUGIN.netNameRecipe)
util.AddNetworkString(PLUGIN.netNameBlueprint)
util.AddNetworkString(PLUGIN.netNameDismantle)

util.AddNetworkString(PLUGIN.netNameCraftingGUI)
util.AddNetworkString(PLUGIN.netNameStoveGUI)

net.Receive(PLUGIN.netNameRecipe, function(_, client)
    local recipe = net.ReadString()
    local quantity = math.Clamp(net.ReadUInt(8), 1, 99)
    if not recipe then return end
    recipe = ix.recipe:FindByID(recipe)
    if not recipe then return end

    ix.recipe:Cook(recipe, client, quantity)
end)

net.Receive(PLUGIN.netNameBlueprint, function(_, client)
    local blueprint = net.ReadString()
    local quantity = math.Clamp(net.ReadUInt(8), 1, 99)
    if not blueprint then return end
    blueprint = ix.blueprint:FindByID(blueprint)
    if not blueprint then return end

    local crafted = 0
    for i = 1, quantity do
        if (not ix.blueprint:CanCraftBlueprint(blueprint, client)) then break end
        ix.blueprint:Craft(blueprint, client)
        crafted = crafted + 1
    end

    if (crafted > 1) then
        client:Notify(('Has ensamblado "%s" x%i'):format(blueprint.name, crafted))
    elseif (crafted == 1) then
        client:Notify(('Has ensamblado "%s"'):format(blueprint.name))
    end
end)

-- Entrega 'total' unidades de un ingrediente respetando su apilado (Amount).
local function GiveStacked(inventory, client, uniqueID, total)
    local maxS = (ix.item.list[uniqueID] and ix.item.list[uniqueID].maxstack) or 1
    if (maxS <= 1) then
        for _ = 1, total do
            if (not inventory:Add(uniqueID)) then
                ix.item.Spawn(uniqueID, client)
            end
        end
        return
    end

    while (total > 0) do
        local chunk = math.min(total, maxS)
        if (not inventory:Add(uniqueID, 1, {Amount = chunk})) then
            ix.item.Spawn(uniqueID, client, nil, nil, {Amount = chunk})
        end
        total = total - chunk
    end
end

net.Receive(PLUGIN.netNameDismantle, function(_, client)
    local blueprintID = net.ReadString()
    if (not blueprintID) then return end

    local requested = math.Clamp(net.ReadUInt(8), 1, 99)

    local blueprint = ix.blueprint:FindByID(blueprintID)
    if (not blueprint) then return end

    local char = client:GetCharacter()
    if (not char) then return end

    -- Desmontar exige el mismo oficio/tier que craftear el blueprint: si no,
    -- se puede farmear material de tier alto con equipo comprado/tradeado.
    if (not blueprint.noOficio and blueprint.oficio) then
        local tierRequired = blueprint.tierRequired or 1
        if (not ix.oficios or not ix.oficios.CanCraft(char, blueprint.oficio, tierRequired)) then
            local officeName = (ix.oficios and ix.oficios.lista and ix.oficios.lista[blueprint.oficio]) or blueprint.oficio
            client:Notify(('Necesitas %s nivel %i en el escondite para desmontar esto.'):format(officeName, tierRequired))
            return
        end
    end

    local inventory = char:GetInventory()

    -- Localiza el primer resultado que el jugador posee y reúne todos sus
    -- montones, sumando las unidades disponibles (campo Amount).
    local stacks, available, matchedResultID = nil, 0, nil
    for resultID, _ in pairs(blueprint.result) do
        local matches = {}
        local total = 0
        for _, invItem in pairs(inventory:GetItems()) do
            if (invItem.uniqueID == resultID) then
                matches[#matches + 1] = invItem
                total = total + invItem:GetData("Amount", 1)
            end
        end
        if (total > 0) then
            stacks = matches
            available = total
            matchedResultID = resultID
            break
        end
    end

    if (not stacks or available <= 0) then
        client:Notify("No tienes el ítem para desmontar.")
        return
    end

    local toDismantle = math.min(requested, available)

    -- Consume las unidades repartidas entre los montones existentes.
    local remaining = toDismantle
    for _, invItem in ipairs(stacks) do
        if (remaining <= 0) then break end
        local amount = invItem:GetData("Amount", 1)
        if (amount > remaining) then
            invItem:SetData("Amount", amount - remaining)
            remaining = 0
        else
            remaining = remaining - amount
            invItem:Remove()
        end
    end

    -- Devuelve ~50% de cada ingrediente, pero "amount" es el coste de UN
    -- crafteo, que puede producir varias unidades de resultado (ej. 1 plomo
    -- + 1 pólvora → 2 balas). Sin dividir por ese rendimiento, dismantle
    -- devolvía el coste de un crafteo COMPLETO por cada unidad desmontada
    -- (dupe: craftear 2 balas y desmontarlas devolvía el doble de material).
    local resultCount = math.max(blueprint.result[matchedResultID] or 1, 1)
    for ingredient, amount in pairs(blueprint.ingredients) do
        local costPerUnit = amount / resultCount
        local give = math.floor(costPerUnit * toDismantle * 0.5)
        if (give > 0) then
            GiveStacked(inventory, client, ingredient, give)
        end
    end

    if (toDismantle > 1) then
        client:Notify(('Has desmontado %ix "%s".'):format(toDismantle, blueprint.name))
    else
        client:Notify(('Has desmontado "%s".'):format(blueprint.name))
    end
end)

-- ════════════════════════════════════════════════════════════════════
--  PERSISTENCIA DE MESAS
-- ════════════════════════════════════════════════════════════════════

ix.mesa_crafteo = ix.mesa_crafteo or {}

local CLASES_MESA = {
	efg_craftingstation        = true,
	efg_craftingstation_quimica  = true,
	efg_craftingstation_reciclaje = true,
	efg_stove                  = true,
}

function PLUGIN:LoadData()
	ix.mesa_crafteo.mesas = self:GetData() or {}

	-- mesas guardadas con las clases de antes del cambio de nombre (metro_*)
	for _, info in ipairs(ix.mesa_crafteo.mesas) do
		if (isstring(info.class)) then
			info.class = info.class:gsub("^metro_", "efg_")
		end
	end

	timer.Simple(1, function()
		for _, info in ipairs(ix.mesa_crafteo.mesas) do
			local pos = Vector(info.px, info.py, info.pz)

			local exists = false
			for _, e in pairs(ents.FindByClass(info.class)) do
				if (IsValid(e) and e:GetPos():DistToSqr(pos) < 100) then
					exists = true
					break
				end
			end

			if (not exists) then
				local ent = ents.Create(info.class)
				if (IsValid(ent)) then
					ent:SetPos(pos)
					ent:SetAngles(Angle(0, info.ay or 0, 0))
					ent:Spawn()
					ent:Activate()
				end
			end
		end
	end)
end

function PLUGIN:SaveData()
	if (ix.shuttingDown) then return end

	self:SetData(ix.mesa_crafteo.mesas)
end

local function SpawnMesa(client, class, label)
	local trace = client:GetEyeTraceNoCursor()
	local pos   = trace.HitPos + trace.HitNormal * 5
	local ang   = (client:GetPos() - pos):Angle()
	ang.pitch   = 0
	ang.roll    = 0

	local ent = ents.Create(class)
	if (not IsValid(ent)) then
		return client:Notify("No se pudo crear la entidad.")
	end

	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent:Spawn()
	ent:Activate()

	ix.mesa_crafteo.mesas = ix.mesa_crafteo.mesas or {}
	ix.mesa_crafteo.mesas[#ix.mesa_crafteo.mesas + 1] = {
		class = class,
		px = pos.x, py = pos.y, pz = pos.z,
		ay = ang.yaw,
	}
	PLUGIN:SaveData()

	client:Notify(label .. " colocada.")
end

ix.command.Add("ColocarMesaArmas", {
	description = "Coloca el Banco de trabajo del escondite.",
	adminOnly = true,
	OnRun = function(self, client)
		SpawnMesa(client, "efg_craftingstation", "Mesa de Armas y Armaduras")
	end
})

ix.command.Add("ColocarMesaQuimica", {
	description = "Coloca la Estación médica del escondite.",
	adminOnly = true,
	OnRun = function(self, client)
		SpawnMesa(client, "efg_craftingstation_quimica", "Mesa Química/Médica")
	end
})

ix.command.Add("ColocarBancoReciclaje", {
	description = "Coloca el Lavabo del escondite.",
	adminOnly = true,
	OnRun = function(self, client)
		SpawnMesa(client, "efg_craftingstation_reciclaje", "Banco de Reciclaje")
	end
})

ix.command.Add("ColocarCocina", {
	description = "Coloca la Unidad de nutrición del escondite.",
	adminOnly = true,
	OnRun = function(self, client)
		SpawnMesa(client, "efg_stove", "Cocina")
	end
})

ix.command.Add("QuitarMesa", {
	description = "Elimina la mesa de crafteo a la que estás mirando.",
	adminOnly = true,
	OnRun = function(self, client)
		local ent = client:GetEyeTrace().Entity
		if (not IsValid(ent) or not CLASES_MESA[ent:GetClass()]) then
			return client:Notify("No estás mirando a ninguna mesa de crafteo.")
		end

		local pos = ent:GetPos()
		ix.mesa_crafteo.mesas = ix.mesa_crafteo.mesas or {}

		for i = #ix.mesa_crafteo.mesas, 1, -1 do
			local info = ix.mesa_crafteo.mesas[i]
			if (Vector(info.px, info.py, info.pz):DistToSqr(pos) < 100) then
				table.remove(ix.mesa_crafteo.mesas, i)
			end
		end

		PLUGIN:SaveData()
		ent:Remove()
		client:Notify("Mesa eliminada.")
	end
})
