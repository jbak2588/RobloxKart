-- lune run tests/finish_sequence_validation.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local count = 0
local function check(value, message) assert(value, message); count += 1 end
local format = luau.load(fs.readFile("src/shared/RaceResultFormat.luau"))()
check(format.time(241.13)=="4:01.13","total time uses minute format")
check(format.time(78.9)=="1:18.90","lap time pads seconds")
check(format.time(58.42)=="58.42","short lap has no minute prefix")
check(format.time(59.999)=="1:00.00","centisecond rollover is correct")
check(format.delta(78.9,78.9,true)=="BEST" and format.delta(83.2,78.9,false)=="+4.30","best and lap deltas")

local function signal()
 local listeners={}
 return {
  Connect=function(_,callback) table.insert(listeners,callback); return {Disconnect=function() end} end,
  Fire=function(_,...) for _,callback in listeners do callback(...) end end,
 }
end
local stateChanged=signal()
local player={attrs={RaceState="GARAGE"},Character=nil,CharacterAdded=signal(),CharacterRemoving=signal()}
function player:GetAttribute(name) return self.attrs[name] end
function player:GetAttributeChangedSignal(name) assert(name=="RaceState"); return stateChanged end
local preSimulation=signal()
local services={Players={LocalPlayer=player},RunService={PreSimulation=preSimulation}}
local controller=luau.load(fs.readFile("src/client/DriverCelebrationController.luau"),{environment={
 game={GetService=function(_,name) return services[name] end},CFrame=rb.CFrame,
}})()
controller.start()
local function character(rig, shoulderName)
 local seat={GetAttribute=function(_,name) return name=="PrototypeKartSeat" end}
 local humanoid={SeatPart=seat}
 local joint={ClassName="Motor6D",Name=shoulderName,Transform=rb.CFrame.identity}
 function joint:IsA(name) return name=="Motor6D" end
 local torso={Name=rig}
 function torso:FindFirstChild(name) if name==shoulderName then return joint end end
 joint.Parent=torso
 local model={}
 function model:FindFirstChildOfClass(name) if name=="Humanoid" then return humanoid end end
 function model:FindFirstChild(name) if name==rig then return torso end end
 function joint:IsDescendantOf(ancestor) return ancestor==model end
 return model,joint,humanoid
end
local function setState(state)
 player.attrs.RaceState=state
 stateChanged:Fire()
end
for _, entry in {{"UpperTorso","RightShoulder"},{"Torso","Right Shoulder"}} do
 local model,joint,humanoid=character(entry[1],entry[2])
 player.Character=model
 setState("FINISHING")
 preSimulation:Fire(0.25)
 check(joint.Transform~=rb.CFrame.identity,entry[1].." shoulder raises")
 check(humanoid.SeatPart~=nil,entry[1].." driver remains seated")
 setState("FINISHED")
 check(joint.Transform==rb.CFrame.identity,entry[1].." shoulder restores at result")
end
local model,joint=character("UpperTorso","Absent")
model.FindFirstChild=function(_,name)
 if name=="UpperTorso" then return {FindFirstChild=function() return nil end} end
end
player.Character=model
setState("FINISHING")
preSimulation:Fire(0.25)
check(joint.Transform==rb.CFrame.identity,"missing shoulder safely falls back")
setState("GARAGE")
player.Character=nil
player.CharacterRemoving:Fire()
preSimulation:Fire(0.1)
check(true,"garage and character removal remain safe")
print("PASS: "..count.." finish format and seated celebration checks")
