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
 local y=(walletBottom or 58)+(if compact then 6 else 54)
 local width=math.min(content,math.max(cell,padLeft-24))
 return {x=12,y=y,width=width,height=rows*(cell+6)-6,content=content,
  cell=cell,columns=columns,compact=compact,messageHeight=if compact then 14 else 20,
  messageY=math.min(y+rows*(cell+6)-4,driftTop-(if compact then 14 else 20)-2)}
end
return Layout
