local WS=game:GetService('Workspace')
while WS:GetAttribute('KDMServerRole')==nil do WS:GetAttributeChangedSignal('KDMServerRole'):Wait()end
if WS:GetAttribute('KDMServerRole')=='HUB'then require(script.Parent:WaitForChild('HubLeaderboardController')).start()end
