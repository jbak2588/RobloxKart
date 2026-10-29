local WS=game:GetService('Workspace')
while WS:GetAttribute('KDMServerRole')==nil do WS:GetAttributeChangedSignal('KDMServerRole'):Wait()end
require(script.Parent:WaitForChild('HubLeaderboardService')).start()
