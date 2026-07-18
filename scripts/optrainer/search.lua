local Search = {}

local Context
local cache = {}

local function normalize(value)
    return tostring(value or ""):lower()
end

local function acceptFilter(entry, filter)
    if filter == "Collectibles" then
        return entry.type == "Collectible"
    end
    if filter == "Trinkets" then
        return entry.type == "Trinket"
    end
    if filter == "Cards" then
        return entry.type == "Card" and not entry.isRune
    end
    if filter == "Runes" then
        return entry.type == "Card" and entry.isRune == true
    end
    if filter == "Pills" then
        return entry.type == "Pill"
    end
    if filter == "Active" then
        return entry.type == "Collectible" and ItemType and entry.itemType == ItemType.ITEM_ACTIVE
    end
    if filter == "Passive" then
        return entry.type == "Collectible" and ItemType and entry.itemType == ItemType.ITEM_PASSIVE
    end
    if filter == "Familiar" then
        return entry.type == "Collectible" and entry.tagsText and entry.tagsText:find("familiar", 1, true) ~= nil
    end
    return true
end

local function searchBucket(bucketName, filter, query, limit)
    local result = {}
    local source = cache[bucketName] or {}
    local exactId = tonumber(query)
    local quality = query:match("^q(%d)$")

    for _, entry in ipairs(source) do
        local ok = acceptFilter(entry, filter)
        if ok then
            if query == "" then
                result[#result + 1] = entry
            elseif exactId and entry.id == exactId then
                result[#result + 1] = entry
            elseif quality and entry.quality == tonumber(quality) then
                result[#result + 1] = entry
            elseif entry.searchText:find(query, 1, true) then
                result[#result + 1] = entry
            end
        end

        if #result >= limit then
            break
        end
    end

    return result
end

function Search.Init(context)
    Context = context
end

function Search.Rebuild()
    cache = {}

    for bucketName, list in pairs(Context.Data.Catalog or {}) do
        cache[bucketName] = {}
        for _, entry in ipairs(list) do
            local copied = {}
            for key, value in pairs(entry) do
                copied[key] = value
            end
            copied.nameLower = normalize(entry.name)
            copied.tagsText = normalize(entry.tags)
            copied.descriptionLower = normalize(entry.description)
            copied.searchText = table.concat({
                copied.nameLower,
                tostring(entry.id),
                normalize(entry.type),
                "q" .. tostring(entry.quality or 0),
                normalize(entry.itemType),
                copied.tagsText,
                copied.descriptionLower,
            }, " ")
            cache[bucketName][#cache[bucketName] + 1] = copied
        end
    end
end

function Search.Query(filter, text, limit)
    filter = filter or "Collectibles"
    local query = normalize(text)
    limit = limit or 12

    local bucketName = ({
        Collectibles = "collectibles",
        Trinkets = "trinkets",
        Cards = "cards",
        Runes = "cards",
        Pills = "pills",
        Active = "collectibles",
        Passive = "collectibles",
        Familiar = "collectibles",
        Quality = "collectibles",
        Pools = "collectibles",
    })[filter] or "collectibles"

    return searchBucket(bucketName, filter, query, limit)
end

return Search
