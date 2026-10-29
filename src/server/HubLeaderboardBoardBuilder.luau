-- Visual-only ranking area outside the Park Hub's left building.
local Builder={}
function Builder.build(hub)
 local origin=hub:GetAttribute('RookieParkOrigin')
 if typeof(origin)~='Vector3'or not hub:FindFirstChild('HubParkRookieLoopG2')then return nil end
 if hub:FindFirstChild('KDMRankings')then return hub.KDMRankings end
 local root=Instance.new('Model');root.Name='KDMRankings'
 local function part(name,size,pos,color,rotation)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=CFrame.new(origin+pos)
  if rotation then p.CFrame*=rotation end
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.Parent=root;return p
 end
 local function text(parent,name,value,pos,size,fontSize,color)
  local t=Instance.new('TextLabel');t.Name=name;t.Text=value;t.Position=UDim2.fromOffset(pos.X,pos.Y);t.Size=UDim2.fromOffset(size.X,size.Y)
  t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBold;t.TextSize=fontSize;t.TextColor3=color or Color3.new(1,1,1)
  t.TextXAlignment=Enum.TextXAlignment.Left;t.TextTruncate=Enum.TextTruncate.AtEnd;t.AutoLocalize=false;t.Parent=parent;return t
 end
 local cyan=Color3.fromRGB(75,225,245);local gold=Color3.fromRGB(255,218,65)
 for _,d in {
  {id='SOLO_Park',name='SoloBoard',title='SOLO TIME ATTACK',sub='ROOKIE RACING PARK  /  2-LAP FINISH',x=71,y=28,z=-27.7,w=38*1.12,h=19*1.12,yaw=0},
  {id='MULTI_Track01Race',name='MultiBoard',title='MULTIPLAYER FINISH TIME',sub='BASE CIRCUIT  /  2-LAP HUMAN RACES',x=105.7,y=12,z=-38,w=28,h=16,yaw=45},
  {id='CASH',name='CashBoard',title='LIFETIME K$ EARNED',sub='PARK + RACES + BONUSES  /  ALL TIME',x=126.913203,y=12,z=-59.213203,w=28,h=16,yaw=45},
 }do
  local pos=Vector3.new(d.x,d.y,d.z)
  local rotation=CFrame.Angles(0,math.rad(d.yaw),0)
  local function localPart(name,size,offset,color)
   return part(name,size,pos+rotation:VectorToWorldSpace(offset),color,rotation)
  end
  local board=localPart(d.name,Vector3.new(d.w,d.h,.8),Vector3.zero,Color3.fromRGB(12,28,42));board:SetAttribute('LeaderboardId',d.id)
  localPart(d.name..'Top',Vector3.new(d.w+.5,.22,1),Vector3.new(0,d.h/2+.15,-.1),cyan)
  if d.name~='SoloBoard'then for _,side in {-1,1}do
   localPart(d.name..'Leg',Vector3.new(.8,4.2,.8),Vector3.new(side*(d.w/2-3),2.1-d.y,0),Color3.fromRGB(30,45,53))
  end end
  local gui=Instance.new('SurfaceGui');gui.Name='RankingFace';gui.Face=Enum.NormalId.Front;gui.CanvasSize=Vector2.new(1000,600)
  gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.MaxDistance=200;gui.Parent=board
  local panel=Instance.new('Frame');panel.Size=UDim2.fromScale(1,1);panel.BackgroundColor3=Color3.fromRGB(38,70,94);panel.BorderSizePixel=0;panel.Parent=gui
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,18);corner.Parent=panel
  local stroke=Instance.new('UIStroke');stroke.Color=Color3.fromRGB(215,245,255);stroke.Thickness=2;stroke.Parent=panel
  text(panel,'Brand','KDM  /  GLOBAL RANKINGS',Vector2.new(32,17),Vector2.new(936,32),24,cyan)
  text(panel,'Title',d.title,Vector2.new(32,57),Vector2.new(936,55),39)
  text(panel,'Subtitle',d.sub,Vector2.new(32,116),Vector2.new(936,38),24,gold)
  for i=1,5 do
   local row=Instance.new('Frame');row.Name='Row'..i;row.Position=UDim2.fromOffset(28,166+(i-1)*66);row.Size=UDim2.fromOffset(944,59)
   row.BackgroundColor3=Color3.fromRGB(80,135,156);row.BackgroundTransparency=if i==1 then .25 else .65;row.BorderSizePixel=0;row.Parent=panel
   local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=row
   text(row,'Rank',tostring(i),Vector2.new(14,0),Vector2.new(58,59),30,if i==1 then gold else cyan)
   text(row,'Racer','--',Vector2.new(85,0),Vector2.new(570,59),29)
   local score=text(row,'Score','--',Vector2.new(665,0),Vector2.new(258,59),30);score.TextXAlignment=Enum.TextXAlignment.Right
  end
  text(panel,'Status','LOADING RANKINGS',Vector2.new(32,506),Vector2.new(936,33),23,cyan)
  text(panel,'Hint','APPROACH BELOW  /  VIEW TOP 50 + MY RECORD',Vector2.new(32,550),Vector2.new(936,30),21)
  local anchor=localPart(d.name..'Open',Vector3.new(1,1,1),Vector3.new(0,3-d.y,-5),cyan);anchor.Transparency=1
  anchor:SetAttribute('LeaderboardId',d.id)
  local prompt=Instance.new('ProximityPrompt');prompt.Name='KDMRankingsPrompt';prompt.ActionText='VIEW TOP 50';prompt.ObjectText=d.title
  prompt.HoldDuration=0;prompt.MaxActivationDistance=15;prompt.RequiresLineOfSight=false;prompt.Parent=anchor
 end
 root.Parent=hub;return root
end
return Builder
