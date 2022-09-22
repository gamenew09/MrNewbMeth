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

AddEventHandler('onResourceStop', function(resource)
   if resource == GetCurrentResourceName() then
      IsMakingMeth = false
   end
end)


local currentAnim = defaultAnim

local function ChangeAnimation(animTable)
    CreateThread(function ()
        StopAnimTask(PlayerPedId(), currentAnim.Dictionary, currentAnim.Animation, 1.0)
        currentAnim = animTable or Config.DefaultMethCreateAnimation
        print("changed animation to ", currentAnim.Dictionary, currentAnim.Animation)
        TaskPlayAnim(PlayerPedId(), currentAnim.Dictionary, currentAnim.Animation, 3.0, 3.0, -1, 16, 0, 0, 0, 0)
    end)
end

local function MakingMethAnim()
    IsMakingMeth = true
    local defaultAnim = Config.DefaultMethCreateAnimation

    -- Load Default Meth Table Animation Dictionary
	loadAnimDict(defaultAnim.Dictionary)

    -- Load any animation dictionaries that a step wants to use.
    for _, methStep in pairs(Config.MethSteps) do
        if methStep.Animation then
            print("loading", methStep.Animation.Dictionary)
	        loadAnimDict(methStep.Animation.Dictionary)
        end
    end

    currentAnim = Config.MethSteps[1].Animation or defaultAnim
    print("changed animation to ", currentAnim.Dictionary, currentAnim.Animation)

    CreateThread(function()
        while true do
            if IsMakingMeth then
                TaskPlayAnim(PlayerPedId(), currentAnim.Dictionary, currentAnim.Animation, 3.0, 3.0, -1, 16, 0, 0, 0, 0)
            else
                StopAnimTask(PlayerPedId(), currentAnim.Dictionary, currentAnim.Animation, 1.0)
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

RegisterNetEvent("mnm:making:secondStepContinue", function ()
	-- TODO: Find a way for devs to quickly swap out qb-skillbar for something else.
	local Skillbar = exports['qb-skillbar']:GetSkillbarObject()
    
    -- prevent players from accessing their inventory during a cook.
    LocalPlayer.state:set("inv_busy", true, true)

	MakingMethAnim()
    local removalIndexes = Config.MethSteps
    
    neededAttempts = #removalIndexes
    
    Skillbar.Start({
        duration = math.random(7500, 8500), -- how long the skillbar runs for
        pos = math.random(10, 30), -- how far to the right the static box is
        width = math.random(10, 20), -- how wide the static box is
    }, function()
        local stepData = removalIndexes[succeededAttempts + 1]
        if stepData and stepData.ItemId and stepData.Amount then
            local itemid = stepData.ItemId
            if Config.MatchItemBoxesToRemovalCount then
                for i = 1, stepData.Amount do
                    ShowItemBox(itemid, "remove")
                end
            else
                ShowItemBox(itemid, "remove")
            end
        end

        if succeededAttempts + 1 >= neededAttempts then
            print('Player succeeded enough times!')
			succeededAttempts = 0
			IsMakingMeth = false
            TriggerServerEvent("mnm:making:startWaitingForProduct")
        else
            TriggerServerEvent("mnm:making:removeAnotherProduct")
            local nextStepData = removalIndexes[succeededAttempts + 2]
            if nextStepData then
                ChangeAnimation(nextStepData.Animation or Config.DefaultMethCreateAnimation)
            end
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