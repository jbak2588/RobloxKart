-- Execute the production Return Lobby activation handler with delayed replication.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local nodes=require('./helpers/practice_ui_nodes')
local source=fs.readFile('src/client/LobbyTestDriveController.luau')
local start=assert(source:find(' button.Activated:Connect(function()',1,true))
local finish=assert(source:find(' PromptService.PromptTriggered:Connect',start,true))
local handler=source:sub(start,finish-1)
local n=0;local function check(v,l)assert(v,l);n+=1 end
for _,mode in {'success','rejected','not_returned','replication_delay','respawn','new_request','dead','timeout','inactive','pending'}do
 local player=nodes.object('Player');player:SetAttribute('LobbyDriveActive',mode~='inactive')
 local h={Health=100,SeatPart={}}
 local character={FindFirstChildOfClass=function()return h end};player.Character=character
 local button=nodes.object('TextButton');local requests,threads={},{}
 local shown,now=0,0
 local control=luau.load('local token=0;local pending=initialPending\n'..
  'local function request(action,callback) token+=1;table.insert(requests,{action=action,callback=callback})end\n'..handler..
  'return {invalidate=function()token+=1 end}',{environment={
   initialPending=if mode=='pending'then {}else nil,button=button,player=player,requests=requests,
   postDrive={show=function()shown+=1 end},os={clock=function()return now end},
   Run={RenderStepped={Wait=function()coroutine.yield()end}},
   task={spawn=function(fn)local thread=coroutine.create(fn);table.insert(threads,thread);assert(coroutine.resume(thread))end},
  }})()
 button.Activated:Fire()
 if mode=='pending'then check(#requests==0 and shown==0,'pending stop ignores extra Return tap');continue end
 if mode=='inactive'then check(requests[1].action=='Drive'and not requests[1].callback and shown==0,'entry does not schedule return popup');continue end
 check(requests[1].action=='Stop'and shown==0,'Return requests server Stop before popup')
 if mode~='replication_delay'and mode~='timeout'then player:SetAttribute('LobbyDriveActive',false);h.SeatPart=nil end
 requests[1].callback(mode~='rejected',mode~='not_returned')
 if mode=='replication_delay'then
  check(shown==0,'ACK alone does not show while replicated driving/seat still active')
  player:SetAttribute('LobbyDriveActive',false);h.SeatPart=nil
 end
 if mode=='respawn'or mode=='new_request'or mode=='dead'then
  -- Exercise cancellation while waiting for replicated return state.
  -- The immediate successful cases above have already completed; restart a delayed request.
  shown=0;player:SetAttribute('LobbyDriveActive',true);h.SeatPart={};button.Activated:Fire()
  requests[#requests].callback(true,true)
  if mode=='respawn'then player.Character={}elseif mode=='new_request'then control.invalidate()else h.Health=0 end
 end
 now=if mode=='timeout'then 3 else .1
 for _,thread in threads do if coroutine.status(thread)~='dead'then check(coroutine.resume(thread),'return waiter resumes safely')end end
 local expected=if mode=='success'or mode=='replication_delay'then 1 else 0
 check(shown==expected,'popup only follows confirmed, settled same-character return: '..mode)
end
check(source:find("end,function() Garage.open('RACE') end)",1,true)~=nil,'Play now uses the existing Race screen entry')
print('PASS: '..n..' production Return Lobby / ACK / delayed replication / cancellation / Race route checks')
