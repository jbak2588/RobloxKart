-- Original template Terrain surface in bounded source modules.
local rows={}
for i=1,8 do for _,row in require(script.Parent:WaitForChild(string.format("SurfaceRows%02d",i))) do table.insert(rows,row)end end
return {SourceMinX=-1792,SourceMinZ=-1152,SourceStep=4,Width=608,Depth=448,BaseY=-8,Materials={"Sand","Sandstone","Rock","Slate","Ground","CrackedLava","Mud","Basalt","Limestone","LeafyGrass","Grass","Salt","Concrete","Asphalt"},Rows=rows}
