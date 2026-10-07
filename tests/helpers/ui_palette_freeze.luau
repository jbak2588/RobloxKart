-- K2 permits colors, not layout/navigation. Compare all non-color statements
-- and retain mixed-assignment fields that set stroke behavior or parenting.
local function canonical(source)
 source=source:gsub("\r\n","\n")
 source=source:gsub("local GARAGE_COLORS = %b{}", "local GARAGE_COLORS = {}")
 source=source:gsub("entries%[definition%[1%]%] = {plate=plate, surface=surface, text=text, arrow=arrow, outline=outline}",
  "entries[definition[1]] = {plate=plate, surface=surface, text=text, arrow=arrow}")
 local result={}
 for line in source:gmatch("[^\n]+") do
  line=line:gsub("%-%-.*$", "")
  line=line:gsub("Theme%.%w+", "PALETTE"):gsub("theme%.%w+", "PALETTE")
  -- Color gradients are palette statements; rotation and lifecycle stay compared.
  if line:match("^%s*visualGradient%(") then continue end
  if line:match('^%s*local Theme%s*=') then continue end
  -- Mixed assignments with frozen non-color suffixes.
  line=line:gsub("stroke%.Color, stroke%.ApplyStrokeMode, stroke%.Parent = .-, Enum%.ApplyStrokeMode%.Border, button",
   "stroke.ApplyStrokeMode, stroke.Parent = Enum.ApplyStrokeMode.Border, button")
  line=line:gsub("outline%.Color, outline%.Thickness, outline%.Parent = .-, 3, stroke",
   "outline.Thickness, outline.Parent = 3, stroke")
  local statements={}
  for statement in line:gmatch("[^;]+") do
   -- Only a complete color-property assignment may be excluded. Statements
   -- sharing a line (Font, Text, Active, etc.) are still compared.
   local lhs=statement:match("^%s*(.-)%s*=")
   local colorOnly=lhs~=nil
   if lhs then
    for field in lhs:gmatch("[^,]+") do
     if not (field:match("%.BackgroundColor3%s*$") or field:match("%.TextColor3%s*$") or field:match("%.Color%s*$")) then colorOnly=false end
    end
   end
   if not colorOnly then table.insert(statements,(statement:gsub("%s+",""))) end
  end
  local normalized=table.concat(statements,";")
  if normalized~="" then table.insert(result,normalized) end
 end
 return table.concat(result,"\n")
end
return canonical
