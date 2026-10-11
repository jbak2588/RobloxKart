local fs,luau,process=require('@lune/fs'),require('@lune/luau'),require('@lune/process')
local B=luau.load(fs.readFile('src/shared/KDMPerformanceBuffer.luau'))()
local n=0
local function check(v,label) assert(v,label);n+=1 end
local b=B.new(60)
for i=1,600 do b:push({i=i}) end
local s=b:snapshot()
check(#b.rows==60 and #s==60,'diagnostic memory bounded after long run')
check(s[1].i==541 and s[60].i==600,'chronological ring history')
check(b:report(0) and not b:report(1) and b:report(10),'anomaly summary rate limited')
for _,id in {1,11700555356,11700555358} do check(not B.allowed(false,id,10768420544,127925465904803),'noncanary excluded') end
check(B.allowed(false,11700555357,10768420544,127925465904803),'exact approved canary')
check(not B.allowed(false,11700555357,1,127925465904803),'wrong experience excluded')
check(not B.allowed(false,11700555357,10768420544,1),'wrong place excluded')
check(B.allowed(true,1,0,0),'Studio diagnostic only permitted')
local source=fs.readFile('src/server/PrototypeWorld.luau'):gsub('\r\n','\n')
source=source:gsub("local perfModule=script.Parent:FindFirstChild%('RacePerformanceMonitor'%)\nlocal PerformanceMonitor=if perfModule then require%(perfModule%) else nil\n",'')
source=source:gsub('\t\t\tif PerformanceMonitor then PerformanceMonitor.remove%(context%) end\n','')
source=source:gsub('\t\tlocal diagnostic=PerformanceMonitor and PerformanceMonitor.active%(%)\n','')
source=source:gsub('\t\t\t\tlocal began=PerformanceMonitor and PerformanceMonitor.active%(%) and os.clock%(%)\n','')
source=source:gsub('\t\t\t\tif began then context.perfBotSteeringMs=%(os.clock%(%)%-began%)%*1000 end\n','')
local added=[[if context.kart.Parent then
				local began=if diagnostic then os.clock() else 0
				context:step(deltaTime)
				if diagnostic then PerformanceMonitor.observe(context,deltaTime,(os.clock()-began)*1000) end
			end]]
local a,z=source:find(added,1,true);check(a~=nil,'exact observer wrapper found')
source=source:sub(1,a-1)..'if context.kart.Parent then context:step(deltaTime) end'..source:sub(z+1)
local baseline=process.exec('git',{'-C',process.args[1] or '.', 'show','c7b23d9c6bbd5b03d33ca24884b63268a99f75d8:src/server/PrototypeWorld.luau'})
check(baseline.ok and source==baseline.stdout:gsub('\r\n','\n'),'entire simulation/input/Bot/lifecycle unchanged except exact observations')
local balance=luau.load(fs.readFile('src/shared/KDMGameplayBalance.luau'))()
local config=luau.load(fs.readFile('src/shared/KartConfig.luau'),{environment={script={Parent={WaitForChild=function()return {} end}},require=function()return balance end}})()
check(config.INPUT_TIMEOUT==.5 and config.COAST_DECELERATION==18,'input timeout and coast tuning preserved')
-- Demonstrates a possible stall amplifier, NOT proof that the mobile server stalled.
check(math.max(70-config.COAST_DECELERATION*4,0)==0,'expired input plus four-second dt can coast to zero in one step')
print('PASS: '..n..' bounded diagnostic gates/history and exact simulation preservation checks')
