local Actions = {}

local Context
local previousKeys = {}
local pendingTeleport = nil

local function notify(text)
    if Context and Context.Notifications then
        Context.Notifications.Push(text)
    elseif ImGui and ImGui.PushNotification then
        pcall(ImGui.PushNotification, text, 0, 2600)
    end
end

local function notifyNow(text)
    if Context and Context.Config and Context.Config.Data.settings and Context.Config.Data.settings.notifications == false then return end
    if ImGui and ImGui.PushNotification then
        pcall(ImGui.PushNotification, text, 0, 2600)
    end
end

local function player()
    return Context.Helpers.Player()
end

local function call(object, methodName, ...)
    return Context.Helpers.CallMethod(object, methodName, ...)
end

local function cacheFlags()
    return Context.Helpers.FullCacheFlags()
end

local function refreshPlayerCache()
    Context.Helpers.AddCacheFlags(player(), cacheFlags())
end

local function spawnAt(position, entityType, variant, subtype)
    return Isaac.Spawn(entityType, variant or 0, subtype or 0, position, Vector.Zero, nil)
end

local function spawnRoomCenter(entityType, variant, subtype)
    local room = Context.Game:GetRoom()
    return spawnAt(room:GetCenterPos(), entityType, variant, subtype)
end

local function parseItems(text)
    local result = {}
    for token in tostring(text or ""):gmatch("[^,%s]+") do
        local numeric = tonumber(token)
        if numeric then
            result[#result + 1] = numeric
        else
            local lowered = token:lower()
            for _, entry in ipairs(Context.Data.Catalog.collectibles) do
                if entry.name:lower():find(lowered, 1, true) then
                    result[#result + 1] = entry.id
                    break
                end
            end
        end
    end
    return result
end

function Actions.Init(context)
    Context = context
end

function Actions.OnGameStarted()
    refreshPlayerCache()
end

function Actions.GiveCollectible(id)
    local currentPlayer = player()
    if not currentPlayer or not id then return end
    local ok = pcall(function() currentPlayer:AddCollectible(id, 0, true) end)
    if not ok then pcall(function() currentPlayer:AddCollectible(id) end) end
end

function Actions.RemoveCollectible(id)
    local currentPlayer = player()
    if currentPlayer and id then
        pcall(function() currentPlayer:RemoveCollectible(id) end)
    end
end

function Actions.GiveTrinket(id)
    local currentPlayer = player()
    if currentPlayer and id then
        pcall(function() currentPlayer:AddTrinket(id) end)
    end
end

function Actions.RemoveTrinket(id)
    local currentPlayer = player()
    if currentPlayer and id then
        pcall(function() currentPlayer:TryRemoveTrinket(id) end)
    end
end

function Actions.GiveCard(id, slot)
    local currentPlayer = player()
    if currentPlayer and id then
        pcall(function() currentPlayer:SetCard(slot or 0, id) end)
    end
end

function Actions.RemoveCard(slot)
    local currentPlayer = player()
    if currentPlayer then
        pcall(function() currentPlayer:SetCard(slot or 0, 0) end)
    end
end

function Actions.GivePill(id, slot)
    local currentPlayer = player()
    if currentPlayer and id then
        pcall(function() currentPlayer:SetPill(slot or 0, id) end)
    end
end

function Actions.RemovePill(slot)
    local currentPlayer = player()
    if currentPlayer then
        pcall(function() currentPlayer:SetPill(slot or 0, 0) end)
    end
end

function Actions.RemoveActive(slot)
    local currentPlayer = player()
    if not currentPlayer then return end
    slot = slot or 0
    local active = 0
    pcall(function() active = currentPlayer:GetActiveItem(slot) end)
    if active and active > 0 then
        Actions.RemoveCollectible(active)
    end
end

function Actions.RemovePocket(slot)
    local currentPlayer = player()
    if not currentPlayer then return end
    slot = slot or 0
    pcall(function() currentPlayer:SetPocketActiveItem(0, slot, false) end)
    pcall(function() currentPlayer:SetCard(slot, 0) end)
    pcall(function() currentPlayer:SetPill(slot, 0) end)
end

function Actions.ClearBuild()
    local currentPlayer = player()
    if not currentPlayer then return end

    -- 1. Remove all collectibles (handles stacked items)
    pcall(function()
        local maxId = CollectibleType.NUM_COLLECTIBLES - 1
        local config = Isaac.GetItemConfig()
        if config and config.GetCollectibles then
            local collectibles = config:GetCollectibles()
            if collectibles then
                maxId = collectibles.Size - 1
            end
        end
        for id = 1, maxId do
            while currentPlayer:HasCollectible(id) do
                currentPlayer:RemoveCollectible(id)
            end
        end
    end)

    -- 2. Remove held trinkets
    pcall(function()
        for slot = 0, 1 do
            local trinket = currentPlayer:GetTrinket(slot)
            if trinket > 0 then
                currentPlayer:TryRemoveTrinket(trinket)
            end
        end
    end)

    -- 3. Remove active items
    pcall(function()
        for slot = 0, 3 do
            local active = currentPlayer:GetActiveItem(slot)
            if active > 0 then
                currentPlayer:RemoveCollectible(active)
            end
            currentPlayer:SetPocketActiveItem(0, slot, false)
        end
    end)

    -- 4. Clear card and pill slots
    pcall(function()
        for slot = 0, 3 do
            currentPlayer:SetCard(slot, 0)
            currentPlayer:SetPill(slot, 0)
        end
    end)

    -- 5. Recalculate stats cache
    pcall(function()
        currentPlayer:AddCacheFlags(CacheFlag.CACHE_ALL)
        currentPlayer:EvaluateItems()
    end)

    notify("Build cleared")
end

function Actions.ApplyBuild(name)
    local build = Context.Data.FindBuild(name)
    if not build then return end

    if build.random then
        local pool = Context.Data.Catalog.collectibles
        for _ = 1, 12 do
            local entry = pool[math.random(1, math.max(#pool, 1))]
            if entry then Actions.GiveCollectible(entry.id) end
        end
    else
        for _, id in ipairs(build.items or {}) do
            Actions.GiveCollectible(id)
        end
    end

    Context.Config.Data.lastBuild = name
    Context.Config.Save(false)
    notify(name .. " applied")
end

function Actions.SaveCustomBuild(name, itemText)
    local items = parseItems(itemText)
    if name == "" or #items == 0 then
        notify("Custom build needs a name and at least one item")
        return false
    end

    local customBuilds = Context.Config.Data.customBuilds
    for _, build in ipairs(customBuilds) do
        if build.name == name then
            build.items = items
            Context.Config.Save(true)
            notify("Build updated")
            return true
        end
    end

    if #customBuilds >= 16 then
        notify("Limit reached (16 custom builds)")
        return false
    end


    customBuilds[#customBuilds + 1] = { name = name, items = items }
    Context.Config.Save(true)
    notify("Build saved")
    return true
end

function Actions.DeleteCustomBuild(name)
    local customBuilds = Context.Config.Data.customBuilds
    for index = #customBuilds, 1, -1 do
        if customBuilds[index].name == name then
            table.remove(customBuilds, index)
        end
    end
    Context.Config.Save(true)
    notify("Build deleted")
end

function Actions.Heal()
    local currentPlayer = player()
    if not currentPlayer then return end
    local maxHearts = currentPlayer:GetMaxHearts()
    if maxHearts < 12 then call(currentPlayer, "AddMaxHearts", 12 - maxHearts, true) end
    call(currentPlayer, "AddHearts", 24)
    local soulHearts = currentPlayer:GetSoulHearts()
    if soulHearts < 12 then call(currentPlayer, "AddSoulHearts", 12 - soulHearts) end
    notify("Healed")
end

function Actions.FullCharge()
    local currentPlayer = player()
    if not currentPlayer then return end
    for slot = 0, 3 do
        call(currentPlayer, "SetActiveCharge", 99, slot)
    end
    notify("Active items charged")
end

function Actions.KillRoom()
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity:IsVulnerableEnemy() and not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
            entity:Kill()
        end
    end
    notify("Room cleared")
end

function Actions.KillBoss()
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity:IsBoss() then entity:Kill() end
    end
    notify("Boss killed")
end

function Actions.ClearRoom()
    local room = Context.Game:GetRoom()
    room:SetClear(true)
    Actions.KillRoom()
end

function Actions.SpawnEnemy(index)
    local entry = Context.Data.Enemies[index] or Context.Data.Enemies[1]
    spawnRoomCenter(entry.type, entry.variant, entry.subtype or 0)
end

function Actions.SpawnPickup(variant, subtype, amount)
    local room = Context.Game:GetRoom()
    local entityType = EntityType and EntityType.ENTITY_PICKUP or 5
    for index = 1, amount or 1 do
        local offset = Vector(((index - 1) % 6) * 24 - 60, math.floor((index - 1) / 6) * 24)
        local position = room:FindFreePickupSpawnPosition(room:GetCenterPos() + offset, 0, true)
        spawnAt(position, entityType, variant, subtype or 0)
    end
end

function Actions.SpawnSlot(variant, subtype, amount)
    local room = Context.Game:GetRoom()
    local entityType = EntityType and EntityType.ENTITY_SLOT or 6
    for index = 1, amount or 1 do
        local position = room:FindFreePickupSpawnPosition(room:GetCenterPos() + Vector((index - 1) * 28, 0), 0, true)
        spawnAt(position, entityType, variant, subtype or 0)
    end
end

function Actions.TeleportToRoom(roomType, fallbackCommand)
    if fallbackCommand and Isaac.ExecuteCommand then
        Isaac.ExecuteCommand(fallbackCommand)
    end
end

function Actions.QueueTeleport(roomType, fallbackCommand)
    pendingTeleport = { roomType = roomType, fallback = fallbackCommand }
end

function Actions.TeleportStage(stage)
    if Isaac.ExecuteCommand then
        Isaac.ExecuteCommand("stage " .. tostring(stage))
    end
end

function Actions.TeleportToRoomIndex(index)
    if not index or index < 0 then return end
    if Isaac.ExecuteCommand then
        Isaac.ExecuteCommand("goto " .. tostring(index))
        notify("Teleporting to room " .. tostring(index) .. "...")
    end
end

function Actions.SpawnCollectiblePedestal(id)
    local room = Context.Game:GetRoom()
    if not room or not id then return end
    local entityType = EntityType and EntityType.ENTITY_PICKUP or 5
    local pedestalVariant = PickupVariant and PickupVariant.PICKUP_COLLECTIBLE or 100
    local position = room:FindFreePickupSpawnPosition(room:GetCenterPos(), 0, true)
    spawnAt(position, entityType, pedestalVariant, id)
    notify("Spawned item " .. tostring(id) .. " as pedestal")
end

function Actions.DeleteProjectiles()
    local removed = 0
    local tearType = EntityType and EntityType.ENTITY_TEAR or 2
    local projectileType = EntityType and EntityType.ENTITY_PROJECTILE or 9
    local laserType = EntityType and EntityType.ENTITY_LASER or 7
    local playerType = EntityType and EntityType.ENTITY_PLAYER or 1
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        local entityType = entity.Type
        if entityType ~= tearType and entityType ~= projectileType and entityType ~= laserType then
            goto continue
        end

        local isPlayerProjectile = false
        if entityType == tearType then
            -- Enemy tears use variants >= 14; player tears are variants 0-13
            pcall(function()
                if entity.Variant < 14 then
                    isPlayerProjectile = true
                end
            end)
        elseif entityType == laserType then
            local laser = entity:ToLaser()
            pcall(function()
                if laser and laser.Shooter and laser.Shooter.Type == playerType then
                    isPlayerProjectile = true
                end
            end)
        elseif entityType == projectileType then
            -- EntityProjectile is always a player projectile; enemy bullets are tears
            isPlayerProjectile = true
        end

        if not isPlayerProjectile then
            pcall(function() entity:Remove() end)
            removed = removed + 1
        end
        ::continue::
    end
    notify(removed > 0 and ("Cleared " .. removed .. " projectiles") or "No enemy projectiles")
end


function Actions.UnlockCharacters()
    local data = Isaac.GetPersistentGameData and Isaac.GetPersistentGameData()
    if not data then return end
    local achievements = {
        1, 2, 3, 4, 5, 78, 79, 80, 82, 165, 188, 333, 356, 405, 406,
        621, 622, 623, 624, 625, 626, 627, 628, 629, 630, 631, 632, 633, 634, 635, 636, 637
    }
    for _, id in ipairs(achievements) do
        pcall(function() data:Unlock(id, true) end)
    end
    notify("Characters unlocked")
end

function Actions.UnlockItems()
    local data = Isaac.GetPersistentGameData and Isaac.GetPersistentGameData()
    if not data then return end
    local charIds = {
        [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [78]=true, [79]=true, [80]=true, [82]=true,
        [165]=true, [188]=true, [333]=true, [356]=true, [405]=true, [406]=true
    }
    for achievement = 1, 637 do
        if not charIds[achievement] and (achievement < 621 or achievement > 637) then
            pcall(function() data:Unlock(achievement, true) end)
        end
    end
    notify("Items unlocked")
end

function Actions.UnlockEverything()
    local data = Isaac.GetPersistentGameData and Isaac.GetPersistentGameData()
    if not data then return end
    notify("Working...")
    for achievement = 1, 1000 do
        local ok, err = pcall(function() data:Unlock(achievement, true) end)
        if not ok then Context.Helpers.Log("Unlock error: " .. tostring(err)) end
    end
    notify("Unlock pass completed")
end

function Actions.ExecuteConsole(command)
    if command ~= "" and Isaac.ExecuteCommand then
        Isaac.ExecuteCommand(command)
    end
end

function Actions.ExecuteMacro(text)
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        Actions.ExecuteConsole(line)
    end
end

function Actions.ExecuteScript(text)
    local env = setmetatable({ OPTrainer = Context, Actions = Actions, player = player, game = Context.Game, Isaac = Isaac, Vector = Vector }, { __index = _G })
    local chunk, err = load(text or "", "OPTrainerCustomScript", "t", env)
    if not chunk then notify(err) return end
    local ok, result = pcall(chunk)
    notify(ok and "Script executed" or tostring(result))
end

local lastBlackHearts = 0

function Actions.ApplyHealthSliders()
    local currentPlayer = player()
    local stats = Context.Config.Data.stats
    if not currentPlayer then return end
    call(currentPlayer, "AddMaxHearts", stats.health - currentPlayer:GetMaxHearts(), true)
    call(currentPlayer, "AddSoulHearts", stats.soulHearts - currentPlayer:GetSoulHearts())
    
    local blackDelta = stats.blackHearts - lastBlackHearts
    if blackDelta ~= 0 then
        call(currentPlayer, "AddBlackHearts", blackDelta)
        lastBlackHearts = stats.blackHearts
    end

    call(currentPlayer, "AddBoneHearts", stats.boneHearts - currentPlayer:GetBoneHearts())
    call(currentPlayer, "AddRottenHearts", stats.rottenHearts - currentPlayer:GetRottenHearts())
    call(currentPlayer, "AddBrokenHearts", stats.brokenHearts - currentPlayer:GetBrokenHearts())
end

local function applyPlayerToggles(currentPlayer)
    local toggles = Context.Config.Data.toggles
    local anyActive = false
    for _, v in pairs(toggles) do if v then anyActive = true; break end end
    if not anyActive then return end
    -- God Mode damage blocking is handled via MC_ENTITY_TAKE_DMG callback
    -- Blinking/flashing is handled via MC_PRE_PLAYER_RENDER callback
    if toggles.infiniteHp then call(currentPlayer, "AddHearts", currentPlayer:GetMaxHearts()); if currentPlayer:GetSoulHearts() < 2 then call(currentPlayer, "AddSoulHearts", 2) end end
    if toggles.infiniteCharge then for slot = 0, 3 do call(currentPlayer, "SetActiveCharge", 99, slot) end end
    if toggles.infiniteBatteries then call(currentPlayer, "SetBatteryCharge", 99) end
    if toggles.infiniteCards then
        pcall(function()
            if currentPlayer:GetCard(0) == 0 then
                currentPlayer:SetCard(0, Card and Card.CARD_HOLY or 1)
            end
        end)
    end
    if toggles.infinitePills then
        pcall(function()
            if currentPlayer:GetPill(0) == 0 then
                currentPlayer:SetPill(0, 1)
            end
        end)
    end
    if toggles.infiniteCoins and currentPlayer:GetNumCoins() < 99 then call(currentPlayer, "AddCoins", 99 - currentPlayer:GetNumCoins()) end
    if toggles.infiniteKeys and currentPlayer:GetNumKeys() < 99 then call(currentPlayer, "AddKeys", 99 - currentPlayer:GetNumKeys()) end
    if toggles.infiniteBombs and currentPlayer:GetNumBombs() < 99 then call(currentPlayer, "AddBombs", 99 - currentPlayer:GetNumBombs()) end
    if toggles.holyMantle or toggles.infiniteHolyMantle then pcall(function() currentPlayer:GetEffects():AddCollectibleEffect(CollectibleType.COLLECTIBLE_HOLY_MANTLE, true, 1) end) end
    if toggles.noCurse then local level = Context.Game:GetLevel(); pcall(function() level:RemoveCurses(level:GetCurses()) end) end
    if toggles.revealMap then
        pcall(function()
            local level = Context.Game:GetLevel()
            level:ApplyMapEffect()
            level:ApplyCompassEffect()
            level:ApplyBlueMapEffect()
        end)
    end
    if toggles.bigIsaac then
        currentPlayer.SpriteScale = Vector(1.55, 1.55)
    elseif toggles.tinyIsaac then
        currentPlayer.SpriteScale = Vector(0.55, 0.55)
    else
        currentPlayer.SpriteScale = Vector(1, 1)
    end
    if toggles.rainbow then
        local frame = Isaac.GetFrameCount()
        currentPlayer:SetColor(Color((math.sin(frame * 0.08) + 1) / 2, (math.sin(frame * 0.08 + 2) + 1) / 2, (math.sin(frame * 0.08 + 4) + 1) / 2, 1, 0, 0, 0), 2, 1, false, false)
    elseif toggles.randomColors and Isaac.GetFrameCount() % 12 == 0 then
        currentPlayer:SetColor(Color(math.random(), math.random(), math.random(), 1, 0, 0, 0), 8, 1, false, false)
    end
end

local function applyEnemyToggles()
    local toggles = Context.Config.Data.toggles
    if not (toggles.freezeEnemies or toggles.slowEnemies or toggles.confuseEnemies or toggles.fearEnemies or toggles.charmEnemies) then return end
    local entities = Isaac.GetRoomEntities()
    if #entities == 0 then return end
    local ref = EntityRef(player())
    for _, entity in ipairs(entities) do
        local npc = entity:ToNPC()
        if npc and npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
            if toggles.freezeEnemies then call(npc, "AddFreeze", ref, 4) end
            if toggles.slowEnemies then call(npc, "AddSlowing", ref, 8, 0.35, Color(0.45, 0.65, 1, 1, 0, 0, 0)) end
            if toggles.confuseEnemies then call(npc, "AddConfusion", ref, 8, false) end
            if toggles.fearEnemies then call(npc, "AddFear", ref, 8) end
            if toggles.charmEnemies then call(npc, "AddCharmed", ref, 8) end
        end
    end
end

local function triggered(keyCode)
    if not keyCode or keyCode == 0 or not Input or not Input.IsButtonPressed then return false end
    local pressed = false
    pcall(function() pressed = Input.IsButtonPressed(keyCode, 0) end)
    local wasPressed = previousKeys[keyCode] == true
    previousKeys[keyCode] = pressed
    return pressed and not wasPressed
end

function Actions.UpdateHotkeys()
    local settings = Context.Config.Data.settings
    local hotkeys = Context.Config.Data.hotkeys

    -- Keep the menu hotkey available even when action hotkeys are disabled.
    -- Otherwise there is no keyboard path back into Settings to re-enable them.
    if triggered(hotkeys.menu) then Context.UI.Toggle() return end
    if settings.enableHotkeys == false then return end
    if ImGui and ImGui.GetVisible then
        local windowVisible = false
        pcall(function()
            if ImGui.ElementExists and ImGui.ElementExists(Context.Constants.UI.WINDOW_ID) then
                windowVisible = ImGui.GetVisible(Context.Constants.UI.WINDOW_ID)
            end
        end)
        if windowVisible then return end
    end
    if triggered(hotkeys.opBuild) then Actions.ApplyBuild("OP Build"); notifyNow("OP Build applied") end
    if triggered(hotkeys.god) then
        local enabled = Context.Config.Toggle({ "toggles", "god" })
        refreshPlayerCache()
        notifyNow(enabled and "God Mode enabled" or "God Mode disabled")
    end
    if triggered(hotkeys.heal) then Actions.Heal(); notifyNow("Healed") end
    if triggered(hotkeys.killRoom) then Actions.KillRoom(); notifyNow("Room cleared") end
    if triggered(hotkeys.fullCharge) then Actions.FullCharge(); notifyNow("Charged") end
    if triggered(hotkeys.noBlink) then
        local enabled = Context.Config.Toggle({ "toggles", "noBlink" })
        notifyNow(enabled and "No Blink enabled" or "No Blink disabled")
    end
    if triggered(hotkeys.infiniteHp) then
        local enabled = Context.Config.Toggle({ "toggles", "infiniteHp" })
        notifyNow(enabled and "Infinite HP enabled" or "Infinite HP disabled")
    end
    if triggered(hotkeys.revealMap) then
        local enabled = Context.Config.Toggle({ "toggles", "revealMap" })
        notifyNow(enabled and "Reveal Map enabled" or "Reveal Map disabled")
    end
    if triggered(hotkeys.noCurse) then
        local enabled = Context.Config.Toggle({ "toggles", "noCurse" })
        notifyNow(enabled and "No Curse enabled" or "No Curse disabled")
    end
    if triggered(hotkeys.teleportBoss) then
        Actions.QueueTeleport(RoomType and RoomType.ROOM_BOSS or 5, "goto s.boss.1010")
        notifyNow("Teleporting to Boss Room...")
    end
end

function Actions.Update()
    if pendingTeleport then
        local tp = pendingTeleport
        pendingTeleport = nil
        Actions.TeleportToRoom(tp.roomType, tp.fallback)
    end

    local currentPlayer = player()
    if currentPlayer then
        applyPlayerToggles(currentPlayer)
        applyEnemyToggles()
    end
    
    -- Decrement custom i-frame timers for all players
    pcall(function()
        for i = 0, Isaac.GetNumPlayers() - 1 do
            local p = Isaac.GetPlayer(i)
            if p then
                local data = p:GetData()
                if data and data.OPTrainerCustomIFrames and data.OPTrainerCustomIFrames > 0 then
                    data.OPTrainerCustomIFrames = data.OPTrainerCustomIFrames - 1
                end
            end
        end
    end)
end

function Actions.EvaluateCache(currentPlayer, cacheFlag)
    local stats = Context.Config.Data.stats
    local toggles = Context.Config.Data.toggles
    if CacheFlag and cacheFlag == CacheFlag.CACHE_DAMAGE then
        currentPlayer.Damage = currentPlayer.Damage + stats.damage
        if stats.damageMultiplier and stats.damageMultiplier ~= 1.0 then
            currentPlayer.Damage = currentPlayer.Damage * stats.damageMultiplier
        end
    elseif CacheFlag and cacheFlag == CacheFlag.CACHE_FIREDELAY then currentPlayer.MaxFireDelay = math.max(1, currentPlayer.MaxFireDelay - stats.tears - stats.fireDelay)
    elseif CacheFlag and cacheFlag == CacheFlag.CACHE_RANGE then currentPlayer.TearRange = currentPlayer.TearRange + stats.range * 40
    elseif CacheFlag and cacheFlag == CacheFlag.CACHE_SPEED then currentPlayer.MoveSpeed = math.min(3, currentPlayer.MoveSpeed + stats.speed)
    elseif CacheFlag and cacheFlag == CacheFlag.CACHE_SHOTSPEED then currentPlayer.ShotSpeed = currentPlayer.ShotSpeed + stats.shotSpeed
    elseif CacheFlag and cacheFlag == CacheFlag.CACHE_LUCK then currentPlayer.Luck = currentPlayer.Luck + stats.luck
    elseif CacheFlag and cacheFlag == CacheFlag.CACHE_SIZE then currentPlayer.SpriteScale = currentPlayer.SpriteScale + Vector(stats.scale + stats.size, stats.scale + stats.size)
    elseif CacheFlag and cacheFlag == CacheFlag.CACHE_FLYING and toggles.flight then currentPlayer.CanFly = true
    elseif CacheFlag and cacheFlag == CacheFlag.CACHE_TEARFLAG then
        if toggles.spectralTears then currentPlayer.TearFlags = currentPlayer.TearFlags | TearFlags.TEAR_SPECTRAL end
        if toggles.homingTears then currentPlayer.TearFlags = currentPlayer.TearFlags | TearFlags.TEAR_HOMING end
        if toggles.piercingTears then currentPlayer.TearFlags = currentPlayer.TearFlags | TearFlags.TEAR_PIERCING end
        if toggles.laserTears then currentPlayer.TearFlags = currentPlayer.TearFlags | TearFlags.TEAR_LASER end
    end
end


function Actions.RefreshStats()
    refreshPlayerCache()
end

function Actions.OnEntityTakeDamage(entity, amount, flags, source)
    if not entity then return nil end
    local config = Context and Context.Config and Context.Config.Data
    if not config or not config.toggles then return nil end
    local toggles = config.toggles

    local entityType = EntityType and EntityType.ENTITY_PLAYER or 1
    if entity.Type == entityType then
        return Actions.ShouldBlockDamage(entity, amount, flags)
    end

    if toggles.oneHitKill then
        local npc = entity:ToNPC()
        if npc and npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
            local data = npc:GetData()
            if not data.OPTrainerOneHit then
                data.OPTrainerOneHit = true
                pcall(function()
                    npc:TakeDamage(99999, flags or 0, source, 1)
                end)
                data.OPTrainerOneHit = nil
            end
        end
    end

    return nil
end

function Actions.ShouldBlockDamage(entity, amount, flags)
    local config = Context and Context.Config and Context.Config.Data
    if not config or not config.toggles then
        return nil
    end

    if not entity or entity.Type ~= (EntityType and EntityType.ENTITY_PLAYER or 1) then
        return nil
    end

    local toggles = config.toggles
    local stats = config.stats or {}

    if toggles.god then
        return false
    end

    local finalAmount = amount
    local finalFlags = flags or 0
    local countdown = nil

    if toggles.noBlink then
        local data = entity:GetData()
        data.OPTrainerCustomIFrames = data.OPTrainerCustomIFrames or 0
        if data.OPTrainerCustomIFrames > 0 then
            return false
        elseif amount and amount > 0 then
            data.OPTrainerCustomIFrames = 30 -- Give standard 1 second of invincibility
            countdown = 0
        end
    end

    if stats.damageTakenMultiplier and stats.damageTakenMultiplier < 1.0 and amount and amount > 0 then
        finalAmount = math.max(1, math.floor(amount * stats.damageTakenMultiplier + 0.5))
    end

    if finalAmount ~= amount or countdown ~= nil then
        return {
            Damage = finalAmount,
            DamageFlags = finalFlags,
            DamageCountdown = countdown or 0
        }
    end

    return nil
end


return Actions
