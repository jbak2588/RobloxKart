-- Read-only decisions from the authoritative progress mirrors.
local State={}
function State.lapNotice(total,completed)
 if type(total)~='number' or type(completed)~='number' or completed<1 then return nil end
 local remaining=math.floor(total)-math.floor(completed)
 if remaining<1 then return nil end
 return if remaining==1 then 'FINAL LAP' else tostring(remaining)..' LAPS TO GO'
end
function State.gateIndex(state,nextIndex,count)
 if state~='RACING' or type(nextIndex)~='number' or type(count)~='number' or count<1 then return nil end
 if nextIndex%1~=0 or nextIndex<1 or nextIndex>count+1 then return nil end
 return if nextIndex>count then 0 else nextIndex -- 0 is the existing StartFinish gate.
end
return State
