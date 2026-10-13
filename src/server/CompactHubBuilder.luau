local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KDMUiTheme"))
local CompactHubBuilder = {}

-- Stand/display + overhead location marker, using native KDM primitives only.
local function kiosk(part,parent,name,x,z,yaw,text,icon)
 local frame=CFrame.new(x,0,z)*CFrame.Angles(0,yaw,0)
 local graphite=Color3.fromRGB(26,40,56);local cyan=Color3.fromRGB(111,211,245)
 part(parent,name..'Base',Vector3.new(5,.25,2.5),frame*CFrame.new(0,.2,0),graphite,false)
 part(parent,name..'Stand',Vector3.new(.6,2.3,.6),frame*CFrame.new(0,1.45,0),graphite,false)
 local screen=part(parent,name..'Sign',Vector3.new(5,2.6,.3),frame*CFrame.new(0,3,0),graphite,false)
 for _,face in {Enum.NormalId.Back,Enum.NormalId.Front} do
  local surface=Instance.new('SurfaceGui');surface.Name='KioskDisplay';surface.Face=face;surface.CanvasSize=Vector2.new(600,300);surface.LightInfluence=0;surface.Parent=screen
  local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(1,1);label.BackgroundColor3=Color3.fromRGB(28,86,108);label.TextColor3=cyan
  label.Position=UDim2.fromScale(0,.60);label.Size=UDim2.fromScale(1,.40)
  label.Font=Enum.Font.GothamBold;label.TextScaled=true;label.Text=text;label.Parent=surface
  local pictogram=Instance.new('Frame');pictogram.AnchorPoint=Vector2.new(.5,0);pictogram.Position=UDim2.fromScale(.5,.07);pictogram.Size=UDim2.fromOffset(130,145);pictogram.BackgroundTransparency=1;pictogram.Parent=surface
  local function tile(x,y,w,h,color)
   local f=Instance.new('Frame');f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(w,h);f.BackgroundColor3=color;f.BorderSizePixel=0;f.Parent=pictogram;return f
  end
  if text=='SELECT KART' then
   tile(25,25,80,90,cyan);for _,x in {10,105} do tile(x,30,15,30,Theme.Panel);tile(x,80,15,30,Theme.Panel) end
   tile(40,45,50,20,Theme.Panel)
  elseif text=='SELECT TRACK' then
   tile(25,20,80,105,cyan);tile(40,35,50,75,Theme.Panel)
  else
   tile(15,20,10,120,cyan);for x=0,3 do for y=0,2 do tile(25+x*22,20+y*22,22,22,if (x+y)%2==0 then cyan else Theme.Panel) end end
  end
 end
 local marker=Instance.new('BillboardGui');marker.Name='KioskMarker';marker.Size=UDim2.fromOffset(190,84);marker.StudsOffsetWorldSpace=Vector3.new(0,4.5,0)
 marker.MaxDistance=100;marker.AlwaysOnTop=false;marker.Parent=screen
 local bubble=Instance.new('TextLabel');bubble.Size=UDim2.fromScale(1,.6);bubble.BackgroundColor3=graphite;bubble.BackgroundTransparency=.12;bubble.Text=text
 bubble.TextColor3=Color3.fromRGB(235,246,250);bubble.Font=Enum.Font.GothamBold;bubble.TextScaled=true;bubble.Parent=marker
 local round=Instance.new('UICorner');round.CornerRadius=UDim.new(0,10);round.Parent=bubble
 local pin=Instance.new('TextLabel');pin.Position=UDim2.fromScale(0,.6);pin.Size=UDim2.fromScale(1,.4);pin.BackgroundTransparency=1;pin.Text='◉';pin.TextColor3=cyan;pin.TextScaled=true;pin.Parent=marker
end

