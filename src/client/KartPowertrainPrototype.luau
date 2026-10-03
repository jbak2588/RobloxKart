-- Acceptance-gated audio/UI owner. One update supplies both gauge and engine.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local Powertrain=require(script.Parent:WaitForChild("KartPowertrainPresentation"))
local Gauge=require(script.Parent:WaitForChild("KartPowertrainGauge"))
local Donor=require(script.Parent:WaitForChild("V2DonorExperiment"))
local Prototype={}
local model,gauge,activeKart,activeEngine,originalId,mode,state
local candidateElapsed,candidateFailed=0,false
function Prototype.enabled()
	return Donor.enabled() or (RunService:IsStudio() and Players.LocalPlayer:GetAttribute("KDMEnablePowertrainPrototype")==true)
		or Workspace:GetAttribute("KDMPowertrainPublishedAcceptance")==true
end
function Prototype.ownsEngine(engine)
	return Donor.enabled() or (Prototype.enabled() and activeEngine==engine and mode~="CURRENT")
end
function Prototype.reset()
	Donor.reset()
	if activeEngine and activeEngine.Parent and originalId then activeEngine.SoundId=originalId end
	if gauge then gauge:destroy() end
	model,gauge,activeKart,activeEngine,originalId,mode,state=nil,nil,nil,nil,nil,nil,nil
	candidateElapsed,candidateFailed=0,false
end
function Prototype.update(parent,kart,chassis,dt,speed,displayedSpeed,topText,mobile,blocked,throttle)
	if Donor.enabled() then
		if gauge then gauge:destroy();gauge=nil end
		state=Donor.update(parent,kart,chassis,dt,speed,mobile,blocked,throttle)
		return state
	end
	Donor.reset()
	if not Prototype.enabled() or not kart or not chassis then Prototype.reset();return end
	if activeKart~=kart then Prototype.reset();model=Powertrain.new();activeKart=kart;gauge=Gauge.new(parent) end
	local velocity=chassis.AssemblyLinearVelocity
	state=model:update(speed,dt,{reverse=velocity:Dot(chassis.CFrame.LookVector)<-1,throttle=throttle})
	mode=Players.LocalPlayer:GetAttribute("KDMPowertrainAudioMode")
		or (if Workspace:GetAttribute("KDMPowertrainPublishedAcceptance")==true then "V2_ORIGINAL_AUDIO" else "CURRENT")
	-- User-approved V2 original engine loop; published mode is independent of local attributes.
	if not RunService:IsStudio() then mode="V2_ORIGINAL_AUDIO" end
	if mode~="VIRTUAL_POWERTRAIN" and mode~="V2_ORIGINAL_AUDIO" then mode="CURRENT" end
	local engine=chassis:FindFirstChild("EngineLoop")
	if engine and activeEngine~=engine then activeEngine=engine;originalId=engine.SoundId end
	if engine then
		if mode=="V2_ORIGINAL_AUDIO" and not candidateFailed then
			if engine.SoundId=="rbxassetid://290290922" and not engine.IsLoaded then
				candidateElapsed+=dt
				if candidateElapsed>=8 then candidateFailed=true end
			end
		else candidateElapsed=0 end
		local id=if mode=="V2_ORIGINAL_AUDIO" and (not candidateFailed or Workspace:GetAttribute("KDMPowertrainPublishedAcceptance")==true) then "rbxassetid://290290922" else originalId
		if engine.SoundId~=id then engine.SoundId=id end
		if mode~="CURRENT" then engine.PlaybackSpeed=state.playbackSpeed;engine.Volume=if candidateFailed and Workspace:GetAttribute("KDMPowertrainPublishedAcceptance")==true then 0 else state.volume end
	end
	state.originalAudioFailed=candidateFailed
	state.displaySpeedKmh=displayedSpeed*Powertrain.SPEED_TO_KMH
	gauge:update(state,topText,state.displaySpeedKmh,dt,parent.AbsoluteSize,mobile,blocked)
	return state
end
function Prototype.getState() return state end
return Prototype
