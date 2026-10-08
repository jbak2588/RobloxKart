local fs,luau=require('@lune/fs'),require('@lune/luau')
local f=luau.load(fs.readFile('src/shared/KDMFinishPresentation.luau'))()
local n=0;local function check(v,label)assert(v,label);n+=1 end
for _,row in {{1,1,'SOLO_CLEAR','RACE COMPLETE'},{2,1,'WINNER','1ST PLACE'},{2,2,'PLACED','2ND PLACE'},
 {3,3,'PLACED','3RD PLACE'},{4,4,'PLACED','4TH PLACE'}} do
 for _,state in {'FINISHING','FINISHED'} do
  local kind,text,profile=f.resolve(state,row[2],row[1])
  check(kind==row[3] and text==row[4] and profile~=nil,'authoritative outcome label')
 end
end
for _,state in {'RACING','PRE_RACE','COUNTDOWN','GARAGE','DNF'} do
 local _,text,profile=f.resolve(state,1,4);check(text=='' and profile==nil,'no premature/failed victory '..state)
end
for _,position in {0,-1,.5,math.huge,0/0,false}do
 check(select(3,f.resolve('FINISHING',position,4))==nil,'invalid place cannot celebrate')
end
for _,total in {0,-1,.5,math.huge,0/0,false}do
 check(select(3,f.resolve('FINISHED',1,total))==nil,'invalid participant count cannot celebrate')
end
check(select(3,f.resolve('FINISHED',3,2))==nil,'place beyond participant count invalid')
local w,p=f.Profiles.WINNER,f.Profiles.PLACED
check(w.PrimaryCount+w.SecondaryCount<=40 and p.PrimaryCount+p.SecondaryCount<=24,'one-shot budgets')
check(w.PrimaryCount>p.PrimaryCount and w.WaveDegrees>p.WaveDegrees and w.WaveSeconds>p.WaveSeconds,'winner hierarchy')
check(not pcall(function()w.PrimaryCount=900 end),'immutable visual profiles')
print('PASS: '..n..' finish outcome/invalid authority/profile budget checks')
