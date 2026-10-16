-- Reuse the central kiosk's heading; no extra floating modal over mobile controls.
local View={}
local Catalog=require(game:GetService('ReplicatedStorage'):WaitForChild('Shared'):WaitForChild('TrackCatalog'))
function View.create(hub)
 local labels={}
 local function arrange(label,width,height)
  local frame=label.Parent;local board=frame.Parent
  if not board:IsA('BillboardGui')then return end
  board.Size=UDim2.fromOffset(width,height+54)
  frame.AutomaticSize=Enum.AutomaticSize.None;frame.Size=UDim2.fromScale(1,1)
  frame.AnchorPoint=Vector2.zero;frame.Position=UDim2.fromOffset(0,0)
  label.AutomaticSize=Enum.AutomaticSize.None;label.Size=UDim2.fromOffset(width,height)
  label.AnchorPoint=Vector2.zero
  label.Position=UDim2.fromOffset(0,0);label.TextWrapped=true
  label.Font=Enum.Font.GothamBold;label.TextScaled=false;label.TextSize=26
  local pin=frame:FindFirstChildOfClass('ImageLabel')
  if pin then pin.AnchorPoint=Vector2.zero;pin.Position=UDim2.new(.5,-24,0,height+4)end
 end
 local kiosk=hub:FindFirstChild('RaceStationKiosk',true)
 if kiosk then for _,v in kiosk:GetDescendants()do
  if v:IsA('TextLabel')and(v.Text=='SELECT RACE'or v:GetAttribute('KDMRaceInfoLabel')==true)then
   v:SetAttribute('KDMRaceInfoLabel',true)
   arrange(v,230,82);v.RichText=true;v.Text='RACE';table.insert(labels,v)
  end
 end end
 for _,spec in {{'TrackStationKiosk','SELECT TRACK','TRACKS'},{'GarageStationKiosk','SELECT KART','GARAGE'}}do
  local station=hub:FindFirstChild(spec[1],true)
  if station then for _,v in station:GetDescendants()do if v:IsA('TextLabel')and v.Text==spec[2]then arrange(v,180,40);v.Text=spec[3]end end end
 end
 return {update=function(snapshot)
  local r=snapshot.featured
  local line=if snapshot.directoryStale then 'CHECKING RACES…'elseif r then
   string.format('%d PLAYERS · %d BOT · %s',r.humanCount or 0,r.botCount or 0,if r.state=='WAITING'or r.quickWarmup then 'JOIN NOW'else 'NEXT RACE')
   else 'START THE FIRST RACE'
  local track=r and Catalog.Entries[r.trackId]
  for _,v in labels do
   v.Text='RACE\n<font size="16">'..(if track then track.DisplayName else 'PLAY TOGETHER')..'</font>\n<font size="14">'..line..'</font>'
  end
 end}
end
return View
