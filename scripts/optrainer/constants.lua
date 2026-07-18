local Constants = {}

Constants.VERSION = "1.3.6"
Constants.REPENTOGON_MIN_VERSION = "0.4.6"

Constants.KEYS = {
    F6 = Keyboard and Keyboard.KEY_F6 or 295,
    F7 = Keyboard and Keyboard.KEY_F7 or 296,
    F8 = Keyboard and Keyboard.KEY_F8 or 297,
    F9 = Keyboard and Keyboard.KEY_F9 or 298,
    F10 = Keyboard and Keyboard.KEY_F10 or 299,
}

Constants.ICONS = {
    bolt = "\u{f0e7}",
    heart = "\u{f004}",
    cross = "\u{f00c}",
    skull = "\u{f54c}",
    search = "\u{f002}",
    star = "\u{f005}",
    trash = "\u{f2ed}",
    gear = "\u{f013}",
    user = "\u{f007}",
    chart = "\u{f201}",
    box = "\u{f187}",
    key = "\u{f084}",
    bomb = "\u{f1e2}",
    coin = "\u{f51e}",
    map = "\u{f279}",
    door = "\u{f52b}",
    wand = "\u{f72b}",
    terminal = "\u{f120}",
    info = "\u{f05a}",
    play = "\u{f04b}",
    save = "\u{f0c7}",
    upload = "\u{f56f}",
    download = "\u{f56e}",
    flask = "\u{f0c3}",
    keyboard = "\u{f11c}",
    palette = "\u{f53f}",
    smile = "\u{f118}",
    plus = "\u{f067}",
    arrow = "\u{f0b2}",
}

Constants.PICKUP = {
    COIN = PickupVariant and PickupVariant.PICKUP_COIN or 20,
    KEY = PickupVariant and PickupVariant.PICKUP_KEY or 30,
    BOMB = PickupVariant and PickupVariant.PICKUP_BOMB or 40,
    CHEST = PickupVariant and PickupVariant.PICKUP_CHEST or 50,
    GOLDEN_CHEST = PickupVariant and PickupVariant.PICKUP_LOCKEDCHEST or 60,
    RED_CHEST = PickupVariant and PickupVariant.PICKUP_REDCHEST or 360,
    MEGA_CHEST = PickupVariant and PickupVariant.PICKUP_MEGACHEST or 340,
    BOMB_CHEST = PickupVariant and PickupVariant.PICKUP_BOMBCHEST or 390,
}

Constants.SLOT = {
    SLOT_MACHINE = SlotVariant and SlotVariant.SLOT_MACHINE or 1,
    BEGGAR = SlotVariant and SlotVariant.BEGGAR or 4,
}

Constants.GRID = {
    TRAPDOOR = GridEntityType and GridEntityType.GRID_TRAPDOOR or 17,
    STAIRS = GridEntityType and GridEntityType.GRID_STAIRS or 24,
}

Constants.UI = {
    WINDOW_ID = "OPTrainer.Main",
    MENU_ID = "OPTrainer.Menu",
    MENU_ITEM_ID = "OPTrainer.Menu.Open",
    BUTTON_WIDTH = 220,
    SMALL_BUTTON_WIDTH = 120,
    MIN_WINDOW_WIDTH = 420,
    MAX_WINDOW_WIDTH = 1600,
    MIN_WINDOW_HEIGHT = 360,
    MAX_WINDOW_HEIGHT = 1100,
    WINDOW_MARGIN = 48,
    TAB_TEXT_BREAKPOINT = 760,
    SEARCH_RESULTS = 12,
}

return Constants
