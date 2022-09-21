local QBCore = exports["qb-core"]:GetCoreObject()

AddEventHandler("QBCore:Server:UpdateObject", function ()
	QBCore = exports["qb-core"]:GetCoreObject()
end)

local items = {
	['sudo'] = {
		name = 'sudo',
		label = "Pseudoephedrine",
		weight = 3,
		type = 'item',
		image = 'pseudoephedrine.png',
		unique = false,
		useable = false, -- May make this usuable later.
		shouldClose = true,
		combinable = nil,
		description = "Good for your stuffy nose and sinuses."
	},
	['acetone'] = {
		name = 'acetone',
		label = "Acetone",
		weight = 2,
		type = 'item',
		image = 'acetone.png',
		unique = false,
		useable = false, -- May make this usuable later.
		shouldClose = true,
		combinable = nil,
		description = "Removes paint from the walls and nails."
	},
	['antifreeze'] = {
		name = 'antifreeze',
		label = "Antifreeze",
		weight = 2,
		type = 'item',
		image = 'antifreeze.png',
		unique = false,
		useable = false, -- May make this usuable later.
		shouldClose = true,
		combinable = nil,
		description = "Prevents water from freezing."
	}
}

for id, itemTable in pairs(items) do
	if QBCore.Shared.Items[id] then
		QBCore.Functions.UpdateItem(id, itemTable)
	else
		QBCore.Functions.AddItem(id, itemTable)
	end
end

function NotifyPlayer(source, text, type, length)
	TriggerClientEvent('QBCore:Notify', source, text, type, length)
end

function IsAlive(source)
	local player = QBCore.Functions.GetPlayer(source)
	if not player or not player.Functions then return false end

	return (not player.Functions.GetMetaData("inlaststand")) and (not player.Functions.GetMetaData("isdead"))
end

-- TODO: Moved to shared lua file.\
-- TODO: Make values table of item name and amount.
local removalIndexes = {
    [1] = "acetone",
    [2] = "antifreeze",
    [3] = "sudo"
}

local AcetoneToMeth = 1
local AntifreezeToMeth = 1
local SudoToMeth = 1

--[[
	playerItemRemovalState
		index is player source
		value is which item in the removalIndex has been removed.
			value >= 3 means all items have been removed.
--]]
local playerItemRemovalState = {}

function ItemBox(source, itemName, type)
	TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], type)
end

RegisterServerEvent("mnm:making:removeAnotherProduct")
RegisterNetEvent("mnm:making:removeAnotherProduct", function ()
	-- I'm not going to care if they remove all items and then startWaitingForProduct in an instant.
	-- I'm more worried about exploiters trying to make meth without giving in the correct products.

	local _source = source

	local player = QBCore.Functions.GetPlayer(_source)
	if not player then return end

	local removalIndex = (playerItemRemovalState[_source] or 0) + 1
	playerItemRemovalState[_source] = removalIndex

	local itemName = removalIndexes[removalIndex]
	if itemName then
		player.Functions.RemoveItem(itemName, 1)
		ItemBox(itemName, "remove")
	end
end)

RegisterServerEvent("mnm:making:startWaitingForProduct")
AddEventHandler("mnm:making:startWaitingForProduct", function ()
	-- TODO: Check that player went through previous steps.
	-- 		 Use local variables or metadata in player?
	local _source = source

	if not playerItemRemovalState[_source] or playerItemRemovalState[_source] < #removalIndexes then
		-- Exploting!!!!!
		warn(tostring(_source) .. " is exploting! Tried to wait for product before removing items!")
		return
	end

	-- Player has removed all items.
	playerItemRemovalState[_source] = nil
	local waitingForProductMiliseconds = 1000
	TriggerClientEvent("mnm:making:waitingForProduct", _source, waitingForProductMiliseconds)

	CreateThread(function ()
		Wait(waitingForProductMiliseconds)
		if not IsAlive(_source) then return end

		local player = QBCore.Functions.GetPlayer(_source)
		if not player then warn("couldn't find player") return end
		-- Well shit, how the fuck do you drop items?
		-- quality will be based on a few factors in the future. just doing this for now.
		if player.Functions.AddItem("meth", 1) then
			ItemBox(_source, "meth", "add")
		else
			print("god damn it, meth didn't go through.")
		end
	end)
end)

-- How the fuck do i get this from qb-inventory resource.
-- Will people have to know to change this???
local MaxPlayerInventoryWeight = 120000

RegisterServerEvent("mnm:making:checkInitialCook")
AddEventHandler("mnm:making:checkInitialCook", function ()
	local _source = source
	local player = QBCore.Functions.GetPlayer(_source)
	if not player then 
		warn(source .. " isn't associated with a valid player.")
		return
	end

	-- Check to make sure the player can actually hold the bag we are about to make. (this is a naive check, but should error on the side of caution)
	local totalWeight = QBCore.Player.GetTotalWeight(player.PlayerData.items)
	local methWeight = QBCore.Shared.Items["meth"].weight or 0

	if totalWeight + methWeight > MaxPlayerInventoryWeight then
		NotifyPlayer(_source, "I'm carying way too much to make this.", "error")
		return
	end

	-- Check if player is alive, and if they die anytime during it then cancel out of making meth.

	if QBCore.Functions.HasItem(_source, "acetone", AcetoneToMeth) and QBCore.Functions.HasItem(_source, "antifreeze", AntifreezeToMeth) and QBCore.Functions.HasItem(_source, "sudo", SudoToMeth) then
		-- We have required stuff to cook. Tell client to start the skillbar.
		-- It'll also handle showing the item boxes too.
		NotifyPlayer(_source, "I have it! I'm making it!", "success") -- DEBUG
		TriggerClientEvent("mnm:making:secondStepContinue", source)
		print("making it")
	else
		NotifyPlayer(_source, "I'm missing something...", "error")
	end
end)

--[[
	Meth Table:
		qb-target start cook (client)
		check if player has required items [acetone, antifreeze, sudo] (server)
		skillbar (client)
		get time to wait and at the same time wait this amount of time to prevent exploiting. (server)
		progressbar (client)

		client notifies server that its ready for the item to be given. Server verifies that the client waited the correct amount of time (if the player ends up sending it a little bit early, then it'll be fine).
			Server will then give the meth to the player.
--]]