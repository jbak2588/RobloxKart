local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Slots=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceItemSlots"))
local View=require(script.Parent:WaitForChild("MobileControlView"))
local ItemIconView=require(script.Parent:WaitForChild("KDMItemIconView"))
local Controller={}
local GuidanceState=require(script.Parent:WaitForChild("HubGuidanceState"))
local started=false
function Controller.start()
 if started then return end
 started=true
	local player=Players.LocalPlayer
	local remote=ReplicatedStorage:WaitForChild("RaceItemControl")
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder="KDMTacticalLoadout",false,30
	gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=player:WaitForChild("PlayerGui")
	local function label(parent,name,text,y,height)
		local l=Instance.new("TextLabel");l.Name=name;l.Text=text;l.Position=UDim2.new(0,12,0,y)
		l.Size=UDim2.new(1,-24,0,height);l.BackgroundTransparency=1;l.TextSize=16
		l.Font=Enum.Font.GothamBold;l.TextColor3=Color3.fromRGB(220,240,250);l.Parent=parent;return l
	end
	local function button(parent,name,text)
		local b=Instance.new("TextButton");b.Name=name;b.Text=text;b.Size=UDim2.fromOffset(100,44)
		b.BackgroundColor3=Color3.fromRGB(35,75,105);b.TextColor3=Color3.new(1,1,1)
		b.Font=Enum.Font.GothamBold;b.TextSize=14;b.Parent=parent;View.round(b,UDim.new(0,6));return b
	end
	local items=button(gui,"Items","ITEMS")
 local nextAction=label(gui,"NextAction","",0,16)
 nextAction.Size=UDim2.fromOffset(100,16);nextAction.TextSize=10;nextAction.AutoLocalize=true
	local overlay=Instance.new("Frame");overlay.Name="Modal";overlay.Size=UDim2.fromScale(1,1)
	overlay.BackgroundColor3=Color3.new(0,0,0);overlay.BackgroundTransparency=.25
	overlay.Active=true;overlay.Visible=false;overlay.Parent=gui
	local card=Instance.new("Frame");card.Name="Card";card.AnchorPoint=Vector2.new(.5,.5)
	card.Position=UDim2.fromScale(.5,.5);card.BackgroundColor3=Color3.fromRGB(16,25,35);card.BorderSizePixel=0
	card.Parent=overlay;View.round(card,UDim.new(0,10))
	label(card,"Core","CORE  •  NITRO LOCKED",8,24)
	label(card,"Choose","CHOOSE 3",36,22)
	local status=label(card,"Status","3 / 3 SELECTED",118,24)
	local controls={}
	local itemIcons,itemLabels={},{}
	local iconCache=ItemIconView.cache(game:GetService("ContentProvider"),task)
	local draft, pending={},false
	local confirm=button(card,"Confirm","CONFIRM & READY")
	confirm.TextSize=11
	local timer=label(card,"Timer","AUTO READY IN 10",110,18)
	timer.TextSize=12
	status.Position=UDim2.new(0,12,0,128);status.Size=UDim2.new(1,-24,0,18);status.TextSize=12
	local reset=button(card,"Reset","RESET DEFAULT")
	local back=button(card,"Back","BACK")
	local function eligible()
		return player:GetAttribute("RaceState")=="PRE_RACE"
			and player:GetAttribute("RaceMatchStatus")=="WAITING"
			and player:GetAttribute("RaceItemsReady")~=true
			and (player:GetAttribute("RaceItemsPrepareRemaining") or 0)>0
	end
	local function refresh()
		local count=#draft
		status.Text=if pending then "SAVING ITEMS..." else tostring(count).." / 3 SELECTED"
		confirm.Active=count==3 and not pending;confirm.AutoButtonColor=confirm.Active
		confirm.BackgroundTransparency=if confirm.Active then 0 else .6
		back.Active=not pending;reset.Active=not pending
		for _,id in Slots.TACTICAL do
			local chosen=table.find(draft,id)~=nil
			controls[id].Text=string.upper(id)..(if chosen then " ✓" else "")
			itemLabels[id].Text=controls[id].Text
			itemLabels[id].TextTransparency=if pending then .55 else 0
			itemIcons[id]:update(true,if pending then 0 else 1,false)
			controls[id].BackgroundColor3=if chosen then Color3.fromRGB(35,125,155) else Color3.fromRGB(35,50,65)
			controls[id].Active=not pending
		end
	end
	for index,id in Slots.TACTICAL do
		local b=button(card,id,string.upper(id));b.Position=UDim2.fromOffset(12+(index-1)*108,66);controls[id]=b
		-- Preserve the native button label/selection semantics; a separate label
		-- reserves the icon lane and remains eligible for Roblox localization.
		b.TextTransparency=1
		local icon=Instance.new("Frame");icon.Name="ItemIcon";icon.BackgroundTransparency=1
		icon.Position=UDim2.fromOffset(4,4);icon.Size=UDim2.fromOffset(36,36)
		icon.Active=false;icon.Parent=b
		itemIcons[id]=ItemIconView.new(icon,id,iconCache,View)
		local text=label(b,"ItemName",b.Text,0,44)
		text.Position=UDim2.fromOffset(46,0);text.Size=UDim2.new(1,-50,1,0)
		text.TextSize=12;text.TextXAlignment=Enum.TextXAlignment.Left
		itemLabels[id]=text
		b.Activated:Connect(function()
			if pending then return end
			local found=table.find(draft,id)
			if found then table.remove(draft,found) elseif #draft<3 then table.insert(draft,id) end
			refresh()
		end)
	end
	local function loadChoice()
		draft={}
		for index=1,3 do table.insert(draft,player:GetAttribute("RaceTacticalItem"..index) or Slots.DEFAULT[index+1]) end
	end
	items.Activated:Connect(function() if eligible() then loadChoice();pending=false;overlay.Visible=true;refresh() end end)
	-- BACK discards edits; invalid/incomplete drafts never leave this modal as a saved loadout.
	back.Activated:Connect(function() if not pending then loadChoice();overlay.Visible=false end end)
	reset.Activated:Connect(function() if not pending then draft={Slots.DEFAULT[2],Slots.DEFAULT[3],Slots.DEFAULT[4]};refresh() end end)
	local requestSerial=0
	confirm.Activated:Connect(function()
		if pending or not eligible() or #draft~=3 then return end
		pending=true;requestSerial+=1;local serial=requestSerial;refresh()
		remote:FireServer("SetTacticalLoadout",table.clone(draft))
		task.delay(4,function() if pending and serial==requestSerial then pending=false;refresh();status.Text="PLEASE TRY AGAIN" end end)
	end)
	local remoteConnection=remote.OnClientEvent:Connect(function(action,accepted,message)
		if action~="TacticalLoadoutResult" or not pending then return end
		pending=false;refresh()
		if accepted then overlay.Visible=false else status.Text=message end
	end)
	local function layout()
		local size=gui.AbsoluteSize
		items.AnchorPoint=if size.X>=600 then Vector2.new(0,1) else Vector2.new(1,0)
		items.Position=if size.X>=600 then UDim2.new(.5,134,.94,-10) else UDim2.new(1,-12,0,8)
  nextAction.AnchorPoint=if size.X>=600 then Vector2.zero else Vector2.new(1,0)
  nextAction.Position=items.Position+UDim2.fromOffset(0,if size.X>=600 then 2 else 46)
		card.Size=UDim2.fromOffset(math.min(456,size.X-24),252)
		local width=(card.Size.X.Offset-32)/3
		for index,id in Slots.TACTICAL do
			local row=math.floor((index-1)/3)
			local col=(index-1)%3
			local inset=if row==1 then (width+4)/2 else 0
			controls[id].Position=UDim2.fromOffset(12+inset+col*(width+4),66+row*48)
			controls[id].Size=UDim2.fromOffset(width,44)
		end
		timer.Position=UDim2.new(0,12,0,158)
		status.Position=UDim2.new(0,12,0,176)
		reset.Position=UDim2.fromOffset(12,202);reset.Size=UDim2.fromOffset(card.Size.X.Offset*.38,44)
		back.Position=UDim2.fromOffset(card.Size.X.Offset*.42,202);back.Size=UDim2.fromOffset(card.Size.X.Offset*.20,44)
		confirm.Position=UDim2.fromOffset(card.Size.X.Offset*.65,202);confirm.Size=UDim2.fromOffset(card.Size.X.Offset*.32-12,44)
	end
	local function lifecycle()
		local waiting=player:GetAttribute("RaceState")=="PRE_RACE" and player:GetAttribute("RaceMatchStatus")=="WAITING"
		local remaining=player:GetAttribute("RaceItemsPrepareRemaining") or 0
		items.Visible=waiting
		items.Active=eligible();items.AutoButtonColor=items.Active
		items.BackgroundTransparency=if items.Active then 0 else .55
		items.Text=if player:GetAttribute("RaceItemsReady")==true then "ITEMS READY" else "ITEMS "..remaining
  nextAction.Text=if player:GetAttribute("RaceItemsReady")==true then "WAIT FOR START" else "SELECT ITEMS"
  nextAction.Visible=GuidanceState.prepHelper(player:GetAttribute("RaceState"),player:GetAttribute("RaceMatchStatus"),player:GetAttribute("RaceItemsReady"))~=nil and not overlay.Visible
		timer.Text="AUTO READY IN "..remaining
		if not eligible() then
			overlay.Visible=false;pending=false;requestSerial+=1;loadChoice()
		end
	end
 local lifecycleConnections={}
 for _,attr in {"RaceState","RaceMatchStatus","RaceItemsReady","RaceItemsPrepareRemaining"} do table.insert(lifecycleConnections,player:GetAttributeChangedSignal(attr):Connect(lifecycle)) end
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
 overlay:GetPropertyChangedSignal("Visible"):Connect(function() nextAction.Visible=items.Visible and not overlay.Visible end)
 gui.Destroying:Connect(function()
  iconCache:destroy();remoteConnection:Disconnect()
  for _,connection in lifecycleConnections do connection:Disconnect() end
  pending=false;requestSerial+=1;started=false
 end)
	layout();lifecycle();refresh()
	iconCache:start(refresh)
end
return Controller
