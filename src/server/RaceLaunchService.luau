local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))

local RaceLaunchService = {}
local pending = {}
local started = false
local ERROR_TEXT = "RACE SERVER UNAVAILABLE - PLEASE TRY AGAIN"

local function fail(player, token)
	local entry = pending[player]
	if not entry or entry.token ~= token then return end
	pending[player] = nil
	if player.Parent ~= Players then return end
	if entry.kind == "launch" then player:SetAttribute("RaceState", "GARAGE") end
	player:SetAttribute("RaceEntryError", if RunService:IsStudio() then
		"TELEPORT TEST REQUIRES PUBLISHED ROBLOX CLIENT" else ERROR_TEXT)
	if entry.onFailure then entry.onFailure() end
end

local function watchdog(player, token)
	if player.Parent == Players and pending[player] and pending[player].token == token then
		warn(string.format("[KDMRoute] teleport watchdog user=%d kind=%s", player.UserId, pending[player].kind))
		fail(player, token)
	end
end

function RaceLaunchService.start()
	if started then return end
	started = true
	TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId)
		local entry = pending[player]
		warn(string.format("[KDMRoute] teleport init failed user=%d kind=%s result=%s place=%s error=%s",
			player.UserId, if entry then entry.kind else "untracked", tostring(teleportResult),
			tostring(placeId), tostring(errorMessage)))
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
	task.delay(30, function() watchdog(player, token) end)
	local ok, resultOrError = pcall(function() return TeleportService:TeleportAsync(game.PlaceId, { player }, options) end)
	if not ok then
		warn(string.format("[KDMRoute] teleport request failed user=%d track=%s error=%s",
			player.UserId, trackId, tostring(resultOrError)))
		fail(player, token)
	else
		local privatePresent = resultOrError ~= nil and type(resultOrError.PrivateServerId) == "string"
			and resultOrError.PrivateServerId ~= ""
		local codePresent = resultOrError ~= nil and type(resultOrError.ReservedServerAccessCode) == "string"
			and resultOrError.ReservedServerAccessCode ~= ""
		print(string.format("[KDMRoute] teleport accepted user=%d reserved=true privateServerId=%s accessCode=%s",
			player.UserId, if privatePresent then "present" else "unavailable",
			if codePresent then "present" else "unavailable"))
	end
	-- A successful API return can still be followed by TeleportInitFailed.
	return ok
end

function RaceLaunchService.returnToHub(player, onFailure)
	if player.Parent ~= Players or pending[player] then return false end
	local token = {}
	pending[player] = { token = token, kind = "return", onFailure = onFailure }
	if not onFailure then player:SetAttribute("RaceEntryError", "") end
	task.delay(30, function() watchdog(player, token) end)
	local ok, resultOrError = pcall(function() return TeleportService:TeleportAsync(game.PlaceId, { player }) end)
	if not ok then
		warn(string.format("[KDMRoute] HUB return request failed user=%d error=%s", player.UserId, tostring(resultOrError)))
		fail(player, token)
	else
		print(string.format("[KDMRoute] HUB return accepted user=%d", player.UserId))
	end
	return ok
end

return RaceLaunchService
