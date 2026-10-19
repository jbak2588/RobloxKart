-- Appended to the shared Roblox GUI/input fixture by six_item_race_ui_validation.
services.Workspace=object("Workspace")
local itemCamera=object("Camera")
itemCamera.ViewportSize=safeSize
services.Workspace.CurrentCamera=itemCamera
modules.SlickRearPreview={new=function(parent)
	local panel=child(parent,"Frame","SlickRearPreview")
	local visible=false
	return {layout=function() end,isVisible=function() return visible end,
		stop=function() visible=false end,show=function() visible=true end,panel=panel}
end}
child(modulesFolder,"ModuleScript","SlickRearPreview")
child(modulesFolder,"ModuleScript","CombatFeedbackView")
local itemModule=child(modulesFolder,"ModuleScript","RaceItemUiController")
local delayed={}
local itemEnv=table.clone(env)
itemEnv.script=itemModule
local combatNow=0
itemEnv.time=function() return combatNow end
modules.CombatFeedbackView=luau.load(fs.readFile("src/client/CombatFeedbackView.luau"),{environment=itemEnv})()
local iconWorker
itemEnv.task={delay=function(seconds,callback) if seconds ~= 12 then table.insert(delayed,callback) end end,
 spawn=function(callback) iconWorker=callback end}
services.ContentProvider={PreloadAsync=function(_,images,callback)
 for _,image in images do callback(image.Image,rb.Enum.AssetFetchStatus.Success) end
end}
child(modulesFolder,"ModuleScript","KDMIconCatalog")
local iconModule=child(modulesFolder,"ModuleScript","KDMItemIconView")
modules.KDMIconCatalog=luau.load(fs.readFile("src/client/KDMIconCatalog.luau"))()
local iconEnv=table.clone(itemEnv);iconEnv.script=iconModule
modules.KDMItemIconView=luau.load(fs.readFile("src/client/KDMItemIconView.luau"),{environment=iconEnv})()
modules.RaceItemUiController=luau.load(fs.readFile("src/client/RaceItemUiController.luau"),
	{environment=itemEnv})()
safeSize=V2.new(1600,739);itemCamera.ViewportSize=safeSize
ui.PreferredInput=rb.Enum.PreferredInput.Touch
player:SetAttribute("RaceState","RACING")
player:SetAttribute("DriftBonusProgress",0)
player:SetAttribute("DriftBonusNitroAwarded",false)
modules.RaceItemUiController.start()
local itemHud=pg.RobloxKartRaceItemHud
