local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local nodes=require('./helpers/practice_ui_nodes')
local function object(class)
 local o=nodes.object(class);o.props={}
 function o:GetPropertyChangedSignal(k)self.props[k]=self.props[k] or nodes.signal();return self.props[k]end
 function o:WaitForChild(k)return assert(self:FindFirstChild(k),k)end
 return o
end
local function child(p,class,name)local o=object(class);o.Name=name;o.Parent=p;return o end
local user={UserId=11700555357};local calls=0;local queue={};local now=0
local pg=object('PlayerGui');pg.ChildAdded=nodes.signal()
function user:WaitForChild()return pg end
local gui=child(pg,'ScreenGui','KDMMyProfile');gui.Enabled=true
local profile=child(gui,'Frame','DriverCard');profile.Visible=true;profile.Size=rb.UDim2.fromOffset(600,280)
child(profile,'TextButton','Close');child(profile,'TextLabel','Status')
local style={applyModalPanel=function()end,applyCloseButton=function()end,apply3DButton=function()end}
local services={Players={LocalPlayer=user},TextService={GetTextSize=function(_,t)return rb.Vector2.new(200,#(t or ""))end},
 ReplicatedStorage={WaitForChild=function()return {InvokeServer=function()calls+=1;return {status='FOUND',records={scoped={}}}end}end}}
local C=luau.load(fs.readFile('src/client/PersonalRecordsController.luau'),{environment={
 game={PlaceVersion=904,GetService=function(_,name)return services[name]end},script={Parent={WaitForChild=function()return 'style'end}},
 require=function()return style end,Instance={new=object},Vector2=rb.Vector2,UDim2=rb.UDim2,Color3=rb.Color3,Enum=rb.Enum,
 task={spawn=function(f)table.insert(queue,f)end},os={clock=function()return now end}}})()
local checks=0;local function check(v,s)assert(v,s);checks+=1 end
C.start();C.start();C.attachProfile(gui)
local button=profile:FindFirstChild('Records');local panel=profile:FindFirstChild('SavedRecords')
check(button~=nil and panel~=nil and not panel.Visible,'records are nested in profile, initially closed')
local count=0;for _,o in profile.children do if o.Name=='Records' then count+=1 end end
check(count==1,'start and attach are idempotent')
check(not pg:FindFirstChild('KDMCanaryPersonalRecords') and calls==0,'no separate header or automatic request')
button.Activated:Fire();check(panel.Visible and #queue==1,'profile action opens records once')
queue[1]();check(calls==1 and panel:FindFirstChild('ReadOnlyRecords').Text:find('No official finished race saved yet.',1,true),'existing read-only response rendered')
panel:FindFirstChild('Close').Activated:Fire();check(not panel.Visible and profile.Visible,'records close returns to profile')
button.Activated:Fire();check(panel.Visible and #queue==1,'cooldown reopens cached records without duplicate fetch')
profile.Visible=false;profile:GetPropertyChangedSignal('Visible'):Fire();check(not panel.Visible,'closing profile closes records')
profile.Visible=true;gui.Enabled=false;button.Activated:Fire();check(not panel.Visible,'hidden profile cannot query')
user.UserId=42
local other=child(pg,'ScreenGui','OrdinaryProfile');local card=child(other,'Frame','DriverCard');child(card,'TextButton','Close')
C.attachProfile(other);check(not card:FindFirstChild('Records') and calls==1,'noncanary gets no records UI or query')
print('PASS: '..checks..' profile Records gating, query, cooldown, close and duplicate lifecycle checks')