-- Provisional foundation footprint, relative to the existing safe PlayerSpawn.
local function buildFallback(workspace, playerSpawn)
 if workspace:GetAttribute("KDMServerRole") ~= "HUB" then return nil end
 local existing = workspace:FindFirstChild("KDMHub")
 if existing then return existing end
 local root = Instance.new("Model")
 root.Name = "KDMHub"
 local origin = playerSpawn.CFrame * CFrame.new(0, -.5, 0)
 local function part(parent, name, size, offset, color, collide)
  local item = Instance.new("Part")
  item.Name, item.Size, item.CFrame = name, size, origin * offset
  item.Color, item.Material = color, Enum.Material.SmoothPlastic
  item.Anchored, item.CanCollide = true, collide
  item.CanTouch, item.CanQuery, item.CastShadow = false, false, false
  item.Parent = parent
  return item
 end
 part(root, "HubFloor", Vector3.new(112, 1, 96), CFrame.new(0, .5, 0), Theme.Background, true)
 local spawn = Instance.new("SpawnLocation")
 spawn.Name, spawn.Size, spawn.CFrame = "HubSpawn", Vector3.new(8, 1, 8), origin * CFrame.new(0, 1.5, 12)
 spawn.Anchored, spawn.Neutral, spawn.Transparency = true, true, 1
 spawn.CanCollide, spawn.CanTouch, spawn.CanQuery = false, false, false
 spawn.Duration = 0
 spawn.Parent = root
 local stations = Instance.new("Folder")
 stations.Name, stations.Parent = "Stations", root
 local visuals = Instance.new("Folder")
 visuals.Name, visuals.Parent = "Visuals", root
 local function sign(target, text)
  local gui = Instance.new("SurfaceGui")
  gui.Name, gui.Face, gui.CanvasSize = "Sign", Enum.NormalId.Back, Vector2.new(500, 120)
  gui.Parent = target
  local label = Instance.new("TextLabel")
  label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
  label.Font, label.TextScaled, label.TextColor3 = Enum.Font.GothamBold, true, Theme.TextPrimary
  label.Text, label.Parent = text, gui
 end
 for _, definition in {{"GarageStation", "GARAGE", -36, -12}, {"TrackStation", "TRACKS", 36, -12}, {"RaceStation", "RACE", 0, -32}} do
  local station = part(stations, definition[1], Vector3.new(20, .3, 16), CFrame.new(definition[3], 1.15, definition[4]), Theme.Panel, true)
  station:SetAttribute("HubAction", definition[2])
  local board = part(visuals, definition[1] .. "Sign", Vector3.new(20, 5, .5), CFrame.new(definition[3], 4, definition[4]-7), Theme.Panel, false)
  sign(board, if definition[2] == "RACE" then "RACE â€¢ SELECT TRACK" else definition[2])
  local prompt = Instance.new("ProximityPrompt")
  prompt.Name, prompt.ActionText, prompt.ObjectText = "HubPrompt", "OPEN", definition[2]
  prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0, 12, false
  prompt.Parent = station
 end
 local title = part(visuals, "KDMTitle", Vector3.new(36, 7, .5), CFrame.new(0, 6, -44), Theme.Panel, false)
 sign(title, "KART DRIFT MASTERS")
 root.Parent = workspace
 return root
end

