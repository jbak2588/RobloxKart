-- Permanent color-specific karts; historical Wing buyers retain all seven.
local C={
 WingId='KDM_V2_WING',WingPrice=25000,KartPrice=50000,
 KartOrder=table.freeze({'Kart05','Kart06','Kart07','Kart08','Kart09','Kart10','Kart11'}),
 Order=table.freeze({'Nitro','Shield','Slick','Missile','Smoke','Thunder'}),
 Prices=table.freeze({Nitro=5000,Shield=2500,Slick=2500,Missile=4000,Smoke=2500,Thunder=3500}),
 PaidItemUseEnabled=false,
 MaxStock=999,MaxRoundRefills=2,MaxItemRoundRefills=1,
}
function C.kartEntitlement(id)
 return if table.find(C.KartOrder,id) then 'KDM_V2_KART_'..id else nil
end
function C.ownsKart(parts,id)
 local entitlement=C.kartEntitlement(id)
 return entitlement~=nil and (parts[entitlement]==true or parts[C.WingId]==true)
end
function C.playerOwnsKart(player,id)
 return C.kartEntitlement(id)~=nil and player:GetAttribute('KDMOwned'..id)==true
end
return table.freeze(C)
