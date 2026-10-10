-- Exact PV545 two-field inverse for two preserved historical assertions only.
-- H3's first Catalog read is its byte freeze; later UI/route reads stay current.
local fs, luau, serde, process = require('@lune/fs'), require('@lune/luau'), require('@lune/serde'), require('@lune/process')
local catalogPath = 'src/shared/TrackCatalog.luau'
local currentHash = '2febe32cea59b45e884b879f334b148e398d43268f158eacd5dff57ea6d65f3e'
local baselineHash = '2a8e4d35d1c98320c8a848616906d794d139b484bcb64b8b173675723a2848ef'
local targets = {
 ['tests/track02_raceability_b_validation.luau'] = '0072527232cc46609cbcd3b66a7868c22b1f3b3a4e92a3b597cc8028775aaa3a',
 ['tests/track_h3_flow_validation.luau'] = '6c2d9fa789f245d3160e3a5998b30519ea724ad0281b3e1bbe62a8bfacca6554',
}
local function normalized(source) return source:gsub('\r\n', '\n') end
local function inverse(source)
 source = normalized(source)
 assert(serde.hash('sha256', source) == currentHash, 'unexpected published Catalog source')
 local count
 source, count = source:gsub('GeometryId = "PrototypeCircuitV2B"', 'GeometryId = "PrototypeCircuitV2"')
 assert(count == 1, 'ambiguous Geometry binding')
 source, count = source:gsub('DisplayName = "Prototype V2B TEST"', 'DisplayName = "Prototype V2 Track"')
 assert(count == 1, 'ambiguous display name')
 assert(serde.hash('sha256', source) == baselineHash, 'Catalog inverse differs from baseline')
 return source
end
local current = fs.readFile(catalogPath)
inverse(current)
for _, changed in {current .. '\n-- unauthorized', '-- unauthorized\n' .. current,
 current:gsub('PrototypeCircuitV2B', 'UnapprovedGeometry'), current:gsub('Prototype V2B TEST', 'Unapproved name')} do
 assert(not pcall(inverse, changed), 'Catalog mutation escaped')
end
if process.args[1] == '--self-test' then print('PASS: exact Catalog inverse and mutation rejection'); return end
local target = process.args[1]
assert(targets[target], 'unreviewed historical target')
local source = fs.readFile(target)
assert(serde.hash('sha256', normalized(source)) == targets[target], 'historical assertion source changed')
local reads = 0
local proxy = setmetatable({readFile = function(path)
 local result = fs.readFile(path)
 if path == catalogPath then
  reads += 1
  inverse(result) -- Check exact current bytes on every read.
  if reads == 1 then return inverse(result) end
 end
 return result
end}, {__index = fs})
local function req(name)
 if name == '@lune/fs' then return proxy end
 if name:sub(1,1) == '.' then return require('../../tests/' .. name) end
 return require(name)
end
luau.load(source, {environment = {require = req}})()
assert(reads >= 1, 'historical Catalog assertion did not run')
assert(target ~= 'tests/track_h3_flow_validation.luau' or reads >= 2, 'H3 current-source UI path did not run')
print('PASS: preserved historical assertion; H3 subsequent UI/route reads use actual PV545 Catalog')
