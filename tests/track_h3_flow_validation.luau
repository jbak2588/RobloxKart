local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
-- P1C changes exactly the accepted Practice asset; every other catalog byte stays frozen.
local prior=require('@lune/process').exec('git',{'show','43f84c3e640f44e9c771cae9ac5428ba6b424c6e:src/shared/TrackCatalog.luau'})
assert(prior.ok,'P1B checkpoint available')
local expected,replacements=prior.stdout:gsub('rbxassetid://132968191916633','rbxassetid://75369478362729',1)
local currentCatalogSource=fs.readFile('src/shared/TrackCatalog.luau'):gsub('\r\n','\n')
local approved=require('@lune/process').exec('git',{'show','749f8726bd789997e5cbb6e6f54cca5b6a4a9e01:src/shared/TrackCatalog.luau'})
assert(approved.ok,'P2A1 accepted catalog available')
-- Exact P2B inverse is independently mutation-tested by practice_public_bot_validation.
local inverseSource=fs.readFile('tests/helpers/p2b_track_capability_freeze.luau')
local inverse=luau.load(inverseSource)()
assert(replacements==1 and expected:gsub('\r\n','\n')==inverse(currentCatalogSource),'P1C preview + exact P2B fields only; all other catalog bytes frozen')
-- Exercise the production static card and real catalog in the safe-area GUI harness.
-- Independent H3 builder/orbit validation files remain as preserved-module coverage.
local harness=fs.readFile('tests/garage_transition_validation.luau')
local cut=assert(harness:find('local controller = luau.load',1,true))
local setup=harness:sub(1,cut-1)
local scenario=[=[
modules.TrackGeometry=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment={Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame}})()
modules.TrackCatalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment={CFrame=rb.CFrame}})()
local fallbackCount=0
modules.TrackMapRenderer.create=function(parent)
 local f=child(parent,'Frame','FallbackSilhouette');fallbackCount+=1
 return {destroy=function() f:Destroy();fallbackCount-=1 end}
end
local imageRequests={}
local delayedImages={}
environment.task.delay=function(seconds,callback)
 if seconds==1 then table.insert(delayedImages,callback) end
end
services.ContentProvider.PreloadAsync=function(_,assets,callback)
 check(not imageRequests[assets[1]],'one preload per asset')
 imageRequests[assets[1]]=callback
end
local controller=luau.load(fs.readFile('src/client/GarageUiController.luau'),{environment=environment})()
controller.start()
local gui=playerGui.RobloxKartGarage
local backdrop=gui:FindFirstChild('Frame')
local panel=backdrop.TrackPreview
local image=panel.ImageArea.ApprovedTrackImage
local back,select,ready
for _,v in backdrop:GetChildren() do
 if v.Text=='BACK' then back=v elseif v.Text=='SELECT' then select=v elseif v.Text=='READY' then ready=v end
