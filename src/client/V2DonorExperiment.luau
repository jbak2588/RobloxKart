-- Isolated audio/gauge owner. Never changes kart physics or input transport.
local Workspace=game:GetService("Workspace")
local Adapter=require(script.Parent:WaitForChild("V2DonorValuesAdapter"))
local Audio=require(script.Parent:WaitForChild("V2DonorAudio"))
local Gauge=require(script.Parent:WaitForChild("V2DonorGauge"))
local C1=require(script.Parent:WaitForChild("KartPowertrainPresentation"))
local RunService=game:GetService("RunService")
local Powertrain=require(script.Parent:WaitForChild("KDMEnginePowertrainPresentation"))
local Experiment={}
local adapter,audio,gauge,c1,kartOwner,compareMode,state,powertrain
local mixer
function Experiment.enabled() return Workspace:GetAttribute("KDMV2DonorExperiment")==true end
function Experiment.bindMixer(value) mixer=value end
function Experiment.reset()
	if gauge then gauge:destroy() end
	adapter,audio,gauge,c1,kartOwner,compareMode,state=nil,nil,nil,nil,nil,nil,nil
	powertrain=nil
	if mixer then mixer:update(nil) end
end
function Experiment.update(parent,kart,chassis,dt,speed,mobile,blocked,throttle)
	if not Experiment.enabled() or not kart or not chassis then Experiment.reset();return end
	if kartOwner~=kart then
		Experiment.reset();kartOwner=kart;adapter=Adapter.new();audio=Audio.new();c1=C1.new();gauge=Gauge.new(parent)
	end
	local requested=Workspace:GetAttribute("KDMV2DonorCompareMode")
	local mode=if requested=="C1_V328" then "C1_V328" else "DONOR_EXACT"
	local engineMode=Workspace:GetAttribute("KDMEngineExperimentMode")
	if engineMode~=nil then
		mode=if not RunService:IsStudio() then "MULTI_RPM"
			elseif engineMode=="DONOR_EXACT" or engineMode=="C1_V328" then engineMode else "MULTI_RPM"
	end
	if compareMode~=mode then
		adapter=Adapter.new();audio=Audio.new();c1=C1.new();powertrain=Powertrain.new();compareMode=mode
	end
	local velocity=chassis.AssemblyLinearVelocity
	local reverse=velocity:Dot(chassis.CFrame.LookVector)<-1
	if mode=="MULTI_RPM" then
		state=powertrain:update(speed,dt,{throttle=throttle,
			boost=kart:GetAttribute("KartBoosting")==true or kart:GetAttribute("KartNitroActive")==true})
		if mixer then mixer:update(state) end
	elseif mode=="DONOR_EXACT" then
		state=adapter:update(speed,dt,{throttle=throttle,velocity=velocity,reverse=reverse})
		state.playbackSpeed,state.volume=audio:update(state,dt,tick())
	else
		local c=c1:update(speed,dt,{throttle=throttle,reverse=reverse})
		state={RPM=c.rpm,Gear=c.gear,Throttle=c.throttle,Velocity=velocity,TransmissionMode="Auto",
			speedKmh=c.speedKmh,playbackSpeed=c.playbackSpeed,volume=c.volume}
	end
	local engine=chassis:FindFirstChild("EngineLoop")
	if mode~="MULTI_RPM" then
		if mixer then mixer:update(nil) end
		if engine then engine.PlaybackSpeed=state.playbackSpeed;engine.Volume=state.volume end
	end
	gauge:update(state,parent.AbsoluteSize,mobile,blocked)
	return state
end
function Experiment.getState() return state end
return Experiment
