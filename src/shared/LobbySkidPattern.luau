-- Fixed, deterministic cosmetic paths; never accumulated player history.
local Pattern={}
function Pattern.paths()
 local paths={}
 local function curve(kind,count,opacity,width,fn)
  local points={}
  for i=0,count do local x,z=fn(i/count);table.insert(points,{x=x-120,z=z-766}) end
  table.insert(paths,{kind=kind,points=points,opacity=opacity,width=width})
 end
 local function circle(kind,x,z,r,count,opacity,width,from,to)
  curve(kind,count,opacity,width,function(t)
   local a=from+(to-from)*t;return x+r*math.cos(a),z+r*math.sin(a)
  end)
 end
 circle("LargeArc",110,770,83,36,.30,.42,math.pi*.85,math.pi*2.25)
 circle("OldLargeArc",113,773,89,32,.14,.34,math.pi*.9,math.pi*2.2)
 curve("S",34,.34,.42,function(t) return -35+340*t,764+58*math.sin(t*math.pi*2) end)
 curve("OldS",28,.13,.32,function(t) return -30+332*t,768+53*math.sin(t*math.pi*2+.08) end)
 curve("FigureEight",40,.28,.40,function(t)
  local a=t*math.pi*2;return 180+75*math.sin(a),778+37*math.sin(a*2)
 end)
 circle("Circle",240,756,39,36,.25,.40,0,math.pi*2)
 circle("LeftWingCircle",-155,904,35,36,.29,.42,0,math.pi*2)
 circle("RightWingCircle",306,902,53,44,.30,.42,0,math.pi*2)
 circle("OldRightArc",301,904,58,26,.13,.32,-.4,math.pi*1.4)
 return paths
end
function Pattern.tirePoint(path,index,offset)
 local points=path.points;local count=#points
 local first,last=points[1],points[count]
 local closed=math.abs(first.x-last.x)+math.abs(first.z-last.z)<1e-6
 local before=points[if closed and index==1 then count-1 else math.max(1,index-1)]
 local after=points[if closed and index==count then 2 else math.min(count,index+1)]
 local dx,dz=after.x-before.x,after.z-before.z
 local length=math.sqrt(dx*dx+dz*dz);local p=points[index]
 return p.x-dz/length*offset,p.z+dx/length*offset
end
return Pattern
