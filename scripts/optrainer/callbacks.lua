local Callbacks = {}

local Context

local function timed(label, fn, ...)
    if Context.Helpers then
        return Context.Helpers.TimeCall(label, fn, ...)
    end
    return pcall(fn, ...)
end

function Callbacks.Init(context)
    Context = context
end

function Callbacks.Register()
    local mod = Context.Mod

    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
        timed("POST_GAME_STARTED", function()
            Context.Save.Load()
            Context.Data.RefreshCatalog()
            Context.Search.Rebuild()
            Context.UI.Build()
            Context.Actions.OnGameStarted(isContinued)
        end)
    end)

    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
        timed("POST_UPDATE", function()
            Context.Actions.Update()
            Context.UI.Update()
        end)
    end)

    mod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
        pcall(function()
            Context.Actions.UpdateHotkeys()
            Context.Notifications.Update()
            Context.Config.FlushIfDirty()
        end)
    end)

    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player, cacheFlag)
        timed("EVALUATE_CACHE", function()
            Context.Actions.EvaluateCache(player, cacheFlag)
        end)
    end)

    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, flags, source, countdown)
        local ok, result = pcall(Context.Actions.OnEntityTakeDamage, entity, amount, flags, source)
        if ok then
            return result
        end
        -- If the call errored, fall back to the god mode toggle directly.
        -- This ensures god mode still blocks damage even if other logic fails.
        if Context.Config and Context.Config.Data and Context.Config.Data.toggles and Context.Config.Data.toggles.god then
            return false
        end
        return nil
    end)


    mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player, offset)
        local toggles = Context.Config.Data.toggles
        if toggles.noBlink or toggles.god then
            pcall(function()
                local sprite = player:GetSprite()
                if sprite then
                    local color = sprite.Color
                    if color and color.A < 1.0 then
                        sprite.Color = Color(color.R, color.G, color.B, 1.0, color.RO, color.GO, color.BO)
                    end
                end
            end)
        end
    end)

    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
        Context.Save.Flush(true)
    end)
end

return Callbacks
