-- Real API shape, injected dependencies. Constructor never looks up a live service.
local Adapter={}
function Adapter.new(deps)
 assert(deps.authorize and deps.getStore and deps.getOptions and deps.budget,"adapter_dependencies_required")
 local store=nil
 local api={}
 local function access(kind)
  if not deps.authorize() then return nil,"ACCESS_BLOCKED" end
  if not deps.budget(kind) then return nil,"BUDGET_UNAVAILABLE" end
  if not store then
   local ok,value=pcall(deps.getStore)
   if not ok or not value then return nil,"STORE_UNAVAILABLE" end
   store=value
  end
  return store
 end
 local function classify(key,value)
  if value==nil then return {status="ABSENT",key=key} end
  if type(value)=="table" and type(value.schemaVersion)=="number" and value.schemaVersion>1 then return {status="FUTURE",key=key,value=value} end
  local valid,reason=deps.schema.validate(value,key)
  return {status=if valid then "FOUND" else "CORRUPT",key=key,value=value,reason=reason}
 end
 function api.read(key)
  if key~=deps.key then return {status="ERROR",key=key,reason="WRONG_USER_KEY"} end
  local backend,reason=access("read")
  if not backend then return {status="ERROR",key=key,reason=reason} end
  local options=deps.getOptions();assert(options.UseCache==false,"uncached_read_required")
  local ok,value=pcall(function() return backend:GetAsync(key,options) end)
  if not ok then return {status="ERROR",key=key,reason="READ_UNAVAILABLE"} end
  return classify(key,value)
 end
 function api.beginUpdate(key,callback)
  assert(key==deps.key and type(callback)=="function","invalid_update_scope")
  return {key=key,callback=callback,consumed=false}
 end
 function api.commit(transaction)
  assert(not transaction.consumed,"transaction_consumed");transaction.consumed=true
  if transaction.key~=deps.key then return {status="READ_ONLY",reason="WRONG_USER_KEY"} end
  local backend,reason=access("write")
  if not backend then return {status="PENDING",reason=reason} end
  local outcome=nil
  local ok,value=pcall(function()
   return backend:UpdateAsync(transaction.key,function(previous,keyInfo)
    -- Recheck authorization on every platform callback replay; never yield here.
    if not deps.authorize() then outcome="ACCESS_BLOCKED";return nil end
    if previous~=nil then
     local read=classify(transaction.key,previous)
     if read.status~="FOUND" then outcome=read.status;return nil end
    end
    local nextValue,result=transaction.callback(previous);outcome=result
    if nextValue==nil then return nil end
    local valid=deps.schema.validate(nextValue,transaction.key)
    if not valid then outcome="CORRUPT";return nil end
    return nextValue,if keyInfo then keyInfo:GetUserIds() else nil,if keyInfo then keyInfo:GetMetadata() else nil
   end)
  end)
  if not ok then return {status="PENDING",reason="UPDATE_OUTCOME_UNKNOWN"} end
  if value==nil then return {status=outcome or "PENDING",reason=outcome or "UPDATE_CANCELLED"} end
  -- Only a write response. Runtime performs uncached receipt/current-selection read-back.
  return {status="SAVED",value=value,outcome=outcome}
 end
 return api
end
return table.freeze(Adapter)
