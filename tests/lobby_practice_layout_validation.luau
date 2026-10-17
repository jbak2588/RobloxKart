local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local mobile=luau.load(fs.readFile('src/client/MobileControlView.luau'),{environment={Color3=rb.Color3,Vector2=rb.Vector2}})()
local drive=luau.load(fs.readFile('src/client/LobbyDriveLayout.luau'))()
local layout=luau.load(fs.readFile('src/shared/LobbyPracticeLayout.luau'))()
local n=0;local function check(v,label)assert(v,label);n+=1 end
local function overlap(a,b)return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h end
for _,s in {{932,390},{844,300},{748,303},{724,311},{801,334},{667,250},{480,210},{390,780},{1920,1080},{1280,720}}do
 local size=rb.Vector2.new(s[1],s[2]);local l=drive.apply(mobile.layout(size),size)
 local a=layout.compute(size,l,58)
 check(a.cell>=44,'touch targets at least 44px')
 check(a.columns==4 and a.height==a.cell*2+6,'always two rows with room for four attacks')
 check(a.x>=0 and a.y>=0 and a.x+a.width<=size.X and a.y+a.height<=size.Y,'practice panel within safe area')
 local panel={x=a.x,y=a.y,w=a.width,h=a.height}
 local message={x=a.x,y=a.messageY,w=a.width,h=a.messageHeight}
 local boost={x=a.x,y=a.boostY,w=a.width,h=a.boostTextHeight}
 local gauge={x=a.x,y=a.gaugeY,w=a.width,h=a.gaugeHeight}
 check(boost.y>=panel.y+panel.h+4,'Boost charge text below every item row')
 check(gauge.y>=boost.y+boost.h+2 and gauge.h>=6,'five-segment gauge visible below charge text')
 check(message.y>=gauge.y+gauge.h+4,'combat/Nitro feedback below Boost gauge')
 check(message.y>=a.y+a.height and message.y+message.h<=size.Y,'message clear of item buttons')
 local pad={x=size.X-l.margin-l.padWidth-l.padInset,y=size.Y-l.padBottom-l.padHeight,w=l.padWidth,h=l.padHeight}
 local drift={x=l.driftX,y=size.Y-l.driftBottom-l.driftHitHeight,w=l.driftHitWidth,h=l.driftHitHeight}
 check(not overlap(panel,pad)and not overlap(panel,drift),'item buttons clear all driving hitboxes')
 check(not overlap(message,pad)and not overlap(message,drift),'feedback clears driving hitboxes')
 check(not overlap(boost,pad)and not overlap(boost,drift)and not overlap(gauge,pad)and not overlap(gauge,drift),'Boost text and gauge clear driving hitboxes')
 local shortcuts=drive.shortcuts(size,mobile)
 check(not overlap(panel,{x=shortcuts.x,y=shortcuts.y,w=shortcuts.width,h=shortcuts.height}),'items clear exit/shortcuts')
 for _,id in {'Slick','Missile','Smoke','Thunder','Nitro','Shield'}do
  local x,y=layout.itemPosition(id,a.cell)
  check(x>=0 and x+a.cell<=a.content and y+a.cell<=a.height,'all six buttons accessible in scroll content')
  check(y==(if id=='Nitro'or id=='Shield'then a.cell+6 else 0),'attacks top row, Nitro/Shield second row')
 end
end
print('PASS: '..n..' practice six-button safe-area / touch / scroll / driving nonoverlap checks')
