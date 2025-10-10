# logging.lua
> Complex enough logging library for Lua


# Installation
Drop the [logging.lua](logging.lua) file into your project.

# Usage
The library is focused on (hierarchial) named loggers. To get started you need to get a logger passsing in a name. The name should be a dot separated string. A good rule of thumb is that the name should be set to the same name the file would normally be required with.
```lua
-- myapp.lua
local mymodule = require "myapp.mymodule"

local logging = require "logging"

local logger = logging.get_logger("myapp.mymodule")

logger:debug("Start")
mymodule.my_fun()
logger:debug("Stop")
```
```lua
-- myapp.mymodule.lua
local logging = require "logging"

local logger = logging.get_logger("myapp.mymodule")
local M = {}

function M.my_fun()
    logger:debug("Some event")
end

return M
```
Running `myapp.lua` you should see
```
[DEBUG] [myapp] mymodule.lua:5: Start
[DEBUG] [myapp.mymodule] mymodule.lua:5: Some event
[DEBUG] [myapp] mymodule.lua:5: Stop'
```
`logging.lua` uses hierarchial logging. A messeged logged at the module level gets forwarded to higher-level modules, this chains continues until it reaches the highest-level logger - the root logger.

> [!NOTE]
> While you can use the root logger directly this is discourged as that defeats the whole purpose of segmenting your logs into child loggers. However, this does enable the module to be a drop in replacement for other logging libraries.
> ```lua 
> local logging = require "logging"
> logging.debug("Something went wrong")
> -- [DEBUG] [root] mymodule.lua:3: Something went wrong
> ```

### Setting log level.

You set the level on the logging object.

> [!NOTE]
> The library uses both the `.` and `:` annotations. Any methods on the module `logging` uses `.` (this includes the discouraged logging event methods),
any other method is expected to be called through the `:` annotation.

```lua
local logging = require "logging"

local logger = logging.get_logger("mymodule")

logger:set_level(logging.INFO)

logger:debug("Something went wrong")
-- As debug is of a lower level than info, this will not print anything.
```

### Hierarchical logging

The library uses a hierarchical logging system. A logger will forward log calls to its parent logger with the same record, while filtering it on the log level. In practice this means that you can use the parent logger to silence child loggers. This can be especially helpful if you have a particular noisy part of your code that you majority of the time want silenced.

This would also enable you to set a higher level on the root logger effeciantly silencing all logs. Which could be useful in production.
```lua
local logging = require "logging"

logging.get_logger("lib.module"):set_level(logging.INFO)

local logger = logging.get_logger("lib.module.file")

logger:debug("Something went wrong")
-- As a parent logger has a higher level (INFO) than this child logger is using (DEBUG) this will not print anything.
```


## Handlers
The library uses handlers to display/emit the log. By default a "`io_handler`" is added to the root logger. 
There is also a "`print_handler`" for when `io.stdout` isn't available and a "`file_logger`" that you can 
set up by setting a file name. You can also write your own handlers easily.

To use the file handler you can do something like this.
```lua
local logging = require "logging"

logging.handlers.file_handler.file_path = "my/file/path/log.log"
logging.get_logger().add_handler(logging.handlers.file_handler)
```

Remember, this is a hierarhical logging library. To fully benefit from the file handler you need to add it at the "top most" logger you want to use it with.

Any logger on a child would not be used with a parent. Meaning something like this
```lua
local logging = require "logging"
logging.get_logger().remove_logger("io_handler")
logging.get_logger("foo.bar").add_handler(logging.handlers.io_handler)

logging.get_logger("foo"):debug("Hi from foo")
logging.get_logger("foo.bar"):debug("Hi from foo.bar")
logging.get_logger("foo.bar.baz"):debug("Hi from foo.bar.baz")

```
Would print `Hi from foo.bar` and `Hi from foo.bar.baz` but as `foo` is the parent logger to `foo.bar` which has the handler. The debug statement from `foo` would not be printed.

### Custom Handlers
A handler is simple table. It shoud have a name and a handle function, and can also have a formatter defined. This is a valid handler, a very useless one.
```lua
{
    name = "my-example",
    handle = function() end
}
```

## Formatters
If you are not happy with the formatting you can specify your own formatter. These are specified on the handlers (or as the default handler, used by all library provided handlers if no handler specific formatter exists).

