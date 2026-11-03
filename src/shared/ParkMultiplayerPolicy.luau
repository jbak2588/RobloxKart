-- Separate Park race identity; official four-racer tracks and Overtake are unchanged.
local Trial=require(script.Parent.RookieParkTrial)
local Overtake=require(script.Parent.ParkOvertakePolicy)
local Layout=require(script.Parent.HubParkRookieLoopLayout)
local P={Id='ParkMultiplayer',DisplayName='Rookie Park Multiplayer',Laps=3,Capacity=8,
 JoinSeconds=10,FillSeconds=.3,Countdown=3,Timeout=900,
 PreviewImageAssetId=Overtake.PreviewImageAssetId,
 Description='8 RACERS / 3 LAPS / JOIN FOR 10s / EMPTY SLOTS FILLED BY BOTS'}
function P.speeds(random)
 local speeds={}
 for i=1,7 do speeds[i]=80+(i-1+random:NextNumber())*6/7 end
 for i=7,2,-1 do local j=random:NextInteger(1,i);speeds[i],speeds[j]=speeds[j],speeds[i]end
 return speeds
end
local finishArc=Trial.project(Trial.Finish.x,Trial.Finish.z)
local starts={};for slot=0,7 do starts[slot]=-((finishArc-Overtake.startArc(slot))%Trial.Length)end
function P.startProgress(slot)return starts[slot]end
function P.finishProgress()return P.Laps*Trial.Length end
function P.reward(humans,humanPosition)
 return if humans==1 then 1500 else ({3500,2500,2000})[humanPosition]or 1500
end
function P.sample(progress,slot)
 local x,z,dx,dz=Overtake.sample(finishArc+progress)
 if slot~=nil then
  local blend=math.clamp(1-(progress-P.startProgress(slot))/90,0,1)
  z+=(Layout.Slots[slot+1].z-Layout.StartStraightZ)*blend
 end
 return x,z,dx,dz
end
function P.humanProgress(s,x,z)
 -- Reuse the accepted bounded route sample; never scan the entire track per rival/frame.
 local relative=if s.route and s.route.previous~=nil then s.route.previous*Trial.Length else (Trial.project(x,z)-finishArc)%Trial.Length
 return (s.completedLaps or 0)*Trial.Length+relative-(if s.finishPassed then 0 else Trial.Length)
end
return table.freeze(P)
