-- Isolation stub for unrelated exit/geometry tests. Full combat executes in lobby_practice_combat_validation.
local Module={}
function Module.new()
 local s={}
 for _,k in {'remove','add','recover','boost','update','destroy','use'}do s[k]=function()end end
 function s:physical()return self.hit==true end
 function s:isNitro()return false end
 function s:motion(_,_,_,_,_,v,y)return v,y end
 Module.last=s;return s
end
return Module
