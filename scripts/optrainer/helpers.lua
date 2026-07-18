local Helpers = {}

local Context
local cachedFullFlags = nil

function Helpers.Init(context)
    Context = context
end

function Helpers.Player()
    local index = 0
    if Context and Context.Config and Context.Config.Data and Context.Config.Data.ui then
        index = Context.Config.Data.ui.selectedPlayer or 0
    end
    local num = 1
    if Isaac and Isaac.GetNumPlayers then
        local ok, value = pcall(Isaac.GetNumPlayers)
        if ok and value then num = value end
    end
    if index >= num then
        index = 0
    end
    local player = Isaac.GetPlayer(index)
    return player and player:ToPlayer() or player
end

function Helpers.SafeCall(fn, ...)
    if not fn then
        return false
    end

    local args = { ... }
    return pcall(function()
        return fn(table.unpack(args))
    end)
end

function Helpers.CallMethod(object, methodName, ...)
    if not object or not object[methodName] then
        return false
    end

    local args = { ... }
    return pcall(function()
        return object[methodName](object, table.unpack(args))
    end)
end

function Helpers.Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function Helpers.Lower(value)
    return tostring(value or ""):lower()
end

function Helpers.Log(message)
    if Context and Context.Config and Context.Config.Data.debug then
        Isaac.DebugString("[OPTrainer] " .. tostring(message))
    end
end

function Helpers.TimeCall(label, fn, ...)
    local start = os.clock()
    local ok, result = Helpers.SafeCall(fn, ...)
    local elapsed = (os.clock() - start) * 1000

    if Context and Context.Config and Context.Config.Data.debug and elapsed > 0.25 then
        Helpers.Log(label .. " took " .. string.format("%.3fms", elapsed))
    end

    return ok, result
end

function Helpers.AddCacheFlags(player, flags)
    if not player or not player.AddCacheFlags then
        return
    end

    pcall(function()
        player:AddCacheFlags(flags)
        player:EvaluateItems()
    end)
end

function Helpers.FullCacheFlags()
    if cachedFullFlags then return cachedFullFlags end
    local flags = 0
    local names = {
        "CACHE_DAMAGE",
        "CACHE_FIREDELAY",
        "CACHE_RANGE",
        "CACHE_SPEED",
        "CACHE_SHOTSPEED",
        "CACHE_LUCK",
        "CACHE_SIZE",
        "CACHE_FLYING",
        "CACHE_TEARFLAG",
    }

    for _, name in ipairs(names) do
        if CacheFlag and CacheFlag[name] then
            flags = flags | CacheFlag[name]
        end
    end

    cachedFullFlags = flags
    return flags
end

function Helpers.GetScreenSize()
    local width = 1280
    local height = 720
    if Isaac and Isaac.GetScreenWidth then
        local ok, value = pcall(Isaac.GetScreenWidth)
        if ok and tonumber(value) then
            width = tonumber(value)
        end
    end
    if Isaac and Isaac.GetScreenHeight then
        local ok, value = pcall(Isaac.GetScreenHeight)
        if ok and tonumber(value) then
            height = tonumber(value)
        end
    end
    return width, height
end

return Helpers
