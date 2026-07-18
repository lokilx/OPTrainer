local Save = {}

local Context

function Save.Init(context)
    Context = context
end

function Save.Load()
    Context.Config.Load()
end

function Save.Flush(force)
    Context.Config.Save(force == true)
end

return Save
