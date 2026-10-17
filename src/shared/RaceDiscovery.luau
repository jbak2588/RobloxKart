-- Cross-track public discovery. Human reservations count as people, never bots.
local Discovery={DefaultTrackId="Track01"}
function Discovery.counts(record)
 local humans,bots,reserved=0,0,0
 if record.state=="WAITING" and record.stagedMembers then
  for _,m in record.stagedMembers do
   if m.arrived then humans+=1 else reserved+=1 end
  end
  bots=#(record.stagedBots or {})
 else
  for _,m in record.currentRoundMembers or record.waitingMembers or {} do
   if not table.find(record.leftUserIds or {},m.userId)then humans+=1 end
  end
  bots=#(record.currentRoundBots or {})
 end
 return humans,bots,reserved
end
function Discovery.rank(record)
 if record.initializing or record.practiceOnly or record.state=="CLOSING"then return nil end
 local h,_,r=Discovery.counts(record)
 if record.state=="WAITING" and h+r<record.maxPlayers then return if h+r>0 then 1 else 3 end
 if record.quickWarmup and record.state=='RACING'and h+#(record.pendingArrivals or {})<record.maxPlayers then return 1.5 end
 if h>0 and #(record.queued or {})<32 then return 2 end
 return nil
end
function Discovery.sort(records)
 table.sort(records,function(a,b)
  local ar,br=Discovery.rank(a)or 99,Discovery.rank(b)or 99
  if ar~=br then return ar<br end
  local ah,_,ap=Discovery.counts(a);local bh,_,bp=Discovery.counts(b)
  if ah+ap~=bh+bp then return ah+ap>bh+bp end
  if (a.createdAt or 0)~=(b.createdAt or 0)then return (a.createdAt or 0)<(b.createdAt or 0)end
  return a.roomId<b.roomId
 end)
 return records
end
return Discovery
