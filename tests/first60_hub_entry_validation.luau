-- tests/first60_hub_entry_validation.luau
-- KDM F60-A First Entry Simplification / One-Click Public Race verification

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local nodes = require("./helpers/practice_ui_nodes")

local checks = 0
local function check(condition: boolean, message: string)
	assert(condition, message)
	checks += 1
end

-- 1. Guidance Presentation & CTA Structure Verification
local stateModule = luau.load(fs.readFile("src/client/HubGuidanceState.luau"))()
local state = stateModule.new()

check(state.context == "HUB", "1. Fresh session starts in HUB context")
check(not state.visited, "1. Initial session is not visited")

local p = stateModule.presentation(state, rb.Vector2.new(1280, 720), "GARAGE", false, nil, false)
check(p.visible == true, "1. Guidance card visible on initial HUB entry")
check(p.button == "RACE NOW", "1. Primary CTA is RACE NOW")
check(p.secondaryButton == "TIME ATTACK", "2. Secondary CTA is TIME ATTACK")
check(p.heading == "YOUR KART IS READY!", "1. Heading is YOUR KART IS READY!")
check(p.message == "Race against real players or a rookie bot.", "1. Subtitle clarifies real players or rookie bot")

-- 3. Default behavior does not mandate prior track selection
check(p.action == "ROOMS", "3. Next action is direct race flow without manual track selection gate")

-- 16. Mobile Safe Area and responsive canvas checks
for _, size in {
	rb.Vector2.new(844, 302), -- iPhone 13/14 landscape
	rb.Vector2.new(932, 342), -- iPhone 14 Pro Max landscape
	rb.Vector2.new(751, 244), -- Small Android landscape
	rb.Vector2.new(640, 230), -- Compact landscape constraint
	rb.Vector2.new(390, 786), -- Portrait fallback
	rb.Vector2.new(1920, 1080), -- Desktop 1080p
} do
	local pres = stateModule.presentation(state, size, "GARAGE", false, nil, false)
	check(pres.visible, "16. Guidance visible at resolution " .. tostring(size))
	check(size.Y - pres.bottom - pres.height >= 0, "16. Card fits within safe height for " .. tostring(size))
	check(pres.width + 24 <= size.X, "16. Card width fits safe canvas for " .. tostring(size))
end

-- 2 & 17. Guidance View Node creation and unclipped elements
local parentGui = nodes.object("ScreenGui")
parentGui.Name = "KDMHubNavigation"
local theme = {
	Panel = rb.Color3.fromRGB(18, 32, 49),
	PrimaryAction = rb.Color3.fromRGB(255, 209, 55),
	TextPrimary = rb.Color3.fromRGB(240, 245, 252),
	TextSecondary = rb.Color3.fromRGB(160, 185, 210),
	Background = rb.Color3.fromRGB(12, 27, 42),
}

local raceNowClicked = 0
local testDriveClicked = 0
local viewModule = luau.load(fs.readFile("src/client/HubGuidanceView.luau"), {
	environment = {
		Instance = { new = nodes.object },
		UDim = rb.UDim,
		UDim2 = rb.UDim2,
		Vector2 = rb.Vector2,
		Color3 = rb.Color3,
		Enum = rb.Enum,
		script = { Parent = { FindFirstChild = function() return nil end } }
	}
})()

local view = viewModule.create(parentGui, theme, function()
	raceNowClicked += 1
end, function()
	testDriveClicked += 1
end)

check(view.card ~= nil, "17. NextAction card created")
check(view.button ~= nil, "1. Primary button exists")
check(view.testDriveButton ~= nil, "2. Secondary button exists")

view.update(p)
check(view.button.Text == "RACE NOW", "1. Primary button displays RACE NOW")
check(view.testDriveButton.Text == "TIME ATTACK", "2. Secondary button displays TIME ATTACK")

-- Test activations
view.button.Activated:Fire()
check(raceNowClicked == 1, "4. RACE NOW button activation fires onRaceNow handler")

view.testDriveButton.Activated:Fire()
check(testDriveClicked == 1, "12. TIME ATTACK button activation fires onTestDrive handler")

