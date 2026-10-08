local selectedTrack=require("@lune/process").args[1] or "Track01Race"
local titleModules=require("./helpers/lobby_title_modules")
-- Actual Directory, Coordinator and BotController under deterministic service/transport mocks.
-- Native physics/effects are independently covered by race_item_validation and Studio driving.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local checks, clock = 0, 1000
local function check(value, message) assert(value, message); checks += 1 end
local function signal()
	local listeners = {}
	return {
		Connect=function(_, callback)
			local connection={connected=true}
			function connection:Disconnect() self.connected=false end
			table.insert(listeners,{connection,callback});return connection
		end,
		Fire=function(_, ...)
			for _, pair in table.clone(listeners) do if pair[1].connected then pair[2](...) end end
		end,
		count=function()
			local count=0;for _, pair in listeners do if pair[1].connected then count+=1 end end;return count
		end,
	}
end
local function object(class, name)
	local self={ClassName=class,Name=name or class,children={},attrs={},signals={},CFrame=rb.CFrame.identity}
	function self:GetChildren()
		local children={};for _, child in self.children do if child.Parent==self then table.insert(children,child) end end;return children
	end
	function self:FindFirstChild(name)
		for _, child in self:GetChildren() do if child.Name==name then return child end end
	end
	function self:WaitForChild(name) return self:FindFirstChild(name) or {Name=name} end
	function self:FindFirstChildOfClass(class)
		for _, child in self:GetChildren() do if child.ClassName==class then return child end end
	end
	function self:SetAttribute(name,value)
		local previous=self.attrs[name];self.attrs[name]=value
		if previous~=value and self.signals[name] then self.signals[name]:Fire() end
	end
	function self:GetAttribute(name) return self.attrs[name] end
	function self:GetAttributeChangedSignal(name)
		self.signals[name]=self.signals[name] or signal();return self.signals[name]
	end
	function self:GetPropertyChangedSignal(name)
		self.signals[name]=self.signals[name] or signal();return self.signals[name]
	end
	function self:Destroy()
		for _, child in self:GetChildren() do child:Destroy() end
		self.Parent=nil
	end
	function self:PivotTo(frame) self.CFrame=frame end
	function self:IsA(class) return class==self.ClassName end
	local parentValue
	return setmetatable(self, {
		__index=function(_, key)
			if key=="Parent" then return parentValue end
			return self:FindFirstChild(key)
		end,
		__newindex=function(_, key, value)
			if key~="Parent" then rawset(self,key,value);return end
			if parentValue then local index=table.find(parentValue.children,self);if index then table.remove(parentValue.children,index) end end
			parentValue=value
			if value then table.insert(value.children,self) end
		end,
	})
end
local function parent(child, container)
	child.Parent=container;return child
end
local function map()
	local self={values={}}
	function self:SetAsync(key,value) self.values[key]=value end
	function self:GetAsync(key) return self.values[key] end
	function self:UpdateAsync(key, transform)
		local result=transform(self.values[key]);if result then self.values[key]=result end;return result
	end
	function self:RemoveAsync(key) self.values[key]=nil end
	function self:GetRangeAsync()
		local rows={};for key,value in self.values do table.insert(rows,{key=key,value=value}) end;return rows
	end
	return self
end
local enum={SortDirection={Ascending=1,Descending=2},HumanoidRigType={R15="R15"}}
local roomMap,presenceMap,inviteMap=map(),map(),map()
local Directory=luau.load(fs.readFile("src/server/ActiveMatchDirectory.luau"),{environment=titleModules.environment(enum)})()
local directory=Directory.new(roomMap,function() return clock end)
local descriptor={botId="Bot01",name="KDM Rookie [BOT]",kartId="Kart01",gridSlot=4}
local function member(id) return {userId=id,name="Human"..id,kartId="Kart01",driverId="Driver01"} end
local function room(id, humans)
	directory:createPersistent({id=id,matchId=id.."-match",trackId=selectedTrack,hostUserId=1,hostName="Human1",maxPlayers=4},"reserved-code","private-room")
	for index=1,humans do
		assert(directory:stage(id,member(index),"token-"..index))
		assert(directory:confirmArrival(id,index,"token-"..index,"race-job"))
	end
	return directory:get(id)
