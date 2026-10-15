local fs,luau,rb,process=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox"),require("@lune/process")
local prior=require("./helpers/ui_palette_freeze")
local m1=require("./helpers/m1_presentation_freeze")
local function normalize(s)return prior(m1(s))end
local count=0
local function check(v,label)assert(v,label);count+=1 end
local baseline="cefda9a48b2eef546b837371da18f61c0f1053be"
for _,name in {"GarageUiController","HubUiController","HubWorldGuidanceView","TacticalLoadoutController"} do
 local path="src/client/"..name..".luau"
 local old=process.exec("git",{"show",baseline..":"..path})
 check(old.ok and normalize(old.stdout)==normalize(fs.readFile(path)),"non-color source frozen "..name)
end

-- Verify the normalizer actually rejects non-color changes and mixed statement edits.
check(normalize("b.TextColor3 = old\nb.Position = UDim2.fromScale(.5,.5)")~=normalize("b.TextColor3 = new\nb.Position = UDim2.fromScale(.4,.5)"),"layout mutation rejected")
check(normalize("b.TextColor3=old;b.Text='BACK'")~=normalize("b.TextColor3=new;b.Text='LEAVE'"),"localization mutation rejected")
check(normalize("b.TextColor3=old;b.Activated:Connect(open)")~=normalize("b.TextColor3=new;b.Activated:Connect(launch)"),"navigation mutation rejected")
local theme=luau.load(fs.readFile("src/shared/KDMUiTheme.luau"),{environment={Color3=rb.Color3}})()
check(table.isfrozen(theme),"semantic theme frozen")
check(theme.Background == rb.Color3.fromRGB(18, 34, 64), "theme Background updated")
check(theme.Panel == rb.Color3.fromRGB(32, 60, 108), "theme Panel updated")
check(theme.Selection == rb.Color3.fromRGB(0, 220, 255), "theme Selection updated")
check(theme.PrimaryAction == rb.Color3.fromRGB(255, 212, 42), "theme PrimaryAction updated")
check(theme.PublicRace == rb.Color3.fromRGB(255, 122, 38), "theme PublicRace updated")
check(theme.Ready == rb.Color3.fromRGB(72, 228, 96), "theme Ready updated")
check(theme.Danger == rb.Color3.fromRGB(238, 64, 64), "theme Danger updated")
check(theme.TextPrimary == rb.Color3.fromRGB(255, 255, 255), "theme TextPrimary updated")
check(theme.TextSecondary == rb.Color3.fromRGB(205, 225, 250), "theme TextSecondary updated")
local room=fs.readFile("src/client/MatchRoomUiController.luau")
check(room:find('if backText == "LEAVE" then Theme.Danger else Theme.Panel',1,true)~=nil,"only Leave dangerous")
local prep=fs.readFile("src/client/TacticalLoadoutController.luau")
check(prep:find('Theme.PrimaryAction,Theme.Background',1,true)~=nil and prep:find('then Theme.Ready else Theme.Panel',1,true)~=nil,"confirm/ready semantic ownership")
-- Real Garage fixture asserts geometry, touch, navigation, orbit and localization.
require("./garage_transition_validation")
print("PASS: "..count.." palette scope/freeze checks + production Garage regression")
