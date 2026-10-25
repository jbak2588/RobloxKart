-- Actual production builders; freeze driving geometry against the task baseline.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local harness=fs.readFile('tests/track_environment_validation.luau')
local prefix=harness:sub(1,assert(harness:find('local prototype=object("Folder")',1,true))-1)
luau.load(prefix..[====[
local oldSource=require('@lune/process').exec('git',{'show','e383a03:src/server/TrackBuilder.luau'})
assert(oldSource.ok)
local before=luau.load(oldSource.stdout,{environment=env})()
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment=env})()
local function physicalSignature(world)
 local rows={}
 local function visit(node,path)
  if node:IsA('BasePart')then table.insert(rows,path..tostring(node.CFrame)..tostring(node.Size)..tostring(node.CanCollide))end
  for _,child in node:GetChildren()do visit(child,path..'/'..child.Name)end
 end
 for _,name in {'Road','Markings','Kerbs','Barriers','BarrierTriggers','RaceTriggers','DirectionMarkers'}do
  local f=world:FindFirstChild(name);if f then visit(f,name)end
 end
 table.sort(rows);return table.concat(rows,'\n')
end
local function descendants(root)
 local all={};local function visit(n)for _,c in n:GetChildren()do table.insert(all,c);visit(c)end end
 visit(root);return all
end
for id,track in catalog.Entries do
 local world=builder.build(object('Folder'),track,0)
 local old=before.build(object('Folder'),track,0)
 check(physicalSignature(world)==physicalSignature(old),id..' driving geometry unchanged')
 local groups,signs,oldSigns={},0,0
 for _,p in descendants(old)do if p:IsA('BasePart')and p:GetAttribute('ChevronDirection')then oldSigns+=1 end end
 for _,p in descendants(world)do
  if p:IsA('BasePart')and p:GetAttribute('ChevronDirection')then
   signs+=1;local group=p:GetAttribute('ChevronCurveId');check(group~=nil,id..' explicit curve identity')
   groups[group]=(groups[group]or 0)+1
   local guis={};for _,g in p:GetChildren()do if g.ClassName=='SurfaceGui'then table.insert(guis,g)end end
   check(#guis==1,id..' rear face removed')
   check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,id..' signs remain decorative')
  end
 end
 local corners=0;for _,n in groups do corners+=1;check(n==3,id..' exactly three boards per corner')end
 check(corners>0,id..' retains corner guidance')
 print(string.format('CHEVRON %s: %d -> %d boards / %d corners',id,oldSigns,signs,corners))
end
print('PASS '..count..' all-track chevron / frozen driving geometry checks')
]====],{environment={require=require}})()
