-- Real production builder, static cosmetic geometry; not mobile performance evidence.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local harness=fs.readFile('tests/track_environment_validation.luau')
local prefix=harness:sub(1,assert(harness:find('local prototype=object("Folder")',1,true))-1)
luau.load(prefix..[====[
local serde=require('@lune/serde')
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment=env})()
local def=geometry.getDefinition('PracticeFigure8V1')
local course=geometry.getCourse(def)
local world=builder.build(object('Folder'),catalog.Entries.Track01,0)
local environment=world:FindFirstChild('Environment')
check(not environment:FindFirstChild('CrossoverApron'),'no square parking-lot apron')
local ribbons={}
for index,name in {'CrossoverRibbonA','CrossoverRibbonB'}do
 local part=environment:FindFirstChild(name)
 check(part and part.Size.X==60 and part.Size.Z==220,'road-width branch ribbon')
 check(math.abs(part.CFrame.LookVector:Dot(def.Crossover.BranchTangents[index]))>.99999,'actual branch tangent')
 check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,'nonphysical ribbon')
 check(part.Position.Y-part.Size.Y/2>.065,'above original visual road layer')
 ribbons[index]=part
end
check(math.abs(ribbons[1].Position.Y-ribbons[2].Position.Y)>=.014,'visual ribbon overlap has no coplanar surface')
local folder=world:FindFirstChild('Markings'):FindFirstChild('CrossoverGuidance')
local rows={}
for _,branch in {'A','B'}do
 local dashes,edges=0,0
 local approach,continuation,exit=false,false,false
 for _,part in folder:GetChildren()do
  if part:GetAttribute('CrossoverBranch')~=branch then continue end
  check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,'guidance cosmetic only')
  check(part.Position.Y-part.Size.Y/2>math.max(ribbons[1].Position.Y+ribbons[1].Size.Y/2,ribbons[2].Position.Y+ribbons[2].Size.Y/2),'guidance above both asphalt overlays')
  if part:GetAttribute('GuidanceKind')=='RacingDivider' then
   dashes+=1 local d=part:GetAttribute('BranchDistance')
   approach=approach or d<=-72
   continuation=continuation or math.abs(d)<=48
   exit=exit or d>=72
   check(math.abs(part.Size.Z-14)<.001 and math.abs(part.Size.X-.8)<.001,'bounded readable long dashed divider')
   check(math.abs(d)>=24,'no clashing divider at exact branch center')
  else edges+=1;check(part:GetAttribute('GuidanceKind')=='OuterEdge','only race-road guidance')end
 end
 check(dashes==8 and edges==4 and approach and continuation and exit,'both branches marked approach/continuation/exit')
 rows[branch]={dashes=dashes,edges=edges,approach=approach,continuation=continuation,exit=exit}
end
local dedicated=0
for _,cluster in world:FindFirstChild('DirectionMarkers'):GetChildren()do
 if cluster:GetAttribute('CrossoverBranch')then
  dedicated+=1
  check(math.abs(cluster:GetAttribute('BranchDistance'))==118 and math.abs(cluster:GetAttribute('LaneSide'))==1,'small cue outside central overlap in each racing lane')
  check(#cluster:GetChildren()==2,'one small chevron, not a giant central arrow')
 end
end
check(dedicated==8,'two branches / approach and exit / both lanes')
check(#world:FindFirstChild('Barriers'):GetChildren()==0 and #world:FindFirstChild('BarrierTriggers'):GetChildren()==0,'no central or Practice barrier')
local bounds,countParts,collisionParts={},0,{}
local function visit(node)
 if node:IsA('BasePart')then
  countParts+=1
  if node.CanCollide then table.insert(collisionParts,node.Name)end
  check(not node.Name:lower():find('stopline') and not node.Name:lower():find('crosswalk') and not node.Name:lower():find('trafficlight'),'no urban traffic markings')
 end
 for _,child in node:GetChildren()do visit(child)end
end
visit(world)
check(#collisionParts==1 and collisionParts[1]=='SafetyGround','single physical support, overlays never add wheel bumps')
check(countParts<=1400,'mobile static geometry budget')
if require('@lune/process').args[1]=='Report' then
 fs.writeDir('artifacts/r7-p1b')
fs.writeFile('artifacts/r7-p1b/crossover-marking-audit.json',serde.encode('json',{checks=count,branches=rows,ribbons=2,monolithicApron=false,dedicatedChevronClusters=dedicated,parts=countParts,physicalSupport=collisionParts,staticVerdict='PASS',manualTemporalFlicker='Requires driven viewport observation'}))
end
print('PASS: '..count..' production crossover visual/physics/guidance checks')
]====])()
