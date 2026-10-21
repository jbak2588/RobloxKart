-- Called once by Server initialization, never as a live-server cleanup command.
local Shared=game:GetService('ReplicatedStorage'):WaitForChild('Shared')
local Policy=require(Shared:WaitForChild('HubParkRuntimePolicy'))
local Startup={}
function Startup.enabled()
 return Policy.enabled(workspace,game:GetService('RunService'):IsStudio(),game.GameId,game.PlaceId)
end
function Startup.prepare()
 if not Startup.enabled() then return end
 local prototype,hub=workspace:FindFirstChild('Prototype'),workspace:FindFirstChild('KDMHub')
 local candidates={}
 for _,row in {{prototype,'TestTrack'},{hub,'LobbyFrontTestDriveZone'},{hub,'HubParkRookieLoopG2'}}do
  if row[1]then for _,v in row[1]:GetChildren()do if v.Name==row[2]then table.insert(candidates,v)end end end
 end
 -- Never move a running world's cars or occupants. A saved prototype may contain
 -- empty models, but an active seat/kart means this is not a clean startup.
 for _,v in workspace:GetDescendants()do
  assert(not(v:IsA('Seat')and v.Occupant),'G2 requires fresh startup, found occupied seat')
  assert(not(v:IsA('Model')and v:GetAttribute('LobbyKart')),'G2 requires fresh startup, found live lobby kart')
 end
 if #candidates==0 then return end
 local archive=Instance.new('Folder');archive.Name='HubParkStartupArchive'
 archive.Parent=game:GetService('ServerStorage')
 for _,v in candidates do v:SetAttribute('G2ArchivedFrom',v:GetFullName());v.Parent=archive end
end
function Startup.snapshot(connectedZone)
 local out={studio=game:GetService('RunService'):IsStudio(),role=workspace:GetAttribute('KDMServerRole'),
  flag=workspace:GetAttribute('HubParkV1Enabled')==true,enabled=Startup.enabled(),gameId=game.GameId,
  placeId=game.PlaceId,connectedZone=if connectedZone then connectedZone:GetFullName() else 'NONE',tracks={},karts={}}
 for _,v in workspace:GetDescendants()do
  if v.Name=='TestTrack'or v.Name=='LobbyFrontTestDriveZone'or v.Name=='HubParkRookieLoopG2'then
   local colliders=0;for _,p in v:GetDescendants()do if p:IsA('BasePart')and p.CanCollide then colliders+=1 end end
   table.insert(out.tracks,{path=v:GetFullName(),colliders=colliders,driveIntegrated=v==connectedZone})
  end
  if v:IsA('Model')and(v:GetAttribute('LobbyKart')or v:GetAttribute('PrototypeKart'))then
   local b=v.PrimaryPart or v:FindFirstChild('Chassis')
   if b then
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={v}
    local hit=workspace:Raycast(b.Position,Vector3.new(0,-20,0),params)
    table.insert(out.karts,{path=v:GetFullName(),position=tostring(b.Position),below=if hit then hit.Instance:GetFullName()else 'NONE'})
   end
  end
 end
 print('[G2Startup] '..game:GetService('HttpService'):JSONEncode(out));return out
end
return Startup
