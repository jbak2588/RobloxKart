local fs=require("@lune/fs")
local luau=require("@lune/luau")
local signals, attrs, delayed, played = {}, {RaceState="GARAGE",RaceCountdown=0,RaceCompletedLaps=0}, {}, {}
local player={}
function player:GetAttribute(key) return attrs[key] end
function player:GetAttributeChangedSignal(key)
 signals[key]=signals[key] or {Connect=function(self,fn) self.callback=fn end}
 return signals[key]
end
local function set(key,value)
 attrs[key]=value
 if signals[key] then signals[key].callback() end
end
local runtime={getGroup=function() return {} end,preload=function() end,stop=function() end,
 createSound=function(name) return {Name=name,TimeLength=0.32,PlaybackSpeed=1} end,
 playOnce=function(sound) table.insert(played,sound.Name) end}
local shared={WaitForChild=function(_,name) return name end}
local modules={AudioRuntime=runtime,AudioConfig={ASSETS={},RACE={}},RaceConfig={TOTAL_LAPS=3}}
local services={Players={LocalPlayer=player},ReplicatedStorage={WaitForChild=function() return shared end},SoundService={}}
local controller=luau.load(fs.readFile("src/client/RaceAudioController.luau"),{environment={
 game={GetService=function(_,name) return services[name] end},script={Parent=shared},require=function(name) return modules[name] end,
 task={delay=function(delay,callback) table.insert(delayed,{delay,callback}) end}
}})()
controller.start()
set("RaceCountdown",3); set("RaceState","COUNTDOWN")
set("RaceCountdown",2); set("RaceCountdown",1); set("RaceCountdown",0); set("RaceState","RACING")
assert(#played==4 and #delayed==2)
assert(delayed[1][1]>0 and delayed[2][1]==delayed[1][1]*2)
for _,item in delayed do item[2]() end
assert(table.concat(played,",")=="CountdownBeep,CountdownBeep,CountdownBeep,RaceGoFirst,RaceGoSecond,RaceGoThird")
played={}; delayed={}
set("RaceState","COUNTDOWN"); set("RaceState","RACING"); set("RaceState","GARAGE")
for _,item in delayed do item[2]() end
assert(#played==1 and played[1]=="RaceGoFirst","leaving race cancels pending beeps")
print("PASS: 3-2-1 and three GO beeps; spacing and cancellation")
