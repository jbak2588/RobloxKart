local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local source=fs.readFile('src/server/GarageController.luau')
local first=assert(source:find('local function stageCharacter(',1,true))
local last=assert(source:find('function GarageController.start()',first,true))
local body=source:sub(first,last-1)..'\nreturn stageCharacter'
local n=0;local function check(v,m)assert(v,m);n+=1 end
for _,mode in {'ordinary','active_countdown','active_running','pending','late_active','late_pending','foreign_state'}do
 local attrs={RaceState=if mode=='foreign_state'then 'RACING'else 'GARAGE',LobbyDriveActive=mode=='active_countdown'or mode=='active_running',LobbyDrivePending=mode=='pending'}
 local health={SeatPart=if mode=='late_active'or mode=='late_pending'then {}else nil,Sit=true,changes=0}
 function health:ChangeState()self.changes+=1 end
 local root={Anchored=true,IsA=function()return true end}
 local moves=0;local character={FindFirstChildOfClass=function()return health end,FindFirstChild=function()return root end,PivotTo=function()moves+=1 end}
 local p={Character=character,GetAttribute=function(_,k)return attrs[k]end,SetAttribute=function(_,k,v)attrs[k]=v end}
 local stage=luau.load(body,{environment={Enum=rb.Enum,CFrame=rb.CFrame,task={wait=function()
  health.SeatPart=nil;if mode=='late_active'then attrs.LobbyDriveActive=true elseif mode=='late_pending'then attrs.LobbyDrivePending=true end
 end}}})()
 stage(p,{CFrame=rb.CFrame.identity})
 check(moves==(if mode=='ordinary'then 1 else 0),'stage only an idle Hub arrival: '..mode)
 if mode=='active_countdown'or mode=='active_running'or mode=='pending'then
  check(health.Sit==true and health.changes==0 and root.Anchored,'delayed arrival cannot unseat an active/pending Park driver: '..mode)
 end
 if mode~='ordinary'then check(attrs.HubArrivalSerial==nil,'no false arrival event: '..mode)end
end
print('PASS '..n..' delayed Hub staging / Park seating lifecycle checks')
