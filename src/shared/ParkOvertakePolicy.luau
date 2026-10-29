-- Park-only pursuit race. Server finish time, not client pass events, owns scoring.
local Trial=require(script.Parent.RookieParkTrial)
local Layout=require(script.Parent.HubParkRookieLoopLayout)
local P={Id='ParkOvertake',Laps=3,Bots=7,BotSpeed=70,Countdown=8,
 PreviewImageAssetId='rbxassetid://94896526779384',DisplayName='Rookie Park Overtake',
 Description='3 LAPS / 7 BOTS / K$5,000 + K$5,000 PER BOT / PERFECT + K$10,000',
 Instructions='Finish 3 laps ahead of 7 evenly spaced bots. Final position counts. Base K$5,000 + K$5,000 per bot ahead; all 7 adds K$10,000. MAX K$50,000.'}
-- Precompute once; binary-search station lookup keeps seven bot renders bounded.
local points=Layout.sample(Layout.Segments);local length=0
for i,p in points do if i>1 then local a=points[i-1];length+=math.sqrt((p.x-a.x)^2+(p.z-a.z)^2)end;p.arc=length end
function P.sample(distance)
 local d=distance%length;local low,high=1,#points-1
 while low<high do local mid=math.floor((low+high)/2);if points[mid+1].arc<d then low=mid+1 else high=mid end end
 local a,b=points[low],points[low+1];local t=(d-a.arc)/(b.arc-a.arc)
 return a.x+(b.x-a.x)*t,a.z+(b.z-a.z)*t,b.x-a.x,b.z-a.z
end
function P.startArc(slot)
 local p=Layout.Slots[slot+1]
 if not p then return nil end
 return Trial.project(p.x,p.z)
end
function P.finishDistance(slot)
 local start=P.startArc(slot);if not start then return nil end
 local finish=Trial.project(Trial.Finish.x,Trial.Finish.z)
 return P.Laps*Trial.Length+(finish-start)%Trial.Length
end
function P.botDistance(index,seconds)
 return Trial.Length*index/8+P.BotSpeed*math.max(0,seconds)
end
function P.countAhead(distance,seconds,distances)
 local count=0
 for i=1,P.Bots do if distance>(if distances then distances[i]else P.botDistance(i,seconds))then count+=1 end end
 return count
end
function P.reward(count)
 assert(type(count)=='number'and count%1==0 and count>=0 and count<=P.Bots,'invalid bot count')
 return 5000+5000*count+(if count==P.Bots then 10000 else 0)
end
return table.freeze(P)
