local Config = {}

local Context
local dirty = false
local lastSaveTime = 0

local function key(name, fallback)
    return Keyboard and Keyboard[name] or fallback
end

local defaults = {
    version = "1.5.0",
    window = { x = 48, y = 32, visible = false },
    language = "en",
    theme = "Midnight",
    autosave = true,
    debug = false,
    lastBuild = "OP Build",
    favorites = {
        builds = { ["OP Build"] = true, ["Laser Build"] = true },
        collectibles = {},
        trinkets = {},
        cards = {},
        pills = {},
    },
    customBuilds = {},
    hotkeys = {
        opBuild = key("KEY_F6", 295),
        god = key("KEY_F7", 296),
        menu = key("KEY_F8", 297),
        heal = key("KEY_F9", 298),
        killRoom = key("KEY_F10", 299),
        fullCharge = 0,
        noBlink = 0,
        infiniteHp = 0,
        revealMap = 0,
        noCurse = 0,
        teleportBoss = 0,
    },
    settings = {
        notifications = true,
        autoCloseMenu = false,
        rememberLastSearch = true,
        enableHotkeys = true,
    },
    toggles = {
        god = false,
        infiniteHp = false,
        infiniteCharge = false,
        infiniteBatteries = false,
        infiniteCards = false,
        infinitePills = false,
        infiniteCoins = false,
        infiniteKeys = false,
        infiniteBombs = false,
        holyMantle = false,
        flight = false,
        spectralTears = false,
        noCurse = false,
        revealMap = false,
        infiniteHolyMantle = false,
        freezeEnemies = false,
        slowEnemies = false,
        confuseEnemies = false,
        fearEnemies = false,
        charmEnemies = false,
        bigIsaac = false,
        tinyIsaac = false,
        rainbow = false,
        randomColors = false,
        noBlink = false,
        oneHitKill = false,
        homingTears = false,
        piercingTears = false,
        laserTears = false,
    },
    stats = {
        damage = 0,
        tears = 0,
        range = 0,
        luck = 0,
        speed = 0,
        shotSpeed = 0,
        fireDelay = 0,
        scale = 0,
        size = 0,
        health = 6,
        soulHearts = 0,
        blackHearts = 0,
        boneHearts = 0,
        rottenHearts = 0,
        brokenHearts = 0,
        damageMultiplier = 1.0,
        damageTakenMultiplier = 1.0,
    },
    ui = {
        search = "",
        itemFilter = "Collectibles",
        lastTab = "Dashboard",
        buildDraftName = "Custom Build",
        buildDraftItems = "",
        importExport = "",
        selectedPlayer = 0,
        roomIndex = 0,
    },
    utilities = { command = "", script = "", macro = "" },
}

local function copy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for keyValue, child in pairs(value) do
        result[keyValue] = copy(child)
    end
    return result
end

local function merge(base, patch)
    if type(base) ~= "table" or type(patch) ~= "table" then
        return base
    end

    for keyValue, value in pairs(patch) do
        if type(value) == "table" and type(base[keyValue]) == "table" then
            merge(base[keyValue], value)
        else
            base[keyValue] = value
        end
    end
    return base
end

local function normalizeFavorites(data)
    if type(data.favorites) ~= "table" then
        data.favorites = copy(defaults.favorites)
        return
    end

    if #data.favorites > 0 then
        local builds = {}
        for _, name in ipairs(data.favorites) do
            builds[tostring(name)] = true
        end
        data.favorites = copy(defaults.favorites)
        data.favorites.builds = builds
    else
        merge(data.favorites, copy(defaults.favorites))
    end
end

local function normalizeWindow(window)
    if type(window) ~= "table" then
        return copy(defaults.window)
    end

    window.x = math.max(0, window.x or 0)
    window.y = math.max(0, window.y or 0)
    return window
end

local function normalizeHotkeys(data)
    if type(data.hotkeys) ~= "table" then
        data.hotkeys = copy(defaults.hotkeys)
        return
    end

    -- The menu key is the recovery path for opening Settings, so it must
    -- never inherit an invalid or unbound value from older save data.
    if type(data.hotkeys.menu) ~= "number" or data.hotkeys.menu <= 0 then
        data.hotkeys.menu = defaults.hotkeys.menu
    end
end

function Config.Init(context)
    Context = context
    Config.Data = copy(defaults)
end

function Config.Load()
    Config.Data = copy(defaults)

    if Context.Mod:HasData() then
        local ok, raw = pcall(function()
            return Context.Mod:LoadData()
        end)
        local decoded = ok and Context.Json.Decode(raw) or nil
        if type(decoded) == "table" then
            merge(Config.Data, decoded)
        else
            Config.Data.saveWarning = "Previous save data was unreadable and has been reset."
        end
    end

    Config.Data.version = Context.Constants.VERSION
    normalizeFavorites(Config.Data)
    Config.Data.window = normalizeWindow(Config.Data.window)
    normalizeHotkeys(Config.Data)
end

function Config.NormalizeWindow()
    Config.Data.window = normalizeWindow(Config.Data.window)
end

function Config.Save(force)
    if force then
        local encoded = Context.Json.Encode(Config.Data)
        if encoded and encoded ~= "" then
            Context.Mod:SaveData(encoded)
        end
        dirty = false
        lastSaveTime = os.clock()
    else
        if Config.Data.autosave then
            dirty = true
        end
    end
end

function Config.FlushIfDirty()
    if dirty and os.clock() - lastSaveTime >= 2.0 then
        Config.Save(true)
    end
end

function Config.Set(path, value)
    local cursor = Config.Data
    for index = 1, #path - 1 do
        local keyValue = path[index]
        cursor[keyValue] = cursor[keyValue] or {}
        cursor = cursor[keyValue]
    end
    cursor[path[#path]] = value
    Config.Save(false)
end

function Config.Toggle(path)
    local cursor = Config.Data
    for index = 1, #path - 1 do
        cursor = cursor[path[index]]
    end
    local keyValue = path[#path]
    cursor[keyValue] = not cursor[keyValue]
    Config.Save(false)
    return cursor[keyValue]
end

function Config.ExportBuilds()
    return Context.Json.Encode(Config.Data.customBuilds or {})
end

function Config.ImportBuilds(text)
    local decoded = Context.Json.Decode(text)
    if type(decoded) == "table" then
        Config.Data.customBuilds = decoded
        Config.Save(true)
        return true
    end
    return false
end

return Config
