local DriverCatalog = {
	DefaultId = "Driver01",
	Order = { "Driver01", "Driver02", "Driver03" },
	Entries = {
		Driver01 = { Id = "Driver01", DisplayName = "Crimson", Theme = Color3.fromRGB(220, 55, 55) },
		Driver02 = { Id = "Driver02", DisplayName = "Azure", Theme = Color3.fromRGB(55, 145, 240) },
		Driver03 = { Id = "Driver03", DisplayName = "Sunburst", Theme = Color3.fromRGB(255, 195, 55) },
	},
}

return table.freeze(DriverCatalog)
