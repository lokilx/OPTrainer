local Favorites = {}

local Context

local function bucket(kind)
    local favorites = Context.Config.Data.favorites
    favorites[kind] = favorites[kind] or {}
    return favorites[kind]
end

local function key(id)
    return tostring(id)
end

function Favorites.Init(context)
    Context = context
end

function Favorites.Is(kind, id)
    return bucket(kind)[key(id)] == true
end

function Favorites.Toggle(kind, id, label)
    local list = bucket(kind)
    local itemKey = key(id)
    list[itemKey] = not list[itemKey] or nil

    Context.Config.Save(false)
    Context.Notifications.Push((list[itemKey] and "Favorited " or "Unfavorited ") .. tostring(label or id))
    return list[itemKey] == true
end

function Favorites.List(kind)
    local result = {}
    for id in pairs(bucket(kind)) do
        result[#result + 1] = tonumber(id) or id
    end
    table.sort(result, function(left, right) return tostring(left) < tostring(right) end)
    return result
end

return Favorites
