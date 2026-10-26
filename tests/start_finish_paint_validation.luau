-- Actual production builders. Freeze all output except the authorized paint.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local harness=fs.readFile('tests/track_environment_validation.luau')
local prefix=harness:sub(1,assert(harness:find('local prototype=object("Folder")',1,true))-1)
luau.load(prefix..[====[
local process=require('@lune/process')
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment=env})()
local oldSource=process.exec('git',{'show','e3f7b3a1370264af85ba70c3f7345c8fa867caef:src/server/TrackBuilder.luau'})
assert(oldSource.ok)
local baseline=luau.load(oldSource.stdout,{environment=env})()
local excluded={GridLaunchHeadingVersion=true,VisualPartCount=true,CheckerPartCount=true,StartFinishPaintVersion=true,StartFinishCheckerRows=true,StartGridColumns=true,StartGridRows=true}
local function signature(root)
 local result={}
 local function visit(node,path)
  if node.Name:match('^StartLine') or node.Name=='StartGrid'then return end
  local values={}
  for k,v in node.props do if k~='Parent'then table.insert(values,k..'='..tostring(v))end end
  for k,v in node.attrs do if not excluded[k]then table.insert(values,'@'..k..'='..tostring(v))end end
  table.sort(values);table.insert(result,path..'|'..table.concat(values,';'))
  for _,child in node:GetChildren()do visit(child,path..'/'..child.Name)end
 end
 visit(root,'');return table.concat(result,'\n')
end
local function distance(samples,p)
 local best=math.huge
 for i,a in samples do local b=samples[i%#samples+1];local d=b-a
  local t=math.clamp((p-a):Dot(d)/d:Dot(d),0,1)
  best=math.min(best,rb.Vector2.new(p.X-a.X-d.X*t,p.Z-a.Z-d.Z*t).Magnitude)
 end
 return best
end
for _,id in catalog.Order do
 local entry=catalog.Entries[id];local def=geometry.getDefinition(entry.GeometryId)
 local course=geometry.getCourse(def)
 local p=object('Folder');local world=builder.build(p,entry,0)
 local old=baseline.build(object('Folder'),entry,0)
 if id~='Track01Metro'then
  check(signature(world)==signature(old),id..' every non-paint property, trigger, road, scenery and attribute frozen')
 end -- New city theme has separately authorized kerb/shoulder presentation.
 local marking=world:FindFirstChild('Markings');local band=marking:FindFirstChild('StartLine')
 local texture=band:FindFirstChild('SourceCheckers')
 check(texture.Texture=='rbxassetid://15424111389' and texture.Face==rb.Enum.NormalId.Top,id..' original template asset on road-facing top')
 check(texture.StudsPerTileU==8 and texture.StudsPerTileV==8 and band.Size.Z==8,id..' exactly four two-stud rows')
 check(band.Size.X==def.RoadWidth-4 and band.Transparency==1,id..' two-stud edge inset, original transparent image')
 check((band.Position-rb.Vector3.new(course.StartPosition.X,.098,course.StartPosition.Z)).Magnitude<.001,id..' unchanged finish center')
 local grid=marking:FindFirstChild('StartGrid')
 check(#grid:GetChildren()==8 and world:GetAttribute('StartGridColumns')==2 and world:GetAttribute('StartGridRows')==4,id..' two columns, four rows')
 check(#entry.GridSlots==4 and entry.MaxPlayers==4,id..' paint does not increase capacity')
 if id=='Track01Metro'then check(entry.PreviewImageAssetId=='rbxassetid://125455433974318','Metro supplied preview asset')end
 if id=='Track01Desert'then check(entry.PreviewImageAssetId=='rbxassetid://83402336096508','Desert supplied preview asset')end
 local parts={band}
 for i,slot in grid:GetChildren()do
  check(slot.Name=='Grid'..i and #slot:GetChildren()==3,id..' bracket has three strokes')
  local front=slot:FindFirstChild('Front')
  local center=front.CFrame*rb.CFrame.new(0,0,7.5)
  local expected=geometry.getStartGridFrames(course)[i]
  check((center.Position-rb.Vector3.new(expected.Position.X,.11,expected.Position.Z)).Magnitude<.001,id..' paint follows common frame '..i)
  if i<=entry.MaxPlayers then
   check((entry.GridSlots[i].Position-expected.Position).Magnitude<.001,id..' actual spawn centered in painted bracket '..i)
   check(entry.GridSlots[i].LookVector:Dot(expected.LookVector)>.99999,id..' spawn faces closed front of bracket '..i)
   check(entry.GridSlots[i].LookVector:Dot(course.StartTangent)>.99999,id..' spawn aims into start straight '..i)
   for travel=0,250,5 do check(distance(course.Samples,entry.GridSlots[i].Position+entry.GridSlots[i].LookVector*travel)<def.RoadWidth/2-2,id..' zero-steer automatic launch stays in corridor '..i..' / '..travel)end
  end
  check(front.Size==rb.Vector3.new(10,.02,.35),id..' Park-width front stroke')
  for _,part in slot:GetChildren()do
   table.insert(parts,part)
   for _,x in {-1,1}do for _,z in {-1,1}do
    local corner=part.CFrame:PointToWorldSpace(rb.Vector3.new(x*part.Size.X/2,0,z*part.Size.Z/2))
    check(distance(course.Samples,corner)<def.RoadWidth/2-1,id..' complete bracket footprint remains inside asphalt')
   end end
  end
 end
 for _,part in parts do check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,id..' paint is presentation only')end
 check(builder.build(p,entry,0)==world,id..' new paint cache reused')
 -- A pre-change cached world must be rebuilt once, retaining gate geometry.
 local prior=object('Folder');local stale=baseline.build(prior,entry,0)
 local rebuilt=builder.build(prior,entry,0)
 check(rebuilt~=stale and rebuilt:GetAttribute('StartFinishPaintVersion')==1,id..' old paint cache invalidated')
end
print('PASS: '..count..' selectable-track paint/road/capacity and frozen-world/cache checks')
]====])()
