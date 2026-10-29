local Service={};local started=false
function Service.start()
 if started then return end
 local Players=game:GetService('Players');local Run=game:GetService('RunService');local RS=game:GetService('ReplicatedStorage');local WS=game:GetService('Workspace')
 local Policy=require(RS.Shared.HubLeaderboardPolicy)
 local role=WS:GetAttribute('KDMServerRole');if role~='HUB'and role~='RACE'then return end
 local ctx={isStudio=Run:IsStudio(),universe=game.GameId,place=game.PlaceId,role=role,privateId=game.PrivateServerId,ownerId=game.PrivateServerOwnerId}
 local live=Policy.allowed(ctx)
 if not live and not Run:IsStudio()then return end
 started=true
 local DS=if live then game:GetService('DataStoreService')else nil
 local Schema=require(RS.Shared.KDMProgressionSchema);local schema=Schema.new(require(RS.Shared.KartCatalog))
 local names,nameQueue,nameCount={},{},0
 local memory={};local function store(b)return DS:GetOrderedDataStore(Policy.StoreName,b.scope)end
 local runtime=require(script.Parent.HubLeaderboardRuntime).new(Policy,{
  remove=function(b,uid)
   if not live then if memory[b.id]then memory[b.id][uid]=nil end;return true end
   if DS:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedWrite)<1 then return false end
   store(b):RemoveAsync(tostring(uid));return true
  end,
  upsert=function(b,uid,score)
   if not live then memory[b.id]=memory[b.id]or {};memory[b.id][uid]=score;return true end
   if DS:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedRead)<1 or DS:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedWrite)<1 then return false end
   store(b):UpdateAsync(tostring(uid),function(old)
    if old~=nil and not Policy.integer(old)then error('invalid_rank_index')end
    return if old==nil then score elseif b.ascending then math.min(old,score)else math.max(old,score)
   end);return true
  end,
  read=function(b,limit)
   if not live then local rows={};for uid,score in memory[b.id]or {}do table.insert(rows,{key=tostring(uid),value=score})end;return rows end
   if DS:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetSortedAsync)<1 then return nil end
   return store(b):GetSortedAsync(b.ascending,limit):GetCurrentPage()
  end,
 })
 local profiles,connections,lastQuery={},{},{}
 local function queue(player)
  if player:GetAttribute('KDMAccountQualified')==true then profiles[player.UserId]={due=os.clock()+2,attempt=0}end
 end
 local function bind(p)
  local list={};connections[p]=list
  for _,attr in {'KDMWalletRevision','KDMAccountQualified','KDMRookieParkBestMilliseconds'}do table.insert(list,p:GetAttributeChangedSignal(attr):Connect(function()queue(p)end))end
  queue(p)
 end
 Players.PlayerAdded:Connect(bind)
 Players.PlayerRemoving:Connect(function(p)for _,c in connections[p]or {}do c:Disconnect()end;connections[p]=nil;lastQuery[p]=nil;runtime.own[p.UserId]=nil end)
 for _,p in Players:GetPlayers()do bind(p)end
 local model
 if role=='HUB'then
  local hub=WS:WaitForChild('KDMHub',60)
  if hub then
   local deadline=os.clock()+90;repeat task.wait(.25)until hub:GetAttribute('RookieParkOrigin')and hub:FindFirstChild('HubParkRookieLoopG2')or os.clock()>deadline
   model=require(script.Parent.HubLeaderboardBoardBuilder).build(hub)
  end
 end
 local function named(uid)
  local p=Players:GetPlayerByUserId(uid)
  if p then return p.DisplayName..' (@'..p.Name..')'end
  if names[uid]then return names[uid]end
  if nameCount<512 and not nameQueue[uid]then nameQueue[uid]=true end
  return 'Racer #'..uid
 end
 local function response(id,uid)
  local b=Policy.Boards[id];local c=runtime:request(id,os.clock());if not c then return {status='INVALID_BOARD'}end
  local rows={};local rank
  for i,r in c.rows do table.insert(rows,{rank=i,userId=r.userId,name=named(r.userId),score=r.score});if r.userId==uid then rank=i end end
  return {status=c.status,rows=rows,myScore=runtime.own[uid]and runtime.own[uid][id],myRank=rank,
   updatedAgo=if c.at then math.floor(math.max(0,os.clock()-c.at))else nil,preview=not live,title=b.title}
 end
 if model then
  local remote=Instance.new('RemoteFunction');remote.Name='KDMHubLeaderboardQuery';remote.Parent=RS
  remote.OnServerInvoke=function(p,id)
   if p:GetAttribute('RaceState')~='GARAGE'or p:GetAttribute('LobbyDriveActive')==true or p:GetAttribute('KDMRoutePending')=='RACE_LAUNCH'then return {status='NOT_IN_LOBBY'}end
   if type(id)~='string'or #id>48 or not Policy.Boards[id]then return {status='INVALID_BOARD'}end
   local now=os.clock();if now-(lastQuery[p]or -math.huge)<1 then return {status='RATE_LIMITED'}end;lastQuery[p]=now
   -- Cache only: no account reads, score writes or client-supplied score/user ID.
   return response(id,p.UserId)
  end
 end
 task.spawn(function()
  while started do
   local now=os.clock()
   for uid,job in profiles do if now>=job.due then
    local ok,profile=pcall(function()
     if not live then local p=Players:GetPlayerByUserId(uid);if not p then return nil end
      return {parkTimeTrial={bestMilliseconds=p:GetAttribute('KDMRookieParkBestMilliseconds')},wallet={lifetimeEarned=p:GetAttribute('KDMLifetimeEarned')},records={scoped={}}}
     end
     if DS:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead)<1 then error('budget')end
     local options=Instance.new('DataStoreGetOptions');options.UseCache=false
     return DS:GetDataStore('KDM_PlayerProgress_v1'):GetAsync(Schema.userKey(uid),options)
    end)
    if ok and (not live or profile and schema.validate(profile,Schema.userKey(uid)))then
     if profile and profile.deleted then runtime:remove(uid)else runtime:offer(uid,Policy.project(profile))end;profiles[uid]=nil
    else job.attempt+=1;job.due=now+math.min(60,2^math.min(job.attempt,6));if job.attempt>=6 and not Players:GetPlayerByUserId(uid)then profiles[uid]=nil end end
    break
   end end
   runtime:write(now)
   if model and model.Parent then
    for _,b in model:GetChildren()do if b:IsA('BasePart')and b:FindFirstChild('RankingFace')then
     local id=b:GetAttribute('LeaderboardId');local data=response(id,0);local panel=b.RankingFace.Frame
     for i=1,5 do local r=data.rows[i];local row=panel['Row'..i];row.Racer.Text=if r then r.name else '--';row.Score.Text=if r then Policy.format(Policy.Boards[id],r.score)else '--'end
     panel.Status.Text=if data.status=='POLICY_PENDING'then 'RANKING POLICY PENDING'elseif #data.rows==0 and data.status=='READY'then 'NO VALID RECORDS YET'elseif data.status=='STALE'then 'UPDATE DELAYED - LAST SAVED RANKINGS'elseif data.status=='LOADING'then 'LOADING RANKINGS'else 'TOP 5  /  REFRESH ~60s'
     if not live then panel.Status.Text='STUDIO PREVIEW - NO LIVE DATA'end
    end end
   end
   runtime:read(now)
   local uid=next(nameQueue);if uid then nameQueue[uid]=nil;nameCount+=1;local ok,name=pcall(function()return Players:GetNameFromUserIdAsync(uid)end);if ok then names[uid]=name end end
   task.wait(1)
  end
 end)
 game:BindToClose(function()
  started=false;local untilTime=os.clock()+5
  while next(runtime.pending)and os.clock()<untilTime do runtime:write(os.clock());task.wait(.1)end
 end)
end
return Service
