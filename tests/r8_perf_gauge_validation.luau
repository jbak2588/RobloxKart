local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local G=luau.load(fs.readFile('src/client/V2DonorGauge.luau'),{environment={Vector2=rb.Vector2,Enum=rb.Enum}})()
local n=0
local function check(v,label)assert(v,label);n+=1 end
for _,s in {{832,384},{932,430},{844,390},{724,260},{1920,1080}} do
 local l=G.layout(s[1],s[2],s[1]<1000)
 check(l.visible and l.width>=190 and l.width<=300,'mobile donor fits existing thumb-safe lane')
 check(l.y==s[2]-10 and l.scale==l.width/640,'existing scale and lower edge unchanged')
end
local source=fs.readFile('src/client/V2DonorGauge.luau')
check(source:find('if settle>0 then',1,true)~=nil,'bounds recomputed only in bounded settle window')
check(source:find('settle=3',1,true)~=nil,'three-frame text/layout settle after invalidation')
check(source:find('if not root.Visible then return false end',1,true)~=nil,'hidden gauge avoids all painted scans')
for _,key in {'size.X~=lastWidth','size.Y~=lastHeight','mobile~=lastMobile','root.Visible~=lastVisible'} do check(source:find(key,1,true)~=nil,'layout cache invalidation '..key) end
print('PASS: '..n..' gauge cache, viewport invalidation and existing mobile layout checks; real-engine timings reported separately')
