-- Attacks on row one; Nitro/Shield on row two. Scroll only on tiny viewports.
local Layout={}
local positions={Slick={0,0},Missile={1,0},Smoke={2,0},Thunder={3,0},Nitro={0,1},Shield={1,1}}
function Layout.itemPosition(id,cell)
 local p=positions[id]
 return p[1]*(cell+6),p[2]*(cell+6)
end
function Layout.compute(size,drive,walletBottom)
 local compact=size.Y<340
 local cell=if compact then 44 else 48
 local columns,rows=4,2
 local content=columns*(cell+6)-6
 local height=rows*(cell+6)-6
 local boostTextHeight=if compact then 16 else 22
 local gaugeHeight=if compact then 6 else 9
 local messageHeight=if compact then 14 else 20
 local rightTop=size.Y-drive.rightDriftBottom-math.max(drive.brake,drive.driftHitHeight)
 local messageY=rightTop-28-messageHeight
 local gaugeY=messageY-4-gaugeHeight
 local boostY=gaugeY-2-boostTextHeight
 local y=boostY-4-height
 local width=content
 local x=size.X-12-width
 -- An exceptionally short canvas uses a scrollable lane to the left of Drift.
 if y<4 then
  x=drive.steerLeftX+drive.steerTotalWidth+12
  width=math.max(cell,drive.rightDriftX-x-8)
  y=4;boostY=y+height+4;gaugeY=boostY+boostTextHeight+2;messageY=gaugeY+gaugeHeight+4
 end
 return {x=x,y=y,width=width,height=height,content=content,
  cell=cell,columns=columns,compact=compact,messageHeight=if compact then 14 else 20,
  boostY=boostY,boostTextHeight=boostTextHeight,gaugeY=gaugeY,gaugeHeight=gaugeHeight,messageY=messageY}
end
return Layout
