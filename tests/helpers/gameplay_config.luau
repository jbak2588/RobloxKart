-- Lune bridge for the real Roblox config dependency; no runtime fallback.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local balance = luau.load(fs.readFile("src/shared/KDMGameplayBalance.luau"))()
return function(path)
	local dependency = { Name = "KDMGameplayBalance" }
	return luau.load(fs.readFile(path), { debugName = path, environment = {
		script = { Parent = { WaitForChild = function(_, name)
			assert(name == dependency.Name, name)
			return dependency
		end } },
		require = function(module) assert(module == dependency); return balance end,
	} })()
end
