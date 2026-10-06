local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KDMUiTheme"))
local CompactHubBuilder = {}

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
  sign(board, if definition[2] == "RACE" then "RACE • SELECT TRACK" else definition[2])
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
  local donorFloor = art.Garage_Part_Architecture:FindFirstChild("Union")
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
   local board=part(visuals,name,Vector3.new(width,height,.25),CFrame.new(x,y,z)*CFrame.Angles(0,yaw,0),Theme.Panel,false)
   local gui=Instance.new("SurfaceGui")
   gui.Face,gui.CanvasSize,gui.LightInfluence=Enum.NormalId.Back,Vector2.new(800,180),0
   gui.Parent=board
   local label=Instance.new("TextLabel")
   label.Size,label.BackgroundTransparency=UDim2.fromScale(1,1),1
   label.Text,label.Font,label.TextScaled,label.TextColor3=text,Enum.Font.GothamBold,true,Theme.TextPrimary
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
   local board=sign(d[1].."Sign",if d[2]=="RACE" then "RACE / SELECT TRACK" else d[2],d[4],5,d[5],10,2.4,math.pi/2)
   local reverse=board:FindFirstChildOfClass("SurfaceGui"):Clone()
   reverse.Name,reverse.Face="ReverseSign",Enum.NormalId.Front
   reverse.Parent=board
  end
  sign("KDMTitle","KART DRIFT MASTERS / KDM PIT GARAGE",-27,20,0,40,4,math.pi/2)
  sign("MyKartLabel","BAY 2 / MY KART",-26,4,0,18,2,math.pi/2)
  sign("Bay1","BAY 1",-26,7,-31,10,2,math.pi/2)
  sign("Bay3","BAY 3",-26,7,31,10,2,math.pi/2)
  for _,d in {{"HeroBoard",assets.Primary.Hero,-26,11,0},{"GarageBoard",assets.Primary.Garage,-10,11,-24},{"TracksBoard",assets.Primary.Tracks,-10,11,24}} do
   local a=anchor(d[1].."Anchor",d[3],d[4],d[5])
   local board=part(visuals,d[1],Vector3.new(18,10.125,.25),CFrame.new(d[3],d[4],d[5])*CFrame.Angles(0,math.pi/2,0),Theme.Panel,false)
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

return CompactHubBuilder
