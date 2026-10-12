-- Server-owned one-account mobile candidate. No client activation path.
return table.freeze({Enabled=true,ExperienceId=10768420544,PlaceId=127925465904803,
 AllowedUserIds=table.freeze({[11700555357]=true}),StoreName="KDM_PlayerProgress_v1",
 RulesetId="KDM_R8A3_RULES_V1",RetryAttempts=3,ShutdownSeconds=20,
 -- User-authorized personal-record reset. Completion marker makes this one-shot.
 ResetUserId=11700555357,ResetId='R8_P2B_MOZZY_20261012',
 -- Stable, short OrderedDataStore scope registry; rules/geometry changes need a new version.
 GeometryTokens=table.freeze({PracticeFigure8V1="F8",PracticeCircuitV1="P1",PrototypeCircuitV2="V2",PrototypeCircuitV2B="V2B",HardCircuitV1="H1"})})