-- Static shell is optional; preserve a safe H1 spawn if extraction/assets are unavailable.
function CompactHubBuilder.build(workspace, playerSpawn)
 if workspace:GetAttribute("KDMServerRole") ~= "HUB" then return nil end
 local existing = workspace:FindFirstChild("KDMHub")
 if existing then return existing end
 local shared = ReplicatedStorage:WaitForChild("Shared")
 local template = shared:FindFirstChild("KDMPitGarageArt")
 if not template then return buildFallback(workspace, playerSpawn) end
 local root = Instance.new("Model")
 root.Name = "KDMHub"
 local ok, failure = pcall(function()
  local assets = require(shared:WaitForChild("KDMWorldAssets"))
  -- Keep the imported floor above the shared Baseplate to prevent coplanar flicker.
  -- Move the shell and its spawn/display anchors together.
  -- The actual pedestrian exit faces local -X (confirmed by the user's runtime test).
  -- Reverse the previous placement by 180 degrees so exiting faces the Base track (-Z).
  local origin = playerSpawn.CFrame * CFrame.new(0, -.25, 0) * CFrame.Angles(0, -math.pi/2, 0)
  local art = template:Clone()
  assert(art:IsA("Model") and art:GetAttribute("H2StaticArt") == true, "Invalid Pit Garage shell")
  art.Name, art.Parent = "KDMPitGarageArt", root
  for _, node in art:GetDescendants() do
   assert(not node:IsA("LuaSourceContainer") and not node:IsA("RemoteEvent") and not node:IsA("RemoteFunction")
    and not node:IsA("Seat") and not node:IsA("VehicleSeat") and not node:IsA("Constraint") and not node:IsA("WeldConstraint") and not node:IsA("JointInstance") and not node:IsA("ProximityPrompt"), "Unsafe art instance")
   if node:IsA("BasePart") then node.CFrame = origin * node.CFrame; node.Anchored = true; node.CanTouch = false end
   -- The template fixtures overlap in the compact showroom; soften their combined light.
   if node:IsA("Light") then node.Brightness = math.min(node.Brightness * .5, 1); node.Range = math.min(node.Range, 30) end
  end
  -- The donor floor is a CSG union with lift-bay cutouts. Use one continuous
  -- surface so the old studded Baseplate cannot show through those openings.
  -- Several walls and the floor share the name Union. Serialized sibling order
  -- can change; select the broad, thin floor rather than the first name match.
  local donorFloor = nil
  for _, candidate in art.Garage_Part_Architecture:GetChildren() do
   if candidate:IsA("BasePart") and candidate.Name == "Union" and candidate.Size.Y < 2
    and candidate.Size.X > 50 and candidate.Size.Z > 80 then
    assert(donorFloor == nil, "Ambiguous garage floor")
    donorFloor = candidate
   end
  end
  assert(donorFloor and donorFloor:IsA("BasePart") and donorFloor.Size.Y < 2, "Missing garage floor")
  local garageFloor = Instance.new("Part")
  garageFloor.Name, garageFloor.Size, garageFloor.CFrame = "GarageFloor", donorFloor.Size, donorFloor.CFrame
  garageFloor.Material, garageFloor.Color = Enum.Material.Concrete, donorFloor.Color
  garageFloor.TopSurface, garageFloor.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
  garageFloor.Anchored, garageFloor.CanCollide, garageFloor.CanQuery, garageFloor.CanTouch = true, true, true, false
  garageFloor.Parent = root
  donorFloor.Transparency, donorFloor.CanCollide, donorFloor.CanQuery = 1, false, false
  local function folder(name)
   local f = Instance.new("Folder"); f.Name, f.Parent = name, root; return f
  end
  local anchors, stations, visuals = folder("Anchors"), folder("Stations"), folder("Visuals")
  local function part(parent, name, size, offset, color, collide)
   local item = Instance.new("Part")
   item.Name, item.Size, item.CFrame = name, size, origin * offset
   item.Color, item.Material = color, Enum.Material.SmoothPlastic
   item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, collide, false, collide
   item.Parent = parent; return item
  end
  -- Immediate forecourt only. Imported floor remains the interior collision surface.
  part(root,"Forecourt",Vector3.new(40,1,100),CFrame.new(50,-.5,0),Color3.fromRGB(83,88,92),true)
  local function anchor(name,x,y,z)
   local a=part(anchors,name,Vector3.new(1,1,1),CFrame.new(x,y,z),Theme.Panel,false)
   a.Transparency=1; return a
  end
  local spawn=Instance.new("SpawnLocation")
  spawn.Name,spawn.Size="HubSpawn",Vector3.new(6,1,6)
  -- Start on the interior side of the kart, facing all three navigation signs (+X).
  spawn.CFrame=origin*CFrame.new(-12,.5,0)*CFrame.Angles(0,-math.pi/2,0)
  spawn.Anchored,spawn.Neutral,spawn.Transparency=true,true,1
  spawn.CanCollide,spawn.CanTouch,spawn.CanQuery=false,false,false
  spawn.Duration=0;spawn.Parent=root
  anchor("MyKartDisplayAnchor",4,.08,0)
  anchor("QueueFutureAnchor",38,1,18)
  local function sign(name,text,x,y,z,width,height,yaw)
   local board=part(visuals,name,Vector3.new(width,height,.25),CFrame.new(x,y,z)*CFrame.Angles(0,yaw,0),Color3.fromRGB(111,211,245),false)
   local gui=Instance.new("SurfaceGui")
   gui.Face,gui.CanvasSize,gui.LightInfluence=Enum.NormalId.Back,Vector2.new(800,180),0
   gui.Parent=board
   local label=Instance.new("TextLabel")
   label.Size,label.BackgroundTransparency=UDim2.fromScale(1,1),1
   label.Text,label.Font,label.TextScaled,label.TextColor3=text,Enum.Font.GothamBold,true,Color3.fromRGB(12,27,42)
   label.Parent=gui;return board
  end
  for _,d in {{"GarageStation","GARAGE","GaragePromptAnchor",9,-17},{"TrackStation","TRACKS","TracksPromptAnchor",9,17},{"RaceStation","RACE","RacePromptAnchor",25,0}} do
   local a=anchor(d[3],d[4],2,d[5])
   local station=part(stations,d[1],Vector3.new(1,1,1),CFrame.new(d[4],2,d[5]),Theme.Panel,false)
   station.Transparency=1;station:SetAttribute("HubAction",d[2])
   local prompt=Instance.new("ProximityPrompt")
   prompt.Name,prompt.ActionText,prompt.ObjectText="HubPrompt","OPEN",d[2]
   prompt.HoldDuration,prompt.MaxActivationDistance,prompt.RequiresLineOfSight=0,12,false
   prompt.Parent=station
   kiosk(part,visuals,d[1],d[4],d[5],math.pi/2,if d[2]=='GARAGE' then 'SELECT KART' elseif d[2]=='TRACKS' then 'SELECT TRACK' else 'SELECT RACE',if d[2]=='GARAGE' then '▰' elseif d[2]=='TRACKS' then '↝' else '⚑')
  end
  -- BAY labels were decorative and did not identify functional destinations.
  -- Arcade lettering is actual raised geometry, without a backing panel.
  -- Mount two lines inside the central window, clear of its outer frame.
  local glyphs = {
   A={"01110","10001","10001","11111","10001","10001","10001"},
   B={"11110","10001","10001","11110","10001","10001","11110"},
   D={"11110","10001","10001","10001","10001","10001","11110"},
   E={"11111","10000","10000","11110","10000","10000","11111"},
   F={"11111","10000","10000","11110","10000","10000","10000"},
   I={"11111","00100","00100","00100","00100","00100","11111"},
   K={"10001","10010","10100","11000","10100","10010","10001"},
   L={"10000","10000","10000","10000","10000","10000","11111"},
   M={"10001","11011","10101","10101","10001","10001","10001"},
   O={"01110","10001","10001","10001","10001","10001","01110"},
   R={"11110","10001","10001","11110","10100","10010","10001"},
   S={"01111","10000","10000","01110","00001","00001","11110"},
   T={"11111","00100","00100","00100","00100","00100","00100"},
   Y={"10001","10001","01010","00100","00100","00100","00100"},
  }
  local letters=Instance.new("Model");letters.Name="KDMWindowLettering";letters.Parent=visuals
  local function raisedLine(text,y,unit,color)
   local frame=CFrame.new(29.1,y,2.51)*CFrame.Angles(0,-math.pi/2,0)
   local width=(#text*6-1)*unit
   for index=1,#text do
    local glyph=glyphs[text:sub(index,index)]
    if glyph then for row,bits in glyph do
     local column=1
     while column<=5 do
      if bits:sub(column,column)=="1" then
       local last=column
       while last<5 and bits:sub(last+1,last+1)=="1" do last+=1 end
       local x=-width/2+((index-1)*6+column-1+(last-column+1)/2)*unit
       local stroke=part(letters,"LetterStroke",Vector3.new((last-column+1)*unit,unit,.28),frame*CFrame.new(x,(4-row)*unit,0),color,false)
       stroke.CastShadow=false
       column=last+1
      else column+=1 end
     end
    end end
   end
  end
  raisedLine("KART DRIFT MASTERS",21,.21,Color3.fromRGB(12,27,42))
  raisedLine("KDM LOBBY",17.5,.28,Color3.fromRGB(12,27,42))
  -- Measured solid rear bays and the window-free side wall. Resolve transformed
  -- donor parts by geometry, never same-name serialization order. Keep tools,
  -- lights, windows, station signs and the pedestrian/garage exits unobstructed.
  local posterWalls = {}
  for _, candidate in art.Garage_Part_Architecture:GetChildren() do
   if candidate:IsA("BasePart") then
    local position = origin:PointToObjectSpace(candidate.CFrame.Position)
    if candidate.Size.X < .6 and candidate.Size.Y > 16.4 and candidate.Size.Y < 16.6
     and position.X < -29 and position.X > -30 then
     local key = if position.Z > 30 then "Hero" elseif position.Z < -35 then "Garage" else nil
     if key then assert(posterWalls[key] == nil,"Ambiguous poster bay");posterWalls[key] = candidate end
    elseif candidate.Size.Z < .2 and candidate.Size.Y > 27 and candidate.Size.Y < 28
     and candidate.Size.X > 60 and position.Z < -46 and position.Z > -47 then
     assert(posterWalls.Tracks == nil,"Ambiguous poster side wall");posterWalls.Tracks = candidate
    end
   end
  end
  local clearance = .1
  for _,d in {{"HeroBoard",assets.Primary.Hero,"Hero",18},{"GarageBoard",assets.Primary.Garage,"Garage",14},{"TracksBoard",assets.Primary.Tracks,"Tracks",14}} do
   local wall = assert(posterWalls[d[3]],"Missing solid poster wall")
   local size = Vector3.new(d[4],d[4]*9/16,.25)
   local position = origin:PointToObjectSpace(wall.CFrame.Position)
   local offset = if d[3] == "Tracks" then CFrame.new(-13-position.X,18.5-position.Y,wall.Size.Z/2+clearance+size.Z/2)
    else CFrame.new(wall.Size.X/2+clearance+size.Z/2,15-position.Y,0)*CFrame.Angles(0,math.pi/2,0)
   -- Back (+Z) carries the image and faces the room; the dark front faces the wall.
   local mounted = wall.CFrame * offset
   local a=anchor(d[1].."Anchor",0,0,0);a.CFrame=mounted
   local board=part(visuals,d[1],size,CFrame.new(),Theme.Panel,false)
   board.CFrame=mounted
   board:SetAttribute("WallMounted",true);board:SetAttribute("WallClearance",clearance)
   board:SetAttribute("WallBay",d[3])
   local gui=Instance.new("SurfaceGui");gui.Face,gui.CanvasSize,gui.LightInfluence=Enum.NormalId.Back,Vector2.new(1672,941),0;gui.Parent=board
   local image=Instance.new("ImageLabel")
   image.Size,image.BackgroundTransparency,image.ScaleType=UDim2.fromScale(1,1),1,Enum.ScaleType.Fit
   image.Image="rbxassetid://"..assets.Boards[d[2]];image.Parent=gui
  end
  -- Local fixtures only; never replace global race Lighting.
  for _,z in {-20,0,20} do
   local fixture=part(visuals,"ShowroomLight",Vector3.new(3,.2,6),CFrame.new(0,23,z),Theme.TextPrimary,false)
   local light=Instance.new("PointLight");light.Brightness,light.Range,light.Shadows=1,30,false;light.Parent=fixture
  end
 end)
 if not ok then root:Destroy(); warn("[Hub] Pit Garage unavailable; H1 fallback: "..tostring(failure)); return buildFallback(workspace,playerSpawn) end
 -- Match the track infield across the exposed plate without adding geometry
 -- or changing the physical ground, race roads, or off-track detection.
 local ground = workspace:FindFirstChild("Baseplate")
 local prototype = workspace:FindFirstChild("Prototype")
 if not ground and prototype then ground = prototype:FindFirstChild("Ground") end
 if ground and ground:IsA("BasePart") then
  ground.Color, ground.Material = Color3.fromRGB(84, 125, 79), Enum.Material.Grass
  ground.TopSurface, ground.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 end
 root:SetAttribute("HubPresentation","PIT_GARAGE")
 root.Parent=workspace;return root
end

-- Explicit Global Lobby startup calls this after the accepted shell has been built.
function CompactHubBuilder.buildFrontDriveZone(hub, ground)
 return require(script.Parent:WaitForChild("LobbyFrontDriveZoneBuilder")).build(hub, ground)
end

return CompactHubBuilder
