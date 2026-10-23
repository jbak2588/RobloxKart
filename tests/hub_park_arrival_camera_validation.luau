local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local n=0;local function check(v,m)assert(v,m);n+=1 end
local function signal()return {Connect=function(self,fn)self.fn=fn end,Fire=function(self,...)if self.fn then self.fn(...)end end}end
for _,park in {true,false}do
 local signals={};local attrs={RaceState='GARAGE',HubArrivalSerial=0};local now=0
 local origin=rb.Vector3.new(0,.75,if park then 852 else 888)
 local spawn={Position=origin,CFrame=rb.CFrame.lookAt(origin,origin+(if park then -rb.Vector3.zAxis else rb.Vector3.zAxis))}
 local body={Position=origin+rb.Vector3.new(0,3,0)};local human={}
 local player={Character={FindFirstChild=function()return body end,FindFirstChildOfClass=function()return human end},CharacterRemoving=signal()}
 function player:GetAttribute(k)return attrs[k]end
 function player:GetAttributeChangedSignal(k)signals[k]=signals[k]or signal();return signals[k]end
 local zone={GetAttribute=function()return if park then 'ROOKIE_LOOP_V1'else nil end,FindFirstChild=function()return {Position=origin+rb.Vector3.zAxis*20}end}
 local hub={FindFirstChild=function(_,name)if name=='HubSpawn'then return spawn elseif name=='HubParkRookieLoopG2'and park or name=='LobbyFrontTestDriveZone'and not park then return zone end end}
 local camera={CFrame=rb.CFrame.identity}
 local world={CurrentCamera=camera,GetAttribute=function()return 'HUB'end,FindFirstChild=function()return hub end}
 local services={Players={LocalPlayer=player},RunService={RenderStepped={Wait=function()now+=1 end}},Workspace=world}
 local Controller=luau.load(fs.readFile('src/client/HubArrivalCameraController.luau'),{environment={game={GetService=function(_,k)return services[k]end},Vector3=rb.Vector3,CFrame=rb.CFrame,Enum=rb.Enum,os={clock=function()return now end},task={spawn=function(fn)fn()end}}})()
 Controller.start();attrs.HubArrivalSerial=1;signals.HubArrivalSerial:Fire()
 check(camera.CameraType==rb.Enum.CameraType.Custom and camera.CameraSubject==human,'native walking camera retained')
 check((camera.CFrame.Position.Z-body.Position.Z)*(if park then 1 else -1)>9,'arrival faces correct Park/legacy direction')
 check(math.abs((camera.CFrame.Position-body.Position).Y-(if park then 6 else 5))<.001,'arrival height follows approved camera composition')
 local previous=camera.CFrame;attrs.RaceState='RACING';signals.HubArrivalSerial:Fire()
 check(camera.CFrame==previous,'arrival event cannot override a race camera')
end
print('PASS '..n..' production Park/legacy arrival framing and camera ownership checks')
