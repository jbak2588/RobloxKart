local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function signal()
 local callbacks={};local s={}
 function s:Connect(f) local c={connected=true};function c:Disconnect() self.connected=false end;table.insert(callbacks,{f=f,c=c});return c end
 function s:Fire() for _,r in callbacks do if r.c.connected then r.f() end end end
 return s
end
local function object(class)
 local props={ClassName=class,Text='Label',AbsoluteSize=rb.Vector2.new(440,195),Activated=signal()};local signals={}
 local methods={GetPropertyChangedSignal=function(_,name) signals[name]=signals[name] or signal();return signals[name] end}
 return setmetatable({}, {__index=function(_,k)return methods[k] or props[k] end,__newindex=function(_,k,v) props[k]=v;if signals[k] then signals[k]:Fire() end end})
end
local measured=0
local textService={GetTextSize=function(_,text,size,font,bounds)
 measured+=1;local lines=0
 for line in (text..'\n'):gmatch('(.-)\n') do lines+=math.max(1,math.ceil(#line*7/bounds.X)) end
 return rb.Vector2.new(bounds.X,lines*size)
end}
local C=luau.load(fs.readFile('src/client/PersonalRecordsController.luau'),{environment={game={GetService=function(_,name) assert(name=='TextService','unexpected service or live access');return textService end},script={Parent={WaitForChild=function()return 'STYLE'end}},require=function()return {applyModalPanel=function()end,applyCloseButton=function()end}end,Instance={new=object},Enum=rb.Enum,UDim2=rb.UDim2,Vector2=rb.Vector2,Color3=rb.Color3}})()
local checks=0;local function check(v,s) checks+=1;assert(v,s) end
local p,l,connections=C.createRecordsPanel({})
l.Text=string.rep('Starting Racers 1 drivers + 1 bots | Boosts 11\n',35)..'LAST RACE\nLap 2 0:53.700\nFinish Position 1 / 1'
check(p.CanvasSize.Y.Offset>195,'long records have scroll range')
check(p.CanvasSize.Y.Offset==l.Size.Y.Offset+16,'last record and lower padding reachable')
local wide=l.Size.Y.Offset;p.AbsoluteSize=rb.Vector2.new(180,130)
check(l.Size.Y.Offset>wide,'narrow orientation rewraps complete text')
check(p.CanvasSize.Y.Offset>130,'short landscape remains scrollable')
p.AbsoluteSize=rb.Vector2.new(440,195);check(l.Size.Y.Offset==wide,'wide orientation restores wrap')
l.Text='RECORDS: ERROR';check(p.CanvasSize.Y.Offset<195,'failure response shrinks previous content')
l.Text='';check(p.CanvasSize.Y.Offset<195,'empty content does not retain old scroll range')
local last=measured;for _,c in connections do c:Disconnect() end;l.Text=string.rep('x',500);p.AbsoluteSize=rb.Vector2.new(200,130)
check(measured==last,'destroy cleanup stops text and size listeners')
print('PASS: '..checks..' long-record scroll range, responsive wrapping, shrink and lifecycle checks; live calls zero')
