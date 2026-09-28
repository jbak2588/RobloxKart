local fs, luau = require("@lune/fs"), require("@lune/luau")
local checks = 0
local function check(value, label)
	assert(value, label)
	checks += 1
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback) table.insert(callbacks, callback) end,
		Fire = function(_, ...) for _, callback in callbacks do callback(...) end end,
	}
end
local function player(id)
	local attributes = {}
	return {
		UserId = id, Parent = true,
		SetAttribute = function(_, key, value) attributes[key] = value end,
		GetAttribute = function(_, key) return attributes[key] end,
	}
end
local function fixture(initial, failLoad, failSave)
	local user = player(47)
	local players = { PlayerAdded = signal(), GetPlayers = function() return { user } end }
	local replicated = {}
	local saved, saveCount = initial, 0
	local store = {
		GetAsync = function()
			if failLoad then error("load unavailable") end
			return saved
		end,
		UpdateAsync = function(_, _, update)
			if failSave then error("save unavailable") end
			saved = update(saved)
			saveCount += 1
		end,
	}
	local dataStore = { GetDataStore = function(_, name)
		check(name == "KDM_PlayerPrefs_v1", "uses dedicated preference store")
		return store
	end }
	local queued = {}
	local env = {
		game = { GetService = function(_, name)
			return assert(({ Players = players, ReplicatedStorage = replicated, DataStoreService = dataStore })[name])
		end },
		Instance = { new = function(class)
			check(class == "RemoteEvent", "creates preference remote")
			return setmetatable({ OnServerEvent = signal() }, { __newindex = function(self, key, value)
				rawset(self, key, value)
				if key == "Parent" then value[self.Name] = self end
			end })
		end },
		task = { spawn = function(callback) table.insert(queued, callback) end },
		warn = function() end,
	}
	local module = luau.load(fs.readFile("src/server/PlayerPreferences.luau"), { environment = env })()
	module.start()
	local function flush()
		while #queued > 0 do table.remove(queued, 1)() end
	end
	return user, replicated.ControlsTutorialPreference, flush,
		function() return saved, saveCount end
end

local user, remote, flush, getSaved = fixture({ controlsTutorialDismissed = true, other = 3 })
check(user:GetAttribute("ControlsTutorialPreferenceLoaded") == false, "load starts pending")
flush()
check(user:GetAttribute("ControlsTutorialPreferenceLoaded") and user:GetAttribute("ControlsTutorialDismissed"),
	"stored dismissal loads")
remote.OnServerEvent:Fire(user, "Dismiss")
flush()
local _, count = getSaved()
check(count == 0, "already dismissed does not save again")

user, remote, flush, getSaved = fixture({ other = 3 })
remote.OnServerEvent:Fire(user, "Dismiss")
check(user:GetAttribute("ControlsTutorialDismissed"), "dismiss updates server attribute immediately")
flush()
local value
value, count = getSaved()
check(user:GetAttribute("ControlsTutorialPreferenceLoaded") and user:GetAttribute("ControlsTutorialDismissed"),
	"late load preserves local dismissal")
check(count == 1 and value.controlsTutorialDismissed and value.other == 3,
	"save preserves unrelated preferences")

user, remote, flush = fixture(nil, true, true)
flush()
check(user:GetAttribute("ControlsTutorialPreferenceLoaded") and not user:GetAttribute("ControlsTutorialDismissed"),
	"load failure falls back to tutorial")
remote.OnServerEvent:Fire(user, "Dismiss")
flush()
check(user:GetAttribute("ControlsTutorialDismissed"), "save failure retains current session dismissal")
print("PASS: " .. checks .. " tutorial preference checks")
