-- Bot identity/actions stay separate from Human invitation UserIds.
local Rows = {}
function Rows.collect(snapshot, isHost, waiting)
	local rows = {}
	local active = snapshot.activeBots or {}
	local candidates = snapshot.botCandidates or {}
	for _, bot in active do
		table.insert(rows, {name=bot.name, botId=bot.botId, botAction=if isHost and waiting then "RemoveBot" else nil,
			status="ACTIVE"})
	end
	if #active == 0 then
		for _, bot in candidates do
			table.insert(rows, {name=bot.name, botId=bot.botId,
				botAction=if isHost and waiting and bot.available then "AddBot" else nil, status="UNAVAILABLE"})
		end
	end
	for _, queued in snapshot.queued or {} do
		table.insert(rows, {name=string.format("NEXT %s  %s", queued.name, queued.kind)})
	end
	for _, human in snapshot.available or {} do table.insert(rows, {name=human.name, userId=human.userId}) end
	return rows
end
function Rows.layout(index, count, hasBot)
	local extra = if hasBot then 20 else 0
	return {y=52+(index-1)*28+(if index>1 then extra else 0),
		height=if index==1 and hasBot then 44 else 24, panelHeight=52+count*28+extra}
end
return Rows
