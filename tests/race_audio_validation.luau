local fs=require("@lune/fs")
local luau=require("@lune/luau")
local signals, attrs, delayed, played = {}, {RaceState="GARAGE",RaceCountdown=0,RaceCompletedLaps=0}, {}, {}
local player={}
player.AncestryChanged={Connect=function(self,fn)self.callback=fn end}
function player:GetAttribute(key) return attrs[key] end
function player:GetAttributeChangedSignal(key)
 signals[key]=signals[key] or {Connect=function(self,fn) self.callback=fn end}
 return signals[key]
end
local function set(key,value)
 attrs[key]=value
 if signals[key] then signals[key].callback() end
end
local created,effects,stopped={},{},{}
local runtime={getGroup=function() return {} end,preload=function() end,stop=function(s)if s then stopped[s.Name]=true end end,
 createSound=function(name,asset,parent,group,looped) local s={Name=name,SoundId=asset,TimeLength=0.32,PlaybackSpeed=1,Looped=looped};created[name]=s;return s end,
 playOnce=function(sound) table.insert(played,sound.Name) end}
local shared={WaitForChild=function(_,name) return name end}
local modules={AudioRuntime=runtime,AudioConfig=luau.load(fs.readFile("src/shared/AudioConfig.luau"))(),RaceConfig={TOTAL_LAPS=3}}
local services={Players={LocalPlayer=player},ReplicatedStorage={WaitForChild=function() return shared end},SoundService={}}
local controller=luau.load(fs.readFile("src/client/RaceAudioController.luau"),{environment={
 game={GetService=function(_,name) return services[name] end},script={Parent=shared},require=function(name) return modules[name] end,
 Instance={new=function(class)assert(class=='PitchShiftSoundEffect');local effect={};table.insert(effects,effect);return effect end},
 task={delay=function(delay,callback) table.insert(delayed,{delay,callback}) end}
}})()
controller.start()
set("RaceCountdown",3); set("RaceState","COUNTDOWN")
set("RaceCountdown",2); set("RaceCountdown",1); set("RaceCountdown",0); set("RaceState","RACING")
assert(#played==4 and #delayed==0,'GO is one sustained cue with no repeat callbacks')
assert(created.RaceGoFirst.SoundId==created.CountdownBeep.SoundId,'same countdown timbre')
assert(not created.RaceGoFirst.Looped and not created.RaceGoSecond and not created.RaceGoThird,'no looping/triple GO')
assert(created.RaceGoFirst.TimeLength/created.RaceGoFirst.PlaybackSpeed==created.CountdownBeep.TimeLength*2,'exact double countdown duration')
assert(#effects==2 and effects[1].Parent==created.RaceGoFirst and effects[2].Parent==created.RaceGoFirst,'effects apply only to GO')
assert(effects[1].Priority>effects[2].Priority,'duration compensation runs before pitch lift')
assert(math.abs(created.RaceGoFirst.PlaybackSpeed*effects[1].Octave*effects[2].Octave-1.18)<1e-6,'independent higher pitch')
assert(created.CountdownBeep.PlaybackSpeed==1,'countdown unchanged')
set('RaceState','RACING');assert(#played==4,'duplicate RACING does not replay GO')
for _,item in delayed do item[2]() end
assert(table.concat(played,",")=="CountdownBeep,CountdownBeep,CountdownBeep,RaceGoFirst")
played={}; delayed={}
set("RaceState","COUNTDOWN"); set("RaceState","RACING"); set("RaceState","GARAGE")
for _,item in delayed do item[2]() end
assert(#played==1 and played[1]=="RaceGoFirst","leaving race cancels pending beeps")
assert(stopped.RaceGoFirst,'leaving race stops sustained GO')
local function flush() local pending=delayed;delayed={};for _,item in pending do item[2]() end end
local function startRace(total)
 set("RaceTotalLaps",total);set("RaceCompletedLaps",0);set("RaceCurrentLap",1)
 set("RaceState","COUNTDOWN");set("RaceState","RACING");flush();played={}
end
startRace(3)
set("RaceCompletedLaps",2)
assert(#played==0,"wait until last-lap display conditions are satisfied")
set("RaceCurrentLap",3)
assert(#played==1 and #delayed==2,"last lap starts one three-beep sequence")
assert(created.FinalLapFirst.PlaybackSpeed==1.18 and created.FinalLapFirst.PlaybackSpeed>created.RaceGoFirst.PlaybackSpeed)
assert(created.FinalLapFirst.SoundId==created.RaceGoFirst.SoundId,"reuse the existing beep asset")
assert(math.abs(delayed[1][1]-(0.32/1.18)*1.16)<1e-6,"spacing follows higher playback speed")
flush();set("RaceCurrentLap",3);set("RaceCompletedLaps",2);flush()
assert(table.concat(played,",")=="FinalLapFirst,FinalLapSecond,FinalLapThird","no duplicate final lap pattern")
startRace(3);set("RaceCurrentLap",3);set("RaceCompletedLaps",2);flush()
assert(#played==3,"lap attributes may arrive in reverse order; rematch re-arms sound")
for _,state in {"GARAGE","DNF","FINISHED","COUNTDOWN"} do
 startRace(3);set("RaceCurrentLap",3);set("RaceCompletedLaps",2);set("RaceState",state);flush()
 local finals=0;for _,name in played do if name:match("^FinalLap")then finals+=1 end end
 assert(finals==1,"transition cancels pending final lap beeps: "..state)
end
startRace(1);set("RaceCompletedLaps",1);flush()
assert(#played==0,"one-lap Practice has no final-lap notice/beeps")
set("RaceState","FINISHING")
assert(#played==1 and played[1]=="RaceFinish","finish sound plays at crossing into FINISHING")
set("RaceState","FINISHED")
assert(#played==1,"result reveal does not replay finish sound")
stopped={};player.AncestryChanged.callback(player,nil);assert(stopped.RaceGoFirst,'departure clears GO')
print("PASS: countdown/GO regression; higher three-beep Final Lap, spacing, ordering, deduplication, rematch and cancellation")
