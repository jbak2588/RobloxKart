-- Practice-only presentation/economy. Race tuning and four-slot HUD stay unchanged.
return table.freeze({
 Items=table.freeze({"Nitro","Slick","Shield","Missile","Smoke","Thunder"}),
 RefillSeconds=6, UseInterval=.25, TargetRange=180, ForwardDot=.15,
 ParkBotTargetRange=480, -- Long RookieLoop demonstration only; PvP/legacy stay 180.
 BotSyncSeconds=.10,
})
