local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local appearance = luau.load(fs.readFile("src/shared/DriverAppearance.luau"))()
local count=0
local function check(v,s) assert(v,s);count+=1 end
local character=rb.Instance.new("Model")
local colors=rb.Instance.new("BodyColors");colors.Parent=character
colors.TorsoColor3=rb.Color3.fromRGB(30,140,80)
colors.LeftArmColor3=rb.Color3.fromRGB(250,210,150)
local hat=rb.Instance.new("Accessory");hat.Name="MyHat";hat.AccessoryType=rb.Enum.AccessoryType.Hat;hat.Parent=character
local hair=rb.Instance.new("Accessory");hair.Name="MyHair";hair.AccessoryType=rb.Enum.AccessoryType.Hair;hair.Parent=character
for _,accessory in {hat,hair} do local part=rb.Instance.new("Part");part.Name="Handle";part.Transparency=.25;part.Parent=accessory end
local shirt=rb.Instance.new("Shirt");shirt.ShirtTemplate="rbxassetid://123";shirt.Parent=character
local pants=rb.Instance.new("Pants");pants.PantsTemplate="rbxassetid://456";pants.Parent=character
local original=rb.serializeModel({character})
for _,theme in {rb.Color3.new(1,0,0),rb.Color3.new(0,0,1),rb.Color3.new(1,1,0)} do
 appearance.applyToCharacter(character,{Theme=theme});appearance.applyHairStyle(character)
 check(rb.serializeModel({character})==original,"Avatar identity byte-for-byte preserved across legacy themes")
 check(colors.TorsoColor3==rb.Color3.fromRGB(30,140,80),"body colors preserved")
 check(hat.Handle.Transparency==.25 and hair.Handle.Transparency==.25,"accessory transparency preserved")
 check(shirt.ShirtTemplate=="rbxassetid://123" and pants.PantsTemplate=="rbxassetid://456","clothing preserved")
end
local empty=rb.Instance.new("Model");appearance.applyToCharacter(empty,{})
check(#empty:GetChildren()==0,"compatibility call adds no synthetic identity")
print("PASS: "..count.." Avatar identity checks")