end
local approved={'rbxassetid://75369478362729','rbxassetid://129972226920253','rbxassetid://104449535838897','rbxassetid://104244063916395'}
local committed=player:GetAttribute('SelectedKartId')
controller.open('TRACKS')
local changedConnections=image:GetPropertyChangedSignal('IsLoaded').count()
local gestureConnections=input.InputChanged.count()
check(gui.Enabled and panel.Visible,'Hub Tracks opens card')
check(image.ScaleType==rb.Enum.ScaleType.Fit and not image.Active,'full image Fit and no drag surface')
for i,id in modules.TrackCatalog.Order do
 check(panel:GetAttribute('TrackId')==id and image.Image==approved[i],'approved asset identity '..id)
 check(panel.TrackInformation.TrackName.Text==modules.TrackCatalog.Entries[id].DisplayName,'catalog name '..id)
 check(panel.TrackInformation.TrackMetadata.Text:find(tostring(modules.TrackCatalog.Entries[id].TargetLaps)..' LAP',1,true),'catalog laps '..id)
 check(panel:GetAttribute('PreviewStatus')=='FALLBACK_2D' and fallbackCount==1,'pending/failed image keeps silhouette '..id)
 image.IsLoaded=true
 check(panel:GetAttribute('PreviewStatus')=='STATIC_IMAGE' and image.Visible and fallbackCount==0,'image completion replaces fallback '..id)
 check(not panel:FindFirstChild('TrackDiorama') and not panel:FindFirstChild('OrbitLeft') and not panel:FindFirstChild('OrbitRight'),'no diorama controls '..id)
 check(runService.RenderStepped.count()==0,'no rendering loop '..id)
 local source=image.Image
 panel.ImageArea.InputBegan:Fire({UserInputType=rb.Enum.UserInputType.Touch,Position=rb.Vector3.zero})
 input.InputChanged:Fire({UserInputType=rb.Enum.UserInputType.Touch,Position=rb.Vector3.new(200,0,0)})
 check(image.Image==source,'drag has no effect '..id)
 if modules.TrackCatalog.Entries[id].MatchType=='PUBLIC_RACE' then
  check(select.Text=='LOBBIES' and panel.TrackInformation.TrackMetadata.Text:find('1–4 PLAYERS',1,true),'public metadata '..id)
  select.Activated:Fire()
  check(remote.lastFire[1]=='Ready' and remote.lastFire[4]==id and panel.Visible,'public keeps existing selected-track Room route '..id)
 else
  check(select.Text=='SELECT' and panel.TrackInformation.TrackMetadata.Text:find('SOLO • 1 PLAYER',1,true),'solo metadata '..id)
  select.Activated:Fire()
  check(not panel.Visible and backdrop.GarageStep.Text=='2 / 2   READY','existing Solo Ready '..id)
  back.Activated:Fire();check(panel.Visible and panel:GetAttribute('TrackId')==id,'Ready Back same Track '..id)
  image.IsLoaded=true
 end
 image.IsLoaded=false
 backdrop.NextChoice.Activated:Fire()