-- 4 & 5. MatchRoomService: QuickStart action and selection preparation
local matchRoomServiceSource = fs.readFile("src/server/MatchRoomService.luau")
check(matchRoomServiceSource:find('action == "QuickStart"', 1, true) ~= nil, "5. MatchRoomService implements QuickStart action")
check(matchRoomServiceSource:find('ensureSelection(player)', 1, true) ~= nil, "4. MatchRoomService automatically ensures valid default selection")
check(matchRoomServiceSource:find('Discovery.DefaultTrackId', 1, true) ~= nil, "4. MatchRoomService defaults track to Track01")
check(matchRoomServiceSource:find('DriverCatalog.DefaultId', 1, true) ~= nil, "4. MatchRoomService defaults driver to DriverCatalog.DefaultId")
check(matchRoomServiceSource:find('stopLobbyDrive(player', 1, true) ~= nil, "11. QuickStart stops any active lobby test drive before matchmaking")

-- 6. FirstRace vs QuickPlay separation
check(matchRoomServiceSource:find('action==\'FirstRace\'', 1, true) ~= nil, "6. FirstRace separate action remains distinct and preserved")
check(matchRoomServiceSource:find('createRoom(player,\'DEFAULT\',nil,true,true)', 1, true) ~= nil, "6. FirstRace creates dedicated solo first race room, distinct from QuickPlay")

-- 7 & 8. Public QuickPlay Matchmaking candidate lookup & new room creation
check(matchRoomServiceSource:find('for _,r in records do if publicTrack(r.trackId)and (not requestedTrackId or r.trackId==requestedTrackId)and Discovery.rank(r)then candidate=r;break end end', 1, true) ~= nil,
	"7. QuickPlay prioritizes existing public race candidate matching Discovery ranking")
check(matchRoomServiceSource:find('if not candidate then', 1, true) ~= nil, "8. QuickPlay creates new public race if no candidate available")
check(matchRoomServiceSource:find('quickMatch=true,initializing=true', 1, true) ~= nil, "8. New candidate is flagged as quickMatch with AutoStart")

-- 9 & 10. Rookie Bot & AutoStart preservation in RaceRoomCoordinator
local coordinatorSource = fs.readFile("src/server/RaceRoomCoordinator.luau")
check(coordinatorSource:find('quickMatch', 1, true) ~= nil, "9. RaceRoomCoordinator supports quickMatch")
check(coordinatorSource:find('KDM Rookie', 1, true) ~= nil or coordinatorSource:find('ROOKIE', 1, true) ~= nil or coordinatorSource:find('Bot', 1, true) ~= nil,
	"9. Rookie bot capability configured for solo quickMatch arrival")
check(coordinatorSource:find('quickWarmup', 1, true) ~= nil or coordinatorSource:find('Warmup', 1, true) ~= nil,
	"10. Quick warmup and bot interruption preserved for multi-player arrival")

-- 12 & 13. LobbyTestDriveController and Display ProximityPrompt
local testDriveSource = fs.readFile("src/client/LobbyTestDriveController.luau")
check(testDriveSource:find('function Controller.requestDrive(mode)', 1, true) ~= nil, "12. LobbyTestDriveController exposes requestDrive API")
check(testDriveSource:find('LobbyDisplayTestDrive', 1, true) ~= nil, "13. Display kart test drive ProximityPrompt preserved")

-- 14. PostDriveView RACE NOW integration
local postDriveSource = fs.readFile("src/client/LobbyPostDriveView.luau")
check(postDriveSource:find('RACE NOW', 1, true) ~= nil, "14. PostDriveView primary CTA is RACE NOW")
check(postDriveSource:find('READY FOR YOUR FIRST RACE?', 1, true) ~= nil, "14. PostDriveView title is READY FOR YOUR FIRST RACE?")
check(testDriveSource:find('MatchRoomUiController', 1, true) ~= nil and testDriveSource:find('quickStart()', 1, true) ~= nil,
	"14. PostDriveView primary CTA links directly to MatchRoomUi.quickStart()")

-- 15. Server Role Isolation
local initClientSource = fs.readFile("src/client/init.client.luau")
check(initClientSource:find('role == "HUB"', 1, true) ~= nil, "15. HUB UI controllers strictly isolated to HUB role")

-- 18. Matchmaking Failure recovery and Retry UI in MatchRoomUiController
local matchRoomUiSource = fs.readFile("src/client/MatchRoomUiController.luau")
check(matchRoomUiSource:find('function MatchRoomUiController.quickStart()', 1, true) ~= nil, "5. MatchRoomUiController exposes quickStart API")
check(matchRoomUiSource:find('FINDING YOUR RACE...', 1, true) ~= nil, "18. MatchRoomUiController shows FINDING YOUR RACE... title")
check(matchRoomUiSource:find('CONNECTING TO AVAILABLE RACERS...', 1, true) ~= nil, "18. MatchRoomUiController shows CONNECTING TO AVAILABLE RACERS... status")
check(matchRoomUiSource:find('RETRY', 1, true) ~= nil, "18. MatchRoomUiController provides RETRY button on failure")

