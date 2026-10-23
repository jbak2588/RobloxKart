local fs,luau,rb,process=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/process')
local fixture=require('./hub_park_rookie_loop_validation')
local root,L=fixture.root,fixture.layout
local folder=assert(root:FindFirstChild('ParkCircuitStructures'))
local checks=0
local function check(v,m)assert(v,m);checks+=1 end
for _,path in {'src/shared/HubParkRookieLoopLayout.luau'}do
 check(fs.readFile(path):gsub('\r\n','\n')==process.exec('git',{'show','1329cbb:'..path}).stdout:gsub('\r\n','\n'),'race/physics/road/service untouched '..path)
end
check(folder:GetAttribute('ArchCount')==1 and folder:GetAttribute('TowerCount')==4,'one arch/four towers')
local parts,rails,branding,chevronRails,chevronImages=0,0,0,0,0
for _,v in folder:GetDescendants()do
 check(not(v:IsA('LuaSourceContainer')or v:IsA('Light')or v:IsA('ParticleEmitter')or v:IsA('RemoteEvent')),'static art only')
 if v:IsA('BasePart')then
  parts+=1;check(v.Anchored and not v.CanCollide and not v.CanTouch and not v.CanQuery and not v.CastShadow,'no changes to contact or raycasts')
  if v.Name:match('^RailSegment')then
   rails+=1;local p=v.CFrame.Position
   check(not(p.Z>L.StartStraightZ and p.X>=-200 and p.X<=200),'pit apron remains clear')
   check(v.CFrame.UpVector.Y>.999,'upright rail')
   local dir=v:GetAttribute('ChevronDirection')
   if dir then
    chevronRails+=1
    check(math.abs(v.Size.Y-6.0)<.001 and math.abs(v.Size.Z-12.0)<.001,'chevron board is 6.0x12.0 studs')
    local expectedAsset=if dir=='Left'then'rbxassetid://125863354300599'else'rbxassetid://118109633914676'
    check(v:GetAttribute('ChevronAssetId')==expectedAsset,'chevron asset attribute matches turn direction')
    for _,face in {'Left','Right'}do
     local gui=v:FindFirstChild('KDMChevronSurfaceGui_'..face)
     check(gui~=nil,'both Left and Right SurfaceGuis exist on chevron board')
     local img=gui and gui:FindFirstChild('ChevronPanel')and gui.ChevronPanel:FindFirstChild('ChevronImage')
     check(img and img:IsA('ImageLabel')and img.Image==expectedAsset,'ChevronImage uses uploaded 1024x512 chevron asset')
     chevronImages+=1
    end
   else
    check(math.abs(v.Size.Y-4.5)<.001 and math.abs(v.Size.Z-20)<.001,'ad rails 4.5x20, 75 percent of chevron height')
   end
  end
 elseif v:IsA('SurfaceGui')then branding+=1;check(not v.AlwaysOnTop,'world occlusion respected')end
end
local arch=folder.SponsorArch
check(math.abs(arch.TopBeam.CFrame.Position.Y-arch.TopBeam.Size.Y/2-24.4)<.001,'Figure-8 vertical clearance preserved')
check(arch.LeftBasePad.CFrame.Position.Z-arch.LeftBasePad.Size.Z/2>L.StartStraightZ+L.RoadWidth/2+L.KerbWidth+12,'pit-side pillar beyond road edge')
check(rails==folder:GetAttribute('RailCount')and rails>40 and rails<250,'bounded rail budget')
check(folder:GetAttribute('ChevronClusterCount')==18 and folder:GetAttribute('ChevronPartCount')==54 and chevronRails==54 and chevronImages==108,'all 18 Hub corners have 3 outer chevron boards with double-sided assets')
check(branding>=rails+2,'KDM panels and both arch faces')
local lamps=rb.deserializeModel(fs.readFile('src/assets/KDMTrackLightingPrefabs.rbxmx'))[1]:FindFirstChild('OB_Spotlight_a')
check(lamps and lamps.PrimaryPart~=nil,'same audited Figure-8 spotlight prefab/pivot available')
local lampParts=0
for _,v in lamps:GetDescendants()do
 check(v:IsA('BasePart')or v:IsA('SurfaceAppearance'),'lamp prefab contains only static visual data')
 if v:IsA('BasePart')then lampParts+=1 end
end
check(lampParts==3,'bounded three-part lamp head: eight heads replace eight fallback blocks')
print(string.format('PASS %d circuit decor checks; %d parts, %d branded rails, four towers; fallback heads in Lune',checks,parts,rails))
