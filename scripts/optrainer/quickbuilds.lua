local QuickBuilds = {}

local Context

-- Special build names that should not appear in the Quick Builds list
local specialBuilds = {
    ["OP Build"] = true,
    ["One Shot"] = true,
    ["Glass Cannon"] = true,
    ["Greed Build"] = true,
    ["Random Broken Build"] = true,
}

function QuickBuilds.Init(context)
    Context = context
end

function QuickBuilds.GetList()
    local result = {}
    for _, build in ipairs(Context.Data.Builds) do
        if not specialBuilds[build.name] and not build.random then
            result[#result + 1] = build
        end
    end
    return result
end

function QuickBuilds.Apply(index)
    local list = QuickBuilds.GetList()
    local build = list[index]
    if not build then
        return
    end

    for _, itemId in ipairs(build.items) do
        Context.Actions.GiveCollectible(itemId)
    end

    Context.Config.Data.lastBuild = build.name
    Context.Config.Save(false)
    Context.Notifications.Push(build.name .. " applied")
end

return QuickBuilds
