-- Bounded diagnostic state only; no control, simulation or remote authority.
local Buffer={}
Buffer.__index=Buffer
function Buffer.new(capacity)
	return setmetatable({capacity=capacity or 60,rows={},cursor=0,count=0,lastReport=-math.huge,events=0},Buffer)
end
function Buffer:push(row)
	self.cursor=self.cursor%self.capacity+1
	self.rows[self.cursor]=row
	self.count=math.min(self.count+1,self.capacity)
end
function Buffer:snapshot()
	local out={}
	for i=1,self.count do out[i]=self.rows[(self.cursor-self.count+i-1)%self.capacity+1] end
	return out
end
function Buffer:report(now)
	self.events+=1
	if now-self.lastReport<10 then return false end
	self.lastReport=now
	return true
end
function Buffer.allowed(studio,userId,experience,place)
	-- Performance diagnostics only; progression/records Canary policies are separate.
	return studio or (userId==11700555357 or userId==11734277722)
		and experience==10768420544 and place==127925465904803
end
return Buffer