end
for humans=1,4 do
 for _,withBot in {false,true} do
  local id='matrix-'..humans..'-'..tostring(withBot)
  room(id,humans)
  if withBot then
   check((directory:addBot(id,descriptor)~=nil)==(humans<4),'Bot capacity matrix '..id)
  end
  check(directory:get(id).currentRacers==humans+(if withBot and humans<4 then 1 else 0),'total occupancy '..id)
  if humans==4 then check(not directory:stage(id,member(5),'fifth'),'four Humans reject fifth') end
 end
end
room("directory",1)
check(directory:get("directory").currentRacers==1,"one Human occupancy")
check(directory:addBot("directory",descriptor).currentRacers==2,"Bot occupies real slot")
check(directory:display(directory:get("directory")).count==2,"Hub display includes Bot")
check(not directory:addBot("directory",descriptor),"duplicate Bot rejected")
check(not directory:addBot("directory",{botId="Other",name=descriptor.name,kartId="Kart01",gridSlot=4}),"unknown descriptor rejected")
local old=directory:get("directory")
directory:update("directory",function(draft) draft.stagedBots[1].name="invalid";return nil end)
check(old.stagedBots[1].name==descriptor.name,"failed mutation cannot corrupt previous Bot descriptor")
check(directory:removeBot("directory","Bot01").currentRacers==1,"remove releases occupancy")
check(not directory:removeBot("directory","Bot01"),"repeated remove is clean")
check(directory:addBot("directory",descriptor).currentRacers==2,"remove/re-add")
check(directory:startRound("directory",1,2).currentRacers==2,"start locks total count")
local record=directory:get("directory")
check(#record.currentRoundMembers==1 and #record.currentRoundBots==1 and #record.stagedBots==0,"Human roster remains Human-only")
check(not directory:addBot("directory",descriptor) and not directory:removeBot("directory","Bot01"),"locked round rejects add/remove")
directory:raceState("directory","directory-match","ROUND_COMPLETE",2)
check(directory:nextStaging("directory",{member(1)}).currentRacers==2,"rematch retains Bot")
check(#directory:get("directory").stagedBots==1,"Bot transferred back to staging")
directory:removeStaged("directory",1)
check(not directory:get("directory"),"last Human closes Bot room")
room("full",3);directory:addBot("full",descriptor)
check(directory:get("full").currentRacers==4 and directory:display(directory:get("full")).count==4,"3H+Bot = 4/4")
check(not directory:stage("full",member(4),"token-4"),"fifth racer rejected")
check(directory:queue("full",member(4))~=nil,"full Bot room uses existing queue")
directory:removeBot("full","Bot01")
check(directory:stage("full",member(5),"token-5")~=nil,"removed Bot frees Human slot")
room("migration",2);directory:addBot("migration",descriptor);directory:removeStaged("migration",1)
check(directory:get("migration").hostUserId==2 and directory:get("migration").currentRacers==2,"Host transfers only to Human")
directory:startRound("migration",2,2);directory:leaveMember("migration",2)
check(not directory:get("migration"),"last Human racing departure closes room")
room("legacy",1);record=directory:get("legacy");record.stagedBots=nil;record.currentRoundBots=nil
check(directory:addBot("legacy",descriptor).currentRacers==2,"nil legacy Bot fields supported")
room("no-rematch",1);directory:addBot("no-rematch",descriptor);directory:startRound("no-rematch",1,2)
directory:raceState("no-rematch","no-rematch-match","ROUND_COMPLETE",0)
check(not directory:nextStaging("no-rematch",{}),"no Bot-only rematch staging")
directory:closeIfIdle("no-rematch","no-rematch-match")
check(not directory:get("no-rematch"),"empty room removed")

local players=object("Players")
players.PlayerAdded=signal()
function players:GetPlayers() return self:GetChildren() end
function players:GetPlayerByUserId(id) for _,p in self:GetPlayers() do if p.UserId==id then return p end end end
function players:CreateHumanoidModelFromDescription(_,rig)
	assert(rig=="R15")
	local npc=object("Model");local h=parent(object("Humanoid","Humanoid"),npc);h.Health=100;return npc
end
local human=parent(object("Player","Human1"),players);human.UserId=1;human.DisplayName="Human1"
local other=parent(object("Player","Human2"),players);other.UserId=2;other.DisplayName="Human2"
local replicated=object("ReplicatedStorage")
parent(object("Folder","Shared"),replicated)
local remote=parent(object("RemoteEvent","GarageControl"),replicated)
remote.OnServerEvent=signal();remote.messages={}
function remote:FireClient(p,action,data) table.insert(self.messages,{player=p,action=action,data=data}) end
local workspace=object("Workspace")
workspace:SetAttribute("KDMServerRole","RACE")
local prototype=parent(object("Folder","Prototype"),workspace);workspace.Prototype=prototype
local ground=parent(object("BasePart","Baseplate"),workspace);ground.Position=rb.Vector3.zero;ground.Size=rb.Vector3.new(100,2,100)
local run={Heartbeat=signal()}
function run:IsStudio() return self.studio==true end
local config=luau.load(fs.readFile("src/shared/RaceConfig.luau"))()
local catalog=luau.load(fs.readFile("src/shared/TrackCatalog.luau"),{environment={CFrame=rb.CFrame}})()
local contexts={}
local session={phase="WAITING",maxPlayers=4,participants={[human]={}},failAdmission=false}
function session:count() local count=0;for _ in self.participants do count+=1 end;return count end
function session:humanCount() local count=0;for p in self.participants do if not p:GetAttribute("IsBot") then count+=1 end end;return count end
function session:contains(p) return self.participants[p]~=nil end
function session:addServerBot(state,context,source)
	if self.failAdmission then return false end
	check(source=="PRODUCTION_ROOM" and context.kart.Parent,"explicit production admission")
	self.participants[state]={context=context};state:SetAttribute("RaceItemsReady",true);return true
end
function session:removeServerBot(state) self.participants[state]=nil end
local world={}
local ownershipUnavailable, ownershipWriteRejected = false, false
function world.createBotKartContext(state,npc,frame,source,roomId)
	check(source=="PRODUCTION_ROOM" and roomId=="production" or source=="STUDIO_TEST" and roomId==nil,"explicit creation source and room")
	local kart=parent(object("Model","KDM_Rookie_Bot"),prototype)
	local seat=object("Seat")
	local chassis={CFrame=frame,AssemblyLinearVelocity=rb.Vector3.zero,auto=false,writes=0}
	chassis.AssemblyRootPart=chassis;seat.AssemblyRootPart=chassis
	function chassis:CanSetNetworkOwnership() return not ownershipUnavailable, "test anchored assembly" end
	function chassis:GetNetworkOwner() return self.owner end
	function chassis:GetNetworkOwnershipAuto() return self.auto end
	function chassis:SetNetworkOwner(owner)
		self.writes+=1
		if not ownershipWriteRejected then self.owner=owner;self.auto=false end
	end
	function seat:Sit(h)
		self.Occupant=h;h.SeatPart=self;chassis.auto=true
		self:GetPropertyChangedSignal("Occupant"):Fire()
	end
	local context={kart=kart,chassis=chassis,seat=seat}
	function context:setSpawnCFrame(cf) self.spawnCFrame=cf end
	contexts[state]=context
	return context
end
function world.releaseBotKartContext(state)
	local context=contexts[state];if context then context.kart:Destroy();contexts[state]=nil end
end
function world.getKartContext(state) return contexts[state] end
local Social=luau.load(fs.readFile("src/server/RoomSocialDirectory.luau"),{environment=titleModules.environment(enum)})()
local modules={ActiveMatchDirectory=Directory,RoomSocialDirectory=Social,PrototypeWorld=world,
	KartConfig=require("./helpers/gameplay_config")("src/shared/KartConfig.luau"),
	RaceSession={active=function() return session end},RaceConfig=config,TrackCatalog=catalog,
	RaceController={isRosterLocked=function() return session.locked==true end},
	RaceBotSteering=luau.load(fs.readFile("src/server/RaceBotSteering.luau"),{environment={Vector3=rb.Vector3}})(),
	TrackGeometry=luau.load(fs.readFile("src/shared/TrackGeometry.luau"),{environment={Vector2=rb.Vector2,Vector3=rb.Vector3,CFrame=rb.CFrame}})()}
local services={Players=players,Workspace=workspace,ReplicatedStorage=replicated,RunService=run,
	MemoryStoreService={GetSortedMap=function(_,name) return if name==Directory.MAP_NAME then roomMap else presenceMap end,GetHashMap=function() return inviteMap end}}
local environment={Vector3=rb.Vector3,Instance={new=object},CFrame=rb.CFrame,Color3=rb.Color3,Enum=enum,time=function() return clock end,
	game={JobId="race-job",PrivateServerId="private-room",GetService=function(_,name) return assert(services[name],name) end},
	script={Parent={WaitForChild=function(_,name) return {Name=name} end}},
	require=function(module) return assert(modules[module.Name],module.Name) end,
	task={spawn=function() end,defer=function(callback) callback() end},warn=function() end}
modules.RaceBotController=luau.load(fs.readFile("src/server/RaceBotController.luau"),{environment=environment})()
local Bot=modules.RaceBotController
local Coordinator=luau.load(fs.readFile("src/server/RaceRoomCoordinator.luau"),{environment=environment})()
room("production",1)
local coordinator=Coordinator.start({roomId="production",matchId="production-match",trackId=selectedTrack,participantUserIds={1}})
check(not replicated:FindFirstChild("KDMBotRacers"),"no action means no Bot")
local function action(p,action,id,extra)
	clock+=1;remote.OnServerEvent:Fire(p,action,id or "Bot01",extra)
	return remote.messages[#remote.messages].data.accepted
end
check(not action(other,"AddBot"),"non-host rejected")
check(not action(human,"AddBot","Unknown"),"unknown botId rejected")
check(not action(human,"AddBot","Bot01",{}),"extra client config rejected")
workspace:SetAttribute("KDMServerRole","HUB")
check(not action(human,"AddBot"),"HUB role rejects Add")
workspace:SetAttribute("KDMServerRole","RACE")
room("production",4)
check(not action(human,"AddBot"),"authoritative full room rejects Add")
room("production",1)
directory:get("production").state="STARTING"
check(not action(human,"AddBot"),"directory STARTING rejects Add")
directory:get("production").state="WAITING"
check(action(human,"AddBot"),"Host explicit Add")
remote.OnServerEvent:Fire(human,"RemoveBot","Bot01")
check(remote.messages[#remote.messages].data.accepted==false and Bot.hasProductionBot("Bot01"),"rapid actions are throttled without changing occupancy")
check(session:count()==2 and directory:get("production").currentRacers==2,"local and authoritative count=2")
local bot=Bot.getProductionBot("Bot01")
local firstSteeringState=bot.steeringState
check(firstSteeringState and firstSteeringState.previous==nil and firstSteeringState.position==nil,"one fresh tracker at creation")
check(bot.context.chassis.owner==nil and not bot.context.chassis.auto,"joined NPC assembly is manual server-owned")
check(bot.context.chassis.writes==1,"initial seating finalization avoids duplicate writes")
bot.context.seat:Sit(bot.humanoid)
check(not bot.context.chassis.auto and bot.context.chassis.writes==2,"reseating finalizes the changed assembly once")
bot.context.seat:GetPropertyChangedSignal("Occupant"):Fire()
check(bot.context.chassis.writes==2,"unchanged Occupant notification does not hammer ownership")
local oldSeat=bot.context.seat
check(bot.state:GetAttribute("DisplayName")=="KDM Rookie [BOT]" and bot.state:GetAttribute("GridSlot")==4,"distinct NPC + final grid slot")
check(bot.context.chassis.CFrame==rb.CFrame.new(0,2.75,0)*catalog.Entries[selectedTrack].GridSlots[4],"actual grid + production groundTop")
bot.state:SetAttribute("RaceState","RACING")
check(bot.context.botControl().targetSpeed==70 and not bot.context.botControl().driftRequested,"same fixed input-only steering")
local firstFraction=firstSteeringState.previous
for _=1,20 do bot.context.botControl() end
check(bot.steeringState==firstSteeringState and firstSteeringState.previous==firstFraction,"control commands reuse one tracker")
local originalFrame=bot.context.chassis.CFrame
for _=1,2 do
	firstSteeringState.cornerCoastActive=true
	Bot.setProductionSpawn(originalFrame)
	check(bot.steeringState==firstSteeringState and firstSteeringState.previous==nil and firstSteeringState.position==nil,"next-round spawn resets existing tracker")
	check(not firstSteeringState.cornerCoastActive,"spawn resets corner coast hysteresis")
	check(bot.context.spawnCFrame==originalFrame and bot.npc.Parent==prototype,"reset preserves NPC and assigned spawn")
	bot.context.botControl()
	check(firstSteeringState.previous~=nil,"fresh acquisition after round reset")
end
local baseCourse=firstSteeringState.course
local finishPose=modules.TrackGeometry.getSampleAtFraction(baseCourse.Samples,.75)
bot.context.chassis.CFrame=rb.CFrame.new(finishPose)
modules.RaceBotSteering.reset(firstSteeringState);bot.context.botControl()
check(firstSteeringState.previous~=nil,"old round established finish-area pursuit")
Bot.setProductionSpawn(originalFrame)
for _,phase in {"FINISHED","WAITING","COUNTDOWN"}do
	bot.state:SetAttribute("RaceState",phase);bot.context.botControl()
	check(firstSteeringState.previous==nil and firstSteeringState.position==nil,"locked-phase poll cannot reacquire stale finish pose "..phase)
end
bot.context.chassis.CFrame=originalFrame;bot.state:SetAttribute("RaceState","RACING")
local firstRoundCommand=bot.context.botControl()
check(not firstRoundCommand.heldPrevious and firstSteeringState.previous~=nil,"first RACING frame freshly acquires teleported grid")
bot.state:SetAttribute("RaceState","WAITING")
check(bot.state:GetAttribute("RaceItemsReady")==true,"Bot auto-ready")
local snapshot
for index=#remote.messages,1,-1 do
	if remote.messages[index].action=="RoomSnapshot" then snapshot=remote.messages[index].data;break end
end
check(#snapshot.activeBots==1 and #snapshot.available==0 and snapshot.count==2,"Bot snapshot separate from Humans")
check(not action(human,"AddBot"),"duplicate Add rejected")
session.phase="RACING"
check(not action(human,"RemoveBot") and not action(human,"AddBot"),"RACING rejects add/remove")
session.phase="WAITING";session.locked=true
check(not action(human,"RemoveBot"),"locked roster rejects removal")
session.locked=false
check(action(human,"RemoveBot"),"Host Remove")
check(session:count()==1 and not replicated:FindFirstChild("KDMBotRacers") and not Bot.hasProductionBot("Bot01"),"full local cleanup")
check(oldSeat.signals.Occupant.count()==0,"removed Bot ownership listener disconnected")
check(not action(human,"RemoveBot"),"Remove twice remains clean")
check(action(human,"AddBot"),"Add Remove Add succeeds")
check(Bot.getProductionBot("Bot01").steeringState~=firstSteeringState and Bot.getProductionBot("Bot01").steeringState.previous==nil,"remove/re-add never inherits tracker")
check(#replicated.KDMBotRacers:GetChildren()==1,"one replicated entry")
check(run.Heartbeat.count()==1,"one bot connection")
action(human,"RemoveBot")
session.failAdmission=true
check(not action(human,"AddBot"),"failed session admission rejects creation")
check(directory:get("production").currentRacers==1 and #directory:get("production").stagedBots==0,"reservation rolled back")
check(not Bot.hasProductionBot("Bot01") and not replicated:FindFirstChild("KDMBotRacers") and run.Heartbeat.count()==0,"failed creation leaves zero local artifacts")
session.failAdmission=false
ownershipUnavailable=true
check(not action(human,"AddBot"),"unavailable final ownership rejects Bot startup")
check(not Bot.hasProductionBot("Bot01") and run.Heartbeat.count()==0,"ownership availability failure cleans lifecycle")
ownershipUnavailable=false;ownershipWriteRejected=true
check(not action(human,"AddBot"),"failed ownership postcondition rejects Bot startup")
check(not Bot.hasProductionBot("Bot01") and not replicated:FindFirstChild("KDMBotRacers"),"ownership verification failure cleans NPC and state")
ownershipWriteRejected=false
local oldFactory=players.CreateHumanoidModelFromDescription
players.CreateHumanoidModelFromDescription=function() error("NPC source unavailable") end
check(not action(human,"AddBot"),"NPC creation failure rejected")
check(#directory:get("production").stagedBots==0 and not replicated:FindFirstChild("KDMBotRacers"),"NPC creation failure rolls back authority and Folder")
players.CreateHumanoidModelFromDescription=oldFactory
action(human,"AddBot")
bot=Bot.getProductionBot("Bot01")
session.participants[human]=nil
coordinator.onRoomLeave(1)
check(not directory:get("production") and not Bot.hasProductionBot("Bot01") and run.Heartbeat.count()==0,"last Human removes room, Bot and connections")
check(remote.OnServerEvent.count()==0,"coordinator disconnected after close")
check(not replicated:FindFirstChild("KDMBotRacers"),"no orphan Folder")
local Rows=luau.load(fs.readFile("src/client/RaceRoomRacerRows.luau"))()
local rows=Rows.collect({activeBots={},botCandidates={{botId="Bot01",name=descriptor.name,available=true}},available={{userId=8,name="Human8"}}},true,true)
check(rows[1].botAction=="AddBot" and rows[1].userId==nil and rows[2].userId==8,"Bot action is never Human Invite")
check(Rows.layout(1,2,true).height==44 and Rows.layout(2,2,true).y>=96,"Bot touch target and nonoverlap")
rows=Rows.collect({activeBots={descriptor}},false,true)
check(rows[1].botAction==nil and rows[1].status=="ACTIVE","non-host inactive Bot label")
rows=Rows.collect({activeBots={descriptor}},true,false)
check(rows[1].botAction==nil,"racing Bot cannot Remove")
check(Rows.layout(1,2,false).panelHeight==108,"racing panel geometry unchanged")
-- The shared creation factory must provide fresh state after a harness restart.
local fixtureKart=parent(object("Model","Kart"),prototype)
fixtureKart:SetAttribute("RaceStartCFrame",rb.CFrame.new(0,3,0))
run.studio=true;workspace:SetAttribute("KDMEnableRaceBot",true)
local harnessStates={}
local originalNew=modules.RaceBotSteering.new
modules.RaceBotSteering.new=function(...)
	local state=originalNew(...);table.insert(harnessStates,state);return state
end
for iteration=1,2 do
	check(Bot.startTestHarness(),"controlled Studio harness start")
	local identity=replicated.KDMBotRacers:FindFirstChild("Bot01")
	local tracker=harnessStates[iteration]
	check(tracker.previous==nil,"harness starts fresh")
	identity:SetAttribute("RaceState","RACING")
	contexts[identity].botControl();check(tracker.previous~=nil,"harness tracker acquires")
	Bot.stop()
	check(not replicated:FindFirstChild("KDMBotRacers") and run.Heartbeat.count()==0,"harness stop fully releases connections and identity")
end
check(harnessStates[1]~=harnessStates[2],"harness restart cannot leak route state")
modules.RaceBotSteering.new=originalNew
workspace:SetAttribute("KDMEnableRaceBot",false);run.studio=false;fixtureKart:Destroy()
local normalizeFreeze=require("./helpers/p2a_bot_controller_freeze")
local process=require("@lune/process")
local checkpoint=process.exec("git",{"show","c815d2fd0ef174e20631a9f034f43c3d7f75c9cc:src/server/RaceBotController.luau"})
local source=fs.readFile("src/server/RaceBotController.luau")
check(checkpoint.ok and normalizeFreeze(source)==checkpoint.stdout:gsub("\r\n","\n"),"only exact approved integration edits excluded from historical freeze")
for _,pair in {{'TrackCatalog.botAllowed(options.trackId)','true'},
 {'root:SetNetworkOwner(nil)','root:SetNetworkOwner(player)'},
 {'state:SetAttribute("SelectedKartId", "Kart01")','state:SetAttribute("SelectedKartId", "Kart02")'},
 {'Steering.reset(productionRecord.steeringState)','Steering.reset(wrongState)'}}do
	local start=assert(source:find(pair[1],1,true));local mutated=source:sub(1,start-1)..pair[2]..source:sub(start+#pair[1])
	check(normalizeFreeze(mutated)~=normalizeFreeze(source),"historical freeze detects unauthorized edit "..pair[1])
end
print("PASS: "..checks.." production Bot room authority, security, reusable NPC and lifecycle checks")
