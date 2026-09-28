local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local PlayerPreferences = {}
local started = false
local warnedLoad, warnedSave = false, false

function PlayerPreferences.start()
	if started then return end
	started = true
	local remote = Instance.new("RemoteEvent")
	remote.Name = "ControlsTutorialPreference"
	remote.Parent = ReplicatedStorage
	local store
	local ok, result = pcall(function() return DataStoreService:GetDataStore("KDM_PlayerPrefs_v1") end)
	if ok then store = result end
	local function bind(player)
		player:SetAttribute("ControlsTutorialDismissed", false)
		player:SetAttribute("ControlsTutorialPreferenceLoaded", false)
		task.spawn(function()
			local dismissed = false
			if store then
				local loaded, value = pcall(function() return store:GetAsync(tostring(player.UserId)) end)
				if loaded then dismissed = type(value) == "table" and value.controlsTutorialDismissed == true
				elseif not warnedLoad then warnedLoad = true; warn("[PlayerPreferences] load failed: " .. tostring(value)) end
			elseif not warnedLoad then warnedLoad = true; warn("[PlayerPreferences] DataStore unavailable") end
			if player.Parent then
				-- A local dismissal during a slow load must not be reverted.
				player:SetAttribute("ControlsTutorialDismissed", dismissed or player:GetAttribute("ControlsTutorialDismissed") == true)
				player:SetAttribute("ControlsTutorialPreferenceLoaded", true)
			end
		end)
	end
	for _, player in Players:GetPlayers() do bind(player) end
	Players.PlayerAdded:Connect(bind)
	remote.OnServerEvent:Connect(function(player, action)
		if action ~= "Dismiss" or player:GetAttribute("ControlsTutorialDismissed") == true then return end
		player:SetAttribute("ControlsTutorialDismissed", true)
		if not store then return end
		task.spawn(function()
			local saved, err = pcall(function()
				store:UpdateAsync(tostring(player.UserId), function(previous)
					local value = if type(previous) == "table" then previous else {}
					value.controlsTutorialDismissed = true
					return value
				end)
			end)
			if not saved and not warnedSave then warnedSave = true; warn("[PlayerPreferences] save failed: " .. tostring(err)) end
		end)
	end)
end

return PlayerPreferences
