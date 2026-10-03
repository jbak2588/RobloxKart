local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local env={Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame}
local geometry=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment=env})()
local steering=luau.load(fs.readFile('src/server/RaceBotSteering.luau'),{environment=env})()
local cache=luau.load(fs.readFile('src/client/RaceResultsCache.luau'))().new()
local rivals=luau.load(fs.readFile('src/client/RaceMinimapRivals.luau'),{environment={typeof=function(v) return if type(v)=='userdata' then 'Vector3' else typeof(v) end}})()
local count=0
local function check(ok,message) assert(ok,message);count+=1 end
local course=geometry.getCourse(geometry.getDefinition('PracticeCircuitV1'))
for _,ahead in {10,14,18,22} do
	for index,point in course.Samples do
		local nextPoint=course.Samples[index % #course.Samples+1]
		local direction=(nextPoint-point).Unit
		-- fromMatrix avoids the installed Lune lookAt handedness mismatch.
		local frame=rb.CFrame.fromMatrix(point,direction:Cross(rb.Vector3.yAxis),rb.Vector3.yAxis,-direction)
		local command=steering.command(course.Samples,frame,ahead,2)
		check(command.targetSpeed==70 and command.throttle==1 and not command.driftRequested,'constant target at every curve/sample')
		check(command.steering>=-1 and command.steering<=1,'bounded steering')
	end
end
local human={UserId=12,Name='Human',DisplayName='Human',attrs={RaceSessionId=1,RaceState='FINISHED',RacePosition=2,RaceFinishPosition=2,RaceFinalTime=150}}
function human:GetAttribute(key) return self.attrs[key] end
local bot=rb.Instance.new('Folder');bot.Name='Bot01'
for key,value in {IsBot=true,BotId='Bot01',DisplayName='KDM Rookie [BOT]',RaceSessionId=1,RaceState='FINISHED',RacePosition=1,RaceFinishPosition=1,RaceFinalTime=140,RaceLap1Time=69,RaceLap2Time=71,RaceMapActive=true,RaceMapPosition=rb.Vector3.new(1,0,2)} do bot:SetAttribute(key,value) end
local rows=cache:collect(human,{human},{bot})
check(#rows==2 and rows[1].isBot and rows[1].displayName=='KDM Rookie [BOT]','explicit Folder bot wins without Player identity')
check(rows[1].finalTime==140 and rows[1].laps[1]==69 and rows[1].laps[2]==71,'bot actual result snapshot')
human.attrs.RaceFinishPosition=1;bot:SetAttribute('RaceFinishPosition',2)
rows=cache:collect(human,{human},{bot})
check(rows[1].userId==12,'human can win with unchanged bot identity')
local positions=rivals.collect(human,{human},2,{bot})
check(positions['bot:Bot01']~=nil,'replicated bot minimap rival')
bot:SetAttribute('RaceSessionId',2)
check(next(rivals.collect(human,{human},2,{bot}))==nil,'other round bot excluded')
human.attrs.RaceSessionId=2
rows=cache:collect(human,{human},{bot})
check(#rows==2,'round cache reset and fresh bot snapshot')
rows=cache:collect(human,{human},{})
check(#rows==2,'departed finisher snapshot retained in current round')
human.attrs.RaceSessionId=0
check(#cache:collect(human,{human},{bot})==0,'Garage clears standings')
print('PASS: '..count..' bot steering, explicit identity, minimap and result snapshot checks')
