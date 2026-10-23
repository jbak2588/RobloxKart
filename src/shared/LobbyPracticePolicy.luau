-- Practice-only fleet and item policy; official race capacity is independent.
return table.freeze({
 Items=table.freeze({"Nitro","Slick","Shield","Missile","Smoke","Thunder"}),
 RefillSeconds=6, UseInterval=.25, TargetRange=180, ForwardDot=.15,
 ParkBotTargetRange=480, -- Long RookieLoop demonstration only; PvP/legacy stay 180.
 BotSyncSeconds=.10,
 BotFleet=table.freeze({
  { id = 1, delay = 0, kartId = "Kart05", name = "PRACTICE BOT 1", driverColor = Color3.fromRGB(35, 155, 240) },
  { id = 2, delay = 30, kartId = "Kart06", name = "PRACTICE BOT 2", driverColor = Color3.fromRGB(220, 45, 45) },
  { id = 3, delay = 60, kartId = "Kart08", name = "PRACTICE BOT 3", driverColor = Color3.fromRGB(250, 200, 45) },
  { id = 4, delay = 90, kartId = "Kart07", name = "PRACTICE BOT 4", driverColor = Color3.fromRGB(240, 240, 240) },
  { id = 5, delay = 120, kartId = "Kart09", name = "PRACTICE BOT 5", driverColor = Color3.fromRGB(55, 100, 210) },
  { id = 6, delay = 150, kartId = "Kart10", name = "PRACTICE BOT 6", driverColor = Color3.fromRGB(225, 95, 165) },
  { id = 7, delay = 180, kartId = "Kart11", name = "PRACTICE BOT 7", driverColor = Color3.fromRGB(35, 40, 48) },
 }),
})
