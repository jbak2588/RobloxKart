local fs,luau,r=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local G=luau.load(fs.readFile('src/client/V2DonorGauge.luau'))()
local checks=0
local function check(ok,message) assert(ok,message);checks+=1 end
local template=r.deserializeModel(fs.readFile('src/client/V2DonorGaugeTemplate.rbxmx'))[1]
for _,g in {template,table.unpack(template:GetDescendants())} do
	check(not g:IsA('LuaSourceContainer'),'no donor executable scripts')
	if g:IsA('GuiObject') then check(not g.Active and not g.Selectable,'passive template') end
end
for _,name in {'Tach','Speedo','Gear','TMode','Speed','ln'} do check(template:FindFirstChild(name)~=nil,'original hierarchy '..name) end
check(template.Tach.Needle.Frame.Size.Y.Offset==110 and template.TMode.Text=='A/T','original needle/mode retained')
for _,size in {{750,361},{749,361},{749,302},{844,332},{932,372},{1920,1080},{1366,768}} do
	local mobile=size[1]<1000;local l=G.layout(size[1],size[2],mobile)
	check(l.visible and l.y==size[2]-14,'bottom 14px')
	check(l.x-l.width/2>=0 and l.x+l.width/2<=size[1] and l.y-l.height>=0,'safe root bounds')
	if mobile then
		local right=size[1]-20-(math.clamp(size[2]*.15,44,56)*3+24)
		check(l.x+l.width/2<=right-8,'8px Digital Pad gap')
		check(l.x-l.width/2>=176,'outside bottom Drift/action lane')
	end
end
local l=G.layout(750,361,true);check(l.width>=280 and l.width<=320 and l.height>=80 and l.height<=100,'requested footprint')
check(not G.layout(390,749,true).visible,'portrait suppresses unsuitable original layout')
local hud=fs.readFile('src/client/RaceHudController.luau')
check(hud:find('steeringDisplay.Visible = false;wheelClip.Visible = false',1,true)~=nil,'steering hidden only under experiment')
check(hud:find('KDMV2DonorHideTopSpeed',1,true)~=nil and hud:find('if not raceHudActive then',1,true)~=nil,'top hide does not disable donor update')
print('PASS: '..checks..' original gauge/layout checks')
