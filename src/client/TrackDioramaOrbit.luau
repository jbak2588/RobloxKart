local Orbit={PITCH=math.rad(35),FOV=40,STEP=math.rad(30),SENSITIVITY=math.rad(.32),THRESHOLD=6}

function Orbit.fit(data,aspect)
 local half=(data.max-data.min)/2
 local radius=Vector3.new(half.X,0,half.Z).Magnitude
 local vertical=math.tan(math.rad(Orbit.FOV)/2)*.84
 local horizontal=vertical*math.max(.05,aspect)
 local pitch=Orbit.PITCH
 -- A swept horizontal bounding circle fits all yaw angles; include pad/gate
 -- height and reserve 16% for legibility. No resize scan of model descendants.
 return math.max(
  radius/horizontal+radius*math.cos(pitch)+half.Y*math.sin(pitch),
  (radius*math.sin(pitch)+half.Y*math.cos(pitch))/vertical+radius*math.cos(pitch)+half.Y*math.sin(pitch),1)
end

function Orbit.frame(center,yaw,distance)
 local direction=Vector3.new(math.sin(yaw)*math.cos(Orbit.PITCH),math.sin(Orbit.PITCH),math.cos(yaw)*math.cos(Orbit.PITCH))
 local right=Vector3.yAxis:Cross(direction).Unit
 return CFrame.fromMatrix(center+direction*distance,right,direction:Cross(right),direction)
end

function Orbit.drag(yaw,deltaX) return yaw-deltaX*Orbit.SENSITIVITY end
return Orbit
