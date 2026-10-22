-- Server-only selection persistence; public-user rollout approved by owner.
return table.freeze({
 Enabled=true,
 AllowAllUsers=true, -- Exact public HUB IDs and valid user IDs still required.
 ExperienceId=10768420544,
 PlaceId=127925465904803,
 StoreName="KDM_PlayerProgress_v1",
 AllowedUserIds=table.freeze({[11700555357]=true}), -- Roblox-resolved mozzy_hni, user-approved
 LoadTimeoutSeconds=5,
 RetryAttempts=3,
 DepartureDrainSeconds=8,
 ShutdownDrainSeconds=20,
})
