local CHAR = ix.meta.character
local RUBLOS_ID = "rublos"

-- Los montones guardados con el uniqueID antiguo ("bala") pasan a "rublos";
-- si no, Helix descartaría el objeto al cargar el inventario.
function PLUGIN:DatabaseConnected()
	local query = mysql:Update("ix_items")
		query:Update("unique_id", RUBLOS_ID)
		query:Where("unique_id", "bala")
	query:Execute()
end

-- ── Net message para dividir un stack de rublos ────────────────────────────
util.AddNetworkString("ix_rublos_split")

net.Receive("ix_rublos_split", function(len, client)
	if not IsValid(client) then return end

	local char = client:GetCharacter()
	if not char then return end

	local itemID     = net.ReadUInt(32)
	local splitAmount = net.ReadUInt(32)

	local inventory = char:GetInventory()
	if not inventory then return end

	local item = ix.item.instances[itemID]
	if not item or item.uniqueID ~= RUBLOS_ID then return end

	-- Verificar que el item pertenece al inventario de este jugador
	if not inventory:GetItemByID(itemID) then return end

	local currentCount = item:GetData("count", 1)
	if splitAmount < 1 or splitAmount >= currentCount then return end

	-- Reducir el stack original
	item:SetData("count", currentCount - splitAmount)

	-- Crear nuevo stack con la cantidad separada
	inventory:Add(RUBLOS_ID, 1, {count = splitAmount})
end)

-- Capturamos SetMoney original para poder zerear el var de DB en CharacterLoaded
local _SetMoney = CHAR.SetMoney

-- ============================================================
--  Helpers de stack
-- ============================================================

-- Devuelve el item de rublos (el único stack) del inventario, o nil si no hay.
local function GetRublosStack(inventory)
    if not inventory then return nil end
    local items = inventory:GetItemsByUniqueID(RUBLOS_ID)
    return items[1]
end

-- Devuelve cuántos rublos tiene el inventario (suma de TODOS los stacks).
local function CountRublosItems(inventory)
    if not inventory then return 0 end
    local items = inventory:GetItemsByUniqueID(RUBLOS_ID)
    local total = 0
    for _, stack in ipairs(items) do
        total = total + stack:GetData("count", 1)
    end
    return total
end

-- Añade `amount` rublos: incrementa el stack existente o crea uno nuevo.
-- El count inicial se pasa como data para que quede correcto desde el primer tick.
local function AddRublosItems(inventory, amount)
    if not inventory or amount <= 0 then return 0 end

    local stack = GetRublosStack(inventory)
    if stack then
        stack:SetData("count", stack:GetData("count", 1) + amount)
        return amount
    end

    -- No hay stack: crear uno nuevo con count ya establecido
    local x = inventory:Add(RUBLOS_ID, 1, {count = amount})
    return x and amount or 0
end

-- Quita `amount` rublos: decrementa el stack. Elimina el item si llega a 0.
-- Recorre TODOS los montones (puede haber más de uno sin consolidar, p. ej.
-- justo tras recoger rublos del suelo) para no dejar de cobrar cuando el
-- primer montón encontrado no alcanza por sí solo la cantidad pedida.
local function RemoveRublosItems(inventory, amount)
    if not inventory or amount <= 0 then return 0 end

    local stacks = inventory:GetItemsByUniqueID(RUBLOS_ID)
    local remaining = amount
    local removed = 0

    for _, stack in ipairs(stacks) do
        if remaining <= 0 then break end

        local current  = stack:GetData("count", 1)
        local toRemove = math.min(remaining, current)

        if toRemove >= current then
            inventory:Remove(stack.id)
        else
            stack:SetData("count", current - toRemove)
        end

        remaining = remaining - toRemove
        removed = removed + toRemove
    end

    return removed
end

-- ============================================================
--  CharacterLoaded: conversión y consolidación
-- ============================================================

function PLUGIN:CharacterLoaded(character)
    local inventory = character:GetInventory()
    if not inventory then return end

    -- 1. Consolidar items de rublos sueltos del sistema anterior (pre-stack)
    --    Si hay más de un item rublos, mergeamos todos en uno.
    local allRublos = inventory:GetItemsByUniqueID(RUBLOS_ID)
    if #allRublos > 1 then
        local total = 0
        for _, item in ipairs(allRublos) do
            total = total + item:GetData("count", 1)
            inventory:Remove(item.id)
        end
        inventory:Add(RUBLOS_ID, 1, {count = total})
    end

    -- 2. Convertir dinero abstracto de Helix (de partidas anteriores) a items
    local storedMoney = character.vars.money or 0
    if storedMoney > 0 then
        if _SetMoney then
            _SetMoney(character, 0)
        end

        AddRublosItems(inventory, storedMoney)
    end
end

-- ============================================================
--  Overrides del metatable de personaje
-- ============================================================

function CHAR:GetMoney()
    return CountRublosItems(self:GetInventory())
end

function CHAR:GiveMoney(amount, bNoLog)
    amount = math.floor(math.abs(amount or 0))
    if amount <= 0 then return end
    AddRublosItems(self:GetInventory(), amount)
end

function CHAR:TakeMoney(amount, bNoLog)
    amount = math.floor(math.abs(amount or 0))
    if amount <= 0 then return end
    RemoveRublosItems(self:GetInventory(), amount)
end

-- SetMoney es no-op: el dinero vive en el campo count del item rublos
function CHAR:SetMoney(amount)
    return
end
