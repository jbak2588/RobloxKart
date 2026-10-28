-- Prepared only: no execution or Publish is performed by this file's creation.
-- Studio Edit command/plugin use only; exact private QA destination, one module.
assert(game.GameId==10772198697 and game.PlaceId==106553302629620,
 'Only the designated private QA Universe/Place may receive this patch')
local run=game:GetService('RunService')
assert(run:IsStudio() and not run:IsRunning(),'Studio Edit only')
local before=[====[-- Cosmetic-only profiles shared by the existing camera and world observer.
-- No gameplay writes, services, instances or Shield input.
local Speed = {}
Speed.HIGH_SPEED_START = 55
Speed.HIGH_SPEED_FULL = 80
Speed.ATTACK_RESPONSE = 10
Speed.RELEASE_RESPONSE = 5
Speed.MAX_FOV = 87
Speed.Profiles = table.freeze({
	NONE = table.freeze({FovDelta=0, TrailCount=0, Lifetime=0, Width=0, Transparency=1, LightEmission=0}),
	HIGH_SPEED = table.freeze({FovDelta=3, TrailCount=2, Lifetime=.10, Width=.14, Transparency=.84, LightEmission=.10}),
	MINI_BOOST = table.freeze({FovDelta=6, TrailCount=4, Lifetime=.20, Width=.26, Transparency=.50, LightEmission=.35}),
	NITRO = table.freeze({FovDelta=10, TrailCount=4, Lifetime=.32, Width=.40, Transparency=.28, LightEmission=.60}),
})
local function finite(value)
	return type(value)=="number" and value==value and math.abs(value)<math.huge
end
function Speed.resolve(forwardSpeed, boosting, nitro, enabled, offTrack)
	if not enabled or offTrack or not finite(forwardSpeed) or forwardSpeed<0 then return "NONE",0 end
	if nitro then return "NITRO",1 end
	if boosting then return "MINI_BOOST",1 end
	local alpha=math.clamp((forwardSpeed-Speed.HIGH_SPEED_START)/(Speed.HIGH_SPEED_FULL-Speed.HIGH_SPEED_START),0,1)
	alpha=alpha*alpha*(3-2*alpha)
	return if alpha>0 then "HIGH_SPEED" else "NONE",alpha
end
function Speed.targetFov(baseFov, tier, intensity)
	local profile=Speed.Profiles[tier] or Speed.Profiles.NONE
	return math.min(baseFov+profile.FovDelta*math.clamp(intensity,0,1),Speed.MAX_FOV)
end
function Speed.stepFov(current, target, dt)
	if not finite(target) then target=75 end
	if not finite(current) then current=target end
	if not finite(dt) or dt<=0 then return current end
	local response=if target>current then Speed.ATTACK_RESPONSE else Speed.RELEASE_RESPONSE
	return current+(target-current)*(1-math.exp(-response*dt))
end
return table.freeze(Speed)
]====]
local after=[====[-- Cosmetic-only profiles shared by the existing camera and world observer.
-- No gameplay writes, services, instances or Shield input.
local Speed = {}
Speed.HIGH_SPEED_START = 50
Speed.HIGH_SPEED_FULL = 90
Speed.ATTACK_RESPONSE = 10
Speed.RELEASE_RESPONSE = 5
Speed.MAX_FOV = 87
Speed.Profiles = table.freeze({
	NONE = table.freeze({FovDelta=0, TrailCount=0, Lifetime=0, Width=0, Transparency=1, LightEmission=0}),
	HIGH_SPEED = table.freeze({FovDelta=5, TrailCount=2, Lifetime=.10, Width=.14, Transparency=.84, LightEmission=.10}),
	MINI_BOOST = table.freeze({FovDelta=6, TrailCount=4, Lifetime=.20, Width=.26, Transparency=.50, LightEmission=.35}),
	NITRO = table.freeze({FovDelta=10, TrailCount=4, Lifetime=.32, Width=.40, Transparency=.28, LightEmission=.60}),
})
local function finite(value)
	return type(value)=="number" and value==value and math.abs(value)<math.huge
end
function Speed.resolve(forwardSpeed, boosting, nitro, enabled, offTrack)
	if not enabled or offTrack or not finite(forwardSpeed) or forwardSpeed<0 then return "NONE",0 end
	if nitro then return "NITRO",1 end
	if boosting then return "MINI_BOOST",1 end
	local alpha=math.clamp((forwardSpeed-Speed.HIGH_SPEED_START)/(Speed.HIGH_SPEED_FULL-Speed.HIGH_SPEED_START),0,1)
	alpha=alpha*alpha*(3-2*alpha)
	return if alpha>0 then "HIGH_SPEED" else "NONE",alpha
end
function Speed.targetFov(baseFov, tier, intensity)
	local profile=Speed.Profiles[tier] or Speed.Profiles.NONE
	return math.min(baseFov+profile.FovDelta*math.clamp(intensity,0,1),Speed.MAX_FOV)
end
function Speed.stepFov(current, target, dt)
	if not finite(target) then target=75 end
	if not finite(current) then current=target end
	if not finite(dt) or dt<=0 then return current end
	local response=if target>current then Speed.ATTACK_RESPONSE else Speed.RELEASE_RESPONSE
	return current+(target-current)*(1-math.exp(-response*dt))
end
return table.freeze(Speed)
]====]
local shared=game:GetService('ReplicatedStorage'):FindFirstChild('Shared')
local module=shared and shared:FindFirstChild('KDMSpeedSensation')
assert(module and module:IsA('ModuleScript'),'Expected existing Shared.KDMSpeedSensation')
local current=module.Source:gsub('\r\n','\n')
assert(current==before or current==after,'Unexpected QA source: stop, do not overwrite')
if current==after then return 'Private QA FOV candidate already present; no write' end
module.Source=after
return 'Private QA FOV module updated in Studio Edit only; NOT Published'
