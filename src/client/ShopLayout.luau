-- CoreUISafeInsets coordinates. Shared Garage/Profile visual tokens; no style framework.
local Layout={}
function Layout.colors()
 return {Background=Color3.fromRGB(16,27,45),Panel=Color3.fromRGB(18,34,54),Card=Color3.fromRGB(27,52,75),
  Light=Color3.fromRGB(35,62,84),Cyan=Color3.fromRGB(0,203,232),Yellow=Color3.fromRGB(255,218,67),
  Blue=Color3.fromRGB(39,137,240),White=Color3.fromRGB(240,245,252),Secondary=Color3.fromRGB(168,197,217)}
end
function Layout.style(object,kind)
 local c=Layout.colors();object.BackgroundColor3=c[kind or 'Card'];object.BorderSizePixel=0
 local corner=Instance.new('UICorner');corner.Name='ArcadeCorner';corner.CornerRadius=UDim.new(0,6);corner.Parent=object
 local stroke=Instance.new('UIStroke');stroke.Name='ArcadeStroke';stroke.Color=c.Secondary;stroke.Transparency=.7;stroke.Thickness=1
 stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=object
 return stroke
end
function Layout.gridForWidth(width,availableHeight)
 local columns=if width>=1000 then 4 elseif width>=680 then 3 else 2
 local gap=10;local cardWidth=math.min(220,math.floor((width-(columns-1)*gap)/columns))
 local height=if availableHeight then math.clamp(math.floor(availableHeight),98,164) else 164
 local icon=if height<128 then 40 elseif height<150 then 56 else 72
 return {columns=columns,gap=gap,width=cardWidth,height=height,icon=icon,nameY=if icon==72 then 82 else icon+6,countY=if icon==72 then 106 else icon+24,priceY=if icon==72 then 130 else icon+40}
end
function Layout.forSize(size)
 local w,h=math.min(1140,math.max(240,size.X)),math.min(if size.Y>=440 then 560 else 680,math.max(176,size.Y))
 local compact=h<260
 return {margin=8,width=w-16,height=h-16,header=44,tabsY=52,tabsHeight=44,
  bodyY=100,bodyHeight=if compact then h-124 else h-152,footerY=h-44,footerHeight=if compact then 0 else 32,
  tabWidth=(w-40)/3,confirmWidth=math.min(420,w-32),confirmHeight=math.min(176,h-16),
  previewHeight=math.clamp((h-152)*.75,110,300),cardHeight=164,compact=compact}
end
-- Mobile landscape first: six choices and the selected action share the safe body.
-- Optional B is a layout comparison only; production uses the Studio-validated A.
function Layout.itemsForSize(size,variant)
 local l=Layout.forSize(size);local w=l.width-16;local h=l.bodyHeight
 local mobile=size.Y<440;local gap=8
 local detail=if mobile then 194 else 296
 local bottom=variant=='B'
 local gridWidth=if bottom then w else w-detail-gap
 local gridHeight=if bottom then h-52 else h
 local columns=if mobile then 3 else 4
 local cardWidth=math.min(if mobile then 190 else 220,math.floor((gridWidth-8-(columns-1)*gap)/columns))
 local cardHeight=math.min(164,math.floor((gridHeight-gap)/2))
 return {mode=if bottom then 'B' else 'A',mobile=mobile,columns=columns,gap=gap,width=cardWidth,height=cardHeight,
  gridWidth=gridWidth,gridHeight=gridHeight,detailX=if bottom then 8 else 8+gridWidth+gap,
  detailY=if bottom then l.bodyY+h-44 else l.bodyY,detailWidth=if bottom then w else detail,detailHeight=if bottom then 44 else h}
end
return Layout
