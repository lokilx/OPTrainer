local UI = {}

local Context
local W
local built = false
local fps = 0
local lastFrame = 0
local lastClock = 0
local searchResults = {}
local selectedEnemy = 1
local selectedStage = 1
local selectedRoom = 1
local selectedFilter = 1
local inventoryItemId = 1

local filters = { "Collectibles", "Trinkets", "Cards", "Runes", "Pills", "Active", "Passive", "Familiar", "Quality", "Pools" }
local tabs = {}

local function icon(name)
    return Context.Constants.ICONS[name] or ""
end

local function ids()
    return Context.Constants.UI
end

local function call(method, ...)
    if ImGui and ImGui[method] then
        local args = { ... }
        return pcall(function() return ImGui[method](table.unpack(args)) end)
    end
    return false
end

local function versionText()
    local repentogon = REPENTOGON and REPENTOGON.Version or "missing"
    local gameVersion = "Repentance+"
    if Isaac and Isaac.GetVersion then
        local ok, value = pcall(Isaac.GetVersion)
        if ok and value then gameVersion = tostring(value) end
    end
    return "OPTrainer " .. Context.Version .. " | REPENTOGON " .. tostring(repentogon) .. " | " .. gameVersion
end

local function statsText()
    local player = Context.Helpers.Player()
    if not player then return "No player" end
    return string.format("DMG %.1f | SPD %.2f | LCK %.1f | TRS %.2f | RNG %.0f | SS %.2f", player.Damage, player.MoveSpeed, player.Luck, math.max(0, 30 / math.max(1, player.MaxFireDelay + 1)), player.TearRange, player.ShotSpeed)
end

local function statusText()
    local game = Context.Game
    local room = game:GetRoom()
    local level = game:GetLevel()
    local status = room:IsClear() and "Clear" or "Combat"
    return string.format("%s | Stage %s | Room %s | TPS %d", status, tostring(level:GetStage()), tostring(level:GetCurrentRoomIndex()), fps)
end

local function autoClose()
    if Context.Config.Data.settings.autoCloseMenu then
        call("SetVisible", ids().WINDOW_ID, false)
        Context.Config.Data.window.visible = false
        Context.Config.Save(false)
    end
end

local function action(fn)
    return function(...)
        fn(...)
        autoClose()
    end
end

local function setToggle(key)
    return function(value)
        Context.Config.Data.toggles[key] = value
        Context.Config.Save(false)
        Context.Actions.RefreshStats()
    end
end

local function statSlider(parent, key, label, min, max, format)
    W.SliderFloat(parent, "OPTrainer.Stat." .. key, label, Context.Config.Data.stats[key], min, max, function(value)
        Context.Config.Data.stats[key] = value
        Context.Config.Save(false)
        Context.Actions.RefreshStats()
    end, format or "%.2f")
end

local function healthSlider(parent, key, label, max)
    W.SliderInt(parent, "OPTrainer.Health." .. key, label, Context.Config.Data.stats[key], 0, max, function(value)
        Context.Config.Data.stats[key] = value
        Context.Config.Save(false)
        Context.Actions.ApplyHealthSliders()
    end)
end

local function shortText(value, maxLength)
    value = tostring(value or "")
    maxLength = maxLength or 34
    if #value <= maxLength then
        return value
    end
    return value:sub(1, maxLength - 3) .. "..."
end


local function tabLabel(iconName, label, compactLabel)
    local width = 640
    pcall(function()
        if ImGui and ImGui.GetWindowWidth then
            width = ImGui.GetWindowWidth()
        end
    end)
    local breakpoint = (Context.Constants.UI and Context.Constants.UI.TAB_TEXT_BREAKPOINT) or 760
    if width <= breakpoint then
        return string.format("%s %s", icon(iconName), compactLabel or label)
    end
    return string.format("%s %s", icon(iconName), label)
end

local function selectedFilterName()
    return filters[selectedFilter] or "Collectibles"
end

local function favoriteKind(entry)
    if not entry then return "collectibles" end
    if entry.type == "Trinket" then return "trinkets" end
    if entry.type == "Card" then return "cards" end
    if entry.type == "Pill" then return "pills" end
    return "collectibles"
end

local function refreshSearch()
    local config = Context.Config.Data
    searchResults = Context.Search.Query(selectedFilterName(), config.ui.search, ids().SEARCH_RESULTS)

    for index = 1, ids().SEARCH_RESULTS do
        local entry = searchResults[index]
        local label = icon("search") .. " Empty"
        local tooltip = ""
        if entry then
            local fav = Context.Favorites.Is(favoriteKind(entry), entry.id) and (icon("star") .. " ") or ""
            label = string.format("%s%s [%s %d Q%d]", fav, shortText(entry.name, 28), entry.type, entry.id, entry.quality or 0)
            if entry.description and entry.description ~= "" then
                tooltip = entry.description
            else
                tooltip = "No description"
            end
        end
        W.UpdateText("OPTrainer.Items.Result." .. index, label)
        W.Tooltip("OPTrainer.Items.Result." .. index, tooltip)
    end
end

local function giveSearchResult(index)
    local entry = searchResults[index]
    if not entry then return end
    if entry.type == "Collectible" then Context.Actions.GiveCollectible(entry.id)
    elseif entry.type == "Trinket" then Context.Actions.GiveTrinket(entry.id)
    elseif entry.type == "Card" then Context.Actions.GiveCard(entry.id)
    elseif entry.type == "Pill" then Context.Actions.GivePill(entry.id) end
    Context.Notifications.Push("Gave " .. entry.name)
    autoClose()
