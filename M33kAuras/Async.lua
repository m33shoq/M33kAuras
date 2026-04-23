local GlobalAddonName = ...

---@class AddonDB
local AddonDB = select(2, ...)

local CopyTable = CopyTable
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local SafePack = SafePack
local SafeUnpack = SafeUnpack
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local coroutine_yield = coroutine.yield
local debugprofilestop = debugprofilestop
local debugstack = debugstack
local geterrorhandler = geterrorhandler
local ipairs = ipairs
local ipairs_reverse = ipairs_reverse
local max = math.max
local next = next
local setmetatable = setmetatable
local tinsert = tinsert
local tDeleteItem = tDeleteItem
local type = type
local xpcall = xpcall
local IsEncounterInProgress = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress or IsEncounterInProgress

-- FIFO multi stream Async Handler
-- Streams are ran in parallel*(bless for pairs), but each stream is ran in FIFO order

--- @class AsyncConfig
--- @field maxTime number
--- @field maxTimeCombat number
--- @field errorHandler fun(msg: string, stacktrace?: string)
--- @field singleton boolean?
--- @field debug boolean? Enable debug info collection
--- @field name string? Optional name for easier identification

---@class AsyncThreadData
---@field type "AsyncThreadData"
---@field co thread
---@field debugStack string
---@field args any[]?
---@field paused boolean?
---@field parentData AsyncThreadData?
---@field executionTime number
---@field totalYields number?
---@field startTime number
---@field Kill fun(self: AsyncThreadData)
---@field OnSuccess fun(self: AsyncThreadData, func: function) -- fires before finally
---@field Catch fun(self: AsyncThreadData, err: string)
---@field Finally fun(self: AsyncThreadData, func: function)
---@field ForceRun fun(self: AsyncThreadData, maxDuration?: number)

local SLEEP = {}

--- @type AsyncConfig
local defaultConfig = {
	maxTime = 16, -- use 2 for background processing, 16 for low priority, 50 if process needs to be done asap
	maxTimeCombat = 2,
	errorHandler = geterrorhandler(),
}

local currentThreadData = nil ---@type AsyncThreadData?
AddonDB.AsyncEnvironment = setmetatable({}, {
	__index = function(_, k)
		if not currentThreadData then
			return nil
		end
		if k == "EXECUTION_TIME" then
			return currentThreadData.executionTime
		elseif k == "TOTAL_TIME" then
			return debugprofilestop() - currentThreadData.startTime
		elseif k == "TOTAL_YIELDS" then
			return currentThreadData.totalYields or 0
		end
	end,
})

function AddonDB:IsThread(val)
	return type(val) == "table" and val.type == "AsyncThreadData"
end

local function runThread(threadData, config, finalTime, globalStart)
  while debugprofilestop() < finalTime do
    local co = threadData.co
    if co and coroutine_status(co) ~= "dead" then
      currentThreadData = threadData
      local ok, msg, msg2
      local s = debugprofilestop()
      if threadData.args then
        ok, msg, msg2 = coroutine_resume(co, SafeUnpack(threadData.args))
        threadData.args = nil
      else
        ok, msg, msg2 = coroutine_resume(co)
      end
      currentThreadData = nil

      -- tracking execution time takes about 20% of the whole overhead
      local elapsed = debugprofilestop() - s
      threadData.executionTime = threadData.executionTime + elapsed
      threadData.totalYields = (threadData.totalYields or 0) + 1
      if config.debug then -- debug
        local stack = debugstack(co, 1, 1, 1)
        if not stack or stack == "" then
          stack = "<no stack>"
        end
        threadData.yieldDebugsByTime = threadData.yieldDebugsByTime or {}
        tinsert(threadData.yieldDebugsByTime, {
          time = elapsed,
          stack = stack,
          msg1 = msg,
          msg2 = msg2,
        })
        threadData.yieldDebugsByStack = threadData.yieldDebugsByStack or {}
        threadData.yieldDebugsByStack[stack] = (threadData.yieldDebugsByStack[stack] or 0) + elapsed
      end

      if coroutine_status(co) == "dead" then -- function returned or errored
        if config.debug then
          sort(threadData.yieldDebugsByTime or {}, function(a, b) return a.time > b.time end)
        end
        if threadData.parentData then
          threadData.parentData.args = { ok, msg }
          threadData.parentData.paused = false
        end
        if ok and threadData._onSuccess then
          for _, func in ipairs(threadData._onSuccess) do
            xpcall(func, geterrorhandler(), msg)
          end
        elseif not ok then
          if threadData._onError then
            for _, func in ipairs(threadData._onError) do
              xpcall(func, geterrorhandler(), msg .. "\n" .. debugstack(co) .. threadData.debugStack)
            end
          end
          if config.errorHandler == geterrorhandler() then -- combine full stack if default error handler
            config.errorHandler(msg .. "\n" .. debugstack(co) .. threadData.debugStack)
          else
            config.errorHandler(msg, debugstack(co) .. threadData.debugStack)
          end
        end
        threadData:Kill()
        return false, true -- we need a break to restart ipairs loop
      elseif ok and type(msg) == "table" and msg.type == "AsyncThreadData" then
        --[[
        nested coroutines are supported as replacement for yield inside pcall
        in case we did
        local ok, res|err = coroutine.yield(AddonDB:Async(config, func, ...))
        then we need to pause the thread
        so we can continue it after the yielded thread is finished
        just returning is not supported so we don't do that if coroutine is dead
        ]]
        threadData.paused = true
        msg.parentData = threadData
        break
      elseif ok and msg == SLEEP then
        threadData.sleep = debugprofilestop() + (msg2 or 0)
        return false, true
      end
    elseif threadData.co == nil then
      -- coroutine killed itself
      return false, true
    else
      threadData:Kill() -- shouldn't ever get there?
      error(GlobalAddonName .. ": Async threadData has dead coroutine, this should never happen\n\nThread stack:\n" .. threadData.debugStack)
      return false, true -- we need a break to restart ipairs loop
    end

    if globalStart and ((InCombatLockdown() or IsInInstance()) and (debugprofilestop() - globalStart > 100)) then
      return true
    end
  end
