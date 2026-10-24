-- Local attacker launch and hit audio shared by races and Hub item practice.
local RS=game:GetService('ReplicatedStorage')
local SoundService=game:GetService('SoundService')
local Config=require(RS:WaitForChild('Shared'):WaitForChild('AudioConfig'))
local Audio=require(script.Parent:WaitForChild('AudioRuntime'))
local Controller={}
local running
function Controller.new(player)
 local sounds,connections,last={},{},{}
 local stopped=false
 for _,kind in {'Missile','Thunder'}do
  local c=Config.COMBAT[kind]
  local sound=Audio.createSound('Attacker'..kind..'Hit',c.Asset,SoundService,Audio.getGroup('RobloxKartSFX'),false,c.Volume,false)
  if sound then sound.PlaybackSpeed=c.Pitch;sounds[kind]=sound end
 end
 local launch=Config.COMBAT.MissileLaunch
 sounds.MissileLaunch=Audio.createSound('AttackerMissileLaunch',launch.Asset,SoundService,Audio.getGroup('RobloxKartSFX'),false,launch.Volume,false)
 Audio.preload(sounds)
 local function stop()
  for _,sound in sounds do Audio.stop(sound)end
 end
 local function kart(practice)
  local h=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
  local seat=h and h.SeatPart;local model=seat and seat.Parent
  if not h or h.Health<=0 or not model or not model.Parent then return nil end
  if practice then
   if player:GetAttribute('RaceState')~='GARAGE' or player:GetAttribute('LobbyDriveActive')~=true
    or player:GetAttribute('KDMRoutePending')=='RACE_LAUNCH' or seat:GetAttribute('LobbyKartSeat')~=true
    or model:GetAttribute('LobbyOwnerUserId')~=player.UserId then return nil end
  elseif player:GetAttribute('RaceState')~='RACING' or seat:GetAttribute('PrototypeKartSeat')~=true
   or model:GetAttribute('PrototypeKart')~=true or model:GetAttribute('RaceControlsLocked')==true then return nil end
  return model
 end
 local function observe(serial,callback)
  last[serial]=player:GetAttribute(serial)
  table.insert(connections,player:GetAttributeChangedSignal(serial):Connect(function()
   local value=player:GetAttribute(serial)
   if stopped or value==last[serial]then return end
   last[serial]=value
   if type(value)=='number'and value>0 then callback()end
  end))
 end
 observe('RaceCombatFeedbackSerial',function()
  if kart(false)and player:GetAttribute('RaceCombatFeedbackCode')=='MISSILE_HIT'then Audio.playOnce(sounds.Missile)end
 end)
 observe('RaceMissileFiredSerial',function()
  local model=kart(false)
  if model and player:GetAttribute('RaceMissileFiredSessionId')==player:GetAttribute('RaceSessionId')
   and player:GetAttribute('RaceMissileFiredResetSerial')==model:GetAttribute('RaceResetSerial')then Audio.playOnce(sounds.MissileLaunch)end
 end)
 observe('RaceThunderResultSerial',function()
  -- One sound for a whole Thunder event, even when several racers are hit.
  if kart(false)and (player:GetAttribute('RaceThunderHitCount')or 0)>0 then Audio.playOnce(sounds.Thunder)end
 end)
 observe('LobbyCombatHitSerial',function()
  local model=kart(true)
  if not model or player:GetAttribute('LobbyCombatHitSessionId')~=player:GetAttribute('LobbyCombatSessionId')
   or player:GetAttribute('LobbyCombatHitGeneration')~=player:GetAttribute('LobbyDriveGeneration')
   or player:GetAttribute('LobbyCombatHitResetSerial')~=model:GetAttribute('RaceResetSerial')then return end
  local kind=player:GetAttribute('LobbyCombatHitItem')
  if sounds[kind]then Audio.playOnce(sounds[kind])end
 end)
 for _,attribute in {'RaceState','RaceSessionId','LobbyDriveActive','LobbyDriveGeneration','LobbyDriveResetSerial'}do
  table.insert(connections,player:GetAttributeChangedSignal(attribute):Connect(stop))
 end
 table.insert(connections,player.CharacterRemoving:Connect(stop))
 local self={}
 function self:destroy()
  if stopped then return end
  stopped=true;stop()
  for _,connection in connections do connection:Disconnect()end
  for _,sound in sounds do sound:Destroy()end
 end
 return self
end
function Controller.start()
 if running then return end
 running=Controller.new(game:GetService('Players').LocalPlayer)
end
return Controller
