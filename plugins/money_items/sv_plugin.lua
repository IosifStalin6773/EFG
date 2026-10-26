local CHAR = ix.meta.character
local BALA_ID = "bala"

-- ── Net message para dividir un stack de balas ────────────────────────────
util.AddNetworkString("ix_bala_split")

net.Receive("ix_bala_split", function(len, client)
	if not IsValid(client) then return end

	local char = client:GetCharacter()
	if not char then return end

	local itemID     = net.ReadUInt(32)
	local splitAmount = net.ReadUInt(32)

	local inventory = char:GetInventory()
	if not inventory then return end

	local item = ix.item.instances[itemID]
	if not item or item.uniqueID ~= BALA_ID then return end

	-- Verificar que el item pertenece al inventario de este jugador
	if not inventory:GetItemByID(itemID) then return end

	local currentCount = item:GetData("count", 1)
	if splitAmount < 1 or splitAmount >= currentCount then return end

	-- Reducir el stack original
	item:SetData("count", currentCount - splitAmount)

	-- Crear nuevo stack con la cantidad separada
	inventory:Add(BALA_ID, 1, {count = splitAmount})
end)

-- Capturamos SetMoney original para poder zerear el var de DB en CharacterLoaded
local _SetMoney = CHAR.SetMoney

-- ============================================================
--  Helpers de stack
-- ============================================================

-- Devuelve el item de bala (el único stack) del inventario, o nil si no hay.
local function GetBalaStack(inventory)
    if not inventory then return nil end
    local items = inventory:GetItemsByUniqueID(BALA_ID)
    return items[1]
end

-- Devuelve cuántas balas tiene el inventario (suma de TODOS los stacks).
local function CountBalaItems(inventory)
    if not inventory then return 0 end
    local items = inventory:GetItemsByUniqueID(BALA_ID)
    local total = 0
    for _, stack in ipairs(items) do
        total = total + stack:GetData("count", 1)
    end
    return total
end

-- Añade `amount` balas: incrementa el stack existente o crea uno nuevo.
-- El count inicial se pasa como data para que quede correcto desde el primer tick.
local function AddBalaItems(inventory, amount)
    if not inventory or amount <= 0 then return 0 end

    local stack = GetBalaStack(inventory)
    if stack then
        stack:SetData("count", stack:GetData("count", 1) + amount)
        return amount
    end

    -- No hay stack: crear uno nuevo con count ya establecido
    local x = inventory:Add(BALA_ID, 1, {count = amount})
    return x and amount or 0
end

-- Quita `amount` balas: decrementa el stack. Elimina el item si llega a 0.
-- Recorre TODOS los montones (puede haber más de uno sin consolidar, p. ej.
-- justo tras recoger balas del suelo) para no dejar de cobrar cuando el
-- primer montón encontrado no alcanza por sí solo la cantidad pedida.
local function RemoveBalaItems(inventory, amount)
    if not inventory or amount <= 0 then return 0 end

    local stacks = inventory:GetItemsByUniqueID(BALA_ID)
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

    -- 1. Consolidar items de bala sueltos del sistema anterior (pre-stack)
    --    Si hay más de un item bala, mergeamos todos en uno.
    local allBalas = inventory:GetItemsByUniqueID(BALA_ID)
    if #allBalas > 1 then
        local total = 0
        for _, item in ipairs(allBalas) do
            total = total + item:GetData("count", 1)
            inventory:Remove(item.id)
        end
        inventory:Add(BALA_ID, 1, {count = total})
    end

    -- 2. Convertir dinero abstracto de Helix (de partidas anteriores) a items
    local storedMoney = character.vars.money or 0
    if storedMoney > 0 then
        if _SetMoney then
            _SetMoney(character, 0)
        end

        AddBalaItems(inventory, storedMoney)
    end
end

-- ============================================================
--  Overrides del metatable de personaje
-- ============================================================

function CHAR:GetMoney()
    return CountBalaItems(self:GetInventory())
end

function CHAR:GiveMoney(amount, bNoLog)
    amount = math.floor(math.abs(amount or 0))
    if amount <= 0 then return end
    AddBalaItems(self:GetInventory(), amount)
end

function CHAR:TakeMoney(amount, bNoLog)
    amount = math.floor(math.abs(amount or 0))
    if amount <= 0 then return end
    RemoveBalaItems(self:GetInventory(), amount)
end

-- SetMoney es no-op: el dinero vive en el campo count del item bala
function CHAR:SetMoney(amount)
    return
end
