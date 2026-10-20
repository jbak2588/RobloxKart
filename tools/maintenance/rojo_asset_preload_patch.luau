-- Local Rojo 7.7.1 tooling repair, never included by default.project.json.
local serde=require('@lune/serde')
local Patch={}
Patch.originalHash='1ec46de4ebee8859e301136dccd49593dd9c35e711b827b0bb814fcf0abe036d'
Patch.source=[=[local ContentProvider = game:GetService("ContentProvider")

local Packages = script.Parent.Parent.Packages
local Log = require(Packages.Log)
local Assets = require(script.Parent.Assets)

local function gatherAssetUrlsRecursive(currentTable, currentUrls)
	currentUrls = currentUrls or {}
	for _, value in currentTable do
		if typeof(value) == "string" then
			table.insert(currentUrls, value)
		elseif typeof(value) == "table" then
			gatherAssetUrlsRecursive(value, currentUrls)
		end
	end
	return currentUrls
end

local function preloadAssets()
	-- Raw IDs are image requests here. Audio must retain its SoundId context.
	local imageAssets = {}
	for key, value in Assets do
		if key ~= "Sounds" then imageAssets[key] = value end
	end
	local contentUrls = gatherAssetUrlsRecursive(imageAssets)
	Log.trace("Preloading assets: {:?}", contentUrls)
	coroutine.wrap(function()
		local sounds = {}
		for _, soundId in Assets.Sounds do
			local sound = Instance.new("Sound")
			sound.SoundId = soundId
			table.insert(sounds, sound)
			table.insert(contentUrls, sound)
		end
		local ok, problem = pcall(function()
			ContentProvider:PreloadAsync(contentUrls)
		end)
		for _, sound in sounds do sound:Destroy() end
		if not ok then error(problem, 0) end
	end)()
end

return preloadAssets
]=]
function Patch.apply(roots)
 local module=nil
 for _,root in roots do
  if root.Name=='Rojo' then
   local plugin=root:FindFirstChild('Plugin')
   module=plugin and plugin:FindFirstChild('preloadAssets')
  end
 end
 assert(module and module:IsA('ModuleScript'),'Expected local Rojo Plugin.preloadAssets module')
 local old=module.Source:gsub('\r\n','\n')
 if old==Patch.source then return false end
 assert(serde.hash('sha256',old)==Patch.originalHash,
  'Unrecognized Rojo preloader; review this plugin version before patching')
 module.Source=Patch.source
 return true
end
return Patch
