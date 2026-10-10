-- Server-only deployment candidate. Enabling requires a separate live-access approval.
return table.freeze({
 Enabled=true, -- L1 candidate only; no live access or publication in this task.
 ExperienceId=10768420544,
 PlaceId=127925465904803,
 StoreName="KDM_PlayerProgress_v1",
 AllowedUserIds=table.freeze({[11700555357]=true}), -- Roblox-resolved mozzy_hni, user-approved
 LoadTimeoutSeconds=5,
 RetryAttempts=3,
 DepartureDrainSeconds=8,
 ShutdownDrainSeconds=20,
})
