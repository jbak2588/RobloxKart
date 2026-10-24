local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local V=luau.load(fs.readFile('src/client/MobileControlView.luau'),{environment={Color3=rb.Color3,Vector2=rb.Vector2}})()
local count=0
local function check(v,label) assert(v,label); count+=1 end
local function overlaps(a,b) return a[1]<b[3] and b[1]<a[3] and a[2]<b[4] and b[2]<a[4] end
for _,pair in {{750,283},{749,361},{844,390},{932,430},{749,303},{724,311},{640,360}} do
 local s=rb.Vector2.new(pair[1],pair[2]); local l=V.layout(s)
 local m=V.minimapLayout(s,-58)
 local map={m.x,m.y,m.x+m.side,m.y+m.side}
 local i=V.inviteLayout(s,m.x,m.y,m.side,m.side,true)
 local invite={i.x,i.y,i.x+i.width,i.y+i.height}
 local room={12,i.statusY,192,i.statusY+22}
 local steer={l.steerLeftX,s.Y-l.steerBottom-l.steerHeight,l.steerLeftX+l.steerTotalWidth,s.Y-l.steerBottom}
 local drift={l.rightDriftX,s.Y-l.rightDriftBottom-l.driftHitHeight,l.rightDriftX+l.driftHitWidth,s.Y-l.rightDriftBottom}
 local reverse={l.rightBrakeX,s.Y-l.rightBrakeBottom-l.brake,l.rightBrakeX+l.brake,s.Y-l.rightBrakeBottom}
 local items=V.itemLayout(s,6)
 local row={items.x,items.top,items.x+items.width,items.secondTop+l.slot}
 local progress={items.x,items.progressTop,items.x+items.width,items.progressTop+items.progressHeight}
 local gauge={l.rightDriftX+l.driftHitWidth/2-l.driftWidth*.65/2,drift[2]-22,
  l.rightDriftX+l.driftHitWidth/2+l.driftWidth*.65/2,drift[2]-10}
 local panel={i.panelX,i.panelY,i.panelX+i.panelWidth,i.panelY+52+i.rows*28}
 check(i.x==12 and i.y==i.statusY+26,'social controls use former left item lane')
 check(items.x==s.X-12-items.width,'six items align with right safe edge')
 check(row[2]>=0 and progress[4]<=gauge[2]-3,'item rows and Nitro progress above Drift gauge')
 check(drift[4]==reverse[4] and reverse[3]+8==drift[1],'Drift and reverse share bottom row with gap')
 check(drift[4]<=s.Y-12 and drift[3]-drift[1]>=132 and reverse[3]-reverse[1]>=44,'right controls fit safe touch sizes')
 local blocks={row,progress,gauge,drift,reverse,steer,room,invite,map,panel}
 for index,rect in blocks do
  check(rect[1]>=0 and rect[3]<=s.X and rect[2]>=-58 and rect[4]<=s.Y,'safe rectangle '..index..' '..tostring(s))
  for other=index+1,#blocks do
   check(not overlaps(rect,blocks[other]),'no item/control/social/map/panel overlap '..index..'/'..other..' '..tostring(s))
  end
 end
 local wheel={s.X*.5-l.wheel*.5,s.Y-3-l.wheel*2/3,s.X*.5+l.wheel*.5,s.Y-3}
 for _,rect in {row,progress,gauge,drift,reverse,steer,invite,map,panel} do
  check(not overlaps(rect,wheel),'mobile controls clear speed gauges')
 end
 check(m.y==-56,'map retains speed topbar baseline')
 check(l.driveVisualSize>=44 and l.direction>=l.driveVisualSize*V.artwork.driveWidth+4 and l.brake>=44,'minimum control targets')
 check(l.padGap==4,'nonoverlapping hitbox gap')
end
check(V.minimapLayout(rb.Vector2.new(749,303)).side==96,'short-phone 96px map')
check(V.minimapLayout(rb.Vector2.new(844,390)).side==112,'844x390 112px map')
check(V.minimapLayout(rb.Vector2.new(932,430)).side==112,'932x430 112px map')
local colors={}
for _,id in {'Nitro','Shield','Slick','Missile','Thunder','Smoke'} do
 local color=V.itemAccent(id); check(not colors[tostring(color)],'distinct accent '..id); colors[tostring(color)]=true
end
print('PASS: '..count..' mobile HUD safe layout and accent checks')
