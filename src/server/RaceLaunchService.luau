local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))

local RaceLaunchService = {}
local pending = {}
local started = false
local ERROR_TEXT = "RACE SERVER UNAVAILABLE - PLEASE TRY AGAIN"

local function fail(player, token)
	local entry = pending[player]
	if not entry or entry.token ~= token then return end
	pending[player] = nil
	if player.Parent == Players then
		if entry.kind == "launch" then player:SetAttribute("RaceState", "GARAGE") end
		player:SetAttribute("RaceEntryError", ERROR_TEXT)
	end
	if entry.onFailure then entry.onFailure() end
end

function RaceLaunchService.start()
	if started then return end
	started = true
	TeleportService.TeleportInitFailed:Connect(function(player)
		local entry = pending[player]
		if entry then fail(player, entry.token) end
	end)
	Players.PlayerRemoving:Connect(function(player) pending[player] = nil end)
end

function RaceLaunchService.launchSolo(player, trackId, driverId, kartId, onFailure)
	if player.Parent ~= Players or pending[player] then return false end
	local payload = RaceLaunchPayload.buildSolo(HttpService:GenerateGUID(false), player, trackId, driverId, kartId)
	if not payload then return false end
	local token = {}
	pending[player] = { token = token, kind = "launch", onFailure = onFailure }
	player:SetAttribute("SelectedDriverId", driverId)
	player:SetAttribute("SelectedKartId", kartId)
	player:SetAttribute("SelectedTrackId", trackId)
	player:SetAttribute("RaceEntryError", "")
	print(string.format("[KDMRoute] launch match=%s track=%s racers=1", payload.matchId, trackId))
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData(payload)
	-- Clear a stalled request even if TeleportAsync never returns.
	task.delay(30, function() fail(player, token) end)
	local ok = pcall(function() TeleportService:TeleportAsync(game.PlaceId, { player }, options) end)
	if not ok then fail(player, token) end
	-- A successful API return can still be followed by TeleportInitFailed.
	return ok
end

function RaceLaunchService.returnToHub(player, onFailure)
	if player.Parent ~= Players or pending[player] then return false end
	local token = {}
	pending[player] = { token = token, kind = "return", onFailure = onFailure }
	player:SetAttribute("RaceEntryError", "")
	task.delay(30, function() fail(player, token) end)
	local ok = pcall(function() TeleportService:TeleportAsync(game.PlaceId, { player }) end)
	if not ok then fail(player, token) end
	return ok
end

return RaceLaunchService