end

local AsyncFrame = CreateFrame("Frame")
local streams = {} ---@type table<AsyncConfig, AsyncThreadData[]>
local threadToConfig = {} ---@type table<AsyncThreadData, AsyncConfig>
AsyncFrame:SetScript("OnUpdate", function(self, elapsed)
	local globalStart = debugprofilestop()
	local hasData = false
	for config, queue in next, streams do
		for i, threadData in ipairs(queue) do
			hasData = true
			if not threadData.paused then
				if threadData.sleep and threadData.sleep > debugprofilestop() then
					break -- we dont want to run this stream while there is sleeping coroutine
				end

				local maxExecutionTime = ((InCombatLockdown() and IsInInstance()) or IsEncounterInProgress()) and config.maxTimeCombat or config.maxTime
				local finalTime = debugprofilestop() + maxExecutionTime
				local shouldReturn, shouldBreak = runThread(threadData, config, finalTime, globalStart)
        if shouldReturn then
          return
        end
        if shouldBreak then
          break
        end
			end
		end
	end
	if not hasData then
		self:Hide()
	end
end)


local function Kill(self)
	local config = threadToConfig[self]
	threadToConfig[self] = nil
	self.co = nil

	if config and streams[config] then
		if self._finally then
			for _, func in ipairs(self._finally) do
				xpcall(func, geterrorhandler(), self)
			end
			self._finally = nil
		end

		tDeleteItem(streams[config], self)
		if #streams[config] == 0 then
			streams[config] = nil
		end
	end
end

local function OnSuccess(self, func)
	if type(func) ~= "function" then
		error(GlobalAddonName .. ": Async OnSuccess func must be a function, got " .. type(func))
	end
	self._onSuccess = self._onSuccess or {}
	tinsert(self._onSuccess, func)
	return self
end

local function Catch(self, func)
	if type(func) ~= "function" then
		error(GlobalAddonName .. ": Async Catch func must be a function, got " .. type(func))
	end
	self._onError = self._onError or {}
	tinsert(self._onError, func)
	return self
end

local function Finally(self, func)
	if type(func) ~= "function" then
		error(GlobalAddonName .. ": Async Finally func must be a function, got " .. type(func))
	end
	self._finally = self._finally or {}
	tinsert(self._finally, func)
	return self
end

local function ForceRun(self, maxDuration)
  local config = threadToConfig[self]
  if not config then
    return
  end
  local finalTime = debugprofilestop() + (maxDuration or math.huge)
  runThread(self, config, finalTime)
end

