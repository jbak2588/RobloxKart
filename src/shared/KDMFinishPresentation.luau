-- Cosmetic profiles resolved only from replicated authoritative finish attributes.
local Finish = {}
Finish.BANNER_SECONDS = 1.1
Finish.REVEAL_SECONDS = .25
Finish.REVEAL_SCALE = .95
Finish.Profiles = table.freeze({
	WINNER = table.freeze({RaiseX=-35, RaiseZ=135, WaveDegrees=20, WaveSeconds=1.8,
		PrimaryCount=22, SecondaryCount=10, LifetimeMin=.7, LifetimeMax=1.05,
		SpeedMin=5, SpeedMax=9, LightEmission=.9, Size=.25}),
	PLACED = table.freeze({RaiseX=-45, RaiseZ=85, WaveDegrees=10, WaveSeconds=1.15,
		PrimaryCount=12, SecondaryCount=6, LifetimeMin=.55, LifetimeMax=.8,
		SpeedMin=4, SpeedMax=7, LightEmission=.65, Size=.18}),
})
local labels = {"1ST PLACE", "2ND PLACE", "3RD PLACE", "4TH PLACE"}
local function positiveInteger(value)
	return type(value)=="number" and value==value and value<math.huge and value>=1 and value%1==0
end
function Finish.resolve(state, position, participants)
	if state=="DNF" then return "DNF", "", nil end
	if state~="FINISHING" and state~="FINISHED" then return "NONE", "", nil end
	if not positiveInteger(participants) or not positiveInteger(position) or position>participants then
		return "NONE", "", nil
	end
	if participants==1 then return "SOLO_CLEAR", "RACE COMPLETE", Finish.Profiles.WINNER end
	if position==1 then return "WINNER", labels[1], Finish.Profiles.WINNER end
	return "PLACED", labels[position] or (tostring(position).."TH PLACE"), Finish.Profiles.PLACED
end
-- Park and official races expose one cosmetic terminal lifecycle.
function Finish.snapshot(player)
 local phase=player:GetAttribute('ParkTrialPhase')
 if player:GetAttribute('LobbyDriveActive')==true and phase~=nil then
  local state=if phase=='FINISHING'or phase=='FINISHED'then phase else 'GARAGE'
  local key='park:'..tostring(player:GetAttribute('LobbyDriveGeneration'))..':'..tostring(player:GetAttribute('ParkTrialGoAt'))
  return state,1,1,player:GetAttribute('ParkTrialFinishPhase'),key
 end
 return player:GetAttribute('RaceState'),player:GetAttribute('RaceFinishPosition'),player:GetAttribute('RaceParticipantCount'),player:GetAttribute('RaceFinishPhase'),player:GetAttribute('RaceSessionId')
end
return table.freeze(Finish)
