-- Runs before StarterPlayerScripts/module loading and before race admission.
-- A missing role is treated as arrival, closing the teleport/replication gap.
local Players=game:GetService('Players')
local Workspace=game:GetService('Workspace')
local Actions=game:GetService('ContextActionService')
local Input=game:GetService('UserInputService')
local player=Players.LocalPlayer
local actionName='KDMRacePreventJump'
local humanoid=nil
local saved=nil
local characterConnection=nil
local humanoidConnections={}
local connections={}
local buttons={}
local function blocked() return Workspace:GetAttribute('KDMServerRole')~='HUB' end
local function disconnect(list) for _,c in list do c:Disconnect() end;table.clear(list) end
local function enforce()
 if not humanoid then return end
 if blocked() then
  if not saved then saved={power=humanoid.JumpPower,height=humanoid.JumpHeight,
   jumping=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),auto=humanoid.AutoJumpEnabled} end
  humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
  if humanoid.JumpPower~=0 then humanoid.JumpPower=0 end
  if humanoid.JumpHeight~=0 then humanoid.JumpHeight=0 end
  humanoid.AutoJumpEnabled=false
  humanoid.Jump=false
 elseif saved then
  local previous=saved;saved=nil
  humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,previous.jumping)
  humanoid.JumpPower=previous.power;humanoid.JumpHeight=previous.height;humanoid.AutoJumpEnabled=previous.auto
 end
end
Actions:BindActionAtPriority(actionName,function()
 if not blocked() then return Enum.ContextActionResult.Pass end
 if humanoid then humanoid.Jump=false end
 -- Keep typing spaces in chat; the Humanoid lock still prevents seat exit.
 return if Input:GetFocusedTextBox() then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.High.Value+100,Enum.PlayerActions.CharacterJump,Enum.KeyCode.Space)
local function attachHumanoid(h)
 if humanoid==h then return end
 disconnect(humanoidConnections);humanoid=h;saved=nil
 enforce()
 for _,property in {'Jump','JumpPower','JumpHeight'} do
  table.insert(humanoidConnections,h:GetPropertyChangedSignal(property):Connect(function()
   if blocked() and ((property=='Jump' and h.Jump) or (property~='Jump' and h[property]~=0)) then enforce() end
  end))
 end
 table.insert(humanoidConnections,h.StateEnabledChanged:Connect(function(state,enabled)
  if blocked() and state==Enum.HumanoidStateType.Jumping and enabled then enforce() end
 end))
end
local function attachCharacter(character)
 if characterConnection then characterConnection:Disconnect() end
 disconnect(humanoidConnections);humanoid=nil;saved=nil
 local h=character:FindFirstChildOfClass('Humanoid');if h then attachHumanoid(h) end
 characterConnection=character.ChildAdded:Connect(function(child)if child:IsA('Humanoid') then attachHumanoid(child) end end)
end
local function updateButton(button,record)
 if blocked() then
  if button.Visible then button.Visible=false end
 elseif record.visible then button.Visible=true end
end
local function watchButton(node)
 if node.Name~='JumpButton' or not node:IsA('GuiButton') or not node:FindFirstAncestor('TouchGui') or buttons[node] then return end
 local record={visible=node.Visible};buttons[node]=record
 record.connection=node:GetPropertyChangedSignal('Visible'):Connect(function()
  if blocked() and node.Visible then node.Visible=false end
 end)
 updateButton(node,record)
end
local function attachGui(pg)
 for _,node in pg:GetDescendants() do watchButton(node) end
 table.insert(connections,pg.DescendantAdded:Connect(watchButton))
end
table.insert(connections,player.CharacterAdded:Connect(attachCharacter))
if player.Character then attachCharacter(player.Character) end
table.insert(connections,player.ChildAdded:Connect(function(child)if child:IsA('PlayerGui') then attachGui(child) end end))
local pg=player:FindFirstChildOfClass('PlayerGui');if pg then attachGui(pg) end
table.insert(connections,Workspace:GetAttributeChangedSignal('KDMServerRole'):Connect(function()
 enforce();for button,record in pairs(buttons) do if button.Parent then updateButton(button,record) end end
end))
script.Destroying:Connect(function()
 Actions:UnbindAction(actionName)
 disconnect(connections);disconnect(humanoidConnections)
 if characterConnection then characterConnection:Disconnect() end
 if humanoid and saved then
  humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,saved.jumping)
  humanoid.JumpPower=saved.power;humanoid.JumpHeight=saved.height;humanoid.AutoJumpEnabled=saved.auto
 end
 for button,record in pairs(buttons) do record.connection:Disconnect();if button.Parent then button.Visible=record.visible end end
end)
