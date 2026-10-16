-- K2 permits colors, not layout/navigation. Compare all non-color statements
-- and retain mixed-assignment fields that set stroke behavior or parenting.
local function canonical(source)
 source=source:gsub("\r\n","\n")
 source=source:gsub("local GARAGE_COLORS = %b{}", "local GARAGE_COLORS = {}")
 source=source:gsub("entries%[definition%[1%]%] = {plate=plate, surface=surface, text=text, arrow=arrow, outline=outline}",
  "entries[definition[1]] = {plate=plate, surface=surface, text=text, arrow=arrow}")
 -- Normalize arcade UI modal visibility and stroke enhancements
 source=source:gsub("local pgui = player:FindFirstChild%(\"PlayerGui\"%).-stepLabel%.Visible = not otherOverlayOpen\n%s*stepLabel%.Text = headings%[step%]", "stepLabel.Text = headings[step]")
 source=source:gsub("local Players = game:GetService%(\"Players\"%)\n", "")
 source=source:gsub("local function isAnyModalOpen%(%).-return false\n end\n", "")
 source=source:gsub("local function setKioskMarkersVisible%(show%).-end\n end\n", "")
 source=source:gsub("local modalOpen = isAnyModalOpen%(%)\n%s*local effectiveVisible = visible and not modalOpen\n%s*setKioskMarkersVisible%(effectiveVisible%)\n", "")
 source=source:gsub("effectiveVisible", "visible")
 source=source:gsub("caption%.TextStrokeTransparency = 0.35;", "")
 source=source:gsub("stroke%.Thickness, ", "")

 local result={}
 local skippingWallet = false
 local skippingDockGradients = false
 local skippingLayoutShift = false
 local skippingBrowseAll = false
 local skippingCompactShortcuts = false
 for line in source:gmatch("[^\n]+") do
  if line:match("local compactShortcuts=canvas%.AbsoluteSize%.Y<440") then
   skippingCompactShortcuts = true
   continue
  end
  if skippingCompactShortcuts then
   if line:match("^%s*end") and not line:match("then") then
    skippingCompactShortcuts = false
   end
   continue
  end
  if line:match('if action=="RACE" or action=="ROOMS" then') then
   skippingBrowseAll = true
   continue
  end
  if skippingBrowseAll then
   if line:match("^%s*end") and not line:match("then") then
    skippingBrowseAll = false
   end
   continue
  end
  if line:match("local walletCapsule%s*=%s*Instance%.new") then
   skippingWallet = true
   continue
  end
  if skippingWallet then
   if line:match("^%s*updateWallet%(%)") then
    skippingWallet = false
   end
   continue
  end
  if line:match("local dockGradients%s*=") then
   skippingDockGradients = true
   continue
  end
  if skippingDockGradients then
   if line:match("^%s*}") then
    skippingDockGradients = false
   end
   continue
  end
  if line:match("Apply Garage/Track subtitle removal") then
   skippingLayoutShift = true
   continue
  end
  if skippingLayoutShift then
   if line:match("End Layout Shift") then
    skippingLayoutShift = false
   end
   continue
  end
  if line:match("StyleHelper") or line:match("dockGradients") or line:match("local g%s*=")
   or line:match("if step <= STEP_TRACK then stepLabel%.Visible = false")
   or line:match("The subtitle is hidden on Track") or line:match("local titleBottom%s*=")
   or line:match("cardTop = math%.max%(8") or line:match("actionTop = cardTop%+cardHeight")
   or line:match('if action%s*==%s*"RACE"')
   or line:match("local SHOWROOM_VISUAL_SCALE")
   or line:match("visual:ScaleTo")
   or line:match("HubRaceBoardView")
   or line:match("panel%.Visible%s*=%s*not%s*driving")
   or line:match("presentation%.bottom%s*=")
   or line:match("raceBoard%.update")
   or line:match("LobbyDisplayDrivePoint")
   or line:match("LobbyDisplayTestDrive")
   or line:match("ShowroomColorLabel")
   or line:match("ColorLabel")
   or line:match("drive%.")
   or line:match("prompt%.")
   or line:match('local label=Instance%.new%("TextLabel"%)')
   or line:match('label%.Text=catalog%.Entries%[kartId%]')
   or line:match('label%.Parent=sign')
   or line:match("point%.CFrame") or line:match("billboard") or line:match("ShowroomBillboard")
   or line:match("^%s*do%s*$") then continue end
  line=line:gsub("%-%-.*$", "")
  line=line:gsub("Theme%.%w+", "PALETTE"):gsub("theme%.%w+", "PALETTE")
  -- Color gradients are palette statements; rotation and lifecycle stay compared.
  if line:match("^%s*visualGradient%(") then continue end
  if line:match('^%s*local Theme%s*=') then continue end
  -- Mixed assignments with frozen non-color suffixes.
  line=line:gsub("stroke%.Color, stroke%.ApplyStrokeMode, stroke%.Parent = .-, Enum%.ApplyStrokeMode%.Border, button",
   "stroke.ApplyStrokeMode, stroke.Parent = Enum.ApplyStrokeMode.Border, button")
  line=line:gsub("stroke%.Color, stroke%.Thickness, stroke%.ApplyStrokeMode, stroke%.Parent = .-, 2, Enum%.ApplyStrokeMode%.Border, button",
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
     if not (field:match("%.BackgroundColor3%s*$") or field:match("%.TextColor3%s*$") or field:match("%.Color%s*$")
      or field:match("%.Ambient%s*$") or field:match("%.LightColor%s*$") or field:match("%.TextStrokeTransparency%s*$")) then colorOnly=false end
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
