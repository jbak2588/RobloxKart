-- Fixed grants; clients may select a product, never an amount or balance.
local C={ExperienceId=10768420544,PlaceId=127925465904803}
C.Order=table.freeze({'Cash25000','Cash60000'})
C.Entries=table.freeze({
 Cash25000=table.freeze({ProductId=3723936705,Amount=25000,BaseRobux=50}),
 Cash60000=table.freeze({ProductId=3723937538,Amount=60000,BaseRobux=100}),
})
function C.byProductId(id)
 if type(id)~='number' or id<=0 then return nil end
 for key,entry in C.Entries do if entry.ProductId==id then return entry,key end end
 return nil
end
return table.freeze(C)
