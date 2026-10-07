local fs,luau,rb,process=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox"),require("@lune/process")
local prior=require("./helpers/ui_palette_freeze")
local m1=require("./helpers/m1_presentation_freeze")
local function normalize(s)return prior(m1(s))end
local count=0
local function check(v,label)assert(v,label);count+=1 end
local baseline="09f82653106f59e73089a84e43d13c58c145a928"
for _,name in {"GarageUiController","HubUiController","HubWorldGuidanceView","TacticalLoadoutController"} do
 local path="src/client/"..name..".luau"
 local old=process.exec("git",{"show",baseline..":"..path})
 check(old.ok and normalize(old.stdout)==normalize(fs.readFile(path)),"non-color source frozen "..name)
end
for _,path in {"src/shared/KDMUiTheme.luau","src/shared/TrackCatalog.luau","src/shared/TrackGeometry.luau",
 "src/shared/KDMGameplayBalance.luau","src/shared/KartConfig.luau","src/server/PrototypeWorld.luau",
 "src/server/KDMStraightSpeedResolver.luau","src/server/TrackBuilder.luau","src/server/RaceBotController.luau",
 "src/client/KartInputController.luau","src/client/RaceHudController.luau","src/client/TrackMapRenderer.luau",
 "src/shared/KartVisualFactory.luau","src/shared/KartPreviewFraming.luau"} do
 local old=process.exec("git",{"show",baseline..":"..path})
 if path=="src/shared/TrackGeometry.luau" then
  local current=fs.readFile(path):gsub("\r\n","\n")
  local a=assert(current:find("\t-- Dedicated planar drift practice:",1,true));local b=assert(current:find("\t-- Exact straight/arc path",a,true))
  current=current:sub(1,a-1)..current:sub(b)
  check(old.ok and old.stdout:gsub("\r\n","\n")==current,"existing geometry/functions byte frozen")
 elseif path=="src/shared/TrackCatalog.luau" or path=="src/server/TrackBuilder.luau" then
  local result=process.exec("lune",{"run","tests/practice_figure8_geometry_validation.luau"})
  check(result.ok,"P1 full Base/V2/Hard catalog/world output freeze "..path..result.stderr)
 else
  check(old.ok and require("./helpers/m1_presentation_freeze")(old.stdout)==require("./helpers/m1_presentation_freeze")(fs.readFile(path)),"byte frozen "..path)
 end
end
-- Verify the normalizer actually rejects non-color changes and mixed statement edits.
check(normalize("b.TextColor3 = old\nb.Position = UDim2.fromScale(.5,.5)")~=normalize("b.TextColor3 = new\nb.Position = UDim2.fromScale(.4,.5)"),"layout mutation rejected")
check(normalize("b.TextColor3=old;b.Text='BACK'")~=normalize("b.TextColor3=new;b.Text='LEAVE'"),"localization mutation rejected")
check(normalize("b.TextColor3=old;b.Activated:Connect(open)")~=normalize("b.TextColor3=new;b.Activated:Connect(launch)"),"navigation mutation rejected")
local theme=luau.load(fs.readFile("src/shared/KDMUiTheme.luau"),{environment={Color3=rb.Color3}})()
check(table.isfrozen(theme),"semantic theme frozen")
local room=fs.readFile("src/client/MatchRoomUiController.luau")
check(room:find('if backText == "LEAVE" then Theme.Danger else Theme.Panel',1,true)~=nil,"only Leave dangerous")
local prep=fs.readFile("src/client/TacticalLoadoutController.luau")
check(prep:find('Theme.PrimaryAction,Theme.Background',1,true)~=nil and prep:find('then Theme.Ready else Theme.Panel',1,true)~=nil,"confirm/ready semantic ownership")
-- Real Garage fixture asserts geometry, touch, navigation, orbit and localization.
require("./garage_transition_validation")
print("PASS: "..count.." palette scope/freeze checks + production Garage regression")
