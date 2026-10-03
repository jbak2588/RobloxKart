-- Optional first-load optimization. Failure releases the normal lazy-load preview.
local GarageTexturePreload = {}

function GarageTexturePreload.collect(catalog)
	local assets, seen = {}, {}
	for _, id in catalog.Order do
		local entry = catalog.Entries[id]
		local texture = entry.BodyTextureId
		if entry.VisualModelName == "KDMV2" and type(texture) == "string"
			and texture ~= "" and not seen[texture] then
			seen[texture] = true
			table.insert(assets, texture)
		end
	end
	return assets
end

function GarageTexturePreload.create(catalog, provider, scheduler, onSettled)
	local state = "NOT_STARTED"
	local alive = true
	local timer = nil
	local assets = GarageTexturePreload.collect(catalog)
	local gate = {}
	local function settle(result)
		if not alive or state ~= "LOADING" then return end
		state = result
		if timer then scheduler.cancel(timer); timer = nil end
		onSettled()
	end
	function gate.start()
		if not alive or state ~= "NOT_STARTED" then return end
		state = "LOADING"
		timer = scheduler.delay(12, function()
			timer = nil
			settle("FAILED")
		end)
		scheduler.spawn(function()
			if not alive or state ~= "LOADING" then return end
			-- Match CurvedBody's content property; direct ID requests can resolve
			-- differently from MeshPart texture dependencies in the asset pipeline.
			local dependencies = {}
			for _, texture in assets do
				local mesh = Instance.new("MeshPart")
				mesh.TextureID = texture
				table.insert(dependencies, mesh)
			end
			local failed = false
			local ok = pcall(function()
				provider:PreloadAsync(dependencies, function(_, status)
					if status.Name ~= "Success" then failed = true end
				end)
			end)
			for _, mesh in dependencies do mesh:Destroy() end
			settle(if ok and not failed then "READY" else "FAILED")
		end)
	end
	function gate.shouldWait(entry)
		return alive and state == "LOADING" and entry.VisualModelName == "KDMV2"
	end
	function gate.getState() return state end
	function gate.destroy()
		alive = false
		if timer then scheduler.cancel(timer); timer = nil end
	end
	return gate
end

return GarageTexturePreload
