local Notifications = {}

local Context
local queue = {}
local lastPushTime = 0
local lastMessage = ""

function Notifications.Init(context)
    Context = context
end

function Notifications.Push(message, level)
    if not message or message == "" then
        return
    end

    local clock = os.clock()
    if message == lastMessage and clock - lastPushTime < 1.0 then
        return
    end

    queue[#queue + 1] = {
        text = tostring(message),
        level = level or 0,
        ttl = 2600,
    }
end

function Notifications.Update()
    if not ImGui or not ImGui.PushNotification then
        return
    end

    local settings = Context.Config.Data.settings
    if settings and settings.notifications == false then
        return
    end

    local clock = os.clock()
    if #queue == 0 or clock - lastPushTime < 0.4 then
        return
    end

    local notification = table.remove(queue, 1)
    lastPushTime = clock
    lastMessage = notification.text
    pcall(ImGui.PushNotification, notification.text, notification.level, notification.ttl)
end

return Notifications
