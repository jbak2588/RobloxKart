-- Current-round replicated standings only; no result authority or persistence.
local Cache = {}
Cache.__index = Cache
Cache.ATTRIBUTES = {"RaceSessionId","RaceState","RacePosition","RaceFinishPosition","RaceFinalTime",
	"RaceCompletedLaps","RaceLap1Time","RaceLap2Time","RaceLap3Time","RaceBestLapTime","RaceBestLapNumber","RaceDNFReason"}
function Cache.new()
	return setmetatable({sessionId=nil, entries={}},Cache)
end
function Cache:collect(localPlayer, players)
	local sessionId = localPlayer:GetAttribute("RaceSessionId")
	if self.sessionId ~= sessionId then self.sessionId=sessionId; table.clear(self.entries) end
	if not sessionId or sessionId == 0 then return {} end
	for _,p in players do
		if p:GetAttribute("RaceSessionId") == sessionId then
			local function number(key) return p:GetAttribute(key) or 0 end
			self.entries[p.UserId] = {userId=p.UserId,name=p.Name,displayName=p.DisplayName or p.Name,sessionId=sessionId,
				finishPosition=number("RaceFinishPosition"),racePosition=number("RacePosition"),
				state=p:GetAttribute("RaceState"),finalTime=number("RaceFinalTime"),
				laps={number("RaceLap1Time"),number("RaceLap2Time"),number("RaceLap3Time")},
				completedLaps=number("RaceCompletedLaps"),bestLap=number("RaceBestLapTime"),
				bestLapNumber=number("RaceBestLapNumber"),dnfReason=p:GetAttribute("RaceDNFReason")}
		end
	end
	local rows={}
	for _,row in self.entries do table.insert(rows,row) end
	local function priority(row)
		if row.state=="DNF" then return 4 end
		if row.finishPosition>0 then return 1 end
		return if row.state=="FINISHED" then 2 else 3
	end
	table.sort(rows,function(a,b)
		local pa,pb=priority(a),priority(b)
		if pa~=pb then return pa<pb end
		local ar,br=if pa==1 then a.finishPosition else a.racePosition,if pb==1 then b.finishPosition else b.racePosition
		if ar~=br then return ar<br end
		return a.userId<b.userId
	end)
	while #rows>4 do table.remove(rows) end
	return rows
end
return Cache