A formatter is a function taking a [record](#record-object) and returning a string.

As an example, you could implement your own colored handler with something like this.
```lua
local logging = require "logging"

local colors = {
  [logging.DEBUG] = "\27[36m",
  [logging.INFO] = "\27[32m",
  [logging.WARNING] = "\27[33m",
  [logging.ERROR] = "\27[31m",
  [logging.CRITICAL] = "\27[35m",
}

local function color_formatter(record)
    local col = colors[record.level]
    local name = logging.get_level_name(record.level)
    local line_info = record.pathname .. ":" .. record.lineno
    return string.format(
        "%s[%s]%s %s: %s",
        col,
        name,
        "\27[0m",
        line_info,
        record.msg
    )
end

logging.handlers.io_handler.formatter = color_formatter
```


# Specifics
## Logging levels

These are the numeric values of each logging level. Normally you do not have to care about these,
they are used internally to compare if even should be emitted. However, if you plan to add your own
logging level then you can use this to see where you would want it. To have it be filtered out and not
filtered out whenever you change the logging level.

If you use [`add_level`](#add_levelnamelevel) to change these beware that if level is already taken by a different logging level
then that logging level will be overwritten. `logging.add_level("warn", 30)` will overwrite the existing `warning` level.
This means that any existing calls to `:warning` will now throw an error.

|name|level|comment|
|---|---|---|
|NOTSET|0|Used to determin if a logging level is not set. Usually can be ignored by a user, but can be used on a handler to log all events.|
|DEBUG| 10 ||
|INFO| 20 ||
|WARNING| 30 ||
|ERROR| 40 ||
|CRITICAL| 50 ||



## Module level
These functions and attributes are defined at a module level.

### `get_logger(name)`
Gets (or creates) the [logger object](#logger-object) with _name_.

### `get_level_name(level)`
Gets the string name (upper case) for the given level.

### `get_default_formatter()`
Gets the default formatter.

### `set_default_formatter(formatter)`
Sets the default _formatter_. The formatter is a function taking a [record](#record-object) and returning a string.

This is mainly useful to change the formatter on the library provided handlers.

### `logger_name()`
Generate a peroid-separated name based on the caller. Enables you to do `logging.get_logger(logging.logger_name())`
to not have to insert the name manually.

### `add_level(name, level)`
Adds a logging level with _name_ with _level_ to all handlers. 

## Logger Object
You always get a logger object with `.get_logger(name)` it is safe (and the intended usage)
to call `.get_logger(name)` with the same name multiple times, it will always return the same
logger object.

The name should be a period-separated hierarchical value, like `foo.bar.baz`. Loggers that are
further down in this chain are children of a logger above it. `foo.bar.baz` is the child logger 
of `foo.bar` which is a child logger of `foo`. A logger named `foo.boo` would also be a child
logger of `foo`. 


### `name`
The loggers name, the same value that is with [`.get_logger()`](#get_loggername).

**This should be treated as READONLY.** Changing this value manually will have undefined behaviour changes.**

### `propagate`
If this attribute is true, events will be passed to the parents handlers, in addition to any handlers attached to this logger.

If this attribute is false, logging messages are not passed to the handlers of parent loggers.

Defaults to `true`

### `level`
The logger objects level.

**This should be treated as READONLY.** Use `set_level()` to change the value.

Defaults to `logging.DEBUG`

### `handlers`
Table of handlers directly attached to this logger.

**This should be treated as READONLY.** Use [`add_hander()`](#add_handlerhandler) and [`remove_handler()`](#remove_handler) to change the value.

Changing this value manually will have undefined behaviour changes.

### `set_level(level)`
Sets the threashold for events in this logger. Events that are of a lower level than _level_ will be ignored;
events will not be handled or passed to the parent.

### `add_handler(handler)`
Add a [_handler_](#hander-object) to this logger.

### `remove_handler(name)`
Remove a logger by _name_ from this logger.

### `debug(...)`
Logs a message with level DEBUG on this logger. Uses a to string method to convert any passed arugments into a string. 

### `info(...)`
Logs a message with level INFO on this logger. Uses a to string method to convert any passed arugments into a string. 

### `warning(...)`
Logs a message with level WARNING on this logger. Uses a to string method to convert any passed arugments into a string. 

### `error(...)`
Logs a message with level ERROR on this logger. Uses a to string method to convert any passed arugments into a string. 

### `critical(...)`
Logs a message with level CRITICAL on this logger. Uses a to string method to convert any passed arugments into a string. 

## Handler object
These are the fields specified on the library provided handlers. A custom handler only needs to implement `name` and `handle`.

You can create your own handler. You are responsible for any logic on your custom handlers, see the default handlers for a reference implementation.

### `name`
Name of the handler.

### `level`
A handle specific level. Will silence events to this handler specifically. 
This can be useful if you have two handlers but only want higher level events recorded in one of them.

### `handle(record)`
Uses the formatter to format the [_record_](#record-object) and then emits it in the approriate way.

### `formatter(record)`
Takes the [_record_](#record-object) and formats it into a string.

## Record object
### `name`
Name of the calling logger.

### `level`
Logging level that was used

### `pathname`
The path to the file causing log event.

### `lineno`
The line number in the file causing the log event.

### `msg`
The supplied message.
