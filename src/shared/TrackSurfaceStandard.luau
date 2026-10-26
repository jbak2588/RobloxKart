-- Owner-selected Figure-8 Desert Canyon visual reference. No driving settings.
local Standard={Version=1,RoadTint=Color3.fromRGB(226,220,188),RailSize=Vector3.new(.5,4.5,20)}
Standard.Lighting={Brightness=2,ExposureCompensation=-.2,ClockTime=15.883889,
 Ambient=Color3.fromRGB(130,128,120),OutdoorAmbient=Color3.fromRGB(145,145,140),
 EnvironmentDiffuseScale=.8,EnvironmentSpecularScale=.25}
Standard.Tracks={Track01=true,Track01Race=true,Track03=true}
function Standard.eligible(role,id,park)
 return (role=='RACE' and Standard.Tracks[id]==true)or(role=='HUB' and park==true)
end
return table.freeze(Standard)
