-- Fixed native air streaks, rendered locally from replicated kart motion/state.
local Speed=require(game.ReplicatedStorage.Shared.KDMSpeedSensation)
local Renderer={}
local color=ColorSequence.new(Color3.fromRGB(222,243,255))
-- Bounded immutable value cache: no sequences/tables/instances allocated on update.
local visuals={}
for tier,profile in Speed.Profiles do
	local levels={}
	for bucket=0,20 do
		local alpha=if tier=="HIGH_SPEED" then bucket/20 else 1
		local width=profile.Width*(if tier=="HIGH_SPEED" then .25+.75*alpha else 1)
		local transparency=1-(1-profile.Transparency)*alpha
		levels[bucket]=table.freeze({
			Width=NumberSequence.new({NumberSequenceKeypoint.new(0,width),NumberSequenceKeypoint.new(1,0)}),
			Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,transparency),NumberSequenceKeypoint.new(1,1)}),
		})
	end
	visuals[tier]=table.freeze(levels)
end
table.freeze(visuals)
-- Immutable rearward particle profiles. Shared tier/camera rules remain unchanged.
local function sequence(a,b,c)
 return NumberSequence.new({NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(.45,b),NumberSequenceKeypoint.new(1,c)})
end
local jetColor=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(240,250,255)),
 ColorSequenceKeypoint.new(.45,Color3.fromRGB(80,210,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(50,120,255))})
