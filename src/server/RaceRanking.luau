-- Pure ordering of a two-racer snapshot. Finish places are fixed at the final gate.
local RaceRanking = {}

function RaceRanking.sort(entries)
	table.sort(entries, function(a, b)
		local aFinish, bFinish = a.finishPosition or 0, b.finishPosition or 0
		if aFinish > 0 or bFinish > 0 then
			if aFinish == 0 then return false end
			if bFinish == 0 then return true end
			return aFinish < bFinish
		end
		local aDnf, bDnf = a.state == "DNF", b.state == "DNF"
		if aDnf ~= bDnf then return not aDnf end
		if a.completedLaps ~= b.completedLaps then return a.completedLaps > b.completedLaps end
		if a.nextCheckpoint ~= b.nextCheckpoint then return a.nextCheckpoint > b.nextCheckpoint end
		if a.routeFraction ~= b.routeFraction then return a.routeFraction > b.routeFraction end
		if a.readyOrder ~= b.readyOrder then return a.readyOrder < b.readyOrder end
		return a.userId < b.userId
	end)
	return entries
end

return RaceRanking