end

local function removeSearchResult(index)
    local entry = searchResults[index]
    if not entry then return end
    if entry.type == "Collectible" then Context.Actions.RemoveCollectible(entry.id)
    elseif entry.type == "Trinket" then Context.Actions.RemoveTrinket(entry.id)
    elseif entry.type == "Card" then Context.Actions.RemoveCard(0)
    elseif entry.type == "Pill" then Context.Actions.RemovePill(0) end
    Context.Notifications.Push("Removed " .. entry.name)
end

local function toggleFavoriteResult(index)
    local entry = searchResults[index]
    if not entry then return end
    Context.Favorites.Toggle(favoriteKind(entry), entry.id, entry.name)
    refreshSearch()
end

local function updateCustomBuildButtons()
    local builds = Context.Config.Data.customBuilds or {}
    for index = 1, 8 do
        local build = builds[index]
        W.UpdateText("OPTrainer.CustomBuild.Apply." .. index, build and (icon("play") .. " " .. build.name) or (icon("plus") .. " Empty Slot"))
        W.UpdateText("OPTrainer.CustomBuild.Delete." .. index, build and (icon("trash") .. " Delete") or (icon("trash") .. " Empty"))
    end
end

local function addBuildFavoriteButton(parent, name, id)
    W.SmallButton(parent, id, icon("star") .. " Fav", function()
        Context.Favorites.Toggle("builds", name, name)
    end, Context.Favorites.Is("builds", name) and "warning" or nil)
end

local function seedText()
    local seedStr = "Unknown"
    pcall(function()
        local seeds = Context.Game:GetSeeds()
        if seeds then
            local startSeed = seeds:GetStartSeed()
            seedStr = Seeds.Seed2String(startSeed)
        end
    end)
    return seedStr
end

