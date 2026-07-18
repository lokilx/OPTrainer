local QuickActions = {}

local Context

local function player()
    return Context.Helpers.Player()
end

local function addToMax(methodName, getterName, target)
    local currentPlayer = player()
    if not currentPlayer then
        return
    end

    local current = 0
    pcall(function()
        current = currentPlayer[getterName](currentPlayer)
    end)
    Context.Helpers.CallMethod(currentPlayer, methodName, target - current)
end

function QuickActions.Init(context)
    Context = context
end

function QuickActions.HealPlayer()
    Context.Actions.Heal()
end

function QuickActions.FullHealth()
    local currentPlayer = player()
    if not currentPlayer then
        return
    end

    Context.Helpers.CallMethod(currentPlayer, "AddMaxHearts", 24, true)
    Context.Helpers.CallMethod(currentPlayer, "AddHearts", 48)
    Context.Helpers.CallMethod(currentPlayer, "AddSoulHearts", 24)
    Context.Helpers.CallMethod(currentPlayer, "AddBlackHearts", 24)
    Context.Notifications.Push("Full health")
end

function QuickActions.FullCharge()
    local currentPlayer = player()
    if not currentPlayer then
        return
    end

    for slot = 0, 3 do
        Context.Helpers.CallMethod(currentPlayer, "SetActiveCharge", 99, slot)
    end
    Context.Notifications.Push("Active items charged")
end

function QuickActions.Give99Coins()
    addToMax("AddCoins", "GetNumCoins", 99)
end

function QuickActions.Give99Bombs()
    addToMax("AddBombs", "GetNumBombs", 99)
end

function QuickActions.Give99Keys()
    addToMax("AddKeys", "GetNumKeys", 99)
end

function QuickActions.GiveAllConsumables()
    QuickActions.Give99Coins()
    QuickActions.Give99Bombs()
    QuickActions.Give99Keys()
    Context.Notifications.Push("All consumables maxed")
end

function QuickActions.OpenAllDoors()
    local room = Context.Game:GetRoom()
    local maxDoorSlot = DoorSlot and DoorSlot.NUM_DOOR_SLOTS and DoorSlot.NUM_DOOR_SLOTS - 1 or 7
    for slot = 0, maxDoorSlot do
        local door = room:GetDoor(slot)
        if door then
            pcall(function()
                door:Open()
            end)
        end
    end
    Context.Notifications.Push("Doors opened")
end

function QuickActions.RevealEntireMap()
    pcall(function()
        local level = Context.Game:GetLevel()
        level:ApplyMapEffect()
        level:ApplyCompassEffect()
        level:ApplyBlueMapEffect()
    end)
    Context.Notifications.Push("Map revealed")
end

function QuickActions.RemoveCurrentCurse()
    local level = Context.Game:GetLevel()
    pcall(function()
        level:RemoveCurses(level:GetCurses())
    end)
    Context.Notifications.Push("Curse removed")
end

function QuickActions.SpawnCrawlspace()
    local room = Context.Game:GetRoom()
    local grid = room:GetGridIndex(room:GetCenterPos())
    pcall(function()
        room:SpawnGridEntity(grid, Context.Constants.GRID.STAIRS, 0, 0, 0)
    end)
    Context.Notifications.Push("Crawlspace spawned")
end

function QuickActions.SpawnTrapdoor()
    local room = Context.Game:GetRoom()
    local grid = room:GetGridIndex(room:GetCenterPos())
    pcall(function()
        room:SpawnGridEntity(grid, Context.Constants.GRID.TRAPDOOR, 0, 0, 0)
    end)
    Context.Notifications.Push("Trapdoor spawned")
end

function QuickActions.ClearCurrentRoom()
    Context.Actions.ClearRoom()
end

function QuickActions.KillAllEnemies()
    Context.Actions.KillRoom()
end

function QuickActions.RefillActiveItem()
    QuickActions.FullCharge()
end

function QuickActions.MaxPickups()
    local pickup = Context.Constants.PICKUP
    Context.Actions.SpawnPickup(pickup.COIN, 0, 12)
    Context.Actions.SpawnPickup(pickup.KEY, 0, 6)
    Context.Actions.SpawnPickup(pickup.BOMB, 0, 6)
    Context.Notifications.Push("Pickups spawned")
end

return QuickActions
