-- Session-local navigation hints. Room/route ownership always takes precedence.
local HubGuidanceState = {}

function HubGuidanceState.new()
 return { context = "HUB", visited = false, garageDone = false, trackConfirmed = false }
end

function HubGuidanceState.profileRestored(state,profile)
 -- Server restore evidence only; default SelectedKartId or KartSelected ACK is insufficient.
 if profile.completed~=true or profile.result~="FOUND" or profile.restored~=true
  or profile.validKart~=true or profile.kartId~=profile.restoredKartId
  or profile.saveState~="SAVE_CONFIRMED" then return false end
 state.garageDone=true
 if state.context=="HUB" then state.context="KART_READY" end
 return true
end

function HubGuidanceState.returned(state, action)
 state.visited = true
 state.context = if action == "GARAGE" then "KART_READY" elseif action == "RACE_RETURN" then "NEXT_RACE" else "TRACK_RETURN"
 if action == "GARAGE" then state.garageDone = true end
 if action == "RACE_RETURN" then state.garageDone, state.trackConfirmed = true, true end
end

function HubGuidanceState.confirmed(state, trackId)
 state.trackConfirmed = true
 if trackId then state.trackId = trackId end
end

function HubGuidanceState.nextAction(state)
 -- Direct Track/Rooms entry stays free; onboarding never gates navigation.
 return "ROOMS", "RACE"
end

function HubGuidanceState.roomHelper(snapshot, userId)
 local room = snapshot and snapshot.room
 if not room then return "CREATE OR JOIN A RACE" end
 if room.membershipKind == "QUEUED" then return "WAITING FOR NEXT RACE" end
 if room.state ~= "WAITING" then return "WAITING FOR NEXT ROUND" end
 -- Hub rooms launch a reserved server BEFORE item prep is available.
 return if room.hostUserId == userId then "INVITE (OPTIONAL) • START TO SELECT ITEMS" else "WAIT FOR HOST • ITEMS NEXT"
end

function HubGuidanceState.prepHelper(raceState, matchStatus, ready)
 if raceState ~= "PRE_RACE" or matchStatus ~= "WAITING" then return nil end
 return if ready then "READY • WAITING FOR START" else "SELECT ITEMS • CONFIRM & READY"
end

function HubGuidanceState.presentation(state, safeSize, raceState, overlayOpen, routePending, roomOwned)
 -- Phone landscapes keep world signs readable from the very first arrival.
 local compact = state.visited or safeSize.Y < 400
 local heading = if state.context == "KART_READY" then "KART READY" elseif state.context == "NEXT_RACE" then "NEXT RACE" elseif state.context == "TRACK_RETURN" then "NEXT" else "YOUR KART IS READY!"
 local message = if state.context == "TRACK_RETURN" then "Create or join a race" elseif not state.visited then "Race against real players or a rookie bot." else "Race against real players or a rookie bot."
 local action, destination = HubGuidanceState.nextAction(state)
 local button = "RACE NOW"
 local secondaryButton = "FREE TEST DRIVE"
 return {
  visible = raceState == "GARAGE" and not overlayOpen and not roomOwned
   and (routePending == nil or routePending == "") and safeSize.X >= 200 and safeSize.Y >= 212,
  compact = compact, heading = heading, message = message, action = action, destination = destination, button = button,
  secondaryButton = secondaryButton,
  width = math.min(280, safeSize.X - 24), height = if compact then 76 else 208,
  bottom = 124, -- Existing 104px shortcuts + 12px bottom inset + 8px gap.
 }
end

return HubGuidanceState
