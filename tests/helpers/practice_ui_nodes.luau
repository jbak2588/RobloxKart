local rb=require("@lune/roblox")
local function signal()
	local listeners={}
	return {Connect=function(_,f)
		local entry={f=f,alive=true};table.insert(listeners,entry)
		return {Disconnect=function() entry.alive=false end}
	end,Fire=function(_,...) for _,entry in listeners do if entry.alive then entry.f(...) end end end}
end
local function object(class)
	local data={ClassName=class,Position=rb.UDim2.fromOffset(0,0),Size=rb.UDim2.fromOffset(0,0),
	 AnchorPoint=rb.Vector2.zero,Visible=true,Destroying=signal(),CharacterRemoving=signal(),Activated=signal()}
	local attrs,signals,children={},{},{}
	local self
	local methods={}
	function methods:GetAttribute(k) return attrs[k] end
	function methods:SetAttribute(k,v) local old=attrs[k];attrs[k]=v;if old~=v and signals[k] then signals[k]:Fire() end end
	function methods:GetAttributeChangedSignal(k) if not signals[k] then signals[k]=signal() end;return signals[k] end
	function methods:FindFirstChildOfClass(k) for _,c in children do if c.ClassName==k then return c end end end
	function methods:FindFirstChild(k) for _,c in children do if c.Name==k then return c end end end
	function methods:Destroy() self.Destroying:Fire();self.Parent=nil end
	self=setmetatable({}, {__index=function(_,k)
		if methods[k] then return methods[k] end
		if k=="AbsoluteSize" then
			if data.bounds then return data.bounds end
			if class=="ScreenGui" and data.Parent then return data.Parent.AbsoluteSize end
			local p=data.Parent and data.Parent.AbsoluteSize or rb.Vector2.zero
			return rb.Vector2.new(p.X*data.Size.X.Scale+data.Size.X.Offset,p.Y*data.Size.Y.Scale+data.Size.Y.Offset)
		end
		if k=="AbsolutePosition" then
			if data.origin then return data.origin end
			local p=data.Parent and data.Parent.AbsolutePosition or rb.Vector2.zero
			local s=data.Parent and data.Parent.AbsoluteSize or rb.Vector2.zero
			return p+rb.Vector2.new(s.X*data.Position.X.Scale+data.Position.X.Offset-self.AbsoluteSize.X*data.AnchorPoint.X,
			 s.Y*data.Position.Y.Scale+data.Position.Y.Offset-self.AbsoluteSize.Y*data.AnchorPoint.Y)
		end
		return data[k]
	end,__newindex=function(_,k,v) data[k]=v;if k=="Parent" and v then table.insert(v.children,self) end end})
	self.children=children
	return self
end

return {object=object,signal=signal}
