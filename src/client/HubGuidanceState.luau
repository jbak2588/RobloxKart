-- Session-local navigation hints. Room/route ownership always takes precedence.
local HubGuidanceState = {}

function HubGuidanceState.new()
 return { context = "HUB", visited = false }
end

function HubGuidanceState.returned(state, action)
 state.visited = true
 state.context = if action == "GARAGE" then "KART_READY" elseif action == "RACE_RETURN" then "NEXT_RACE" else "TRACK_RETURN"
end

function HubGuidanceState.presentation(state, safeSize, raceState, overlayOpen, routePending, roomOwned)
 -- Phone landscapes keep world signs readable from the very first arrival.
 local compact = state.visited or safeSize.Y < 400
 local heading = if state.context == "KART_READY" then "KART READY" elseif state.context == "NEXT_RACE" then "NEXT RACE" else "NEXT"
 local message = if state.context == "TRACK_RETURN" then "Choose a track and race again" else "Choose a track and start racing"
 return {
  visible = raceState == "GARAGE" and not overlayOpen and not roomOwned
   and (routePending == nil or routePending == "") and safeSize.X >= 200 and safeSize.Y >= 212,
  compact = compact, heading = heading, message = message,
  width = math.min(if compact then 150 else 280, safeSize.X - 24), height = if compact then 76 else 150,
  bottom = 124, -- Existing 104px shortcuts + 12px bottom inset + 8px gap.
 }
end

return HubGuidanceState
