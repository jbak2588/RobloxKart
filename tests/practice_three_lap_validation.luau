-- Actual production controller, with deterministic transport/time/positions only.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/race_mode_validation.luau'):gsub('\r\n','\n')
local first=assert(source:find('start("Track01")\ncheck',1,true))
source=source:sub(1,first-1):gsub('require%("%./helpers/gameplay_config"%)','_configLoader')
local scenario=[====[
for best=1,3 do
 start('Track01')
 check(player:GetAttribute('RaceMode')=='RACE' and player:GetAttribute('RaceTotalLaps')==3,'public Practice target')
 for lap=1,3 do
  local duration=if lap==best then 2 else 4
  cross(checkpoints[1],nil,duration);cross(checkpoints[2],nil,duration);cross(finish,nil,duration)
  check(player:GetAttribute('RaceCompletedLaps')==lap,'completed lap '..lap)
  check(player:GetAttribute('RaceState')==(if lap==3 then 'FINISHING' else 'RACING'),'only third lap finishes')
 end
 check(player:GetAttribute('RaceBestLapNumber')==best,'best lap may be '..best)
 for lap=1,3 do check(player:GetAttribute('RaceLap'..lap..'Time')>0,'all three actual times')end
 tick(raceConfig.FINISH_SEQUENCE_SECONDS+.1)
 check(player:GetAttribute('RaceState')=='FINISHED','normal result lifecycle')
 services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,'Rematch')
 tick(raceConfig.ITEM_PREP_SECONDS)
 services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,'StartSolo')
 check(player:GetAttribute('RaceState')=='COUNTDOWN','one Human can start rematch')
 for lap=1,3 do check(player:GetAttribute('RaceLap'..lap..'Time')==0,'rematch clears lap '..lap)end
end
print('PASS: '..count..' production Practice public three-lap / all best-lap / rematch checks')
]====]
luau.load(source..scenario,{environment={_configLoader=require('./helpers/gameplay_config')}})()
