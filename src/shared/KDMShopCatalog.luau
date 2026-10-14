-- Store inventory is separate from the four temporary race slots.
return table.freeze({
 WingId='KDM_V2_WING',WingPrice=3000,
 Order=table.freeze({'Nitro','Shield','Slick','Missile','Smoke','Thunder'}),
 Prices=table.freeze({Nitro=25,Shield=30,Slick=15,Missile=35,Smoke=20,Thunder=40}),
 MaxStock=999,MaxRoundRefills=2,MaxItemRoundRefills=1,
})
