local Catalog = require(script.Parent:WaitForChild("KDMIconCatalog"))
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
		for id in Catalog.Items do self.states[id] = "Loading" end
		scheduler.delay(View.PRELOAD_TIMEOUT, finish)
		scheduler.spawn(function()
			if not self.alive or finished then return end
			local assets, ids = {}, {}
			for id, asset in Catalog.Items do
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

function View.new(button, id, cache, mobileView)
	local image = Instance.new("ImageLabel")
	image.Name = "KDMItemImage"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Position = UDim2.fromScale(0, 0)
	image.Size = UDim2.fromScale(1, 1)
	image.ScaleType = Enum.ScaleType.Fit
	image.Active = false
	image.Selectable = false
	image.ZIndex = button.ZIndex + 1
	image.Visible = false
	image.Parent = button
	local slot = {image = image}
	function slot:setItem(nextId)
		if self.icon then self.icon.root:Destroy() end
		self.id = nextId
		self.image.Image = Catalog.Items[nextId] or ""
		self.image.Visible = false
		self.icon = mobileView.icon(button, nextId)
		local scale = Instance.new("UIScale")
		scale.Scale = 0.90
		scale.Parent = self.icon.root
		self.icon.root.Position = UDim2.fromScale(0.40, 0.40)
	end
	function slot:update(mobile, charges, highlighted)
		local loaded = Catalog.Items[self.id] ~= nil and cache:ready(self.id)
		self.image.Visible = mobile and loaded
		self.image.ImageTransparency = if charges > 0 then 0 else 0.55
		self.icon.root.Visible = mobile and not loaded
		self.icon:setEnabled(charges > 0)
		-- Artwork already contains its frame. Retain only meaningful outer emphasis.
		return mobile and (not loaded or highlighted)
	end
	slot:setItem(id)
	return slot
end

return View
