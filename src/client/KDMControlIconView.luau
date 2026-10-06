local Catalog = require(script.Parent:WaitForChild("KDMIconCatalog"))
local Assets = table.freeze({
	AutoStart=Catalog.Actions.AutoStart,
	AutoStartOn=Catalog.Actions.AutoStartOn,
	Forward=Catalog.Drive.Forward, ForwardLeft=Catalog.Drive.ForwardLeft,
	ForwardRight=Catalog.Drive.ForwardRight, BrakeReverse=Catalog.Drive.BrakeReverse,
	DriftWide=Catalog.Actions.DriftWide, DriftSquare=Catalog.Actions.DriftSquare,
})
local View = {}
View.PRELOAD_TIMEOUT = 12

-- The HUD stays interactive while content loads. Terminal states never reopen:
-- late callbacks cannot replace a timeout fallback or touch a destroyed HUD.
function View.cache(provider, scheduler)
	local cache = {states = {}, alive = true, started = false}
	local preloadImages = {}
	local function releaseImages()
		for _, image in preloadImages do image:Destroy() end
		table.clear(preloadImages)
	end
	function cache:ready(id) return self.alive and self.states[id] == "Success" end
	function cache:destroy() self.alive = false; releaseImages() end
	function cache:start(changed)
		if self.started or not self.alive then return end
		self.started = true
		local finished = false
		local function finish()
			if finished then return end
			finished = true
			for id, state in self.states do
				if state == "Loading" then self.states[id] = "Failure" end
			end
			releaseImages()
			if self.alive then changed() end
		end
		for id in Assets do self.states[id] = "Loading" end
		scheduler.delay(View.PRELOAD_TIMEOUT, finish)
		scheduler.spawn(function()
			if not self.alive or finished then return end
			local assets, ids = {}, {}
			for id, asset in Assets do
				local image = Instance.new("ImageLabel")
				image.Image = asset
				table.insert(preloadImages, image)
				table.insert(assets, image)
				ids[asset:match("%d+")] = id
			end
			pcall(function()
				provider:PreloadAsync(assets, function(asset, status)
					local id = ids[tostring(asset):match("%d+")]
					if not self.alive or finished or not id then return end
					self.states[id] = if status == Enum.AssetFetchStatus.Success then "Success" else "Failure"
					changed()
				end)
			end)
			finish()
		end)
	end
	return cache
end

function View.new(button, key, cache, mobileView)
	local fallbackKey = if key == "DriftWide" or key == "DriftSquare" then "Drift" elseif key == "AutoStart" then "AutoForward"
		elseif key == "ForwardLeft" then "Left" elseif key == "ForwardRight" then "Right" else key
	local fallback = mobileView.icon(button, fallbackKey, button.ZIndex + 1)
	local image = Instance.new("ImageLabel")
	image.Name = "KDMControlImage"
	image.AnchorPoint = Vector2.new(.5,.5)
	image.Position = UDim2.fromScale(.5,.5)
	image.Size = UDim2.fromScale(1,1)
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = Assets[key] or ""
	image.ZIndex = button.ZIndex + 1
	image.Active = false
	image.Selectable = false
	image.Visible = false
	image.Parent = button
	local scale = Instance.new("UIScale");scale.Parent = image
	local self = {image=image, fallback=fallback, scale=scale}
	function self:layout(width, height) image.Size=UDim2.fromOffset(width,height) end
	function self:update(enabled, held)
		local assetKey = if key == "AutoStart" and enabled and held then "AutoStartOn" else key
		local loaded = Assets[assetKey] ~= nil and cache:ready(assetKey)
		image.Image = Assets[assetKey] or ""
		image.Visible=loaded;fallback.root.Visible=not loaded
		image.ImageTransparency=if enabled then 0 else .55
		scale.Scale=1
		image.ImageColor3=if held and enabled then Color3.fromRGB(255,255,255) else Color3.fromRGB(225,235,245)
		fallback:setLatched(key == "AutoStart" and held == true)
		fallback:setEnabled(enabled)
		return loaded
	end
	self:update(true,false)
	return self
end
return View
