Config = Config or {}
Config.DefaultMethCreateAnimation = {
	Dictionary = "amb@world_human_stand_fire@male@idle_a",
	Animation = "idle_a"
}

-- The amount of time it takes to "pack" meth into a bag.
-- This shows up as a progress bar after the skillbar checks for items.
Config.PackingTimeSeconds = 3

Config.MaxPlayerInventoryWeight = 120000

Config.MethSteps = {
    [1] = {
        ItemId = "acetone",
        Amount = 2,
        Animation = {
            Dictionary = "amb@code_human_in_car_mp_actions@dance@low@ps@base",
            Animation = "enter"
        }
    },
    [2] = {
        ItemId = "antifreeze",
        Amount = 2,
        Animation = {
            Dictionary = "amb@code_human_in_car_mp_actions@dance@std@ds@base",
            Animation = "idle_a"
        }
    },
    [3] = {
        ItemId = "sudo",
        Amount = 2
    },
    [4] = {},
    [5] = {},
    [6] = {}
}

-- When removing an item for the meth creation process, this will determine
-- how many item boxes show up on screen everytime an item is removed.
-- If true: If a step removes 2 items, then it'll show 2 removal item boxes.
-- If false: If a step removes 2 items, it'll show 1 removal item box.
Config.MatchItemBoxesToRemovalCount = true