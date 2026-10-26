-- Owner-selected Figure-8 Desert Canyon visual reference. No driving settings.
local Standard={Version=2,RoadTint=Color3.fromRGB(226,220,188),RailSize=Vector3.new(.5,4.5,20)}
Standard.ParkRoadTint=Color3.fromRGB(165,170,180)
Standard.Sun={ClockTime=13,GeographicLatitude=23.5}
Standard.MarkingLift=.20
Standard.Lighting={Brightness=2,ExposureCompensation=-.2,ClockTime=Standard.Sun.ClockTime,GeographicLatitude=Standard.Sun.GeographicLatitude,
 Ambient=Color3.fromRGB(130,128,120),OutdoorAmbient=Color3.fromRGB(145,145,140),
 EnvironmentDiffuseScale=.8,EnvironmentSpecularScale=.25}
Standard.Tracks={Track01=true,Track01Race=true,Track03=true}
function Standard.hideCrossingPaint(id,kind)
 return id=='Track01'and(kind=='RacingDivider'or kind=='OuterEdge')
end
function Standard.eligible(role,id,park)
 return (role=='RACE' and Standard.Tracks[id]==true)or(role=='HUB' and park==true)
end
return table.freeze(Standard)
