local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local module={WaitForChild=function(self) return self end}
local controller=luau.load(fs.readFile('src/client/HubUiController.luau'),{environment={game={GetService=function() return module end},script={Parent=module},require=function() return {} end,Vector3=rb.Vector3,CFrame=rb.CFrame}})()
local n=0;local function check(v,s) assert(v,s);n+=1 end
local function factory(def)
 local model=rb.Instance.new('Model')
 local p=rb.Instance.new('Part');p.Size=rb.Vector3.new(4,2,8);p.CFrame=rb.CFrame.new(0,1,0);p.Parent=model
 for _,class in {'Script','LocalScript','ModuleScript','VehicleSeat','Seat','WeldConstraint','Sound','BodyVelocity','ProximityPrompt'} do local o=rb.Instance.new(class);o.Parent=model end
 return model
end
local a,b=rb.Instance.new('Model'),rb.Instance.new('Model')
local anchor=rb.Instance.new('Part');anchor.CFrame=rb.CFrame.new(4,.08,900)
local cyan=controller.createDisplay(a,anchor,{Id='Kart05'},{createVisual=factory})
local red=controller.createDisplay(b,anchor,{Id='Kart06'},{createVisual=factory})
check(cyan:GetAttribute('SelectedKartId')=='Kart05' and red:GetAttribute('SelectedKartId')=='Kart06','two independent client worlds')
for _,display in {cyan,red} do
 check(#display:GetDescendants()==1,'only safe visual part survives')
 for _,p in display:GetDescendants() do check(p:IsA('BasePart') and p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,'static visual safety');check(math.abs(p.CFrame.Position.Y-p.Size.Y/2-.08)<.001,'display rests on anchor floor') end
end
local yellow=controller.createDisplay(a,anchor,{Id='Kart08'},{createVisual=factory})
check(cyan.Parent==nil and #a:GetChildren()==1 and a.KDMClientMyKartDisplay==yellow,'replacement destroys old root')
check(red.Parent==b and red:GetAttribute('SelectedKartId')=='Kart06','other client not overwritten')
for _=1,6 do controller.createDisplay(a,anchor,{Id='Kart08'},{createVisual=factory});check(#a:GetChildren()==1,'no duplicates after refresh') end
print('Garage H2 Kart display validation PASS: '..n..' checks')
