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

--[[
	playerItemRemovalState
		index is player source
		value is which item in the removalIndex has been removed.
			value >= 3 means all items have been removed.
--]]
local playerMethCreationStepState = {}

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

	local removalIndex = (playerMethCreationStepState[_source] or 0) + 1
	playerMethCreationStepState[_source] = removalIndex

	local item = Config.MethSteps[removalIndex]
	if item then
		if item.ItemId and item.Amount then
			player.Functions.RemoveItem(item.ItemId, item.Amount)
		end
	end
end)

RegisterServerEvent("mnm:making:startWaitingForProduct")
AddEventHandler("mnm:making:startWaitingForProduct", function ()
	-- TODO: Check that player went through previous steps.
	-- 		 Use local variables or metadata in player?
	local _source = source

	-- Since we call startWaitingForProduct on the last creation step, we should just check that we at least got to the step before last.
	if not playerMethCreationStepState[_source] or playerMethCreationStepState[_source] < (#Config.MethSteps - 1) then
		-- Exploting!!!!!
		warn(tostring(_source) .. " is exploting! Tried to wait for product before removing items!")
		return
	end

	-- Player has removed all items.
	playerMethCreationStepState[_source] = nil
	local waitingForProductMiliseconds = Config.PackingTimeSeconds * 1000
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
local MaxPlayerInventoryWeight = Config.MaxPlayerInventoryWeight

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

	local hasAllItems = true

	for _, itemData in pairs(Config.MethSteps) do
		if itemData.ItemId and itemData.Amount and not QBCore.Functions.HasItem(_source, itemData.ItemId, itemData.Amount) then
			hasAllItems = false
			break
		end
	end

	if hasAllItems then
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