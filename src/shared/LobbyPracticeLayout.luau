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
 local padLeft=size.X-drive.margin-drive.padWidth-drive.padInset
 local driftTop=size.Y-drive.driftBottom-drive.driftHitHeight
 local y=(walletBottom or 58)+6
 local height=rows*(cell+6)-6
 local boostY=y+height+4
 local boostTextHeight=if compact then 16 else 22
 local gaugeY=boostY+boostTextHeight+2
 local gaugeHeight=if compact then 6 else 9
 local messageY=gaugeY+gaugeHeight+4
 local messageHeight=if compact then 14 else 20
 -- Very short windows use the middle lane beside Drift, with scrollable items.
 local x=if messageY+messageHeight>driftTop-2 then drive.driftX+drive.driftHitWidth+12 else 12
 local padTop=size.Y-drive.padBottom-drive.padHeight
 local right=if messageY+messageHeight>padTop then padLeft-12 else size.X-12
 local width=math.min(content,math.max(cell,right-x))
 return {x=x,y=y,width=width,height=height,content=content,
  cell=cell,columns=columns,compact=compact,messageHeight=if compact then 14 else 20,
  boostY=boostY,boostTextHeight=boostTextHeight,gaugeY=gaugeY,gaugeHeight=gaugeHeight,messageY=messageY}
end
return Layout
