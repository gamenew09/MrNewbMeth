local QBCore = exports["qb-core"]:GetCoreObject()
local IsMakingMeth = false

AddEventHandler("QBCore:Client:UpdateObject", function ()
	QBCore = exports["qb-core"]:GetCoreObject()
end)

function explodeLocalPlayer()
	local pp = PlayerPedId()
	local coords = GetEntityCoords(pp)
	AddExplosion(coords.x, coords.y+2.0, coords.z, 32, 100000.0, true, false, 4.0)
end

function startMethCook()
	TriggerServerEvent("mnm:making:checkInitialCook")
end

RegisterCommand("startMethCookTest", function ()
	-- This will eventually be moved to a target on a model.
	startMethCook()
end)

local neededAttempts = 5 -- how many succesful attempts it takes to pass
local succeededAttempts = 0 -- changes dynamically do not edit

function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(100)
    end
end

local methAnim = {
	Dictionary = "amb@world_human_stand_fire@male@idle_a",
	Animation = "idle_a"
}

local function MakingMethAnim()
    IsMakingMeth = true

	local animDict = methAnim.Dictionary
	local anim = methAnim.Animation

	loadAnimDict(animDict)
    CreateThread(function()
        while true do
            if IsMakingMeth then
                TaskPlayAnim(PlayerPedId(), animDict, anim, 3.0, 3.0, -1, 16, 0, 0, 0, 0)
            else
                StopAnimTask(PlayerPedId(), animDict, anim, 1.0)
                break
            end
            Wait(1000)
        end
    end)
end

RegisterNetEvent("mnm:making:waitingForProduct", function (waitTime)
    QBCore.Functions.Progressbar("waitingforproduct", "Packing the Bag...", waitTime, false, false, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    },
    nil, nil, nil, function ()
        IsMakingMeth = false
        LocalPlayer.state:set("inv_busy", false, true)
    end, function ()
        IsMakingMeth = false
        LocalPlayer.state:set("inv_busy", false, true)
		explodeLocalPlayer()
    end)
end)

local function ShowItemBox(itemName, type)
    TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items[itemName], type)
end

-- If a recipe requires more than one type of item, we may want to show it removed that many items.
local removalIndexes = {
    [1] = "acetone",
    [2] = "antifreeze",
    [3] = "sudo"
}

RegisterNetEvent("mnm:making:secondStepContinue", function ()
	-- TODO: Find a way for devs to quickly swap out qb-skillbar for something else.
	local Skillbar = exports['qb-skillbar']:GetSkillbarObject()
    
    -- prevent players from accessing their inventory during a cook.
    LocalPlayer.state:set("inv_busy", true, true)

	MakingMethAnim()

    Skillbar.Start({
        duration = math.random(7500, 8500), -- how long the skillbar runs for
        pos = math.random(10, 30), -- how far to the right the static box is
        width = math.random(10, 20), -- how wide the static box is
    }, function()
        local itemNameToShowRemoval = removalIndexes[succeededAttempts + 1]
        if itemNameToShowRemoval then
            ShowItemBox(itemNameToShowRemoval, "remove")
        end

        if succeededAttempts + 1 >= neededAttempts then
            print('Player succeeded enough times!')
			succeededAttempts = 0
			IsMakingMeth = false
            TriggerServerEvent("mnm:making:startWaitingForProduct")
        else
            TriggerServerEvent("mnm:making:removeAnotherProduct")
            Skillbar.Repeat({
                duration = math.random(4500, 7500),
                pos = math.random(10, 30),
                width = math.random(5, 15),
            })
            succeededAttempts = succeededAttempts + 1
        end
    end, function()
		succeededAttempts = 0
		IsMakingMeth = false
        LocalPlayer.state:set("inv_busy", false, true)
		explodeLocalPlayer()
        print('Player cancelled the skillbar!')
    end)
end)