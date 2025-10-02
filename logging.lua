---@class record
---@field name string
---@field level number One of the logging levels
---@field pathname string
---@field lineno number
---@field msg string

---@class handler
---@field name string
---@field level number One of the logging levels
---@field handle fun(self: handler, record: record): nil
---@field formatter? fun(self:handler, record: record): string

---@class logging
local logging = {
	__HOMEPAGE = "https://github.com/Jerakin/logging.lua",
	__DESCRIPTION = "Complex enough logging library.",
	__VERSION = "0.1.0",
}

---@type table<string, handler> The library provided handlers
logging.handlers = {}

logging.NOTSET = 0
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
	for str in __lua_string_gmatch(inputstr, "([^" .. sep .. "]+)") do
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
		t.level = new_level
	elseif var_type == "number" then
		t.level = name_or_level
	else
		assert(false, "Not a valid logging level: " .. name_or_level)
	end
end

local function __default_formatter(record)
	local lineinfo = record.pathname .. ":" .. record.lineno
	return string.format("%s:%s: %s: %s", logging.get_level_name(record.level):upper(), record.name, lineinfo, record.msg)
end

local function __record_factory(name, level, message)
	local info = debug.getinfo(3, "Sl")
	local record = {
		name = name,
		level = level,
		pathname = info.short_src,
		lineno = info.currentline,
		msg = message,
	}
	return record
end

----------------------------- Handlers --------------------------------------

logging.handlers.io_handler = {
	name = "io_handler",
	level = logging.NOTSET,
	handle = function(self, record)
		if self.level ~= logging.NOTSET and record.level < self.level then
			return
		end

		local formatter = self.formatter or __default_formatter
		io.stdout:write(formatter(record), "\n")
		io.stdout:flush()
	end,
}


logging.handlers.print_handler = {
	name = "print_handler",
	level = logging.NOTSET,
	handle = function(self, record)
		if self.level ~= logging.NOTSET and record.level < self.level then
			return
		end

		local formatter = self.formatter or __default_formatter
		print(formatter(record))
	end,
}

-- Example file handler
logging.handlers.file_handler = {
	name = "file_handler",
	file_path = nil,
	level = logging.NOTSET,
	handle = function(self, record)
		if self.level ~= logging.NOTSET and record.level < self.level then
			return
		end
		if self.file_path == nil then
			return
		end

		local formatter = self.formatter or __default_formatter
		local fp = io.open(self.file_path, "a")
		local str = formatter(record)
		if fp ~= nil then
			fp:write(str)
			fp:close()
		end
	end,
}

------------------------------- Logger factory -------------------------------

---@class logger
---@field name string Name this logger was constructed with. READONLY
---@field parent string Name of the parent logger. READONLY
---@field propagate boolean If this logger should propegate to parent logger
---@field handlers table<number, handler> Table of handlers. READONLY
---@field level number A logging level. READONLY
---@field debug fun(...): nil
---@field info fun(...): nil
---@field error fun(...): nil
---@field warning fun(...): nil
---@field critical fun(...): nil
local __logger = {}
__logger.__index = __logger

function __logger.new(name, parent)
	local self = setmetatable({}, __logger)
	self.level = logging.NOTSET
	self.propagate = true
	self.name = name
	self.parent = parent
	self.handlers = {}
	for log_name, log_level in pairs(__levels) do
		self[log_name] = function(...)
			local msg = __tostring(...)
			local record = __record_factory(self.name, log_level, msg)
			self:_emit(record)
		end
	end

	return self
end

---@param record record
function __logger:_emit(record)
	if self.level ~= logging.NOTSET and record.level < self.level then
		return
	end
	if self.parent and self.propagate then
		__loggers[self.parent]:_emit(record)
	end
	for _, handler in ipairs(self.handlers) do
		handler:handle(record)
	end
end

---@param name_or_level string|number Logging level, either the string representation or number. logging.DEBUG or "DEBUG".
function __logger:set_level(name_or_level)
	__set_logging_level(self, name_or_level)
end

---@param handler handler
function __logger:add_handler(handler)
	assert(handler.name ~= nil, "Handler name required")
	assert(handler.handle ~= nil, "Handler requires a handle function")
	table.insert(self.handlers, handler)
end

---@param name string
function __logger:remove_handler(name)
	for index, _handler in pairs(self.handlers) do
		if _handler.name == name then
			table.remove(self.handlers, index)
			return true
		end
	end
	return false
end

-------------------------- Child to Parent Cache ----------------------------

local __parent_child_relasionship = {}

local function __update_child_parent_relasionship(name)
	__parent_child_relasionship[name] = "root"
	local name_hierarchy = __string_split(name, ".")

	for _ = #name_hierarchy, 1, -1 do
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
			local child_ = table.concat({ unpack(child_split, 1, i) }, ".")
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

------------------------------ Public Method --------------------------------

---@param name? string Name of the logger, pass nil to get the root logger.
---@return logger
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

---@param formatter fun(record: record): string
function logging.set_default_formatter(formatter)
	assert(type(formatter == "function"), "Formatter should be a function")
	__default_formatter = formatter
end

---@return fun(record: record): string
function logging.get_default_formatter()
	return __default_formatter
end

---@param level number A logging level, such as logging.DEBUG
---@return string
function logging.get_level_name(level)
	return __level_to_name[level]
end


local __name_cache = {}

---Generate name a name depending on the file calling this method.
---@return string
function logging.logger_name()
	local debuginfo = debug.getinfo(2, "S")
	local current_script_path = debuginfo.short_src

	if __name_cache[current_script_path] then
		return __name_cache[current_script_path]
	end
	local name = string.gsub(current_script_path, "\\", ".")
	name = string.match(name, "(.*)%..*$")
	name = string.match(name, "%W+(.*)")
	__name_cache[current_script_path] = name
	return name
end


function logging.debug(...)
	__root.debug(...)
end

function logging.info(...)
	__root.info(...)
end

function logging.warning(...)
	__root.warning(...)
end

function logging.error(...)
	__root.error(...)
end

function logging.critical(...)
	__root.critical(...)
end

-- Setup root logger
__root = __logger.new("root")
__loggers["root"] = __root
__root:add_handler(logging.handlers.io_handler)

return logging
