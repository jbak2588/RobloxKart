local training=require('./helpers/lobby_drift_session')
local fs,luau=require('@lune/fs'),require('@lune/luau')
local rb=require('@lune/roblox')
local p=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local geometry=luau.load(fs.readFile('src/shared/LobbyDriveGeometry.luau'))().create(p)
local n=0;local function check(v,label)assert(v,label);n+=1 end
check(p.Forward==60 and p.Reverse==30 and p.TurnRadius==50 and p.DriftTurnRadius==35,'approved Lobby policy')
for _,dt in {1/30,1/60,.05} do for _,input in {-10,-1,0,1,10} do
 local s=0;for _=1,300 do s=p.advance(s,input,dt);check(s>=-30 and s<=60,'oversized finite axes cannot overspeed') end
end end
for angle=0,359,3 do
 local a=math.rad(angle);local nx,nz=math.cos(a),math.sin(a)
 for _,sign in {-1,1} do for tangent=-60,60,10 do
  local x,z=nx*20-nz*tangent,nz*20+nx*tangent
  local sx,sz=p.slide(x,z,nx,nz)
  check(math.abs(sx*nx+sz*nz)<1e-10,'outward component removed in all world orientations')
  check(math.abs((-nz*sx+nx*sz)-tangent)<1e-10,'tangent retained')
  check(sx*sx+sz*sz<=x*x+z*z+1e-8,'no energy gain')
  local fx,fz=-nz*sign,nx*sign
  for _,direction in {-1,1} do for _,steer in {-1,1} do
   local yaw=p.escapeSteering(fx,fz,nx,nz,steer,direction)
   check(math.abs(yaw)<=p.SteeringAssist,'bounded player-directed yaw')
   check(yaw==0 or (fz*nx-fx*nz)*yaw*direction<0,'assist only toward interior including reverse')
  end end
 end end
end
for i,a in geometry.points do
 local b=geometry.points[i%#geometry.points+1];local dx,dz=b.x-a.x,b.z-a.z;local length=math.sqrt(dx*dx+dz*dz)
 local nx,nz=dz/length,-dx/length
 local x,z=(a.x+b.x)/2-nx*5,(a.z+b.z)/2-nz*5
 local c,qx,qz=geometry.contact(x,z);local footprint=p.footprint(dx/length,dz/length,qx,qz)
 local d=p.escapeDistance(c,footprint)
 check(d<=3 and d>=0,'small correction bounded including concave seams')
 check(geometry.inside(x-qx*d,z-qz*d,footprint),'complete footprint remains inside')
 check(p.fits(geometry,x-qx*d,z-qz*d,dx/length,dz/length),'all four chassis corners clear every boundary')
end
-- Execute the real stop function with a yielding heartbeat. This models late
-- SeatWeld updates and concurrent lifecycle cancellation, not a duplicate exit implementation.
local source=fs.readFile('src/server/LobbyTestDriveService.luau')
source=source:gsub('return Service%s*$','Service.inject=function(player,record) records[player]=record end; return Service')
local shared={WaitForChild=function(_,name)return {Name=name}end}
local tick,service,scenario=0,nil,nil
local modules={LobbyPracticeCombat=require('./helpers/lobby_practice_stub'),LobbyDrivePolicy=p,LobbyDriveGeometry={create=function()return geometry end},KartConfig={},KartCatalog={},KartVisualFactory={},LobbyDriftSession=training}
local run={Heartbeat={Wait=function()tick+=1;coroutine.yield()end}}
local spawn={CFrame=rb.CFrame.new(0,1,888)}
local hub={FindFirstChild=function()return spawn end}
local workspace={FindFirstChild=function()return hub end}
service=luau.load(source,{environment={script={Parent={LobbyDriftSession={Name='LobbyDriftSession'},LobbyPracticeCombat={Name='LobbyPracticeCombat'}}},game={GetService=function(_,name)
 if name=='ReplicatedStorage' then return {WaitForChild=function()return shared end} elseif name=='RunService' then return run elseif name=='Workspace' then return workspace else return {} end
end},require=function(m)return modules[m.Name]end,Vector3=rb.Vector3,CFrame=rb.CFrame,Enum={HumanoidStateType={GettingUp='GettingUp'}}}})()
for _,mode in {'exit','unseated','duplicate','race','death','respawn','cancel'} do
 tick=0;local attrs={RaceState='GARAGE'};local pivots,destroyed,release=0,0,false
 local character={Parent=true};local player={Parent=true,Character=character,GetAttribute=function(_,k)return attrs[k]end,SetAttribute=function(_,k,v)attrs[k]=v end}
 local root={Parent=true,SetNetworkOwner=function()end,SetNetworkOwnershipAuto=function()end}
 character.FindFirstChild=function()return root end
 character.PivotTo=function(_,cf)check(release and destroyed==1,'return occurs after seat release and destroy');pivots+=1;character.frame=cf end
 local humanoid={Parent=true,Health=100,ChangeState=function()end}
 local seat={Occupant=humanoid};humanoid.SeatPart=seat
 local body={Parent=true};local kart={Parent=true,Destroy=function(self)destroyed+=1;self.Parent=nil;humanoid.SeatPart=nil;seat.Occupant=nil;release=true end}
 local record={body=body,kart=kart,seat=seat,character=character,humanoid=humanoid}
 service.inject(player,record)
 local first=coroutine.create(function()service.stop(player,mode,true)end)
 check(coroutine.resume(first),'exit starts')
 check(pivots==0 and destroyed==0 and attrs.LobbyDrivePending,'waits for release before return')
 local other
 if mode=='duplicate' or mode=='cancel' then other=coroutine.create(function()service.stop(player,'second',mode~='cancel')end);check(coroutine.resume(other),'concurrent stop starts') end
 if mode=='race' then attrs.KDMRoutePending='RACE_LAUNCH' elseif mode=='death' then humanoid.Health=0 elseif mode=='respawn' then player.Character={} end
 humanoid.SeatPart=nil;seat.Occupant=nil;release=true
 while coroutine.status(first)~='dead' do check(coroutine.resume(first),'exit completes') end
 if other then while coroutine.status(other)~='dead' do check(coroutine.resume(other),'duplicate completes') end end
 local expected=if mode=='race' or mode=='death' or mode=='respawn' or mode=='cancel' then 0 else 1
 check(pivots==expected,'only live same-character normal exits return')
 check(destroyed==1 and not attrs.LobbyDriveActive and not attrs.LobbyDrivePending,'one cleanup, settled flags')
 service.stop(player,'arbitrary',true);check(pivots==expected,'arbitrary Stop without valid session cannot teleport')
end
print('PASS: '..n..' A2 speed, world-normal slide, footprint escape, real yielding exit checks')
