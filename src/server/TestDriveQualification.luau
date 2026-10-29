-- Retired 2026-10-30. TIME ATTACK rewards require a server-verified 2-lap finish.
-- Kept as an inert internal compatibility module; no duration/distance qualification.
local Q={}
function Q.new()return {}end
function Q.step()return false end
function Q.proof()return nil end
return table.freeze(Q)
