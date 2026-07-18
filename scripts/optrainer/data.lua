local Data = {}

local Context
local cachedItemConfig

local function enum(tableRef, key, fallback)
    return tableRef and tableRef[key] or fallback
end

local C = CollectibleType

Data.Builds = {
    { name = "OP Build", items = { 182, 395, 118, 678, 698, 562, 330, 689, 105, 691, 331, 12, 4, 313, 14, 28, 1, 143, 70 } },
    { name = "One Shot", items = { 118, 182, 331, 4, 245, 562, 689 } },
    { name = "Laser Build", items = { 118, 395, 68, 52, 114, 562, 689 } },
    { name = "Knife Build", items = { 114, 182, 331, 330, 562, 698, 689 } },
    { name = "Infinite Tears", items = { 330, 233, 245, 531, 562, 395, 698 } },
    { name = "Glass Cannon", items = { 352, 182, 4, 331, 562, 689, 691 } },
    { name = "Angel Build", items = { 182, 331, 313, 184, 363, 499, 691 } },
    { name = "Devil Build", items = { 118, 79, 360, 399, 51, 562, 698 } },
    { name = "Greed Build", items = { 349, 202, 74, 109, 105, 689, 691 } },
    { name = "Random Broken Build", random = true },
    { name = "Summoner Build", items = { 67, 100, 113, 167, 188, 390, 698 } },
    { name = "Bomb Build", items = { 19, 106, 125, 220, 353, 517, 648 } },
    { name = "Luck Build", items = { 46, 53, 75, 246, 368, 528, 689 } },
    { name = "Beast Killer", items = { 118, 395, 182, 331, 562, 691, 698 } },
    { name = "Mother Killer", items = { 114, 182, 330, 395, 562, 689, 698 } },
    { name = "Delirium Killer", items = { 118, 395, 331, 493, 562, 689, 691 } },
    { name = "Ultra Greed Killer", items = { 202, 349, 395, 492, 562, 689, 691 } },
    { name = "God Run", items = { 1, 4, 12, 105, 118, 182, 313, 331, 395, 562, 678, 689, 691, 698 } },
}

Data.Enemies = {
    { name = "Gaper", type = 10, variant = 0 },
    { name = "Horf", type = 26, variant = 0 },
    { name = "Mulligan", type = 14, variant = 0 },
    { name = "Globin", type = 24, variant = 0 },
    { name = "Clotty", type = 25, variant = 0 },
    { name = "Keeper", type = 215, variant = 0 },
    { name = "Monstro", type = 20, variant = 0 },
    { name = "Larry Jr.", type = 19, variant = 0 },
    { name = "Duke of Flies", type = 67, variant = 0 },
    { name = "Mom", type = 45, variant = 0 },
}

Data.RoomTargets = {
    -- Floor boss rooms
    { name = "Boss Room", roomType = RoomType and RoomType.ROOM_BOSS or 5, command = "goto s.boss.1010" },
    { name = "Mini Boss", roomType = RoomType and RoomType.ROOM_MINIBOSS or 6, command = "goto s.miniboss.0" },
    { name = "Boss Rush", roomType = RoomType and RoomType.ROOM_BOSSRUSH or 11, command = "goto s.bossrush.0" },
    -- Completion mark bosses
    { name = "Mom (Depths II)", command = "stage 6" },
    { name = "Mom's Heart (Womb II)", command = "stage 8" },
    { name = "Isaac (Cathedral)", command = "stage 10a" },
    { name = "Satan (Sheol)", command = "stage 10" },
    { name = "??? / Blue Baby (Chest)", command = "stage 11a" },
    { name = "The Lamb (Dark Room)", command = "stage 11" },
    { name = "Hush (Blue Womb)", command = "stage 9" },
    { name = "Mega Satan", command = "goto s.boss.5000" },
    { name = "Delirium (Void)", command = "stage 12" },
    { name = "Mother (Corpse II)", command = "stage 8c" },
    { name = "The Beast (Home)", command = "macro beast" },
    -- Special rooms
    { name = "Treasure", roomType = RoomType and RoomType.ROOM_TREASURE or 4, command = "goto s.treasure.0" },
    { name = "Angel", roomType = RoomType and RoomType.ROOM_ANGEL or 15, command = "goto s.angel.0" },
    { name = "Devil", roomType = RoomType and RoomType.ROOM_DEVIL or 14, command = "goto s.devil.0" },
    { name = "Secret", roomType = RoomType and RoomType.ROOM_SECRET or 7, command = "goto s.secret.0" },
    { name = "Ultra Secret", roomType = RoomType and RoomType.ROOM_ULTRASECRET or 29, command = "goto s.ultrasecret.0" },
    { name = "Error Room", roomType = RoomType and RoomType.ROOM_ERROR or 12, command = "goto s.error.0" },
}

