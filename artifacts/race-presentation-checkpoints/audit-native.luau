-- Read-only deserialize: NEVER serialize Native Terrain through Lune.
local fs,rb,serde=require('@lune/fs'),require('@lune/roblox'),require('@lune/serde')
local base='artifacts/lobby-vfx-audio-integration/KDM_PUBLISHED_PV655_VERIFIED.rbxl'
local candidate='artifacts/race-presentation-checkpoints/KDM_RACE_PRESENTATION_NATIVE_CANDIDATE.rbxl'
local expected={}
local function sources(dir)
 for _,name in fs.readDir(dir) do
  local file=dir..'/'..name
  if fs.isDir(file) then sources(file)
  elseif file:sub(-5)=='.luau' then
   local branch=file:match('src/([^/]+)/');local root=if branch=='shared' then 'ReplicatedStorage.Shared' elseif branch=='server' then 'ServerScriptService.Server' else 'StarterPlayer.StarterPlayerScripts.Client'
   local scriptName=name:sub(1,-6)
   local path=if scriptName=='init.server' or scriptName=='init.client' then root else root..'.'..scriptName
   expected[path]=fs.readFile(file):gsub('\r\n','\n')
  end
 end
end
sources('src')
local added={BoostFlameEnvelope=true,CheckpointGuidanceController=true,RacePresentationState=true,RaceStartAudio=true}
local function inspect(file,check)
 local m=rb.deserializePlace(fs.readFile(file));local rows={};local count=0
 if check then
  for path,source in expected do
   local o=m;for name in path:gmatch('[^.]+') do o=assert(o:FindFirstChild(name),path) end
   assert(o.Source:gsub('\r\n','\n')==source,'source mismatch '..path);count+=1
  end
  local scripts=0;for _,o in m:GetDescendants() do if o:IsA('LuaSourceContainer') then scripts+=1 end end
  assert(scripts==count,'unexpected test/imported script persisted '..scripts..'/'..count)
 end
 local function walk(o,path)
  if o:IsA('Camera') or o.Name=='KDMRacePresentationResources' then return end
  if o:IsA('LuaSourceContainer') and added[o.Name] then return end
  local e={class=o.ClassName,name=o.Name,attributes=o:GetAttributes()}
  if o:IsA('BasePart') then for _,k in {'Size','CFrame','Color','Material','Anchored','CanCollide','CanTouch','CanQuery','Transparency'} do e[k]=tostring(o[k]) end end
  if o:IsA('Model') then e.primaryPart=if o.PrimaryPart then o.PrimaryPart:GetFullName() else '' end
  for _,k in {'MeshId','TextureID','TextureId','SoundId','AnimationId','Image','Texture','ColorMap','NormalMap','MetalnessMap','RoughnessMap'} do local ok,v=pcall(function()return o[k]end);if ok then e[k]=tostring(v)end end
  table.insert(rows,path..'|'..serde.encode('json',e))
  for _,c in o:GetChildren() do walk(c,path..'/'..c.Name) end
 end
 for _,name in {'Workspace','ReplicatedStorage','ServerScriptService','ServerStorage','StarterGui','StarterPack','StarterPlayer','Lighting','MaterialService'} do
  local o=m:FindFirstChild(name);if o then walk(o,name)end
 end
 table.sort(rows);return rows,count
end
local a=inspect(base,false);local b,n=inspect(candidate,true)
local set={};for _,v in a do set[v]=true end;for _,v in b do if not set[v] then print('ADDED/CHANGED '..v) end end; local back={};for _,v in b do back[v]=true end;for _,v in a do if not back[v] then print('MISSING/CHANGED '..v) end end;assert(#a==#b,'world count '..#a..'/'..#b)
for i,v in a do assert(b[i]==v,'world change '..v..' / '..tostring(b[i]))end
fs.writeFile('artifacts/race-presentation-checkpoints/native-semantic.json',serde.encode('json',{status='PASS',sources=n,preservedEntries=#a,newSourceModules=4,cameraExcluded=true}))
print('PASS: '..n..' exact sources, '..#a..' preserved Native world/asset entries')
