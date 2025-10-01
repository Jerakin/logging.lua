---@class record
---@field name string
---@field level number
---@field pathname string
---@field lineno number
---@field msg string

---@class handler
---@field handle fun(record: record): nil
---@field name string
---@field formatter fun(record: record): string

---@class logger
---@field debug fun(...): nil
---@field info fun(...): nil
---@field warning fun(...): nil
---@field error fun(...): nil
---@field critical fun(...): nil
---@field propagate boolean If this logger should propegate to parent loggers
---@field set_level fun(name_or_level: number|string): nil
---@field get_level fun(): number
---@field add_handler fun(handler: handler): nil
---@field remove_handler fun(name: string): boolean

---@class logging_module: logger
---@field DEBUG number
---@field INFO number
---@field WARNING number
---@field ERROR number
---@field CRITICAL number
---@field get_logger fun(name?: string): logger


---@type logging_module
local logging = {
	__HOMEPAGE = 'https://github.com/Jerakin/logging.lua',
	__DESCRIPTION = "Complex enough logging library." ,
	__VERSION = '0.1.0',
}

logging.DEBUG = 10
logging.INFO = 20
logging.WARNING = 30
logging.ERROR = 40
logging.CRITICAL = 50

local __levels = {
	debug = logging.DEBUG,
	info = logging.INFO,
	warning = logging.WARNING,
	error = logging.ERROR,
	critical = logging.CRITICAL,
}

local __level_to_name = {
	[logging.DEBUG] = "debug",
	[logging.INFO] = "info",
	[logging.WARNING] = "warning",
	[logging.ERROR] = "error",
	[logging.CRITICAL] = "critical",
}
local __root
local __loggers = {}

local __lua_tostring = tostring
local __lua_string_gmatch = string.gmatch
local __lua_table_insert = table.insert
local __lua_math_floor = math.floor
local __lua_math_ceil = math.ceil

local __string_split = function(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in __lua_string_gmatch(inputstr, "([^"..sep.."]+)") do
		__lua_table_insert(t, str)
	end
	return t
end


local __round = function(x, increment)
	increment = increment or 1
	x = x / increment
	return (x > 0 and __lua_math_floor(x + 0.5) or __lua_math_ceil(x - 0.5)) * increment
end

local __tostring = function(...)
	local t = {}
	for i = 1, select("#", ...) do
		local x = select(i, ...)
		if type(x) == "number" then
			x = __round(x, 0.01)
		end
		t[#t + 1] = __lua_tostring(x)
	end
	return table.concat(t, " ")
end

local function __set_logging_level(t, name_or_level)
	local var_type = type(name_or_level)
	if var_type == "string" then
		local new_level = __levels[name_or_level]
		assert(new_level ~= nil, "Not a valid logging level: " .. name_or_level)
		t["_level"] = new_level
	elseif var_type == "number" then
		t["_level"] = name_or_level
	else
		assert(false, "Not a valid logging level: " .. name_or_level)
	end
end


local function __default_formatter(record)
	local lineinfo = record.pathname .. ":" .. record.lineno
	return string.format("[%s] [%s] %s: %s", __level_to_name[record.level]:upper(), record.name, lineinfo, record.msg)
end

local __print_handler = {
	name = "print_handler",
	handle = function(self, record)
		local formatter = self.formatter or __default_formatter
		print(formatter(record))
	end
}


-- Example file handler
local __file_handler = {
	name = "file_handler",
	_file_path = nil,
	handle = function(self, record)
		if self._file_path == nil then
			return
		end
		local lineinfo = record.pathname .. ":" .. record.lineno
		local fp = io.open(self._file_path, "a")
		local str = string.format("[%s] [%s] %s: %s", __level_to_name[record.level]:upper(), record.name, lineinfo, record.msg)
		if fp ~= nil then
			fp:write(str)
			fp:close()
		end
	end
}

local __logger = {}
__logger.__index = __logger

function __logger.new(name, parent)
	local self = setmetatable({}, __logger)
	self._level = logging.DEBUG
	self.propagate = true
	self._name = name
	self.parent = parent
	self._handlers = {
	}
	for log_name, log_level in pairs(__levels) do
		self[log_name] = function(...)

			local msg = __tostring(...)
			local record = self:_make_record(msg, log_level)
			self:_emit(record)
		end
	end

	return self
end
function __logger:_make_record(message, log_level)
	local info = debug.getinfo(3, "Sl")
	local record = {
		name = self._name,
		level = log_level,
		pathname = info.short_src,
		lineno = info.currentline,
		msg=message
	}
	return record
end

function __logger:_emit(record)
	if record.level < self._level then
		return
	end
	if self.parent and self.propagate then
		__loggers[self.parent]:_emit(record)
	end
	for _, handler in ipairs(self._handlers) do
		handler:handle(record)
	end
end

function __logger:set_level(name_or_level)
	__set_logging_level(self, name_or_level)
end

function __logger:get_level()
	return self._level
end

function __logger:add_handler(handler)
	assert(handler.name ~= nil, "Handler name required")
	assert(handler.handle ~= nil, "Handler requires a handle function")
	table.insert(self._handlers, handler)
end

function __logger:remove_handler(name_)
	for index, _handler in pairs(self._handlers) do
		if _handler.name == name_ then
			table.remove(self._handlers, index)
			return true
		end
	end
	return false
end


local __parent_child_relasionship = {

}

local function __update_child_parent_relasionship(name)
	__parent_child_relasionship[name] = "root"
	local name_hierarchy = __string_split(name, ".")

	for _=#name_hierarchy, 1, -1 do
		table.remove(name_hierarchy, #name_hierarchy)
		local parent = table.concat(name_hierarchy, ".")
		if __parent_child_relasionship[parent] then
			__parent_child_relasionship[name] = parent
			__loggers[name].parent = parent
			break
		end
	end

	local updated_relationships = {}
	for child, _ in pairs(__parent_child_relasionship) do
		local child_split = __string_split(child, ".")
		for i = #child_split, 1, -1 do
			local child_ =  table.concat({unpack(child_split, 1, i)}, ".")
			if __parent_child_relasionship[child_] and child_ ~= child and child ~= name then
				updated_relationships[child] = child_
				__loggers[child].parent = child_
				break
			end
		end
	end

	for k, v in pairs(updated_relationships) do
		__parent_child_relasionship[k] = v
		__loggers[k].parent = v
	end
end

---@param name string Name of the logger.
function logging.get_logger(name)
	local logger = __loggers[name]
	if logger ~= nil then
		return logger
	end

	if name == nil or name == "" then
		return __root
	end
	__loggers[name] = __logger.new(name, "root")
	__update_child_parent_relasionship(name)
	return __loggers[name]
end


-- Setup root logger
__root = __logger.new("root")
__loggers["root"] = __root
__root._level = logging.DEBUG
__root:add_handler(__print_handler)
setmetatable(logging, {__index = function(_, key)
	return __root[key]
end})

return logging