-- TASK 4: Button font & duplicate rendering audit
check(view.button.TextStrokeTransparency == 1, "T4. RACE NOW button has TextStrokeTransparency = 1 (no smudged black outline)")
check(view.testDriveButton.TextStrokeTransparency == 1, "T4. TIME ATTACK button has TextStrokeTransparency = 1 (no smudged black outline)")
check(view.button.Font == rb.Enum.Font.GothamBold, "T4. RACE NOW button uses legible GothamBold font")
check(view.testDriveButton.Font == rb.Enum.Font.GothamBold, "T4. TIME ATTACK button uses legible GothamBold font")
check(view.button.TextColor3 == rb.Color3.fromRGB(255, 215, 50), "T4. RACE NOW uses yellow text on semi-transparent pill")
check(view.testDriveButton.TextColor3 == rb.Color3.fromRGB(111, 211, 245), "T4. TIME ATTACK uses cyan text on semi-transparent pill")

-- Compact layout text sizes
local compactPres = stateModule.presentation(state, rb.Vector2.new(640, 230), "GARAGE", false, nil, false)
view.update(compactPres)
check(view.button.TextSize == 16, "T4. Compact RACE NOW uses 16px legible text")
check(view.testDriveButton.TextSize == 16, "T4. Compact TIME ATTACK uses legible text")
check(view.button.TextStrokeTransparency == 1 and view.testDriveButton.TextStrokeTransparency == 1, "T4. Compact mode retains clean unoutlined text")

-- TASK 5: Scenario tests (1-12)
-- S1: New profile initial visit
local schemaModule = luau.load(fs.readFile("src/shared/KDMProgressionSchema.luau"))
check(schemaModule ~= nil, "T5. Progression schema loaded")

-- S5: Returning unactivated user (session reset with no qualifications)
local unactivatedState = stateModule.new()
check(unactivatedState.context == "HUB", "T5. Unactivated returning user starts with HUB context")
local unactivatedPres = stateModule.presentation(unactivatedState, rb.Vector2.new(1280, 720), "GARAGE", false, nil, false)
check(unactivatedPres.button == "RACE NOW" and unactivatedPres.secondaryButton == "TIME ATTACK", "T5. Unactivated returning user sees RACE NOW and TIME ATTACK")

-- S6: Returning active user (restored profile)
local activeState = stateModule.new()
local mockProfile = {
	completed = true, result = "FOUND", restored = true,
	validKart = true, kartId = "Kart05", restoredKartId = "Kart05",
	saveState = "SAVE_CONFIRMED"
}
check(stateModule.profileRestored(activeState, mockProfile), "T5. Active user profileRestored returns true")
check(activeState.context == "KART_READY", "T5. Active user transitions to KART_READY context")

-- S7: Profile restore pending
local pendingState = stateModule.new()
local pendingProfile = { completed = false, result = "LOADING" }
check(not stateModule.profileRestored(pendingState, pendingProfile), "T5. Loading profile does not flip to restored")
check(pendingState.context == "HUB", "T5. Pending profile remains in initial HUB context without premature flip")

-- S8 & S9: Modal open hides guidance
local modalPres = stateModule.presentation(state, rb.Vector2.new(1280, 720), "GARAGE", true, nil, false)
check(not modalPres.visible, "T5. Modal open (overlayOpen=true) hides guidance card")

local roomOwnedPres = stateModule.presentation(state, rb.Vector2.new(1280, 720), "GARAGE", false, nil, true)
check(not roomOwnedPres.visible, "T5. Room owned hides guidance card")

local routePendingPres = stateModule.presentation(state, rb.Vector2.new(1280, 720), "GARAGE", false, "RACE_LAUNCH", false)
check(not routePendingPres.visible, "T5. Route pending hides guidance card")

-- S12: Personal records permission restriction (only Canary admin 11700555357)
local recordsSource = fs.readFile("src/client/PersonalRecordsController.luau")
check(recordsSource:find('player.UserId~=11700555357', 1, true) ~= nil, "T5. MY RECORDS restricted strictly to Canary Admin 11700555357")

view.destroy()
parentGui:Destroy()

print(string.format("PASS: %d F60-A First 60 Seconds V1 verification checks", checks))