Data.Stages = {
    -- Chapter 1
    { id = "1", name = "Basement I" },
    { id = "1a", name = "Cellar I" },
    { id = "1b", name = "Burning Basement I" },
    { id = "1c", name = "Downpour I" },
    { id = "2", name = "Basement II" },
    { id = "2a", name = "Cellar II" },
    { id = "2b", name = "Burning Basement II" },
    { id = "2c", name = "Downpour II / Dross II" },
    -- Chapter 2
    { id = "3", name = "Caves I" },
    { id = "3a", name = "Catacombs I" },
    { id = "3b", name = "Flooded Caves I" },
    { id = "3c", name = "Mines I / Ashpit I" },
    { id = "4", name = "Caves II" },
    { id = "4a", name = "Catacombs II" },
    { id = "4b", name = "Flooded Caves II" },
    { id = "4c", name = "Mines II / Ashpit II" },
    -- Chapter 3
    { id = "5", name = "Depths I" },
    { id = "5a", name = "Necropolis I" },
    { id = "5b", name = "Dank Depths I" },
    { id = "5c", name = "Mausoleum I / Gehenna I" },
    { id = "6", name = "Depths II (Mom)" },
    { id = "6a", name = "Necropolis II" },
    { id = "6b", name = "Dank Depths II" },
    { id = "6c", name = "Mausoleum II / Gehenna II" },
    -- Chapter 4
    { id = "7", name = "Womb I" },
    { id = "7a", name = "Utero I" },
    { id = "7b", name = "Scarred Womb I" },
    { id = "7c", name = "Corpse I" },
    { id = "8", name = "Womb II (Mom's Heart)" },
    { id = "8a", name = "Utero II" },
    { id = "8b", name = "Scarred Womb II" },
    { id = "8c", name = "Corpse II (Mother)" },
    -- End-game
    { id = "9", name = "Blue Womb (Hush)" },
    { id = "10", name = "Sheol (Satan)" },
    { id = "10a", name = "Cathedral (Isaac)" },
    { id = "11", name = "Dark Room (The Lamb)" },
    { id = "11a", name = "Chest (??? / Blue Baby)" },
    { id = "12", name = "Void (Delirium)" },
    { id = "13", name = "Home (The Beast)" },
}
Data.Catalog = { collectibles = {}, trinkets = {}, cards = {}, pills = {} }

function Data.Init(context)
    Context = context
end

local familiarIds = {
    [8]=true, [67]=true, [95]=true, [99]=true, [100]=true, [113]=true, [163]=true, [167]=true,
    [174]=true, [267]=true, [268]=true, [269]=true, [270]=true, [273]=true, [274]=true, [276]=true,
    [278]=true, [322]=true, [358]=true, [359]=true, [360]=true, [363]=true, [364]=true, [365]=true,
    [373]=true, [374]=true, [384]=true, [388]=true, [389]=true, [390]=true, [416]=true, [417]=true,
    [421]=true, [422]=true, [424]=true, [426]=true, [428]=true, [446]=true, [447]=true, [448]=true,
    [450]=true, [451]=true, [452]=true, [491]=true, [492]=true, [493]=true, [496]=true, [512]=true,
    [513]=true, [537]=true, [539]=true, [540]=true, [541]=true, [542]=true, [565]=true, [568]=true,
    [607]=true, [613]=true, [621]=true, [622]=true, [628]=true, [633]=true, [643]=true, [678]=true,
    [693]=true, [694]=true, [695]=true, [705]=true
}

local function resolveString(str, category)
    if not str or str == "" then return "" end
    if str:sub(1, 1) == "#" then
        local key = str:sub(2)
        if Isaac and Isaac.GetString then
            local categories = { "Items", "Pocketitems", "PocketItems" }
            if category and category ~= "Cards" and category ~= "Pills" then
                table.insert(categories, 1, category)
            end
            for _, cat in ipairs(categories) do
                local ok, val = pcall(Isaac.GetString, cat, key)
                if ok and val and val ~= "" 
                   and val ~= "StringTable::InvalidKey" 
                   and val ~= "StringTable::InvalidCategory"
                   and not val:find("StringTable::", 1, true)
                then
                    return val
                end
            end
        end
        
        -- Clean up key if not found in any category (e.g. "#CARD_FOOL_NAME" -> "Fool")
        local clean = key
        if clean:sub(-5) == "_NAME" then
            clean = clean:sub(1, -6)
        elseif clean:sub(-12) == "_DESCRIPTION" then
            clean = clean:sub(1, -13)
        end
        if clean:sub(1, 5) == "CARD_" then
            clean = clean:sub(6)
        elseif clean:sub(1, 5) == "PILL_" then
            clean = clean:sub(6)
        elseif clean:sub(1, 5) == "RUNE_" then
            clean = clean:sub(6)
        end
        clean = clean:gsub("_", " ")
        clean = clean:gsub("(%a)([%w]*)", function(first, rest)
            return first:upper() .. rest:lower()
        end)
        return clean
    end
    return str
