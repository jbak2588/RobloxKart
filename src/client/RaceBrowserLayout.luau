-- Logical UI pixels: readable type and 44px+ targets without shrinking text.
local Layout={}
function Layout.measure(width,height)
 local mobile=width<1000 or height<550
 local w=math.min(960,math.max(0,width-24))
 local h=math.min(700,math.max(0,height-16))
 local stacked=w<460
 return {width=w,height=h,title=if mobile then 22 else 28,body=if mobile then 16 else 18,
  detail=if mobile then 14 else 16,button=if mobile then 16 else 18,
  thumb=if stacked then 52 elseif mobile then 56 else 72,
  row=if stacked then 160 elseif mobile then 112 else 120,
  action=if mobile then 112 else 144,stacked=stacked,listTop=94,listBottom=72}
end
return Layout
