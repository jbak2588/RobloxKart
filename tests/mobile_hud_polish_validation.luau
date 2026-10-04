local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local V=luau.load(fs.readFile('src/client/MobileControlView.luau'),{environment={Color3=rb.Color3,Vector2=rb.Vector2}})()
local count=0
local function check(v,label) assert(v,label); count+=1 end
local function overlaps(a,b) return a[1]<b[3] and b[1]<a[3] and a[2]<b[4] and b[2]<a[4] end
for _,pair in {{750,283},{749,361},{844,390},{932,430},{749,303},{724,311},{640,360}} do
 local s=rb.Vector2.new(pair[1],pair[2]); local l=V.layout(s)
 local top=s.Y-l.padBottom-l.padHeight; local left=s.X-l.margin-l.padWidth-l.padInset
 local m=V.minimapLayout(s,-58)
 local map={m.x,m.y,m.x+m.side,m.y+m.side}
 local i=V.inviteLayout(s,m.x,m.y,m.side,m.side,true); local invite={i.x,i.y,i.x+i.width,i.y+i.height}
 local pad={left,top,left+l.padWidth,s.Y-l.padBottom}
 check(invite[2]==m.y+m.side+34,'invite directly below Room status')
 check(not overlaps(invite,map),'invite clears minimap')
 -- The cluster bounding rectangle includes empty corner space.
 check(not overlaps(invite,map),'invite avoids minimap')

 check(i.x>=0 and i.x+i.width<=s.X and i.y>=0,'invite inside safe area')
 local panel={i.panelX,i.panelY,i.panelX+i.panelWidth,i.panelY+52+i.rows*28}
 check(not overlaps(panel,map),'open panel clears map')
 local wheel={s.X*.5-l.wheel*.5,s.Y-3-l.wheel*2/3,s.X*.5+l.wheel*.5,s.Y-3}
 check(not overlaps(map,wheel),'minimap clears Steering')
 check(m.x>=0 and m.y>=-58 and map[3]<=s.X-12 and map[4]<=s.Y-l.margin,'minimap topbar/safe containment')
 check(m.side>=92,'minimap readable minimum')
 check(m.y==-56,'map leaves 2px above the topbar speed baseline')
 local room={s.X-12-118,m.y+m.side+6,s.X-12,m.y+m.side+28}
 check(not overlaps(room,map) and not overlaps(room,invite),'map room invite stack')
 check(invite[2]==room[4]+6 or invite[3]<=left-4,'room/invite stack or adjacent safe lane')
 local directionTop=s.Y-l.padBottom-(l.padHeight+l.direction)/2
 local forwardX=left+(l.padWidth-l.forward)*.5
 local brakeX=left+(l.padWidth-l.brake)*.5
 local buttons={
  Forward={forwardX,top,forwardX+l.forward,top+l.forward},
  ForwardLeft={left,directionTop,left+l.direction,directionTop+l.direction},
  ForwardRight={left+l.padWidth-l.direction,directionTop,left+l.padWidth,directionTop+l.direction},
  BrakeReverse={brakeX,s.Y-l.padBottom-l.brake,brakeX+l.brake,s.Y-l.padBottom},
}
 for name,rect in buttons do check(not overlaps(map,rect),'minimap clears actual '..name); check(not overlaps(panel,rect),'panel clears actual '..name); check(not overlaps(invite,rect),'invite clears actual '..name) end
 local speed={s.X*.5-80,-58,s.X*.5+80,-2}
 check(not overlaps(map,speed) and not overlaps(invite,speed),'map/invite clear speed')
 check(not overlaps(panel,speed),'open panel clears speed')
 check(not overlaps(panel,wheel),'open panel clears wheel')
 local items=V.itemLayout(s,4); local row={items.x,s.Y-items.bottom-l.slot,items.x+items.width,s.Y-items.bottom}
 check(not overlaps(panel,row),'open panel clears items '..tostring(s)..' panel='..table.concat(panel,',')..' row='..table.concat(row,','))
 check(not overlaps(map,row),'minimap clears item row')
 local drift={l.driftX,s.Y-l.driftBottom-l.driftHitHeight,l.driftX+l.driftHitWidth,s.Y-l.driftBottom}
 local progress={items.x,items.progressTop,items.x+items.width,items.progressTop+items.progressHeight}
 check(not overlaps(map,drift) and not overlaps(map,progress),'minimap clears Drift/Nitro progress')
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