local particleProfiles={
 MINI_BOOST={
  {Rate=36,Lifetime=NumberRange.new(.14,.20),Speed=NumberRange.new(20,28),SpreadAngle=Vector2.new(6,6),LightEmission=.85,VelocityInheritance=.15,Size=sequence(.38,.28,.07),Transparency=sequence(.18,.40,1)},
  {Rate=18,Lifetime=NumberRange.new(.22,.30),Speed=NumberRange.new(12,18),SpreadAngle=Vector2.new(10,10),LightEmission=.55,VelocityInheritance=.15,Size=sequence(.65,.85,.20),Transparency=sequence(.45,.65,1)},
 },
 NITRO={
  {Rate=55,Lifetime=NumberRange.new(.20,.26),Speed=NumberRange.new(30,42),SpreadAngle=Vector2.new(8,8),LightEmission=1,VelocityInheritance=.15,Size=sequence(.52,.38,.08),Transparency=sequence(.12,.30,1)},
  {Rate=30,Lifetime=NumberRange.new(.28,.38),Speed=NumberRange.new(16,24),SpreadAngle=Vector2.new(13,13),LightEmission=.75,VelocityInheritance=.15,Size=sequence(.85,1.15,.25),Transparency=sequence(.38,.60,1)},
  {Rate=12,Lifetime=NumberRange.new(.08,.14),Speed=NumberRange.new(24,36),SpreadAngle=Vector2.new(12,12),LightEmission=1,VelocityInheritance=.15,Size=sequence(.12,.08,.02),Transparency=sequence(.10,.35,1)},
 },
}
function Renderer.new(kart)
	local chassis=kart.PrimaryPart
	if not chassis or not chassis:IsA("BasePart") then return nil end
	local visual=kart:FindFirstChild("Visual")
	if not visual then return nil end
	-- Read the fixed wheel pivots once. Wheel spin must not move the air origin.
	local wheels,exhausts={},{}
	for _,wheel in visual:GetDescendants() do
		if wheel:IsA("BasePart") and wheel:GetAttribute("VisualMotionRole")=="RearWheel" then
			local motor=wheel:FindFirstChild("VisualMotor")
			local width=wheel:GetAttribute("WheelWidth")
			if motor and type(width)=="number" and width>0 then
				wheels[wheel:GetAttribute("WheelSide") or ""]= {Center=motor.C0.Position,Width=width}
			end
		end
		if wheel:IsA("Attachment") then
		 local role=wheel:GetAttribute("EffectRole")
		 if role=="ExhaustLeft" or role=="ExhaustRight" then exhausts[role]=wheel end
		end
	end
	if not wheels.Left or not wheels.Right or not exhausts.ExhaustLeft or not exhausts.ExhaustRight then return nil end
	local attachments,trails,particlePoints,emitters={},{},{},{}
	for index=1,2 do
		local side=if index%2==1 then -1 else 1
		local wheel=if side<0 then wheels.Left else wheels.Right
		-- Small world-space gap approximates one mobile pixel, without camera-dependent jitter.
		local gap=if index<=2 then .12 else .30
		local x=wheel.Center.X+side*(wheel.Width*.5+gap)
		local y=wheel.Center.Y
		for edge=1,2 do
			local attachment=Instance.new("Attachment")
			attachment.Name="KDMSpeedPoint"..index.."_"..edge
			attachment.Position=Vector3.new(x,y+(if edge==1 then -.5 else .5),wheel.Center.Z)
			attachment.Parent=chassis
			attachments[#attachments+1]=attachment
		end
		local trail=Instance.new("Trail")
		trail.Name="KDMSpeedTrail"..index
		trail.Attachment0=attachments[index*2-1]
		trail.Attachment1=attachments[index*2]
		trail.Color=color
		trail.FaceCamera=true
		trail.Enabled=false
		trail.MinLength=.05
		trail.MaxLength=40
		trail.LightInfluence=0
		trail.Parent=chassis
		trails[index]=trail
	end
	for _,role in {"ExhaustLeft","ExhaustRight"} do
	 local source=exhausts[role]
	 -- Reuse the actual source location, but explicitly align Back (+Z) with
	 -- chassis rear. Imported attachment rotation must not turn the jet sideways.
	 local position=chassis.CFrame:ToObjectSpace(source.Parent.CFrame*source.CFrame).Position
	 local point=Instance.new("Attachment")
	 point.Name="KDMSpeedJetPoint"..role
	 point.CFrame=CFrame.new(position)
	 point.Parent=chassis;particlePoints[#particlePoints+1]=point
	 local layers={}
	 for layer,name in {"Core","Plume","Spark"} do
	  local emitter=Instance.new("ParticleEmitter")
	  emitter.Name="KDMSpeedJet"..name
	  emitter.Texture=if layer==3 then "rbxasset://textures/particles/sparkles_main.dds" else "rbxasset://textures/particles/smoke_main.dds"
	  emitter.Enabled=false;emitter.Rate=0
	  emitter.Acceleration=Vector3.zero;emitter.Drag=0
	  emitter.EmissionDirection=Enum.NormalId.Back
	  emitter.Orientation=Enum.ParticleOrientation.FacingCamera
	  emitter.LockedToPart=false;emitter.LightInfluence=0
	  emitter.Color=jetColor;emitter.Parent=point;layers[layer]=emitter
	 end
	 emitters[#emitters+1]=layers
	end
	local lastTier,lastBucket=nil,nil
	local record={}
	function record:update(_dt, enabled)
		local look=chassis.CFrame.LookVector
		local forward=Vector3.new(look.X,0,look.Z)
		local speed=if forward.Magnitude>.001 then chassis.AssemblyLinearVelocity:Dot(forward.Unit) else 0
		local tier,alpha=Speed.resolve(speed,kart:GetAttribute("KartBoosting")==true,kart:GetAttribute("KartNitroActive")==true,
			enabled and kart:GetAttribute("RaceControlsLocked")~=true,kart:GetAttribute("KartOffTrack")==true)
		-- Only the ordinary air streak yields to established Drift smoke/tire marks.
		if tier=="HIGH_SPEED" and kart:GetAttribute("KartDrifting")==true then tier,alpha="NONE",0 end
		local bucket=math.floor(alpha*20+.5)
		if tier==lastTier and bucket==lastBucket then return end
		local profile=Speed.Profiles[tier]
		local visual=visuals[tier][bucket]
		for index,trail in trails do
			local active=tier=="HIGH_SPEED" and alpha>0
			if not active and trail.Enabled then trail:Clear() end
			trail.Enabled=active
			trail.Lifetime=math.max(profile.Lifetime,.01)
			trail.WidthScale=visual.Width
			trail.Transparency=visual.Transparency
			trail.LightEmission=profile.LightEmission
		end
		local particles=particleProfiles[tier]
		for _,layers in emitters do
		 for layer,emitter in layers do
		  local values=particles and particles[layer]
		  if values then
		   for property,value in values do emitter[property]=value end
		  else emitter.Rate=0 end
		  emitter.Enabled=values~=nil
		  -- Normal boost expiry leaves the short-lived particles to fade naturally.
		  -- Suppression/termination clears them immediately.
		  if tier=="NONE" then emitter:Clear() end
		 end
		end
		lastTier,lastBucket=tier,bucket
	end
	function record:destroy()
		for _,layers in emitters do for _,emitter in layers do emitter.Enabled=false;emitter:Clear();emitter:Destroy() end end
		for _,point in particlePoints do point:Destroy() end
		for _,trail in trails do trail:Clear();trail:Destroy() end
		for _,attachment in attachments do attachment:Destroy() end
	end
	return record
end
return Renderer
