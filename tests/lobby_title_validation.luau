local m=require("./helpers/lobby_title_modules")
local C,S=m.catalog,m.service
local n=0
local function check(v,label)assert(v,label);n+=1 end
local player={UserId=42,DisplayName="Racer",Name="Account"}
local input,author,context,calls
local filter={FilterStringAsync=function(_,text,id,ctx)
 input,author,context=text,id,ctx;calls=(calls or 0)+1
 return {GetNonChatStringForBroadcastAsync=function()return "Filtered Lobby" end}
end}
local kind,title=S.resolve(player,nil)
check(kind=="DEFAULT" and title=="Racer's Lobby","legacy default")
player.DisplayName="";check(select(2,S.resolve(player,"DEFAULT"))=="Account's Lobby","username fallback");player.DisplayName="Racer"
for _,id in C.Order do
 kind,title=S.resolve(player,"PRESET",id,filter)
 check(kind=="PRESET" and title==C.Presets[id],"allowlisted preset "..id)
end
check(calls==nil,"presets never filter")
for _,bad in {"Injected text",{},32} do check(S.resolve(player,"PRESET",bad,filter)==nil,"preset injection rejected") end
check(S.resolve(player,"unknown","text",filter)==nil,"invalid mode")
check(S.resolve(player,false,"text",filter)==nil,"invalid boolean mode")
for _,raw in {" \tHello\r\n Racers  ","한국어 로비",string.rep("🚗",32),string.rep("界",32)} do
 kind,title=S.resolve(player,"CUSTOM",raw,filter)
 check(kind=="CUSTOM" and title=="Filtered Lobby","filtered custom")
 check(author==42 and context=="PublicChat","filter authority/context")
end
check(C.normalize(" \tHello\r\n Racers  ")=="Hello Racers","trim/control whitespace")
check(C.normalize("A\u{3000}B\u{A0}C")=="A B C","unicode whitespace")
check(S.resolve(player,"CUSTOM"," \n\t",filter)=="DEFAULT","blank default")
for _,raw in {string.rep("🚗",33),string.rep("a",33),string.char(255),{},9,string.rep(" ",1025)} do
 local before=calls;check(S.resolve(player,"CUSTOM",raw,filter)==nil and calls==before,"reject before filter")
end
for _,output in {"", "####", " # # ",string.char(255),string.rep("界",33)} do
 filter.FilterStringAsync=function()return {GetNonChatStringForBroadcastAsync=function()return output end}end
 check(S.resolve(player,"CUSTOM","safe",filter)==nil,"unusable filter output")
end
filter.FilterStringAsync=function()error("filter unavailable")end
check(S.resolve(player,"CUSTOM","safe",filter)==nil,"filter exception")
filter.FilterStringAsync=function()return {GetNonChatStringForBroadcastAsync=function()error("broadcast unavailable")end}end
check(S.resolve(player,"CUSTOM","safe",filter)==nil,"broadcast exception")
check(C.publicTitle({hostName="Legacy"})=="Legacy's Lobby","legacy fallback")
check(C.publicTitle({hostName="New",lobbyTitleKind="DEFAULT",lobbyTitle="Old's Lobby"})=="New's Lobby","default host authority")
check(C.publicTitle({hostName="New",lobbyTitleKind="CUSTOM",lobbyTitle="Filtered"})=="Filtered","custom identity")
-- Every source freeze must still reject unauthorized geometry/physics edits.
local inverse=require("./helpers/m1_presentation_freeze")
check(inverse('speed = 70')~=inverse('speed = 80'),"freeze does not mask physics")
check(inverse('Position = Vector3.new(1,2,3)')~=inverse('Position = Vector3.new(2,2,3)'),"freeze does not mask geometry")
print("PASS: "..n.." title Unicode/filter/security and narrow freeze contracts")
