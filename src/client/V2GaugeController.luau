local Gauge=require(script.Parent:WaitForChild("V2DonorGauge"))
local Presentation=require(script.Parent:WaitForChild("V2GaugePresentation"))
local Controller={}
function Controller.new(playerGui)
	local gui=Instance.new("ScreenGui")
	gui.Name="KDMV2GaugeHud"
	gui.ResetOnSpawn=false
	-- Physical-screen bottom, including donor transparent padding correction.
	-- The centered passive artwork fits outside side cutouts; portrait is suppressed.
	gui.ScreenInsets=Enum.ScreenInsets.None
	gui.ClipToDeviceSafeArea=false
	gui.DisplayOrder=10
	gui.Parent=playerGui
	local gauge=Gauge.new(gui)
	local model=Presentation.new()
	local owner=nil
	local self={gui=gui,gauge=gauge}
	function self:update(chassis,speed,dt,mobile,active)
		if chassis~=owner or not active then model=Presentation.new();owner=chassis end
		return gauge:update(model:update(speed,dt),gui.AbsoluteSize,mobile,not active or chassis==nil)
	end
	function self:destroy() gui:Destroy() end
	return self
end
return Controller
