local fs,luau,rb,process=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/process')
local checks=0
local function check(ok,label) assert(ok,label);checks+=1 end
local stable='6903d20737c5e63711f785b9b238f2c017b412e9'
for _,path in {'src/shared/AudioConfig.luau','src/client/KartInputController.luau'} do
 local result=process.exec('git',{'show',stable..':'..path})
 check(result.ok and fs.readFile(path):gsub('\r\n','\n')==result.stdout:gsub('\r\n','\n'),'stable exact equality '..path)
end
for _,name in {'V2DonorAudio','KDMMultiRpmEngineAudio','KDMEnginePowertrainPresentation','V2DonorExperiment'} do
 check(not fs.isFile('src/client/'..name..'.luau'),'failed audio experiment absent '..name)
end
local P=luau.load(fs.readFile('src/client/V2GaugePresentation.luau'))()
local env={Vector2=rb.Vector2,Enum=rb.Enum}
local G=luau.load(fs.readFile('src/client/V2DonorGauge.luau'),{environment=env})()
local model=P.new()
for _,speed in {0,10,30,50,70,100,70,0} do
 local state
 for _=1,240 do state=model:update(speed,1/60) end
 check(math.abs(state.speedKmh-speed*1.008)<1e-8,'actual speed conversion')
 check(state.rpm>=700 and state.rpm<=7000 and state.rpm==state.rpm,'finite donor visual RPM')
 check(state.gear==nil and state.Gear==nil,'no displayed gear state')
 if speed==70 then check(math.abs(state.rpm-2500)<1,'normal 70 visual RPM') end
end
for _,mode in {{true,false,5000},{false,true,7000}} do
 local m=P.new();local state
 for _=1,240 do state=m:update(100,1/60,mode[1],mode[2]) end
 check(math.abs(state.rpm-mode[3])<1,'boost/nitro peak')
 local previous=state.rpm
 for speed=99,70,-1 do
  state=m:update(speed,.1,false,false)
  check(state.rpm<=previous,'deceleration synchronized down');previous=state.rpm
 end
 for _=1,120 do state=m:update(70,1/60,false,false) end
 check(math.abs(state.rpm-2500)<1,'returns to normal after boost')
end
local template=rb.deserializeModel(fs.readFile('src/client/V2DonorGaugeTemplate.rbxmx'))[1]
for _,v in {template,table.unpack(template:GetDescendants())} do
 check(not v:IsA('LuaSourceContainer'),'no donor executable code')
 if v:IsA('GuiObject') then check(not v.Active and not v.Selectable,'passive artwork') end
end
local function gui(class,p,s,parent)
 local o={ClassName=class,Visible=true,BackgroundTransparency=1,TextTransparency=0,Text='',
  TextBounds=rb.Vector2.zero,TextXAlignment=rb.Enum.TextXAlignment.Center,TextYAlignment=rb.Enum.TextYAlignment.Center,
  AbsolutePosition=rb.Vector2.new(p[1],p[2]),AbsoluteSize=rb.Vector2.new(s[1],s[2]),Rotation=0,AbsoluteRotation=0,Parent=parent}
 function o:IsA(c) return c=='GuiObject' or c==self.ClassName end
 return o
end
local root=gui('Frame',{200,200},{300,93.75},{})
local painted=gui('Frame',{220,260},{20,10},root);painted.BackgroundTransparency=0
local transparent=gui('Frame',{200,200},{300,93.75},root)
local hidden=gui('TextLabel',{200,900},{40,20},root);hidden.Visible=false;hidden.Text='GEAR';hidden.TextBounds=rb.Vector2.new(40,20)
local zeroText=gui('TextLabel',{240,270},{0,0},root);zeroText.Text='0';zeroText.TextBounds=rb.Vector2.new(10,12)
local bounds=G.visualBounds(root,{painted,transparent,hidden,zeroText})
check(bounds.maxY==276 and bounds.minY==260,'painted content excludes padding/hidden but includes zero-size glyphs')
local pivot=gui('Frame',{250,250},{0,0},root);pivot.Rotation=90
local needle=gui('Frame',{250,250},{4,100},pivot);needle.BackgroundTransparency=0
needle.AbsoluteRotation=90
local rotated=G.visualBounds(root,{needle})
check(math.abs(rotated.minX-202)<1e-8 and math.abs(rotated.maxY-302)<1e-8,'rotated painted bounds')
root.Visible=false;check(G.visualBounds(root,{painted})==nil,'hidden root paints nothing')
for _,s in {{750,361},{749,361},{749,303},{844,390},{932,430},{1920,1080}} do
 local l=G.layout(s[1],s[2],s[1]<1000)
 check(l.width<=300 and l.width>=190 and l.height==l.width*200/640 and l.visible,'donor aspect preserved in the space beside enlarged Drift')
 local visibleBottomOffset=-17
 local rootBottom=l.y-visibleBottomOffset
 check(s[2]-(rootBottom+visibleBottomOffset)==10,'visible-content alignment, not root padding')
end
for _,file in {'V2GaugeController','V2GaugePresentation','V2DonorGauge'} do
 local source=fs.readFile('src/client/'..file..'.luau')
 for _,forbidden in {'SoundId','PlaybackSpeed','TimePosition','KartAudioController','290290922','AssemblyLinearVelocity =','FireServer'} do
  check(not source:find(forbidden,1,true),'visual-only boundary '..file..' '..forbidden)
 end
end
local source=fs.readFile('src/client/V2DonorGauge.luau')
check(source:find('root.Gear.Visible=false;root.TMode.Visible=true',1,true)~=nil,'gear hidden and A/T restored')
check(source:find('root.TMode.Text="A/T"',1,true)~=nil,'A/T text explicit')
check(source:find('root.TMode.Position=UDim2.fromOffset(137,173)',1,true)~=nil,'A/T inside Tach footprint')
for _,contract in {'value.Font=Enum.Font.GothamBlack;value.TextSize=40','unit.TextSize=28','DigitalSpeedGroup','label.TextYAlignment=Enum.TextYAlignment.Bottom'} do
 check(source:find(contract,1,true)~=nil,'D4 split typography '..contract)
end
print('PASS: '..checks..' V1 exact audio / gauge independence / painted bounds checks')
