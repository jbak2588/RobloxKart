-- Multi-bot fleet validation: 4 bots, 30s staggered delay, 4 distinct colors, combat targeting & item hit effects.
local fs, luau, rb = require('@lune/fs'), require('@lune/luau'), require('@lune/roblox')

local n = 0
local function check(v, m) assert(v, m); n += 1 end

local policy = luau.load(fs.readFile('src/shared/LobbyPracticePolicy.luau'), { environment = { Color3 = rb.Color3 } })()
check(policy.BotFleet ~= nil, 'BotFleet table defined in LobbyPracticePolicy')
check(#policy.BotFleet == 7, 'BotFleet contains exactly 4 bots')

local delays = {}
local kartIds = {}
for i, bot in policy.BotFleet do
 check(bot.id == i, 'bot id matches index ' .. i)
 check(bot.delay == (i - 1) * 30, 'bot ' .. i .. ' has staggered delay ' .. ((i - 1) * 30) .. 's')
 table.insert(delays, bot.delay)
 check(not kartIds[bot.kartId], 'distinct kart model/color for bot ' .. i .. ': ' .. bot.kartId)
 kartIds[bot.kartId] = true
 check(bot.driverColor ~= nil, 'distinct driver suit color defined for bot ' .. i)
end
check(delays[1] == 0 and delays[2] == 30 and delays[3] == 60 and delays[4] == 90, 'delays strictly 0, 30, 60, 90')

-- Load full practice orchestrator to verify multi-bot combat
local prefix = fs.readFile('tests/lobby_practice_combat_validation.luau')
prefix = prefix:sub(1, assert(prefix:find('local c,p,q,r,s=fresh()', 1, true)) - 1)
prefix = prefix:gsub("require%('%./helpers/gameplay_config'%)", 'CONFIG_LOADER'):gsub("require%('%./helpers/lobby_drift_session'%)", 'DRIFT')
prefix = prefix:gsub('local Combat=module', "module('HubParkRookieLoopLayout','src/shared/HubParkRookieLoopLayout.luau')\nmodule('RookieLoopDemoRoute','src/shared/RookieLoopDemoRoute.luau')\nlocal Combat=module")
prefix = prefix:gsub("zone:SetAttribute%('Center',rb.Vector3.new%(120,0,766%)%)", "zone:SetAttribute('Center',rb.Vector3.zero);zone:SetAttribute('DriveGeometry','ROOKIE_LOOP_V1')")

local testScript = [[
local c, p, q = fresh()
check(#c.bots == 7, 'server spawned 4 practice bots for RookieLoop')
check(c.bot == c.bots[1], 'c.bot backward compatibility points to bot 1')

-- At t=0, only bot 1 is active
tick(0.01)
check(c:valid(c.bots[1]), 'bot 1 is active at t=0')
check(not c:valid(c.bots[2]), 'bot 2 inactive before 30s')
check(not c:valid(c.bots[3]), 'bot 3 inactive before 60s')
check(not c:valid(c.bots[4]), 'bot 4 inactive before 90s')

-- Advance to t=35s -> bot 1 and bot 2 active
tick(35)
check(c:valid(c.bots[1]), 'bot 1 still active at t=35')
check(c:valid(c.bots[2]), 'bot 2 activated after 30s')
check(not c:valid(c.bots[3]), 'bot 3 inactive before 60s')
check(not c:valid(c.bots[4]), 'bot 4 inactive before 90s')

-- Advance to t=65s -> bots 1, 2, 3 active
tick(30)
check(c:valid(c.bots[3]), 'bot 3 activated after 60s')
check(not c:valid(c.bots[4]), 'bot 4 inactive before 90s')

-- Advance to t=95s -> all 4 bots active
tick(120) -- t185: every30s activation through the seventh color
check(c:valid(c.bots[4]), 'bot 4 activated after 90s')
for i = 1, 7 do
 check(c:valid(c.bots[i]), 'all 4 bots active at t=95: bot ' .. i)
 check(c.bots[i].record.kart:GetAttribute('BotActive') == true, 'replicated BotActive attribute true for bot ' .. i)
 check(c.bots[i].record.kart:GetAttribute('KartId') == policy.BotFleet[i].kartId, 'replicated KartId matches for bot ' .. i)
end

-- Test targeting against bot 2 and item hit effects
local victim = c.bots[2]
local accepted, reason = c:resolve(victim, c.actors[p], 'Missile', now)
check(accepted and reason == 'hit', 'missile resolves on bot 2')
tick(0.01)
check(victim.record.kart:GetAttribute('KartMissileHitActive') == true, 'KartMissileHitActive replicated on bot 2')

c:clearTransient(victim)
accepted, reason = c:resolve(victim, c.actors[p], 'Thunder', now)
check(accepted and reason == 'hit', 'thunder resolves on bot 2')
tick(0.01)
check(victim.record.kart:GetAttribute('KartThunderHitActive') == true, 'KartThunderHitActive replicated on bot 2')

c:clearTransient(victim)
accepted, reason = c:resolve(victim, c.actors[p], 'Slick', now)
check(accepted and reason == 'hit', 'slick resolves on bot 2')
tick(0.01)
check(victim.record.kart:GetAttribute('KartSlickActive') == true, 'KartSlickActive replicated on bot 2')

c:destroy()
scene.root:Destroy()
return n
]]

local integrationCount = luau.load(prefix .. testScript, {
 environment = {
  CONFIG_LOADER = require('./helpers/gameplay_config'),
  DRIFT = require('./helpers/lobby_drift_session'),
  policy = policy,
  check = check,
 }
})()

print(string.format('PASS %d checks: 4-bot fleet (30s staggered delay, 4 distinct colors, progressive activation & hit effects verified)', n))