end
for cycle=1,20 do
 image.IsLoaded=false;backdrop.NextChoice.Activated:Fire()
 check(fallbackCount==1 and #panel.ImageArea:GetChildren()==2,'switch bounded objects '..cycle)
 image.IsLoaded=true
 check(fallbackCount==0 and #panel.ImageArea:GetChildren()==1,'loaded image bounded objects '..cycle)
 check(image:GetPropertyChangedSignal('IsLoaded').count()==changedConnections and input.InputChanged.count()==gestureConnections,'no added listeners '..cycle)
end
controller.close();check(fallbackCount==0 and image.Image=='','close releases image/fallback')
image.IsLoaded=false;controller.open('TRACKS');check(fallbackCount==1,'reopen nonblocking fallback')
back.Activated:Fire();check(not gui.Enabled,'Track Back Hub')
local create=modules.TrackMapRenderer.create
modules.TrackMapRenderer.create=function() error('injected silhouette failure') end
controller.open('TRACKS')
check(panel:GetAttribute('PreviewStatus')=='NEUTRAL' and panel.TrackInformation.TrackName.Text~='','both unavailable retain named card')
check(select.Active and back.Visible,'failure does not block navigation')
controller.close();modules.TrackMapRenderer.create=create
for _,spec in {{844,390,0,true},{932,430,47,true},{873,401,62,true},{780,360,47,true},{640,360,0,true},{1280,720,0,false},{1920,1080,0,false},{390,844,0,true}} do
 safeSize=rb.Vector2.new(spec[1]-2*spec[3],spec[2]-58)
 cameraScreenSize=rb.Vector2.new(spec[1],spec[2]);input.TouchEnabled=spec[4]
 camera.ViewportSize=rb.Vector2.new(spec[1]-2*spec[3],spec[2])
 controller.open('TRACKS')
 for _,v in {panel,back,select,backdrop.PreviousChoice,backdrop.NextChoice,panel.TrackInformation.TrackName,panel.TrackInformation.TrackMetadata} do
  local pos=v.AbsolutePosition-gui.AbsolutePosition;local size=v.AbsoluteSize
  check(pos.X>=-.1 and pos.Y>=-.1 and pos.X+size.X<=safeSize.X+.1 and pos.Y+size.Y<=safeSize.Y+.1,'safe card/control '..spec[1]..' '..v.Name)
 end
 check(panel.ImageArea.AbsoluteSize.X/panel.ImageArea.AbsoluteSize.Y>1.7,'large landscape image canvas')
 check(not backdrop.GarageChoice.Visible and not backdrop.GarageDetail.Visible,'metadata only in card')
 local cp,cs=panel.AbsolutePosition,panel.AbsoluteSize
 check(math.abs(back.AbsolutePosition.X-cp.X)<=1 and math.abs(select.AbsolutePosition.X+select.AbsoluteSize.X-cp.X-cs.X)<=1,'card and CTA common bounds')
 check(back.AbsoluteSize==select.AbsoluteSize and math.abs(select.AbsolutePosition.X-back.AbsolutePosition.X-back.AbsoluteSize.X-16)<=1,'equal CTA sizes and 16px gap')
 check(back.AbsolutePosition.Y>=cp.Y+cs.Y and select.AbsolutePosition.Y==back.AbsolutePosition.Y,'CTA below card')
 check(math.abs(panel.ImageArea.AbsoluteSize.X/panel.ImageArea.AbsoluteSize.Y-1672/941)<.01 and image.ScaleType==rb.Enum.ScaleType.Fit,'whole static preview ratio/Fit within raster rounding')
 check(backdrop.PreviousChoice.AbsolutePosition.X+backdrop.PreviousChoice.AbsoluteSize.X<=cp.X and backdrop.NextChoice.AbsolutePosition.X>=cp.X+cs.X,'arrows outside card')
 if spec[1]>spec[2] then
  local lobby=backdrop.ServerPresence
  check(backdrop.NextChoice.AbsolutePosition.X+backdrop.NextChoice.AbsoluteSize.X<=lobby.AbsolutePosition.X,'carousel clears preserved Lobby column')
 end
 if spec[4] and spec[1]>spec[2] then
  local growth=cs.X/panel:GetAttribute('H3BCardBaselineWidth')-1
  check(growth>=.08-.001 and growth<=.12+.001,'mobile enlargement 8-12% '..spec[1]..' actual '..growth)
 end
 print('H3B1 layout '..spec[1]..'x'..spec[2]..' card='..tostring(cs)..' image='..tostring(panel.ImageArea.AbsoluteSize)..' baselineWidth='..panel:GetAttribute('H3BCardBaselineWidth'))
 controller.close()
end
check(player:GetAttribute('SelectedKartId')==committed,'Track browsing preserves committed Kart')
image.IsLoaded=false;controller.open('TRACKS')
local active=image.Image
local fallbackBefore=fallbackCount
for i=1,#delayedImages-1 do delayedImages[i]() end
check(image.Image==active and fallbackCount==fallbackBefore,'stale delayed selections leave current image intact')
for asset,callback in imageRequests do
 if asset~=active then callback(asset,rb.Enum.AssetFetchStatus.Success) end
end
check(panel:GetAttribute('PreviewStatus')=='FALLBACK_2D','stale other asset completion cannot replace current fallback')
imageRequests[active](active,rb.Enum.AssetFetchStatus.Success)
check(panel:GetAttribute('PreviewStatus')=='STATIC_IMAGE' and fallbackCount==0,'CDN success works without IsLoaded event')
controller.close()
for _,callback in delayedImages do callback() end
check(image.Image=='' and fallbackCount==0,'delayed reconciliation cannot reopen closed card')
imageRequests[active](active,rb.Enum.AssetFetchStatus.Success)
check(image.Image=='' and fallbackCount==0,'late completion cannot reopen closed card')
gui:Destroy()
for _,callback in delayedImages do callback() end
imageRequests[active](active,rb.Enum.AssetFetchStatus.Success)
check(image:GetPropertyChangedSignal('IsLoaded').count()==0,'image listener cleanup')
check(runService.RenderStepped.count()==0 and input.InputChanged.count()==0 and input.InputEnded.count()==0,'controller cleanup')
print('PASS: '..count..' H3B static card / catalog / routes / load failure / safe area / 20-switch cleanup checks')
]=]

local env={require=require,print=print,warn=function() end}
luau.load(setup..scenario,{environment=env})()
