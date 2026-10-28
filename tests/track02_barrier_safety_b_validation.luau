-- Independently recompute actual boxes; never trust Builder's clearance attributes.
local H=require('./helpers/track02_b_world');local G=H.geometry;local rb=H.rb
local count=0
local function check(v,m)assert(v,m);count+=1 end
local world=H.build();local p=G.getCourse(G.Definitions.PrototypeCircuitV2B).Samples
local roads=world.Road:GetChildren();local triggers=world.BarrierTriggers:GetChildren();local minimum=math.huge
check(#triggers>0,'nonempty certified B barriers')
check(world.SafetyGround.CanCollide==true and world.SafetyGround.Anchored==true,'expanded support')
for _,r in roads do
 local localP=world.SafetyGround.CFrame:PointToObjectSpace(r.Position)
 check(math.abs(localP.X)+r.Size.Magnitude*.5<world.SafetyGround.Size.X*.5 and math.abs(localP.Z)+r.Size.Magnitude*.5<world.SafetyGround.Size.Z*.5,'support covers all roads')
end
for _,t in triggers do
 local rail=world.Barriers:FindFirstChild('Barrier'..t:GetAttribute('BarrierIndex'));check(rail~=nil,'rail/trigger paired')
 local tq,rq=H.quad(t),H.quad(rail);local gap=math.huge
 for _,road in roads do
  local delta=road.Position-t.Position
  if rb.Vector2.new(delta.X,delta.Z).Magnitude<120 then
   gap=math.min(gap,H.gap(tq,H.quad(road)),H.gap(rq,H.quad(road)))
  end
 end
 minimum=math.min(minimum,gap);check(gap>=18-1e-4,'actual all-road rail/trigger >=18: '..t.Name)
 check(t.Anchored and not t.CanCollide and not t.CanTouch and not t.CanQuery,'logical trigger flags')
 local normal=t:GetAttribute('BarrierInwardNormal');local forward=t:GetAttribute('BarrierForwardTangent')
 check(math.abs(normal.Magnitude-1)<1e-5 and math.abs(forward.Magnitude-1)<1e-5,'finite unit contact frame')
 check(normal.Y==0 and forward.Y==0,'planar contact frame')
end
for i,a in triggers do for j=i+1,#triggers do check(not H.overlap(H.quad(a),H.quad(triggers[j])),'no trigger overlap') end end
for _,r in roads do
 local index=tonumber(r.Name:match('%d+'));local first=H.quad(r)
 for j=index+1,#roads do
  if math.min(j-index,#roads-j+index)>8 then check(not H.overlap(first,H.quad(roads[j])),'no opposing road OBB overlap '..index..'/'..j) end
 end
end
for _,kerb in world.Kerbs:GetChildren() do check(kerb.Anchored and not kerb.CanCollide and not kerb.CanTouch and not kerb.CanQuery and not kerb.CastShadow,'kerb visual-only') end
local directions=world.DirectionMarkers
check(directions==nil,'retired V2B omits unguaranteed forward cues per visual safety contract')
for _,cluster in (if directions then directions:GetChildren()else {}) do
 local index=cluster:GetAttribute('SampleIndex');local tangent=(p[index%#p+1]-p[(index-2)%#p+1]).Unit
 local a=cluster:FindFirstChild('Arrow0Wing-1');local b=cluster:FindFirstChild('Arrow0Wing1')
 check((a.CFrame.LookVector+b.CFrame.LookVector).Unit:Dot(tangent)>=.95,'arrow apex direction')
 check(math.abs(cluster:GetAttribute('LaneSide'))==1,'lane-center station')
end
print(string.format('PASS: %d V2B all-road OBB/kerb/arrow checks; triggers%d / actual minimum gap %.3f / omitted%d',count,#triggers,minimum,world:GetAttribute('V2BSafetyOmittedBarrierCount')))
