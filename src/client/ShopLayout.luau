-- All coordinates are relative to the CoreUISafeInsets root; no second inset subtraction.
local Layout={}
function Layout.forSize(size)
 local w,h=math.max(240,size.X),math.max(176,size.Y)
 local compact=h<260
 return {margin=8,width=w-16,height=h-16,header=44,tabsY=56,tabsHeight=44,
  bodyY=108,bodyHeight=if compact then h-132 else h-180,footerY=h-64,footerHeight=if compact then 0 else 40,
  tabWidth=(w-40)/3,confirmWidth=math.min(400,w-32),confirmHeight=math.min(176,h-16),
  previewHeight=math.clamp(h*.42,140,220),cardHeight=112}
end
return Layout
