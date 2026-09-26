local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local motion = luau.load(fs.readFile("src/shared/ChaseCameraMotion.luau"))()
local V, CF = rb.Vector3, rb.CFrame
local checks = 0
for _, speed in {0, 70, 82, 100, -20} do
	local target, previous = V.zero, nil
	local camera = CF.identity
	for frame = 1, 600 do
		local dt = if frame % 17 == 0 then 0.1 elseif frame % 3 == 0 then 1/30 else 1/120
		target += V.new(0, 0, -speed*dt)
		local desired = CF.lookAt(target+V.new(0,8,18),target+V.new(0,2,-10))
		camera = motion.step(camera,previous,target,desired,6,dt)
		assert((camera.Position-target-V.new(0,8,18)).Magnitude < 0.001, "frame cadence must not cause chase distance oscillation")
		previous = target
	end
	checks += 1
end
local desired = CF.new(500,10,0)
assert(motion.step(CF.identity,V.zero,V.new(500,0,0),desired,6,0.016)==desired)
checks += 1
print("PASS: "..checks.." camera motion cases (3000 variable-frame samples and teleport reset)")
