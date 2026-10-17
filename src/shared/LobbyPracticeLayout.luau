-- Six direct practice buttons; horizontal scrolling retains 44px targets on tiny screens.
local Layout={}
function Layout.compute(size,drive,walletBottom)
 local compact=size.Y<340
 local cell=if compact then 44 else 48
 local columns=if compact then 6 else 3
 local rows=if compact then 1 else 2
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
 local width=math.min(content,math.max(cell,padLeft-x-12))
 return {x=x,y=y,width=width,height=height,content=content,
  cell=cell,columns=columns,compact=compact,messageHeight=if compact then 14 else 20,
  boostY=boostY,boostTextHeight=boostTextHeight,gaugeY=gaugeY,gaugeHeight=gaugeHeight,messageY=messageY}
end
return Layout
