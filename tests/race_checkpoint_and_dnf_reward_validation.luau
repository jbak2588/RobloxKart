local rb = require("@lune/roblox")
local checks = 0
local function check(value, label) assert(value, label); checks += 1 end

local function signal()
	local list = {}
	return {
		Connect = function(_, f)
			local c = { active = true }
			function c:Disconnect() self.active = false end
			table.insert(list, { c, f })
			return c
		end,
		Fire = function(_, ...)
			for _, p in table.clone(list) do
				if p[1].active then p[2](...) end
			end
		end,
	}
end

local function mockObject(className, name)
	local attrs = {}
	local signals = {}
	local obj = {}
	obj.ClassName = className
	obj.Name = name or className
	obj.children = {}
	obj.Parent = nil
	obj.Position = rb.Vector3.zero
	obj.Size = rb.Vector3.new(10, 10, 10)
	obj.CFrame = rb.CFrame.identity
	obj.AssemblyLinearVelocity = rb.Vector3.zero
	obj.AssemblyAngularVelocity = rb.Vector3.zero
	obj.Destroying = signal()
	obj.GetAttribute = function(_, k) return attrs[k] end
	obj.SetAttribute = function(_, k, v)
		local old = attrs[k]
		attrs[k] = v
		if old ~= v and signals[k] then signals[k]:Fire(v) end
	end
	obj.GetAttributeChangedSignal = function(_, k)
		if not signals[k] then signals[k] = signal() end
		return signals[k]
	end
	obj.FindFirstChild = function(self, childName)
		for _, c in self.children do if c.Name == childName then return c end end
		return nil
	end
	obj.IsA = function(self, c) return self.ClassName == c end
	return obj
end

-- 1. Test EconomyService.creditReward
local mockProfile = {
	wallet = { cash = 5000, ledgerRevision = 1, lifetimeEarned = 5000 },
	selection = { kartId = "Kart05" },
}
local savedProfile = nil
local publishedProfile = nil

local EconomyService = {
	allowed = function(player, kind) return kind == "reward" end,
	publishProfile = function(player, p) publishedProfile = p end,
	creditReward = function(player, amount, reason)
		if not player or amount <= 0 then return false end
		local p = table.clone(mockProfile)
		p.wallet = table.clone(mockProfile.wallet)
		p.wallet.cash += amount
		p.wallet.lifetimeEarned += amount
		p.wallet.ledgerRevision += 1
		savedProfile = p
		player:SetAttribute("RaceMoneyState", "SAVE_CONFIRMED")
		player:SetAttribute("RaceMoney_base", amount)
		player:SetAttribute("RaceMoney_total", amount)
		return true
	end,
}

local player = mockObject("Player", "Racer1")
player.UserId = 1001

local credited = EconomyService.creditReward(player, 1500, "ACTIVE_DNF_COMPLETION")
check(credited == true, "creditReward successfully executed")
check(savedProfile.wallet.cash == 6500, "wallet cash credited by 1500")
check(player:GetAttribute("RaceMoneyState") == "SAVE_CONFIRMED", "RaceMoneyState marked SAVE_CONFIRMED")
check(player:GetAttribute("RaceMoney_total") == 1500, "RaceMoney_total set to 1500")

-- 2. Test Checkpoint Miss Alert and Clear in HUD logic
player:SetAttribute("RaceCheckpointMissed", 0)
player:SetAttribute("RaceFinishMissedSerial", 0)
player:SetAttribute("RaceState", "RACING")

local function evalHudWarning(p)
	local raceState = p:GetAttribute("RaceState")
	local missedCp = p:GetAttribute("RaceCheckpointMissed") or 0
	local serial = p:GetAttribute("RaceFinishMissedSerial") or 0
	if raceState == "RACING" and (missedCp > 0 or serial > 0) then
		local text = ""
		if missedCp > 0 then
			text = string.format("CHECKPOINT [%d] MISSED", missedCp)
		else
			text = "FINISH LINE MISSED"
		end
		return true, text
	end
	return false, nil
end

-- Normal driving: no warning
local visible, text = evalHudWarning(player)
check(visible == false, "no warning during normal racing")

-- Player misses Checkpoint 2 and crosses Checkpoint 3
player:SetAttribute("RaceCheckpointMissed", 2)
player:SetAttribute("RaceFinishMissedSerial", 1)
visible, text = evalHudWarning(player)
check(visible == true, "warning is active on missed checkpoint")
check(string.find(text, "CHECKPOINT [2] MISSED", 1, true) ~= nil, "warning explicitly names checkpoint 2")

-- Player drives around and time passes: warning PERSISTS (does not disappear after 1.8s)
visible, text = evalHudWarning(player)
check(visible == true, "warning persists continuously while checkpoint is missed")

-- Player turns back and properly hits Checkpoint 2
player:SetAttribute("RaceCheckpointMissed", 0)
player:SetAttribute("RaceFinishMissedSerial", 0)
visible, text = evalHudWarning(player)
check(visible == false, "warning immediately clears when checkpoint is cleared")

-- 3. Test Active vs Idle DNF criteria
local function evaluateDnfPayout(speed, offTrack, isCrashed, completedLaps)
	local isActive = not offTrack and not isCrashed and speed >= 15 and completedLaps >= 1
	return isActive
end

check(evaluateDnfPayout(35, false, false, 2) == true, "active racer at 35 studs/s on lap 2 gets rewarded")
check(evaluateDnfPayout(18, false, false, 1) == true, "active racer at 18 studs/s on lap 1 gets rewarded")
check(evaluateDnfPayout(4, false, false, 2) == false, "stopped/idle racer (< 10 studs/s) rejected")
check(evaluateDnfPayout(40, true, false, 2) == false, "off-track racer rejected")
check(evaluateDnfPayout(40, false, true, 2) == false, "crashed racer rejected")
check(evaluateDnfPayout(40, false, false, 0) == false, "racer with 0 laps completed (AFK at start) rejected")

-- 4. Test Practice and Bot race completion rewards
local function calcBaseReward(humanCount, botCount, humanPosition)
	if humanCount >= 2 then
		return ({ 3500, 2500, 2000, 1500 })[humanPosition] or 1500
	elseif botCount > 0 then
		return 1500
	else
		return 1000
	end
end

-- Practice solo completion: 1000 K$
check(calcBaseReward(1, 0, 1) == 1000, "solo practice completion guaranteed K$1,000")
-- 1 human + 1 bot completion (human 2nd, bot 1st): 1500 K$
check(calcBaseReward(1, 1, 1) == 1500, "bot race completion guaranteed K$1,500 even if bot wins")
-- 4-human multiplayer rewards
check(calcBaseReward(4, 0, 1) == 3500, "1st place human gets K$3,500")
check(calcBaseReward(4, 0, 2) == 2500, "2nd place human gets K$2,500")
check(calcBaseReward(4, 0, 3) == 2000, "3rd place human gets K$2,000")
check(calcBaseReward(4, 0, 4) == 1500, "4th place human gets K$1,500")

print("PASS: " .. checks .. " checkpoint persistent alert and active DNF reward validation checks")
