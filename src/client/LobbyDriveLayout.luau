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
 if size.X<l.driftHitWidth+l.padWidth+36 and size.Y>size.X then l.driftBottom=l.padBottom+l.padHeight+100 end
 return l
end
function Layout.shortcuts(size,view)
 local l=Layout.apply(view.layout(size),size)
 return {x=size.X-l.margin-l.padWidth,y=math.max(4,size.Y-l.padBottom-l.padHeight-88),width=l.padWidth,height=80}
end
return Layout