local function getPlayerNames()
    local names = {}
    local num = 1
    if Isaac and Isaac.GetNumPlayers then
        local ok, val = pcall(Isaac.GetNumPlayers)
        if ok and val then num = val end
    end
    for i = 1, num do
        names[#names + 1] = "Player " .. tostring(i)
    end
    return names
end

local function buildDashboard(tab)
    W.Separator(tab, "OPTrainer.Dashboard.Header", icon("bolt") .. " Dashboard")
    W.Combo(tab, "OPTrainer.Dashboard.PlayerSelect", "Target Player", getPlayerNames(), (Context.Config.Data.ui.selectedPlayer or 0) + 1, function(index)
        Context.Config.Data.ui.selectedPlayer = index - 1
        Context.Config.Save(false)
        Context.Actions.RefreshStats()
    end)
    
    W.Button(tab, "OPTrainer.Dashboard.OP", icon("bolt") .. " OP BUILD", action(function() Context.Actions.ApplyBuild("OP Build") end), "success")
    W.SameLine(tab, "OPTrainer.Dashboard.OP.Same")
    W.Button(tab, "OPTrainer.Dashboard.Heal", icon("heart") .. " Heal", action(Context.Actions.Heal), "success")

    W.Button(tab, "OPTrainer.Dashboard.Kill", icon("skull") .. " Kill Everything", action(Context.Actions.KillRoom), "danger")
    W.SameLine(tab, "OPTrainer.Dashboard.Kill.Same")
    W.Button(tab, "OPTrainer.Dashboard.Clear", icon("trash") .. " Clear Build", action(Context.Actions.ClearBuild), "danger")

    W.Button(tab, "OPTrainer.Dashboard.Restart", icon("play") .. " Restart Run", action(function()
        if Isaac.ExecuteCommand then Isaac.ExecuteCommand("restart") end
    end), "warning")
    W.SameLine(tab, "OPTrainer.Dashboard.Restart.Same")
    W.Button(tab, "OPTrainer.Dashboard.Charge", icon("bolt") .. " Full Charge", action(Context.Actions.FullCharge))

    W.Text(tab, "OPTrainer.Dashboard.Seed", "Seed: " .. seedText(), true, true)
    W.Text(tab, "OPTrainer.Dashboard.Last", "Last build: " .. Context.Config.Data.lastBuild, true, true)
    W.Text(tab, "OPTrainer.Dashboard.Stats", statsText(), false, true)
end

local function buildBuilds(tab)
    W.Separator(tab, "OPTrainer.Builds.Presets", icon("bolt") .. " Preset Builds")
    for index, build in ipairs(Context.Data.Builds) do
        W.Button(tab, "OPTrainer.Build." .. index, icon("bolt") .. " " .. build.name, action(function() Context.Actions.ApplyBuild(build.name) end), build.name == "OP Build" and "success" or nil)
    end

    W.Separator(tab, "OPTrainer.QuickBuilds.Header", icon("bolt") .. " Quick Builds")
    local list = Context.QuickBuilds.GetList()
    for index, build in ipairs(list) do
        W.Button(tab, "OPTrainer.QuickBuild." .. index, icon("bolt") .. " " .. build.name, action(function() Context.QuickBuilds.Apply(index) end), index == #list and "success" or nil)
    end

    W.Separator(tab, "OPTrainer.Builds.Custom", icon("save") .. " Custom Builds")
    W.Input(tab, "OPTrainer.CustomBuild.Name", "Name", Context.Config.Data.ui.buildDraftName, "Custom Build", function(text) Context.Config.Data.ui.buildDraftName = text end)
    W.Multiline(tab, "OPTrainer.CustomBuild.Items", "Item IDs", Context.Config.Data.ui.buildDraftItems, 3, function(text) Context.Config.Data.ui.buildDraftItems = text end)
    W.Button(tab, "OPTrainer.CustomBuild.Save", icon("save") .. " Save / Edit", function()
        if Context.Actions.SaveCustomBuild(Context.Config.Data.ui.buildDraftName, Context.Config.Data.ui.buildDraftItems) then updateCustomBuildButtons() end
    end, "success")
    W.Multiline(tab, "OPTrainer.CustomBuild.ImportExport", "Build JSON", Context.Config.ExportBuilds(), 4, function(text) Context.Config.Data.ui.importExport = text end)
    W.Button(tab, "OPTrainer.CustomBuild.Export", icon("download") .. " Export", function()
        Context.Config.Data.ui.importExport = Context.Config.ExportBuilds()
        W.UpdateValue("OPTrainer.CustomBuild.ImportExport", Context.Config.Data.ui.importExport)
    end)
    W.Button(tab, "OPTrainer.CustomBuild.Import", icon("upload") .. " Import", function()
        if Context.Config.ImportBuilds(Context.Config.Data.ui.importExport or "") then updateCustomBuildButtons() end
    end, "warning")
    for index = 1, 8 do
        W.Button(tab, "OPTrainer.CustomBuild.Apply." .. index, icon("plus") .. " Empty Slot", action(function()
            local build = Context.Config.Data.customBuilds[index]
            if build then Context.Actions.ApplyBuild(build.name) end
        end))
        W.SmallButton(tab, "OPTrainer.CustomBuild.Delete." .. index, icon("trash") .. " Empty", function()
            local build = Context.Config.Data.customBuilds[index]
            if build then Context.Actions.DeleteCustomBuild(build.name); updateCustomBuildButtons() end
        end, "danger")
    end
end

local function buildItems(tab)
    W.Separator(tab, "OPTrainer.Items.Header", icon("search") .. " Items")
    W.Combo(tab, "OPTrainer.Items.Filter", "Filter", filters, selectedFilter, function(index)
        selectedFilter = index
        Context.Config.Data.ui.itemFilter = selectedFilterName()
        refreshSearch()
    end)
    W.Input(tab, "OPTrainer.Items.Search", "Search", Context.Config.Data.ui.search, "name, id, q4, type...", function(text)
        Context.Config.Data.ui.search = text
        if Context.Config.Data.settings.rememberLastSearch then Context.Config.Save(false) end
        refreshSearch()
    end)
    W.Separator(tab, "OPTrainer.Items.Results", icon("search") .. " Results")
    for index = 1, ids().SEARCH_RESULTS do
        W.Button(tab, "OPTrainer.Items.Result." .. index, icon("search") .. " Empty", function() giveSearchResult(index) end, nil, 460)
        W.SameLine(tab, "OPTrainer.Items.Result.Same." .. index)
        W.SmallButton(tab, "OPTrainer.Items.Fav." .. index, icon("star"), function() toggleFavoriteResult(index) end, "warning", 35)
        W.SameLine(tab, "OPTrainer.Items.Fav.Same." .. index)
        W.SmallButton(tab, "OPTrainer.Items.Remove." .. index, icon("trash"), function() removeSearchResult(index) end, "danger", 35)
    end
end

local function buildPlayer(tab)
    W.Separator(tab, "OPTrainer.Player.Header", icon("user") .. " Player")
    W.Combo(tab, "OPTrainer.Player.PlayerSelect", "Target Player", getPlayerNames(), (Context.Config.Data.ui.selectedPlayer or 0) + 1, function(index)
        Context.Config.Data.ui.selectedPlayer = index - 1
        Context.Config.Save(false)
        Context.Actions.RefreshStats()
    end)
    local rows = {
        { "god", "God Mode" }, { "infiniteHp", "Infinite HP" }, { "infiniteCharge", "Infinite Charge" },
        { "infiniteBatteries", "Infinite Batteries" }, { "infiniteCards", "Infinite Cards" }, { "infinitePills", "Infinite Pills" },
        { "infiniteCoins", "Infinite Coins" }, { "infiniteKeys", "Infinite Keys" }, { "infiniteBombs", "Infinite Bombs" },
        { "holyMantle", "Holy Mantle" }, { "flight", "Flight" }, { "spectralTears", "Spectral Tears" },
        { "noCurse", "No Curse" }, { "revealMap", "Reveal Map" }, { "infiniteHolyMantle", "Infinite Holy Mantle" },
        { "noBlink", "No Blink (Hide i-frames)" },
    }
    for index, row in ipairs(rows) do
        W.Toggle(tab, "OPTrainer.Player." .. row[1], row[2], Context.Config.Data.toggles[row[1]], setToggle(row[1]))
        if index % 2 == 1 then
            W.SameLine(tab, "OPTrainer.Player." .. row[1] .. ".Same")
        end
    end

    W.Separator(tab, "OPTrainer.Stats.Header", icon("chart") .. " Stats")
    W.Text(tab, "OPTrainer.Stats.Live", statsText(), true, true)
    statSlider(tab, "damage", "Damage", -10, 100)
    statSlider(tab, "tears", "Tears", -10, 30)
    statSlider(tab, "range", "Range", -10, 30)
    statSlider(tab, "luck", "Luck", -20, 100, "%.1f")
    statSlider(tab, "speed", "Speed", -2, 2)
    statSlider(tab, "shotSpeed", "Shot Speed", -2, 5)
    statSlider(tab, "fireDelay", "Fire Delay", -30, 30, "%.1f")
    statSlider(tab, "scale", "Scale", -0.5, 2)
    statSlider(tab, "size", "Size", -0.5, 2)
    W.Separator(tab, "OPTrainer.Stats.Health", icon("heart") .. " Health")
    healthSlider(tab, "health", "Health", 24)
    healthSlider(tab, "soulHearts", "Soul Hearts", 24)
    healthSlider(tab, "blackHearts", "Black Hearts", 24)
    healthSlider(tab, "boneHearts", "Bone Hearts", 12)
    healthSlider(tab, "rottenHearts", "Rotten Hearts", 24)
    healthSlider(tab, "brokenHearts", "Broken Hearts", 12)
end

local function buildWorld(tab)
    local pickup = Context.Constants.PICKUP
    local slot = Context.Constants.SLOT
    W.Separator(tab, "OPTrainer.Room.Header", icon("box") .. " Room Spawning")
    W.Button(tab, "OPTrainer.Room.Clear", icon("cross") .. " Clear Room", action(Context.Actions.ClearRoom), "success")
    
    W.Button(tab, "OPTrainer.Room.Chest", icon("box") .. " Chest", action(function() Context.Actions.SpawnPickup(pickup.CHEST, 0, 1) end))
    W.SameLine(tab, "OPTrainer.Room.Chest.Same")
    W.Button(tab, "OPTrainer.Room.GoldenChest", icon("box") .. " Golden Chest", action(function() Context.Actions.SpawnPickup(pickup.GOLDEN_CHEST, 0, 1) end))
    W.SameLine(tab, "OPTrainer.Room.GoldenChest.Same")
    W.Button(tab, "OPTrainer.Room.RedChest", icon("box") .. " Red Chest", action(function() Context.Actions.SpawnPickup(pickup.RED_CHEST, 0, 1) end))
    W.SameLine(tab, "OPTrainer.Room.RedChest.Same")
    W.Button(tab, "OPTrainer.Room.MegaChest", icon("box") .. " Mega Chest", action(function() Context.Actions.SpawnPickup(pickup.MEGA_CHEST, 0, 1) end))
    W.SameLine(tab, "OPTrainer.Room.MegaChest.Same")
    W.Button(tab, "OPTrainer.Room.BombChest", icon("box") .. " Bomb Chest", action(function() Context.Actions.SpawnPickup(pickup.BOMB_CHEST, 0, 1) end))

    W.Button(tab, "OPTrainer.Room.Coins", icon("coin") .. " Spawn Coins", action(function() Context.Actions.SpawnPickup(pickup.COIN, 0, 8) end))
    W.SameLine(tab, "OPTrainer.Room.Coins.Same")
    W.Button(tab, "OPTrainer.Room.Bombs", icon("bomb") .. " Spawn Bombs", action(function() Context.Actions.SpawnPickup(pickup.BOMB, 0, 6) end))
    W.SameLine(tab, "OPTrainer.Room.Bombs.Same")
    W.Button(tab, "OPTrainer.Room.Keys", icon("key") .. " Spawn Keys", action(function() Context.Actions.SpawnPickup(pickup.KEY, 0, 6) end))

    W.Button(tab, "OPTrainer.Room.Beggar", icon("user") .. " Beggar", action(function() Context.Actions.SpawnSlot(slot.BEGGAR, 0, 1) end))
    W.SameLine(tab, "OPTrainer.Room.Beggar.Same")
    W.Button(tab, "OPTrainer.Room.Machine", icon("gear") .. " Slot Machine", action(function() Context.Actions.SpawnSlot(slot.SLOT_MACHINE, 0, 1) end))

    W.Separator(tab, "OPTrainer.Teleport.Header", icon("arrow") .. " Teleport")
    local stageNames = {}
    for _, stage in ipairs(Context.Data.Stages) do stageNames[#stageNames + 1] = stage.name end
    W.Combo(tab, "OPTrainer.Teleport.Stage", "Floor", stageNames, selectedStage, function(index) selectedStage = index end, 200)
    W.SameLine(tab, "OPTrainer.Teleport.Stage.Same")
    W.Button(tab, "OPTrainer.Teleport.GoStage", icon("map") .. " Go To Floor", action(function()
        local stage = Context.Data.Stages[selectedStage]
        if stage then Context.Actions.TeleportStage(stage.id) end
    end), nil, 140)

    local roomNames = {}
    for _, target in ipairs(Context.Data.RoomTargets) do roomNames[#roomNames + 1] = target.name end
    W.Combo(tab, "OPTrainer.Teleport.Room", "Room", roomNames, selectedRoom, function(index) selectedRoom = index end, 200)
    W.SameLine(tab, "OPTrainer.Teleport.Room.Same")
    W.Button(tab, "OPTrainer.Teleport.GoRoom", icon("door") .. " Go To Room", action(function()
        local target = Context.Data.RoomTargets[selectedRoom]
        if target then
            Context.Actions.QueueTeleport(target.roomType, target.command)
        end
    end), nil, 140)

    W.Separator(tab, "OPTrainer.Enemies.Header", icon("skull") .. " Enemies")
    local enemyNames = {}
    for _, enemy in ipairs(Context.Data.Enemies) do enemyNames[#enemyNames + 1] = enemy.name end
    W.Combo(tab, "OPTrainer.Enemies.Select", "Enemy", enemyNames, selectedEnemy, function(index) selectedEnemy = index end, 200)
    W.SameLine(tab, "OPTrainer.Enemies.Select.Same")
    W.Button(tab, "OPTrainer.Enemies.Spawn", icon("plus") .. " Spawn Enemy", action(function() Context.Actions.SpawnEnemy(selectedEnemy) end), nil, 140)

    W.Button(tab, "OPTrainer.Enemies.KillRoom", icon("skull") .. " Kill Room", action(Context.Actions.KillRoom), "danger")
    W.SameLine(tab, "OPTrainer.Enemies.KillRoom.Same")
    W.Button(tab, "OPTrainer.Enemies.KillBoss", icon("skull") .. " Kill Boss", action(Context.Actions.KillBoss), "danger")

    W.Toggle(tab, "OPTrainer.Enemies.freezeEnemies", "Freeze", Context.Config.Data.toggles.freezeEnemies, setToggle("freezeEnemies"))
    W.SameLine(tab, "OPTrainer.Enemies.freezeEnemies.Same")
    W.Toggle(tab, "OPTrainer.Enemies.slowEnemies", "Slow", Context.Config.Data.toggles.slowEnemies, setToggle("slowEnemies"))
    W.SameLine(tab, "OPTrainer.Enemies.slowEnemies.Same")
    W.Toggle(tab, "OPTrainer.Enemies.confuseEnemies", "Confuse", Context.Config.Data.toggles.confuseEnemies, setToggle("confuseEnemies"))
    W.SameLine(tab, "OPTrainer.Enemies.confuseEnemies.Same")
    W.Toggle(tab, "OPTrainer.Enemies.fearEnemies", "Fear", Context.Config.Data.toggles.fearEnemies, setToggle("fearEnemies"))
    W.SameLine(tab, "OPTrainer.Enemies.fearEnemies.Same")
    W.Toggle(tab, "OPTrainer.Enemies.charmEnemies", "Charm", Context.Config.Data.toggles.charmEnemies, setToggle("charmEnemies"))
end

local function buildUnlocks(tab)
    W.Separator(tab, "OPTrainer.Unlocks.Header", icon("star") .. " Unlocks")
    W.Button(tab, "OPTrainer.Unlocks.Characters", icon("user") .. " Unlock Characters", action(Context.Actions.UnlockCharacters), "success")
    W.SameLine(tab, "OPTrainer.Unlocks.Characters.Same")
    W.Button(tab, "OPTrainer.Unlocks.Items", icon("box") .. " Unlock Items", action(Context.Actions.UnlockItems), "success")
    
    W.Button(tab, "OPTrainer.Unlocks.All", icon("star") .. " Unlock Everything", action(Context.Actions.UnlockEverything), "danger")
end

local function buildInventory(tab)
    W.Separator(tab, "OPTrainer.Inventory.Header", icon("box") .. " Inventory Editor")
    W.Button(tab, "OPTrainer.Inventory.ClearBuild", icon("trash") .. " Clear Build (Remove All Items)", action(Context.Actions.ClearBuild), "danger")
    W.Separator(tab, "OPTrainer.Inventory.ById", "By Item ID")
    W.InputInt(tab, "OPTrainer.Inventory.ItemId", "Item ID", inventoryItemId, function(value) inventoryItemId = value end)
    W.Button(tab, "OPTrainer.Inventory.GiveById", icon("plus") .. " Give Item", action(function()
        if inventoryItemId > 0 then
            Context.Actions.GiveCollectible(inventoryItemId)
            local name = tostring(inventoryItemId)
            pcall(function()
                local item = Isaac.GetItemConfig():GetCollectible(inventoryItemId)
                if item and item.Name then name = item.Name end
            end)
            Context.Notifications.Push("Gave " .. name)
        end
    end), "success")
    W.SameLine(tab, "OPTrainer.Inventory.GiveById.SameLine")
    W.Button(tab, "OPTrainer.Inventory.RemoveById", icon("trash") .. " Remove Item", function()
        if inventoryItemId > 0 then
            Context.Actions.RemoveCollectible(inventoryItemId)
            local name = tostring(inventoryItemId)
            pcall(function()
                local item = Isaac.GetItemConfig():GetCollectible(inventoryItemId)
                if item and item.Name then name = item.Name end
            end)
            Context.Notifications.Push("Removed " .. name)
        end
    end, "danger")
    W.Separator(tab, "OPTrainer.Inventory.Slots", "Slot Actions")
    W.Button(tab, "OPTrainer.Inventory.RemoveActive", icon("trash") .. " Remove Active Item", function() Context.Actions.RemoveActive(0) end, "danger")
    W.Button(tab, "OPTrainer.Inventory.RemoveTrinket0", icon("trash") .. " Remove Trinket 1", function()
        pcall(function() local t = Context.Helpers.Player():GetTrinket(0); if t > 0 then Context.Helpers.Player():TryRemoveTrinket(t) end end)
    end, "danger")
    W.SameLine(tab, "OPTrainer.Inventory.Trinket.SameLine")
    W.Button(tab, "OPTrainer.Inventory.RemoveTrinket1", icon("trash") .. " Remove Trinket 2", function()
        pcall(function() local t = Context.Helpers.Player():GetTrinket(1); if t > 0 then Context.Helpers.Player():TryRemoveTrinket(t) end end)
    end, "danger")
    W.Button(tab, "OPTrainer.Inventory.RemoveCards", icon("trash") .. " Remove All Cards/Pills", function()
        pcall(function()
            local p = Context.Helpers.Player()
            for slot = 0, 3 do p:SetCard(slot, 0); p:SetPill(slot, 0) end
        end)
    end, "danger")
end

local function buildQuickActions(tab)
    W.Separator(tab, "OPTrainer.QuickActions.PlayerSec", icon("user") .. " Player Status")
    W.Button(tab, "OPTrainer.QuickActions.Heal", icon("heart") .. " Heal Player", action(Context.QuickActions.HealPlayer), "success")
    W.SameLine(tab, "OPTrainer.QuickActions.Heal.Same")
    W.Button(tab, "OPTrainer.QuickActions.FullHealth", icon("heart") .. " Full Health", action(Context.QuickActions.FullHealth), "success")
    W.SameLine(tab, "OPTrainer.QuickActions.FullHealth.Same")
    W.Button(tab, "OPTrainer.QuickActions.FullCharge", icon("bolt") .. " Full Charge", action(Context.QuickActions.FullCharge))
    W.SameLine(tab, "OPTrainer.QuickActions.FullCharge.Same")
    W.Button(tab, "OPTrainer.QuickActions.Refill", icon("wand") .. " Refill Active", action(Context.QuickActions.RefillActiveItem))

    W.Separator(tab, "OPTrainer.QuickActions.ResourcesSec", icon("coin") .. " Resources & Pickups")
    W.Button(tab, "OPTrainer.QuickActions.Coins", icon("coin") .. " 99 Coins", action(Context.QuickActions.Give99Coins))
    W.SameLine(tab, "OPTrainer.QuickActions.Coins.Same")
    W.Button(tab, "OPTrainer.QuickActions.Bombs", icon("bomb") .. " 99 Bombs", action(Context.QuickActions.Give99Bombs))
    W.SameLine(tab, "OPTrainer.QuickActions.Bombs.Same")
    W.Button(tab, "OPTrainer.QuickActions.Keys", icon("key") .. " 99 Keys", action(Context.QuickActions.Give99Keys))
    
    W.Button(tab, "OPTrainer.QuickActions.AllConsumables", icon("star") .. " All Consumables", action(Context.QuickActions.GiveAllConsumables), "success")
    W.SameLine(tab, "OPTrainer.QuickActions.AllConsumables.Same")
    W.Button(tab, "OPTrainer.QuickActions.MaxPickups", icon("plus") .. " Max Pickups", action(Context.QuickActions.MaxPickups))

    W.Separator(tab, "OPTrainer.QuickActions.WorldSec", icon("map") .. " World & Navigation")
    W.Button(tab, "OPTrainer.QuickActions.RevealMap", icon("map") .. " Reveal Map", action(Context.QuickActions.RevealEntireMap))
    W.SameLine(tab, "OPTrainer.QuickActions.RevealMap.Same")
    W.Button(tab, "OPTrainer.QuickActions.NoCurse", icon("cross") .. " Remove Curse", action(Context.QuickActions.RemoveCurrentCurse))
    W.SameLine(tab, "OPTrainer.QuickActions.NoCurse.Same")
    W.Button(tab, "OPTrainer.QuickActions.OpenDoors", icon("door") .. " Open Doors", action(Context.QuickActions.OpenAllDoors))
    
    W.Button(tab, "OPTrainer.QuickActions.Crawlspace", icon("plus") .. " Crawlspace", action(Context.QuickActions.SpawnCrawlspace))
    W.SameLine(tab, "OPTrainer.QuickActions.Crawlspace.Same")
    W.Button(tab, "OPTrainer.QuickActions.Trapdoor", icon("arrow") .. " Trapdoor", action(Context.QuickActions.SpawnTrapdoor))

    W.Separator(tab, "OPTrainer.QuickActions.RoomSec", icon("skull") .. " Room & Combat")
    W.Button(tab, "OPTrainer.QuickActions.ClearRoom", icon("cross") .. " Clear Room", action(Context.QuickActions.ClearCurrentRoom), "success")
    W.SameLine(tab, "OPTrainer.QuickActions.ClearRoom.Same")
    W.Button(tab, "OPTrainer.QuickActions.KillEnemies", icon("skull") .. " Kill Enemies", action(Context.QuickActions.KillAllEnemies), "danger")
end

local function buildUtilities(tab)
    W.Separator(tab, "OPTrainer.Utilities.Header", icon("terminal") .. " Utilities")
    W.Input(tab, "OPTrainer.Utilities.Command", "Console", Context.Config.Data.utilities.command, "debug 8", function(text) Context.Config.Data.utilities.command = text end)
    W.Button(tab, "OPTrainer.Utilities.ExecuteCommand", icon("play") .. " Execute Command", function() Context.Actions.ExecuteConsole(Context.Config.Data.utilities.command) end)
    W.Multiline(tab, "OPTrainer.Utilities.Macro", "Macros", Context.Config.Data.utilities.macro, 4, function(text) Context.Config.Data.utilities.macro = text end)
    W.Button(tab, "OPTrainer.Utilities.ExecuteMacro", icon("play") .. " Execute Macro", function() Context.Actions.ExecuteMacro(Context.Config.Data.utilities.macro) end)
    W.Multiline(tab, "OPTrainer.Utilities.Script", "Custom Scripts", Context.Config.Data.utilities.script, 5, function(text) Context.Config.Data.utilities.script = text end)
    W.Button(tab, "OPTrainer.Utilities.ExecuteScript", icon("play") .. " Execute Script", function() Context.Actions.ExecuteScript(Context.Config.Data.utilities.script) end)

    W.Separator(tab, "OPTrainer.Fun.Header", icon("smile") .. " Fun")
    for _, row in ipairs({ { "bigIsaac", "Big Isaac" }, { "tinyIsaac", "Tiny Isaac" }, { "rainbow", "Rainbow" }, { "randomColors", "Random Colors" } }) do
        W.Toggle(tab, "OPTrainer.Fun." .. row[1], row[2], Context.Config.Data.toggles[row[1]], setToggle(row[1]))
    end
    W.Button(tab, "OPTrainer.Fun.Effects", icon("wand") .. " Funny Effects", function()
        Context.Config.Data.toggles.rainbow = true
        Context.Config.Data.toggles.tinyIsaac = not Context.Config.Data.toggles.tinyIsaac
        Context.Config.Save(false)
    end, "warning")
end

local function buildSettings(tab)
    local settings = Context.Config.Data.settings
    W.Separator(tab, "OPTrainer.Settings.Hotkeys", icon("keyboard") .. " Hotkeys")
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.OP", "F6 OP BUILD", function(keyId) Context.Config.Data.hotkeys.opBuild = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.opBuild)
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.God", "F7 GOD", function(keyId) Context.Config.Data.hotkeys.god = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.god)
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.Menu", "F8 MENU", function(keyId) Context.Config.Data.hotkeys.menu = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.menu)
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.Heal", "F9 HEAL", function(keyId) Context.Config.Data.hotkeys.heal = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.heal)
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.Kill", "F10 KILL", function(keyId) Context.Config.Data.hotkeys.killRoom = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.killRoom)
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.Charge", "CHARGE", function(keyId) Context.Config.Data.hotkeys.fullCharge = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.fullCharge or 0)
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.NoBlink", "NO BLINK", function(keyId) Context.Config.Data.hotkeys.noBlink = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.noBlink or 0)
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.InfHP", "INFINITE HP", function(keyId) Context.Config.Data.hotkeys.infiniteHp = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.infiniteHp or 0)
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.RevealMap", "REVEAL MAP", function(keyId) Context.Config.Data.hotkeys.revealMap = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.revealMap or 0)
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.NoCurse", "NO CURSE", function(keyId) Context.Config.Data.hotkeys.noCurse = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.noCurse or 0)
    ImGui.AddInputKeyboard(tab, "OPTrainer.Hotkey.TeleportBoss", "TELEPORT TO BOSS", function(keyId) Context.Config.Data.hotkeys.teleportBoss = keyId; Context.Config.Save(true) end, Context.Config.Data.hotkeys.teleportBoss or 0)
    W.Separator(tab, "OPTrainer.Settings.Options", icon("gear") .. " Options")
    for _, row in ipairs({ { "enableHotkeys", "Enable Hotkeys" }, { "notifications", "Notifications" }, { "autoCloseMenu", "Auto Close Menu" }, { "rememberLastSearch", "Remember Last Search" } }) do
        W.Toggle(tab, "OPTrainer.Settings." .. row[1], row[2], settings[row[1]], function(value)
            settings[row[1]] = value
            Context.Config.Save(false)
            if row[1] == "enableHotkeys" then
                Context.Notifications.Push(value and "Hotkeys enabled" or "Hotkeys disabled")
            end
        end)
    end
    W.Toggle(tab, "OPTrainer.Settings.Debug", "Debug Mode", Context.Config.Data.debug, function(value) Context.Config.Data.debug = value; Context.Config.Save(true) end)
    W.Toggle(tab, "OPTrainer.Settings.Autosave", "Autosave", Context.Config.Data.autosave, function(value) Context.Config.Data.autosave = value; Context.Config.Save(true) end)
end

local function addTab(tabBar, id, label, tooltip, builder)
    ImGui.AddTab(tabBar, id, label)
    W.Tooltip(id, tooltip)
    builder(id)
end

function UI.Init(context)
    Context = context
    W = include("scripts.optrainer.widgets")
end

function UI.Build()
    if built or not ImGui then return end
    if REPENTOGON and REPENTOGON.MeetsVersion and not REPENTOGON.MeetsVersion(Context.Constants.REPENTOGON_MIN_VERSION) then
        Context.Notifications.Push("OPTrainer requires REPENTOGON " .. Context.Constants.REPENTOGON_MIN_VERSION .. "+")
    end

    Context.Config.NormalizeWindow()
    local window = Context.Config.Data.window
    selectedFilter = 1
    for index, filter in ipairs(filters) do if filter == Context.Config.Data.ui.itemFilter then selectedFilter = index end end

    -- Remove stale elements from a previous game session / mod reload
    -- to prevent "element already exists" errors during re-creation.
    pcall(function()
        if ImGui.ElementExists and ImGui.ElementExists(ids().WINDOW_ID) then
            ImGui.RemoveWindow(ids().WINDOW_ID)
        end
    end)
    pcall(function()
        if ImGui.ElementExists and ImGui.ElementExists(ids().MENU_ID) then
            ImGui.RemoveMenu(ids().MENU_ID)
        end
    end)

    ImGui.CreateMenu(ids().MENU_ID, icon("bolt") .. " OPTrainer")
    ImGui.AddElement(ids().MENU_ID, ids().MENU_ITEM_ID, ImGuiElement.MenuItem, icon("gear") .. " Open Trainer")
    ImGui.CreateWindow(ids().WINDOW_ID, icon("bolt") .. " OPTrainer")
    ImGui.LinkWindowToElement(ids().WINDOW_ID, ids().MENU_ITEM_ID)
    ImGui.SetVisible(ids().WINDOW_ID, window.visible)
    W.ApplyWindowStyle(ids().WINDOW_ID, 1.0)

    W.Text(ids().WINDOW_ID, "OPTrainer.Top.Status", statusText(), true, true)
    W.Input(ids().WINDOW_ID, "OPTrainer.Global.Search", icon("search") .. " Search", Context.Config.Data.ui.search, "Search items", function(text)
        Context.Config.Data.ui.search = text
        refreshSearch()
    end)

    ImGui.AddTabBar(ids().WINDOW_ID, "OPTrainer.Tabs")
    addTab("OPTrainer.Tabs", "OPTrainer.Tab.Dashboard", tabLabel("bolt", "Dashboard", "Dash"), "Dashboard", buildDashboard)
    addTab("OPTrainer.Tabs", "OPTrainer.Tab.Builds", tabLabel("save", "Builds"), "Builds", buildBuilds)
    addTab("OPTrainer.Tabs", "OPTrainer.Tab.Items", tabLabel("search", "Items"), "Items", buildItems)
    addTab("OPTrainer.Tabs", "OPTrainer.Tab.Player", tabLabel("user", "Player"), "Player", buildPlayer)
    addTab("OPTrainer.Tabs", "OPTrainer.Tab.World", tabLabel("map", "World"), "World", buildWorld)
    addTab("OPTrainer.Tabs", "OPTrainer.Tab.Unlocks", tabLabel("star", "Unlocks"), "Unlocks", buildUnlocks)
    addTab("OPTrainer.Tabs", "OPTrainer.Tab.Inventory", tabLabel("box", "Inventory", "Inv"), "Inventory", buildInventory)
    addTab("OPTrainer.Tabs", "OPTrainer.Tab.QuickActions", tabLabel("play", "Quick Actions", "Q Actions"), "Quick Actions", buildQuickActions)
    addTab("OPTrainer.Tabs", "OPTrainer.Tab.Utilities", tabLabel("terminal", "Utilities", "Tools"), "Utilities", buildUtilities)
    addTab("OPTrainer.Tabs", "OPTrainer.Tab.Settings", tabLabel("gear", "Settings", "Prefs"), "Settings", buildSettings)
    W.Text(ids().WINDOW_ID, "OPTrainer.Footer", versionText(), true, true)

    local savedFilter = Context.Config.Data.ui.itemFilter or "Collectibles"
    for i, name in ipairs(filters) do
        if name == savedFilter then
            selectedFilter = i
            break
        end
    end

    built = true
    refreshSearch()
    updateCustomBuildButtons()

    if Context.Config.Data.saveWarning then
        Context.Notifications.Push(Context.Config.Data.saveWarning, "danger")
        Context.Config.Data.saveWarning = nil
    end
end

function UI.Toggle()
    if not ImGui then return end

    -- If the window hasn't been built yet, build it now.
    if not built then
        pcall(function() UI.Build() end)
    end

    -- Guard against the window not existing (build may have failed).
    local exists = false
    pcall(function()
        if ImGui.ElementExists then
            exists = ImGui.ElementExists(ids().WINDOW_ID)
        end
    end)
    if not exists then return end

    local ok, currentlyVisible = pcall(ImGui.GetVisible, ids().WINDOW_ID)
    local visible = not (ok and currentlyVisible)
    pcall(ImGui.SetVisible, ids().WINDOW_ID, visible)
    Context.Config.Data.window.visible = visible
    Context.Config.Save(false)
    if visible then pcall(ImGui.Show) end
end

function UI.Update()
    if not built or not ImGui then UI.Build(); return end
    local frame = Isaac.GetFrameCount()
    local clock = os.clock()
    if lastClock > 0 and clock > lastClock then fps = math.floor((frame - lastFrame) / (clock - lastClock) + 0.5) end
    lastFrame = frame
    lastClock = clock





    if frame % 15 == 0 then
        W.UpdateText("OPTrainer.Top.Status", statusText())
        W.UpdateText("OPTrainer.Dashboard.Stats", statsText())
        W.UpdateText("OPTrainer.Stats.Live", statsText())
        W.UpdateText("OPTrainer.Dashboard.Seed", "Seed: " .. seedText())
        W.UpdateText("OPTrainer.Dashboard.Last", "Last build: " .. Context.Config.Data.lastBuild)
        W.UpdateText("OPTrainer.Footer", versionText())
    end
end

return UI