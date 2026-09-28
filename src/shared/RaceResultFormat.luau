local Format = {}

function Format.time(seconds: number): string
	local centiseconds = math.max(0, math.floor(seconds * 100 + 0.5))
	local minutes = math.floor(centiseconds / 6000)
	local wholeSeconds = math.floor(centiseconds / 100) % 60
	local fraction = centiseconds % 100
	if minutes > 0 then
		return string.format("%d:%02d.%02d", minutes, wholeSeconds, fraction)
	end
	return string.format("%d.%02d", wholeSeconds, fraction)
end

function Format.delta(lapTime: number, bestTime: number, isBest: boolean): string
	if isBest then return "BEST" end
	return string.format("+%.2f", math.max(0, lapTime - bestTime))
end

return table.freeze(Format)
