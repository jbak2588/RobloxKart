-- Derived ranking index only. Adapters never write the account/profile store.
local Runtime={}
function Runtime.new(policy,deps)
 local self={pending={},cache={},own={},wanted={},lastRead=-math.huge}
 function self:offer(userId,scores)
  if not policy.integer(userId)or userId<=0 then return end
  local rows=self.pending[userId]or {};self.pending[userId]=rows
  self.own[userId]=self.own[userId]or {}
  for id,score in scores do
   local b=policy.Boards[id]
   if b and b.enabled and policy.integer(score)and (not b.ascending or score>0)then
    local old=rows[id]and rows[id].score or self.own[userId][id]
    local best=if old==nil then score elseif b.ascending then math.min(old,score)else math.max(old,score)
    self.own[userId][id]=best
    if not rows[id]or rows[id].score~=best then rows[id]={score=best,attempt=0,due=0}end
   end
  end
  if next(rows)==nil then self.pending[userId]=nil end
 end
 function self:remove(userId)
  local rows={};for id,b in policy.Boards do if b.enabled then rows[id]={remove=true,attempt=0,due=0}end end
  self.pending[userId]=if next(rows)then rows else nil;self.own[userId]=nil
 end
 function self:write(now)
  for uid,rows in self.pending do for id,row in rows do if now>=row.due then
   local ok,saved=pcall(if row.remove then deps.remove else deps.upsert,policy.Boards[id],uid,row.score)
   if ok and saved then rows[id]=nil else row.attempt+=1;row.due=now+math.min(60,2^math.min(row.attempt,6))end
   if next(rows)==nil then self.pending[uid]=nil end
   return
  end end end
 end
 function self:request(id,now)
  local board=policy.Boards[id];if not board then return nil end
  if not board.enabled then return {status='POLICY_PENDING',rows={}}end
  local c=self.cache[id]
  if not c or now-(c.at or 0)>=policy.RefreshSeconds then self.wanted[id]=self.wanted[id]or now end
  return c or {status='LOADING',rows={}}
 end
 function self:read(now)
  if now-self.lastRead<policy.ReadInterval then return end
  local id,oldest=nil,math.huge
  for candidate,queuedAt in self.wanted do
   if queuedAt<oldest or(queuedAt==oldest and(id==nil or candidate<id))then id=candidate;oldest=queuedAt end
  end
  if not id then return end
  self.wanted[id]=nil;self.lastRead=now
  local ok,rows=pcall(deps.read,policy.Boards[id],policy.PageSize)
  if ok and type(rows)=='table'then
   local clean={};for _,r in rows do
    local uid=tonumber(r.key)
    if policy.integer(uid)and uid>0 and policy.integer(r.value)and (not policy.Boards[id].ascending or r.value>0)then table.insert(clean,{userId=uid,score=r.value})end
   end
   table.sort(clean,function(a,b)if a.score==b.score then return a.userId<b.userId end;return if policy.Boards[id].ascending then a.score<b.score else a.score>b.score end)
   while #clean>policy.PageSize do table.remove(clean)end
   self.cache[id]={status='READY',rows=clean,at=now}
  else
   local old=self.cache[id];self.cache[id]={status='STALE',rows=old and old.rows or {},at=old and old.at or 0}
  end
 end
 return self
end
-- One bounded, restart-safe sweep per Hub. Only derivative indexes are written.
-- A failed page/read retains its cursor/key. Repeating a sweep is idempotent.
function Runtime.newBackfill(deps)
 local self={cursor='',keys=nil,index=1,done=false,visited=0,due=0,attempt=0}
 function self:step(now)
  if self.done or now<self.due or not deps.canStep()then return end
  self.due=now+2
  local ok,accepted
  if self.keys==nil then
   local page;ok,page=pcall(deps.page,self.cursor)
   accepted=ok and type(page)=='table'and type(page.keys)=='table'and type(page.cursor)=='string'
    and type(page.finished)=='boolean'and(page.finished or page.cursor~=self.cursor)
   if accepted then self.keys=page.keys;self.cursor=page.cursor;self.lastPage=page.finished;self.index=1 end
  elseif self.index>#self.keys then
   if self.lastPage then self.done=true else self.keys=nil end
   accepted=true;ok=true
  else
   ok,accepted=pcall(deps.consume,self.keys[self.index])
   if ok and accepted then self.index+=1;self.visited+=1 end
  end
  if ok and accepted then self.attempt=0
  else self.attempt+=1;self.due=now+math.min(60,2^math.min(self.attempt,6))end
 end
 return self
end
return Runtime