end

local function push(target, itemType, id, item)
    if not item or not item.Name or item.Name == "" then
        return
    end

    local category = "Items"
    if itemType == "Card" then
        category = "Cards"
    elseif itemType == "Pill" then
        category = "Pills"
    end

    local tagsList = {}
    local isFamiliar = false
    
    if itemType == "Collectible" then
        if familiarIds[id] then
            isFamiliar = true
        end
        pcall(function()
            if item.HasCustomTag and item:HasCustomTag("familiar") then
                isFamiliar = true
            elseif item.HasTag and item:HasTag("familiar") then
                isFamiliar = true
            elseif ItemConfig and ItemConfig.ItemTags and ItemConfig.ItemTags.TAG_FAMILIAR and item.HasTags and item:HasTags(ItemConfig.ItemTags.TAG_FAMILIAR) then
                isFamiliar = true
            elseif ItemConfig and ItemConfig.TAG_FAMILIAR and item.HasTags and item:HasTags(ItemConfig.TAG_FAMILIAR) then
                isFamiliar = true
            end
        end)
    end
    
    if isFamiliar then
        tagsList[#tagsList + 1] = "familiar"
    end

    if item.GetCustomTags then
        pcall(function()
            local t = item:GetCustomTags()
            if type(t) == "table" then
                for _, tag in ipairs(t) do
                    local tstr = tostring(tag)
                    if tstr ~= "" then
                        tagsList[#tagsList + 1] = tstr
                    end
                end
            end
        end)
    end
    local tagsString = table.concat(tagsList, " ")

    local isRune = false
    if itemType == "Card" then
        if id >= 32 and id <= 41 then -- Standard runes
            isRune = true
        elseif id >= 81 and id <= 97 then -- Soul stones
            isRune = true
        elseif item.IsRune then
            pcall(function() isRune = item:IsRune() end)
        end
    end

    local entry = {
        id = id,
        type = itemType,
        name = resolveString(item.Name, category),
        quality = item.Quality or 0,
        tags = tagsString,
        itemType = item.Type or 0,
        pools = item.Pools or "",
        description = resolveString(item.Description or "", category),
        isRune = isRune,
    }
    target[#target + 1] = entry
end

local function scan(maxId, getter, bucket, kind)
    for id = 1, maxId do
        local ok, item = pcall(function()
            return getter(cachedItemConfig, id)
        end)
        if ok then
            push(bucket, kind, id, item)
        end
    end
end

function Data.RefreshCatalog()
    cachedItemConfig = cachedItemConfig or Isaac.GetItemConfig()
    Data.Catalog = { collectibles = {}, trinkets = {}, cards = {}, pills = {} }

    local function getSize(getter, fallback)
        local ok, result = pcall(function()
            local list = getter(cachedItemConfig)
            return list and list.Size or fallback
        end)
        return (ok and result) or fallback
    end

    scan(getSize(cachedItemConfig.GetCollectibles, 1000) - 1, cachedItemConfig.GetCollectible, Data.Catalog.collectibles, "Collectible")
    scan(getSize(cachedItemConfig.GetTrinkets, 350) - 1, cachedItemConfig.GetTrinket, Data.Catalog.trinkets, "Trinket")
    scan(getSize(cachedItemConfig.GetCards, 350) - 1, cachedItemConfig.GetCard, Data.Catalog.cards, "Card")
    scan(getSize(cachedItemConfig.GetPillEffects, 150) - 1, cachedItemConfig.GetPillEffect, Data.Catalog.pills, "Pill")
end

function Data.FindBuild(name)
    for _, build in ipairs(Data.Builds) do
        if build.name == name then
            return build
        end
    end

    for _, build in ipairs(Context.Config.Data.customBuilds or {}) do
        if build.name == name then
            return build
        end
    end

    return nil
end

function Data.SearchCatalog(filter, query, limit)
    if Context.Search then
        return Context.Search.Query(filter, query, limit)
    end
    return {}
end

return Data