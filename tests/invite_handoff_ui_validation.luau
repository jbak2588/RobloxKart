-- Execute production send/response handlers with interleaved background snapshots.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('src/client/MatchRoomUiController.luau')
local a=assert(source:find('\tlocal function send(action, ...)',1,true))
local b=assert(source:find('\n\tcreateView=',a,true))
local send=source:sub(a,b-1)
a=assert(source:find(' local remoteConnection = remote.OnClientEvent:Connect',1,true))
b=assert(source:find(' local raceConnection =',a,true))
local receive=source:sub(a,b-1)
local count=0
local function check(v,label)assert(v,label);count+=1 end
local listener,delayed,calls,renders=nil,{}, {},0
local remote={OnClientEvent={Connect=function(_,callback)listener=callback;return{}end},
 FireServer=function(_,...)table.insert(calls,table.pack(...))end}
local player={UserId=123,GetAttribute=function()return 'GARAGE'end}
local api=luau.load([[
local invitation={roomId='invited-room'},snapshot
local pendingAction,errorMessage,pendingSerial=nil,nil,0
local render=function()renderProbe()end
]]..send..receive..[[
return {accept=function()send('AcceptInvite','Driver01','Kart05')end,
 state=function()return pendingAction,invitation,errorMessage end}
]],{environment={remote=remote,player=player,renderProbe=function()renders+=1 end,
 task={delay=function(_,callback)table.insert(delayed,callback)end}}})()
api.accept();check(#calls==1 and calls[1][1]=='AcceptInvite','one Join sends acceptance')
listener('Snapshot',{visible=false})
check(api.state()=='AcceptInvite','empty background snapshot cannot cancel handoff')
listener('Invite',{roomId='duplicate'})
local pending,invite=api.state()
check(pending=='AcceptInvite'and invite.roomId=='invited-room','duplicate invite does not replace accepted invite')
api.accept();check(#calls==1,'pending handoff rejects second Join')
listener('Snapshot',{visible=true,room={roomId='invited-room'}})
pending,invite=api.state();check(pending==nil and invite==nil,'actual room admission completes acceptance')
delayed[1]();check(api.state()==nil,'old timeout cannot revive admitted invitation')
listener('Invite',{roomId='retry'});api.accept()
listener('Error','RACE ENTRY UNAVAILABLE - PLEASE TRY AGAIN')
pending,invite=api.state();check(pending==nil and invite.roomId=='retry','entry failure permits retry without losing invite')
check(source:find('or pendingAction ~= nil',1,true)~=nil,'progress stays visible after invitation is accepted')
print('PASS '..count..' invitation handoff UI ordering checks')
