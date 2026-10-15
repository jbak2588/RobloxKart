-- Store inventory is separate from the four temporary race slots.
return table.freeze({
 WingId='KDM_V2_WING',WingPrice=25000,
 Order=table.freeze({'Nitro','Shield','Slick','Missile','Smoke','Thunder'}),
 Prices=table.freeze({Nitro=250,Shield=250,Slick=250,Missile=250,Smoke=250,Thunder=250}),
 MaxStock=999,MaxRoundRefills=2,MaxItemRoundRefills=1,
})
