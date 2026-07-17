local Mod = RegisterMod("OPTrainer", 1)

local OPTrainer = {
    Mod = Mod,
    Name = "OPTrainer",
    Game = Game(),
}

OPTrainer.Json = include("scripts.optrainer.json")
OPTrainer.Constants = include("scripts.optrainer.constants")
OPTrainer.Version = OPTrainer.Constants.VERSION
OPTrainer.Helpers = include("scripts.optrainer.helpers")
OPTrainer.Config = include("scripts.optrainer.config")
OPTrainer.Save = include("scripts.optrainer.save")
OPTrainer.Data = include("scripts.optrainer.data")
OPTrainer.Search = include("scripts.optrainer.search")
OPTrainer.Favorites = include("scripts.optrainer.favorites")
OPTrainer.Notifications = include("scripts.optrainer.notifications")
OPTrainer.Actions = include("scripts.optrainer.actions")
OPTrainer.QuickActions = include("scripts.optrainer.quickactions")
OPTrainer.QuickBuilds = include("scripts.optrainer.quickbuilds")
OPTrainer.UI = include("scripts.optrainer.ui")
OPTrainer.Callbacks = include("scripts.optrainer.callbacks")

OPTrainer.Helpers.Init(OPTrainer)
OPTrainer.Config.Init(OPTrainer)
OPTrainer.Save.Init(OPTrainer)
OPTrainer.Data.Init(OPTrainer)
OPTrainer.Search.Init(OPTrainer)
OPTrainer.Favorites.Init(OPTrainer)
OPTrainer.Notifications.Init(OPTrainer)
OPTrainer.Actions.Init(OPTrainer)
OPTrainer.QuickActions.Init(OPTrainer)
OPTrainer.QuickBuilds.Init(OPTrainer)
OPTrainer.UI.Init(OPTrainer)
OPTrainer.Callbacks.Init(OPTrainer)
OPTrainer.Callbacks.Register()

if Isaac and Isaac.IsInGame and Isaac.IsInGame() then
    pcall(function()
        OPTrainer.Save.Load()
        OPTrainer.Data.RefreshCatalog()
        OPTrainer.Search.Rebuild()
        OPTrainer.UI.Build()
    end)
end