--- @param config AsyncConfig
--- @param func function
--- @param ... any Optional arguments to pass to the function
--- @return AsyncThreadData
--- @overload fun(self: AddonDB, func: function, ...): AsyncThreadData
function AddonDB:Async(config, func, ...)
	local tconfig, f, overload = type(config), func
	if tconfig == "function" then
		-- if config is a function, treat it as the func and use default config
		f = config
		config = CopyTable(defaultConfig)
		overload = true
	elseif tconfig ~= "table" then
		config = CopyTable(defaultConfig)
	end

	if type(f) ~= "function" then
		error(GlobalAddonName .. ": Async function must be a function, got " .. type(f))
	end
	if type(config) ~= "table" then
		error(GlobalAddonName .. ": Async config must be a table, got " .. type(config))
	end

	if type(config.maxTime) ~= "number" or config.maxTime < 0 then
		config.maxTime = 16
	end

	if type(config.maxTimeCombat) ~= "number" then -- or config.maxTimeCombat < 0
		config.maxTimeCombat = 5
	end

	if type(config.errorHandler) ~= "function" then
		config.errorHandler = geterrorhandler()
	end

	local co = coroutine_create(f)

	--- @type AsyncThreadData
	local data = {
		type = "AsyncThreadData",
		co = co,
		debugStack = "Async start:\n"..debugstack(2),
		args = overload and SafePack(func, ...) or SafePack(...),
		executionTime = 0,
		startTime = debugprofilestop(),
		Kill = Kill,
		OnSuccess = OnSuccess,
		Catch = Catch,
		Finally = Finally,
    ForceRun = ForceRun,
	}
	threadToConfig[data] = config

	if not streams[config] then
		streams[config] = {}
	end

	if config.singleton then
		for i, threadData in ipairs_reverse(streams[config]) do
			threadData:Kill() -- kill all previous threads in the singleton stream
		end
	end

	-- ddt(data, "AsyncThreadData")
	tinsert(streams[config], data)
	AsyncFrame:Show()
  if config.debug then
    if DevTool and DevTool.AddData then
      DevTool:AddData(data, "AsyncThreadData")
    end
  end
	return data
end

local function wrapper(config, func)
	return function(...)
		return AddonDB:Async(config, func, ...)
	end
end


--- We can't annotate that returned function returns AsyncThreadData because luals doesn't support this.
--- Could move to EmmyLua but it sounds like a lot of work
---@generic T: function
---@param config table|T
---@param func T?
---@return T AsyncFunction callable async function
function AddonDB:WrapAsync(config, func)
	local tconfig, f = type(config), func
	if tconfig == "function" then
		-- if config is a function, treat it as the func and use default config
		f = config
		config = CopyTable(defaultConfig)
	elseif tconfig ~= "table" then
		config = CopyTable(defaultConfig)
	end
	return wrapper(config, f)
end

local function wrapperSingleton(config, func)
	local threadData = nil

	return function(...)
		if threadData then
			threadData:Kill()
		end
		threadData = AddonDB:Async(config, func, ...)
		return threadData
	end
end

---@generic T: function
---@param config table|T
---@param func T?
---@return T AsyncFunction callable async function than cancels previous thread when new one is started
function AddonDB:WrapAsyncSingleton(config, func)
	local tconfig, f = type(config), func
	if tconfig == "function" then
		-- if config is a function, treat it as the func and use default config
		f = config
		config = CopyTable(defaultConfig)
	elseif tconfig ~= "table" then
		config = CopyTable(defaultConfig)
	end
	return wrapperSingleton(config, f)
end

function AddonDB:Sleep(ms)
	coroutine_yield(SLEEP, ms)
end

local function testNestedCoroutines()
	local config = true and "" or {
		maxTime = 100,
		maxTimeCombat = 10,
		errorHandler = geterrorhandler()
	}
	local print = function(...) print(GetTime(), ...) end

	AddonDB:Async(config, function()
		print("Parent started")

		local start = debugprofilestop()
		while debugprofilestop() - start < 100 do end

		local asyncData = AddonDB:Async(config, function()
			print("Child started")
			local start = debugprofilestop()
			while debugprofilestop() - start < 200 do end
			local ok, msg = coroutine.yield(AddonDB:Async(config, function()
				print("Child nested async")
				local start = debugprofilestop()
				while debugprofilestop() - start < 100 do end
				print("Child nested async finished")
				return "qwwweeerty"
			end))
			print("Child yielded for nested async to finish", ok, msg)
			error("Child error") -- this will be caught by the parent
			-- next code won't be executed due to the error
			print("Child finished")
			return "wahooo"
		end):OnSuccess(function (arg)
			print("child success", arg)
		end):Finally(function()
			coroutine.yield() -- yield in a callback will error `attempt to yield across metamethod/C-call boundary`
			print("child finally")
			AddonDB:Async(config, function()
				print("child nested finally")
			end)
		end)
		print("Parent yielded for child to finish")
		local ok, res = coroutine.yield(asyncData) -- false, "path...: Child error"
		print("Parent resumed after child finished", ok, res)

		start = debugprofilestop()
		while debugprofilestop() - start < 10 do end

		print("Parent finished")
		return "????????????"
	end):OnSuccess(function (arg)
		print("Parent success", arg)
	end):Finally(function()
		print("Parent finally")
		AddonDB:Async(config, function()
			print("Nested finally")
		end)
	end)
end
-- testNestedCoroutines()
