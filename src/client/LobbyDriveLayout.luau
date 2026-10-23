-- Lobby-only safe layout. Race artwork/inset positioning is left unchanged.
local Layout={}
function Layout.apply(l,size)
 l.padBottom=12
 l.driftBottom=12
 l.driftX=12
 l.padInset=0
 -- Fit the full hitboxes and two shortcut rows, even on short safe viewports.
 local scale=math.min(1,math.max(0.5,(size.Y-100)/l.padHeight))
 for _,key in {"padWidth","padHeight","forward","brake","sideWidth","sideHeight","sideVisualWidth","driveVisualSize","autoHitSize","autoVisualSize","autoRight","autoTop"} do l[key]*=scale end
 l.steerLeftX=12
 l.steerBottom=12
 l.steerTotalWidth=l.sideWidth*2+8
 l.steerHeight=l.sideHeight
 l.rightPadWidth=l.driftHitWidth+8+l.brake
 l.rightPadX=size.X-12-l.rightPadWidth
 l.rightBrakeX=l.rightPadX+l.driftHitWidth+8
 l.rightBrakeBottom=12
 l.rightDriftX=l.rightPadX
 l.rightDriftBottom=l.rightBrakeBottom
 if size.X<l.steerLeftX+l.steerTotalWidth+8+l.rightPadWidth+12 and size.Y>size.X then
  l.rightBrakeBottom=l.steerBottom+l.steerHeight+8
  l.rightDriftBottom=l.rightBrakeBottom
 end
 if size.X<l.driftHitWidth+l.padWidth+36 and size.Y>size.X then l.driftBottom=l.padBottom+l.padHeight+100 end
 return l
end
function Layout.shortcuts(size,view)
 local l=Layout.apply(view.layout(size),size)
 return {x=12,y=if size.Y<340 then 64 else 100,width=math.min(210,l.steerTotalWidth,size.X-(l.slot*4+18)-32),height=80}
end
-- Coordinates are relative to the same CoreUISafeInsets canvas as the wallet.
function Layout.trainingHud(size,walletLeft,walletBottom,driftLeft,driftHitWidth,driftVisualWidth)
 local x=walletLeft or 16
 return {x=x,y=(walletBottom or 58)+12,width=math.min(230,size.X-x-12),
  exitX=(driftLeft or 12)+math.max(0,((driftHitWidth or 0)-(driftVisualWidth or 0))/2)}
end
return Layout
